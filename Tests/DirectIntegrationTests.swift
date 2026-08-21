import AVFoundation
import AudioToolbox
import Foundation

@main
struct DirectIntegrationTests {
    static func main() async throws {
        let temporaryRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("StemPlayerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporaryRoot) }

        try testModel()
        testTempoEstimator()
        let toneURL = try makeTone(in: temporaryRoot)
        try testAudioUtilities(with: toneURL)
        try testProjectStore(in: temporaryRoot, asset: toneURL)
        let skipsAudioEngine = ProcessInfo.processInfo.environment["SP4_SKIP_AUDIO_ENGINE"] == "1"
        if !skipsAudioEngine {
            try await testRealtimeEngine(source: toneURL)
            try await testOfflineMix(in: temporaryRoot, source: toneURL)
        }

        let engineResult = skipsAudioEngine ? "audio engine checks skipped by environment" : "realtime engine and offline export"
        print("PASS: model, tempo lock, project package, generated kit, waveform analysis, import probe, and \(engineResult)")
    }

    private static func testModel() throws {
        precondition(StemRole.infer(from: "01_DRUMS.wav") == .drums)
        precondition(StemRole.infer(from: "Lead Vocals.flac") == .vocals)
        precondition(StemRole.infer(from: "sub_bass.aif") == .bass)
        precondition(StemRole.infer(from: "guitars.wav") == .instruments)
        precondition(StemRole.infer(from: "mystery.wav") == .custom)

        let original = StemProject(title: "Round Trip")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StemProject.self, from: data)
        precondition(decoded.title == original.title)
        precondition(decoded.pads.count == 12)
        precondition(LoopRange(isEnabled: true, startSeconds: 2, endSeconds: 2).duration == 0.05)
        precondition(62.345.transportString == "01:02.344" || 62.345.transportString == "01:02.345")

        let beatGrid = BeatGridClock(bpm: 120, beatReferenceTime: 10)
        let phase = beatGrid.phase(at: 10.3125, subdivision: 4)
        precondition(abs(phase.beatPosition - 0.625) < 0.000_001)
        precondition(abs(phase.beatPhase - 0.625) < 0.000_001)
        precondition(phase.subdivisionIndex == 2)
        precondition(abs(phase.subdivisionPhase - 0.5) < 0.000_001)
        let nextBoundary = beatGrid.nextBoundary(after: 10.26, subdivision: 4)
        precondition(abs(nextBoundary - 10.375) < 0.000_001)
        let boundaryPhase = beatGrid.phase(at: nextBoundary, subdivision: 4)
        precondition(boundaryPhase.subdivisionIndex == 3)
        precondition(boundaryPhase.subdivisionPhase < 0.000_001)
        precondition(abs((beatGrid.quantizedBeat(at: 10.26, lengthInBeats: 4, subdivision: 4) ?? 0) - 0.75) < 0.000_001)
    }

    private static func testTempoEstimator() {
        let sampleRate = 8_000.0
        let duration = 9.0
        var lockedEstimator: TempoEstimator?

        for expectedBPM in [90.0, 120.0, 174.0] {
            let frameCount = Int(sampleRate * duration)
            var signal = [Float](repeating: 0, count: frameCount)
            let period = 60 / expectedBPM
            let beatFrames = Int((sampleRate * period).rounded())

            for beatStart in stride(from: 0, to: frameCount, by: beatFrames) {
                for offset in 0..<min(96, frameCount - beatStart) {
                    let decay = exp(-Double(offset) / 18)
                    signal[beatStart + offset] = Float(sin(Double(offset) * 0.91) * decay * 0.9)
                }
            }

            let estimator = TempoEstimator()
            var estimate: TempoEstimator.Estimate?
            let chunkSize = 512
            for start in stride(from: 0, to: signal.count, by: chunkSize) {
                let end = min(start + chunkSize, signal.count)
                if let update = estimator.process(
                    samples: Array(signal[start..<end]),
                    sampleRate: sampleRate,
                    startTime: Double(start) / sampleRate
                ) {
                    estimate = update
                }
            }

            precondition(estimate != nil, "A steady \(expectedBPM) BPM click track should produce a tempo lock.")
            precondition(abs((estimate?.bpm ?? 0) - expectedBPM) < 1.8, "Expected \(expectedBPM) BPM, got \(estimate?.bpm ?? 0).")
            precondition((estimate?.confidence ?? 0) >= 0.16, "The click-track lock should clear the live-sync confidence threshold.")
            let reference = estimate?.beatReferenceTime ?? 0
            let phaseError = abs(reference / period - (reference / period).rounded())
            precondition(phaseError < 0.08, "The estimated beat phase should follow the click positions.")
            if expectedBPM == 120 { lockedEstimator = estimator }
        }

        let quietTail = [Float](repeating: 0, count: Int(sampleRate * 3))
        precondition(
            lockedEstimator?.process(samples: quietTail, sampleRate: sampleRate, startTime: duration) == nil,
            "A tempo lock should expire after rhythmic evidence stops."
        )

        let silentEstimator = TempoEstimator()
        let silence = [Float](repeating: 0, count: Int(sampleRate * 5))
        precondition(silentEstimator.process(samples: silence, sampleRate: sampleRate, startTime: 0) == nil)
    }

