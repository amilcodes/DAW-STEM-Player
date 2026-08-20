import Accelerate
import Foundation

final class TempoEstimator {
    struct Estimate: Equatable, Sendable {
        var bpm: Double
        var confidence: Double
        var beatReferenceTime: Double
    }

    private struct EnvelopePoint {
        var time: Double
        var value: Float
    }

    private let envelopeRate = 100.0
    private let analysisDuration = 12.0
    private let minimumAnalysisDuration = 4.0
    private var pendingSamples: [Float] = []
    private var pendingStartTime: Double?
    private var currentSampleRate = 48_000.0
    private var lastLogEnergy: Float?
    private var lastLogDifference: Float?
    private var envelope: [EnvelopePoint] = []
    private var lastEstimateTime = -Double.infinity
    private var smoothedBPM: Double?

    func reset() {
        pendingSamples.removeAll(keepingCapacity: true)
        pendingStartTime = nil
        lastLogEnergy = nil
        lastLogDifference = nil
        envelope.removeAll(keepingCapacity: true)
        lastEstimateTime = -Double.infinity
        smoothedBPM = nil
    }

    func process(samples: [Float], sampleRate: Double, startTime: Double) -> Estimate? {
        guard !samples.isEmpty, sampleRate > 0 else { return nil }

        if abs(sampleRate - currentSampleRate) > 1 {
            reset()
            currentSampleRate = sampleRate
        }

        if let pendingStartTime {
            let expectedStart = pendingStartTime + Double(pendingSamples.count) / currentSampleRate
            if abs(expectedStart - startTime) > 0.15 {
                reset()
                self.pendingStartTime = startTime
            }
        } else {
            pendingStartTime = startTime
        }

        pendingSamples.append(contentsOf: samples)
        let hopSize = max(64, Int((currentSampleRate / envelopeRate).rounded()))
        var newestEstimate: Estimate?

        while pendingSamples.count >= hopSize, let blockStart = pendingStartTime {
            let block = Array(pendingSamples.prefix(hopSize))
            pendingSamples.removeFirst(hopSize)
            pendingStartTime = blockStart + Double(hopSize) / currentSampleRate

            let pointTime = blockStart + Double(hopSize) / currentSampleRate * 0.5
            envelope.append(EnvelopePoint(time: pointTime, value: onsetValue(for: block)))
            envelope.removeAll { pointTime - $0.time > analysisDuration }

            if pointTime - lastEstimateTime >= 0.5 {
                lastEstimateTime = pointTime
                newestEstimate = estimateTempo()
            }
        }

        return newestEstimate
    }

    private func onsetValue(for samples: [Float]) -> Float {
        var rms: Float = 0
        samples.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            vDSP_rmsqv(base, 1, &rms, vDSP_Length(pointer.count))
        }

        var differences = [Float](repeating: 0, count: max(1, samples.count - 1))
        if samples.count > 1 {
            samples.withUnsafeBufferPointer { source in
                differences.withUnsafeMutableBufferPointer { destination in
                    guard let sourceBase = source.baseAddress, let destinationBase = destination.baseAddress else { return }
                    vDSP_vsub(sourceBase, 1, sourceBase + 1, 1, destinationBase, 1, vDSP_Length(samples.count - 1))
                }
            }
        }

