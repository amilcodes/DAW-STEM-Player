import AVFoundation
import CoreMedia
import Foundation
import ScreenCaptureKit

final class SystemAudioTempoSync: NSObject, ObservableObject, SCStreamOutput, SCStreamDelegate, @unchecked Sendable {
    enum State: Equatable {
        case idle
        case requestingPermission
        case listening
        case locked
        case failed(String)
    }

    struct ClockSnapshot {
        var bpm: Double
        var confidence: Double
        var beatReferenceTime: Double
        var updatedTime: Double
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var bpm: Double?
    @Published private(set) var confidence = 0.0
    var onFailure: ((String) -> Void)?

    private let estimator = TempoEstimator()
    private let captureQueue = DispatchQueue(label: "dev.amil.stemplayer.system-audio", qos: .userInitiated)
    private let estimatorLock = NSLock()
    private let clockLock = NSLock()
    private var clock: ClockSnapshot?
    private var stream: SCStream?
    private var captureGeneration = UUID()

    var isEnabled: Bool {
        switch state {
        case .idle, .failed: false
        case .requestingPermission, .listening, .locked: true
        }
    }

    var isLocked: Bool { state == .locked && bpm != nil }

    var displayText: String {
        switch state {
        case .idle: "sync off"
        case .requestingPermission: "permission"
        case .listening: "listening"
        case .locked:
            bpm.map { String(format: "%.1f bpm", $0) } ?? "listening"
        case .failed: "sync blocked"
        }
    }