    private static func makeTone(in directory: URL) throws -> URL {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        let frames = AVAudioFrameCount(format.sampleRate * 0.35)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let channels = buffer.floatChannelData!
        for frame in 0..<Int(frames) {
            let sample = Float(sin(2 * Double.pi * 220 * Double(frame) / format.sampleRate) * 0.35)
            channels[0][frame] = sample
            channels[1][frame] = sample
        }

        let url = directory.appendingPathComponent("test-tone.wav")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: format.sampleRate,
            AVNumberOfChannelsKey: format.channelCount,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false
        ]
        let file = try AVAudioFile(forWriting: url, settings: settings)
        try file.write(from: buffer)
        return url
    }

    private static func testAudioUtilities(with url: URL) throws {
        let probe = try AudioImportService.probe(url: url)
        precondition(abs(probe.duration - 0.35) < 0.02)
        precondition(probe.sampleRate == 44_100)
        precondition(probe.channels == 2)

        let waveform = try WaveformAnalyzer.analyze(url: url, targetPeakCount: 100)
        precondition(waveform.peaks.count > 20)
        precondition(waveform.peaks.max() ?? 0 > 0.3)

        let kit = DrumSoundFactory.makeFactoryKit()
        precondition(kit.count == 12)
        precondition(kit.values.allSatisfy { $0.frameLength > 0 })
    }

    private static func testProjectStore(in directory: URL, asset: URL) throws {
        let store = ProjectStore()
        let package = directory.appendingPathComponent("Portable.stemproject", isDirectory: true)
        try store.preparePackage(at: package)
        let relative = try store.copyAsset(asset, into: package, folder: "Audio")
        let model = StemModel(role: .mix, relativePath: relative)
        let project = StemProject(title: "Portable", durationSeconds: 0.35, stems: [model])
        try store.save(project, to: package)

        let restored = try store.load(from: package)
        precondition(restored.title == project.title)
        precondition(restored.stems.first?.relativePath == relative)
        precondition(FileManager.default.fileExists(atPath: store.resolve(relative, in: package).path))
    }

    @MainActor
    private static func testRealtimeEngine(source: URL) async throws {
        let controller = AudioEngineController()
        let stem = StemModel(role: .mix, relativePath: "unused")
        try controller.load(stems: [(stem, source)], duration: 0.35, loop: LoopRange())
        controller.play()
        try await Task.sleep(for: .milliseconds(140))
        precondition(controller.isPlaying)
        precondition(controller.currentTime > 0.03)
        controller.pause()
        precondition(!controller.isPlaying)
    }

    private static func testOfflineMix(in directory: URL, source: URL) async throws {
        let destination = directory.appendingPathComponent("rendered-mix.wav")
        let stem = StemModel(role: .mix, relativePath: "unused", gainDB: -60, pan: 0.2)
        var pattern = DrumPattern(bpm: 120)
        pattern.events = [PatternEvent(padIndex: 0, beat: 0), PatternEvent(padIndex: 1, beat: 1)]
        try await MixExporter.export(
            stems: [(stem, source)],
            pads: StemProject.defaultPads.map { ($0, nil) },
            pattern: pattern,
            duration: 0.35,
            sampleRate: 44_100,
            destination: destination,
            progress: { _ in }
        )
        let rendered = try AudioImportService.probe(url: destination)
        precondition(abs(rendered.duration - 0.35) < 0.03)
        precondition(rendered.channels == 2)
        let peaks = try WaveformAnalyzer.analyze(url: destination, targetPeakCount: 80).peaks
        precondition(peaks.max() ?? 0 > 0.1, "The exported pattern should be audible above the muted stem.")
    }
}