        var differenceRMS: Float = 0
        differences.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            vDSP_rmsqv(base, 1, &differenceRMS, vDSP_Length(pointer.count))
        }

        let logEnergy = log1p(rms * 120)
        let logDifference = log1p(differenceRMS * 180)
        defer {
            lastLogEnergy = logEnergy
            lastLogDifference = logDifference
        }

        guard let lastLogEnergy, let lastLogDifference else { return 0 }
        let energyFlux = max(0, logEnergy - lastLogEnergy)
        let differenceFlux = max(0, logDifference - lastLogDifference)
        return energyFlux + differenceFlux * 0.72
    }

    private func estimateTempo() -> Estimate? {
        guard let first = envelope.first, let last = envelope.last,
              last.time - first.time >= minimumAnalysisDuration else { return nil }

        let raw = envelope.map(\.value)
        let mean = raw.reduce(0, +) / Float(max(1, raw.count))
        let centered = raw.map { max(0, $0 - mean * 0.72) }
        let energy = centered.reduce(0) { $0 + $1 * $1 }
        guard energy > 0.000_01 else { return nil }
        let recentPointCount = min(centered.count, Int(envelopeRate * 2))
        let recentEnergy = centered.suffix(recentPointCount).reduce(0) { $0 + $1 * $1 }
        guard recentEnergy > max(0.000_001, energy * 0.015) else { return nil }

        let minimumLag = Int((60 / 200 * envelopeRate).rounded())
        let maximumLag = min(centered.count / 2, Int((60 / 55 * envelopeRate).rounded()))
        guard maximumLag > minimumLag else { return nil }

        var correlations: [Int: Double] = [:]
        for lag in minimumLag...maximumLag {
            correlations[lag] = normalizedCorrelation(centered, lag: lag)
        }

        var bestLag = minimumLag
        var bestScore = -Double.infinity
        for lag in minimumLag...maximumLag {
            let base = correlations[lag] ?? 0
            let doublePeriod = peakCorrelation(near: lag * 2, radius: 2, correlations: correlations)
            let halfPeriod = peakCorrelation(near: max(minimumLag, lag / 2), radius: 1, correlations: correlations)
            let bpm = 60 * envelopeRate / Double(lag)
            let centerPreference = 1 - min(0.12, abs(bpm - 112) / 1_200)
            let continuity = smoothedBPM.map { 1 - min(0.18, abs($0 - bpm) / 300) } ?? 1
            let score = (base + doublePeriod * 0.62 + halfPeriod * 0.03) * centerPreference * continuity
            if score > bestScore {
                bestScore = score
                bestLag = lag
            }
        }

        guard bestScore > 0.08 else { return nil }
        let refinedLag = parabolicLag(bestLag, correlations: correlations)
        var bpm = 60 * envelopeRate / refinedLag

        if let previous = smoothedBPM {
            let candidates = [bpm / 2, bpm, bpm * 2].filter { 55...200 ~= $0 }
            bpm = candidates.min(by: { abs($0 - previous) < abs($1 - previous) }) ?? bpm
            bpm = previous * 0.78 + bpm * 0.22
        }
        smoothedBPM = bpm

        let period = 60 / bpm
        let reference = phaseReference(period: period, points: envelope)
        let confidence = max(0, min(1, (bestScore - 0.05) / 0.42))
        return Estimate(bpm: bpm, confidence: confidence, beatReferenceTime: reference)
    }

    private func normalizedCorrelation(_ values: [Float], lag: Int) -> Double {
        guard lag > 0, values.count > lag else { return 0 }
        var product = 0.0
        var firstEnergy = 0.0
        var secondEnergy = 0.0
        for index in lag..<values.count {
            let first = Double(values[index])
            let second = Double(values[index - lag])
            product += first * second
            firstEnergy += first * first
            secondEnergy += second * second
        }
        let denominator = sqrt(firstEnergy * secondEnergy)
        return denominator > 0 ? product / denominator : 0
    }

    private func parabolicLag(_ lag: Int, correlations: [Int: Double]) -> Double {
        let left = correlations[lag - 1] ?? correlations[lag] ?? 0
        let center = correlations[lag] ?? 0
        let right = correlations[lag + 1] ?? correlations[lag] ?? 0
        let denominator = left - 2 * center + right
        guard abs(denominator) > 0.000_001 else { return Double(lag) }
        return Double(lag) + 0.5 * (left - right) / denominator
    }

    private func peakCorrelation(near lag: Int, radius: Int, correlations: [Int: Double]) -> Double {
        ((lag - radius)...(lag + radius)).compactMap { correlations[$0] }.max() ?? 0
    }

    private func phaseReference(period: Double, points: [EnvelopePoint]) -> Double {
        guard let first = points.first, let last = points.last else { return 0 }
        let bins = max(8, Int((period * envelopeRate).rounded()))
        var phaseScores = [Double](repeating: 0, count: bins)

        for point in points {
            let offset = point.time - first.time
            let phase = Int((offset / period * Double(bins)).rounded()).quotientAndRemainder(dividingBy: bins).remainder
            phaseScores[max(0, min(bins - 1, phase))] += Double(point.value)
        }

        let bestPhase = phaseScores.indices.max(by: { phaseScores[$0] < phaseScores[$1] }) ?? 0
        var reference = first.time + Double(bestPhase) / Double(bins) * period
        while reference + period <= last.time { reference += period }
        return reference
    }
}