    func start() {
        guard !isEnabled else { return }
        state = .requestingPermission
        bpm = nil
        confidence = 0
        resetEstimator()
        setClock(nil)
        let generation = UUID()
        captureGeneration = generation

        Task { [weak self] in
            guard let self else { return }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                guard self.captureGeneration == generation else { return }
                guard let display = content.displays.first else {
                    throw CaptureFailure.noDisplay
                }

                let ownBundleIdentifier = Bundle.main.bundleIdentifier
                let excludedApplications = content.applications.filter {
                    $0.bundleIdentifier == ownBundleIdentifier
                }
                let filter = SCContentFilter(
                    display: display,
                    excludingApplications: excludedApplications,
                    exceptingWindows: []
                )
                let configuration = SCStreamConfiguration()
                configuration.width = 2
                configuration.height = 2
                configuration.minimumFrameInterval = CMTime(value: 1, timescale: 2)
                configuration.queueDepth = 3
                configuration.showsCursor = false
                configuration.capturesAudio = true
                configuration.excludesCurrentProcessAudio = true
                configuration.sampleRate = 48_000
                configuration.channelCount = 2

                let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
                try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: captureQueue)
                self.stream = stream
                try await stream.startCapture()
                guard self.captureGeneration == generation else {
                    try? await stream.stopCapture()
                    return
                }

                DispatchQueue.main.async { [weak self] in
                    guard let self, self.state == .requestingPermission else { return }
                    self.state = .listening
                }
            } catch {
                guard self.captureGeneration == generation else { return }
                fail(error)
            }
        }
    }

    func stop() {
        let activeStream = stream
        stream = nil
        captureGeneration = UUID()
        state = .idle
        bpm = nil
        confidence = 0
        resetEstimator()
        setClock(nil)

        guard let activeStream else { return }
        Task { try? await activeStream.stopCapture() }
    }

    func nextQuantizedHostTime(subdivision: Int = 4, minimumLeadTime: Double = 0.009) -> UInt64? {
        guard subdivision > 0, let snapshot = clockSnapshot(), snapshot.confidence >= 0.16 else { return nil }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - snapshot.updatedTime < 2.5 else { return nil }
        let stepDuration = 60 / snapshot.bpm / Double(subdivision)
        let elapsed = now + minimumLeadTime - snapshot.beatReferenceTime
        let step = ceil(elapsed / stepDuration)
        let target = snapshot.beatReferenceTime + step * stepDuration
        let delay = max(0.003, target - now)
        return mach_absolute_time() + AVAudioTime.hostTime(forSeconds: delay)
    }

    func nextQuantizedBeat(lengthInBeats: Double, subdivision: Int = 4) -> Double? {
        guard lengthInBeats > 0, subdivision > 0, let snapshot = clockSnapshot(), snapshot.confidence >= 0.16 else {
            return nil
        }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - snapshot.updatedTime < 2.5 else { return nil }
        let beat = (now - snapshot.beatReferenceTime) * snapshot.bpm / 60
        let quantized = (beat * Double(subdivision)).rounded(.up) / Double(subdivision)
        let wrapped = quantized.truncatingRemainder(dividingBy: lengthInBeats)
        return wrapped >= 0 ? wrapped : wrapped + lengthInBeats
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of outputType: SCStreamOutputType) {
        guard outputType == .audio, sampleBuffer.isValid,
              let formatDescription = sampleBuffer.formatDescription else { return }
        let format = AVAudioFormat(cmAudioFormatDescription: formatDescription)

        try? sampleBuffer.withAudioBufferList { audioBufferList, _ in
            guard let pcmBuffer = AVAudioPCMBuffer(
                pcmFormat: format,
                bufferListNoCopy: audioBufferList.unsafePointer
            ) else { return }

            let samples = monoSamples(from: pcmBuffer)
            guard !samples.isEmpty else { return }
            let duration = Double(samples.count) / pcmBuffer.format.sampleRate
            let arrivalTime = ProcessInfo.processInfo.systemUptime
            let presentationTime = CMTimeGetSeconds(sampleBuffer.presentationTimeStamp)
            let hostClockTime = CMTimeGetSeconds(CMClockGetTime(CMClockGetHostTimeClock()))
            let startTime = presentationTime.isFinite && abs(presentationTime - hostClockTime) < 2
                ? presentationTime
                : arrivalTime - duration
            guard let estimate = processEstimate(
                samples: samples,
                sampleRate: pcmBuffer.format.sampleRate,
                startTime: startTime
            ) else {
                if let snapshot = clockSnapshot(), arrivalTime - snapshot.updatedTime >= 2.5 {
                    setClock(nil)
                    DispatchQueue.main.async { [weak self] in
                        guard let self, self.isEnabled else { return }
                        self.bpm = nil
                        self.confidence = 0
                        self.state = .listening
                    }
                }
                return
            }

            let snapshot = ClockSnapshot(
                bpm: estimate.bpm,
                confidence: estimate.confidence,
                beatReferenceTime: estimate.beatReferenceTime,
                updatedTime: arrivalTime
            )
            setClock(snapshot)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.isEnabled else { return }
                self.bpm = estimate.bpm
                self.confidence = estimate.confidence
                self.state = estimate.confidence >= 0.16 ? .locked : .listening
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard stream === self.stream else { return }
        fail(error)
    }

    private func monoSamples(from buffer: AVAudioPCMBuffer) -> [Float] {
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return [] }

        var mono = [Float](repeating: 0, count: frameCount)
        let isInterleaved = buffer.format.isInterleaved

        switch buffer.format.commonFormat {
        case .pcmFormatFloat32:
            guard let channels = buffer.floatChannelData else { return [] }
            if isInterleaved {
                let source = channels[0]
                for frame in 0..<frameCount {
                    for channel in 0..<channelCount { mono[frame] += source[frame * channelCount + channel] }
                }
            } else {
                for channel in 0..<channelCount {
                    let source = channels[channel]
                    for frame in 0..<frameCount { mono[frame] += source[frame] }
                }
            }
        case .pcmFormatInt16:
            guard let channels = buffer.int16ChannelData else { return [] }
            if isInterleaved {
                let source = channels[0]
                for frame in 0..<frameCount {
                    for channel in 0..<channelCount {
                        mono[frame] += Float(source[frame * channelCount + channel]) / Float(Int16.max)
                    }
                }
            } else {
                for channel in 0..<channelCount {
                    let source = channels[channel]
                    for frame in 0..<frameCount { mono[frame] += Float(source[frame]) / Float(Int16.max) }
                }
            }
        case .pcmFormatInt32:
            guard let channels = buffer.int32ChannelData else { return [] }
            if isInterleaved {
                let source = channels[0]
                for frame in 0..<frameCount {
                    for channel in 0..<channelCount {
                        mono[frame] += Float(source[frame * channelCount + channel]) / Float(Int32.max)
                    }
                }
            } else {
                for channel in 0..<channelCount {
                    let source = channels[channel]
                    for frame in 0..<frameCount { mono[frame] += Float(source[frame]) / Float(Int32.max) }
                }
            }
        default:
            return []
        }
        let scale = 1 / Float(channelCount)
        if channelCount > 1 {
            for frame in mono.indices { mono[frame] *= scale }
        }
        return mono
    }

    private func fail(_ error: Error) {
        let message: String
        if let localized = error as? LocalizedError, let description = localized.errorDescription {
            message = description
        } else {
            message = error.localizedDescription
        }
        stream = nil
        captureGeneration = UUID()
        resetEstimator()
        setClock(nil)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.bpm = nil
            self.confidence = 0
            self.state = .failed(message)
            self.onFailure?(message)
        }
    }

    private func setClock(_ snapshot: ClockSnapshot?) {
        clockLock.lock()
        clock = snapshot
        clockLock.unlock()
    }

    private func clockSnapshot() -> ClockSnapshot? {
        clockLock.lock()
        defer { clockLock.unlock() }
        return clock
    }

    private func processEstimate(samples: [Float], sampleRate: Double, startTime: Double) -> TempoEstimator.Estimate? {
        estimatorLock.lock()
        defer { estimatorLock.unlock() }
        return estimator.process(samples: samples, sampleRate: sampleRate, startTime: startTime)
    }

    private func resetEstimator() {
        estimatorLock.lock()
        estimator.reset()
        estimatorLock.unlock()
    }
}

private enum CaptureFailure: LocalizedError {
    case noDisplay

    var errorDescription: String? {
        switch self {
        case .noDisplay: "No display is available for system-audio capture."
        }
    }
}
