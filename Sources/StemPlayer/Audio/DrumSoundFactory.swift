import AVFoundation
import Foundation

enum DrumSoundFactory {
    static let sampleRate = 44_100.0
    static let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)!

    static func makeFactoryKit() -> [Int: AVAudioPCMBuffer] {
        Dictionary(uniqueKeysWithValues: (0..<12).map { ($0, makeSound(index: $0)) })
    }

    static func makeSound(index: Int) -> AVAudioPCMBuffer {
        let durations = [0.52, 0.34, 0.09, 0.42, 0.36, 0.28, 0.38, 0.13, 0.70, 0.18, 0.22, 0.30]
        let duration = durations[index % durations.count]
        let frameCount = AVAudioFrameCount(duration * sampleRate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount
        guard let channels = buffer.floatChannelData else { return buffer }

        var random = LCG(seed: UInt64(0xC0FFEE + index * 7_919))
        var previousNoise: Float = 0

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            let normalized = t / duration
            let noise = random.nextFloat() * 2 - 1
            let highNoise = noise - previousNoise * 0.82
            previousNoise = noise
            var sample: Double

            switch index {
            case 0: // Kick
                let frequency = 47 + 118 * exp(-t * 28)
                sample = sin(2 * .pi * frequency * t) * exp(-t * 8.2)
                sample += Double(noise) * exp(-t * 80) * 0.12
            case 1: // Snare
                sample = Double(highNoise) * exp(-t * 13) * 0.72
                sample += sin(2 * .pi * 184 * t) * exp(-t * 17) * 0.30
            case 2: // Closed hat
                sample = Double(highNoise) * exp(-t * 52) * 0.56
                sample += sin(2 * .pi * 7_100 * t) * exp(-t * 58) * 0.12
            case 3: // Open hat
                sample = Double(highNoise) * exp(-t * 9.5) * 0.46
                sample += sin(2 * .pi * 6_400 * t) * exp(-t * 11) * 0.10
            case 4: // Low tom
                let frequency = 91 + 38 * exp(-t * 18)
                sample = sin(2 * .pi * frequency * t) * exp(-t * 10.5) * 0.82
            case 5: // High tom
                let frequency = 164 + 54 * exp(-t * 20)
                sample = sin(2 * .pi * frequency * t) * exp(-t * 13) * 0.76
            case 6: // Clap
                let burst = max(0, sin(2 * .pi * 17 * t))
                sample = Double(highNoise) * exp(-t * 8.5) * (0.24 + burst * 0.50)
            case 7: // Rim
                sample = sin(2 * .pi * 1_860 * t) * exp(-t * 42) * 0.62
                sample += sin(2 * .pi * 760 * t) * exp(-t * 36) * 0.25
            case 8: // Sub
                let frequency = 42 + 18 * exp(-t * 5)
                sample = sin(2 * .pi * frequency * t) * exp(-t * 4.5) * 0.86
            case 9: // Perc A
                sample = sin(2 * .pi * (520 + 310 * normalized) * t) * exp(-t * 20) * 0.58
            case 10: // Perc B
                sample = sin(2 * .pi * (850 - 430 * normalized) * t) * exp(-t * 16) * 0.54
                sample += Double(highNoise) * exp(-t * 32) * 0.18
            default: // Noise hit
                sample = Double(highNoise) * exp(-t * 12) * 0.46
            }

            let softened = tanh(sample * 1.35) * 0.82
            channels[0][frame] = Float(softened)
            channels[1][frame] = Float(softened)
        }

        return buffer
    }

    static func loadAndConvert(url: URL, maximumDuration: Double = 30) throws -> AVAudioPCMBuffer {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let sourceFrames = min(file.length, AVAudioFramePosition(maximumDuration * sourceFormat.sampleRate))
        guard sourceFrames > 0,
              let source = AVAudioPCMBuffer(
                pcmFormat: sourceFormat,
                frameCapacity: AVAudioFrameCount(sourceFrames)
              ) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        try file.read(into: source, frameCount: AVAudioFrameCount(sourceFrames))

        if sourceFormat.sampleRate == format.sampleRate && sourceFormat.channelCount == format.channelCount {
            return source
        }

        guard let converter = AVAudioConverter(from: sourceFormat, to: format) else {
            throw CocoaError(.fileReadUnsupportedScheme)
        }
        let ratio = format.sampleRate / sourceFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(ceil(Double(source.frameLength) * ratio) + 32)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: outputCapacity) else {
            throw CocoaError(.fileReadCorruptFile)
        }

        var served = false
        var conversionError: NSError?
        converter.convert(to: output, error: &conversionError) { _, status in
            if served {
                status.pointee = .endOfStream
                return nil
            }
            served = true
            status.pointee = .haveData
            return source
        }
        if let conversionError { throw conversionError }
        return output
    }
}

private struct LCG {
    var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func nextFloat() -> Float {
        state = 2_862_933_555_777_941_757 &* state &+ 3_037_000_493
        return Float((state >> 33) & 0x7FFF_FFFF) / Float(0x7FFF_FFFF)
    }
}
