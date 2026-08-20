import AVFoundation
import AudioToolbox
import Foundation

enum MixExporter {
    enum ExportError: LocalizedError {
        case noAudibleStems
        case renderingFailed

        var errorDescription: String? {
            switch self {
            case .noAudibleStems: "There are no audible stems to export."
            case .renderingFailed: "The offline audio renderer could not complete the mix."
            }
        }
    }

    static func export(
        stems: [(StemModel, URL)],
        pads: [(PadModel, URL?)] = [],
        pattern: DrumPattern? = nil,
        duration: Double,
        sampleRate: Double,
        destination: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        try await Task.detached(priority: .userInitiated) {
            let anySolo = stems.contains(where: { $0.0.isSolo })
            let audible = stems.filter { model, _ in
                !model.isMuted && (!anySolo || model.isSolo)
            }
            guard !audible.isEmpty else { throw ExportError.noAudibleStems }

            let engine = AVAudioEngine()
            var players: [AVAudioPlayerNode] = []
            var retainedNodes: [AVAudioNode] = []
            let outputFormat = AVAudioFormat(
                standardFormatWithSampleRate: sampleRate > 0 ? sampleRate : 44_100,
                channels: 2
            )!

            for (model, url) in audible {
                let file = try AVAudioFile(forReading: url)
                let player = AVAudioPlayerNode()
                let equalizer = AVAudioUnitEQ(numberOfBands: 2)
                let mixer = AVAudioMixerNode()
                engine.attach(player)
                engine.attach(equalizer)
                engine.attach(mixer)
                engine.connect(player, to: equalizer, format: file.processingFormat)
                engine.connect(equalizer, to: mixer, format: file.processingFormat)
                engine.connect(mixer, to: engine.mainMixerNode, format: nil)
                configureTone(equalizer, value: model.tone)
                mixer.outputVolume = max(0, min(1.5, pow(10, model.gainDB / 20)))
                mixer.pan = max(-1, min(1, model.pan))
                player.scheduleFile(
                    file,
                    at: nil,
                    completionCallbackType: .dataConsumed,
                    completionHandler: nil
                )
                players.append(player)
                retainedNodes.append(contentsOf: [equalizer, mixer])
            }

            if let pattern, !pattern.events.isEmpty, !pads.isEmpty {
                let cycleDuration = pattern.lengthInBeats * 60 / max(40, pattern.bpm)
                for (pad, customURL) in pads {
                    let padEvents = pattern.events.filter { $0.padIndex == pad.index }
                    guard !padEvents.isEmpty else { continue }
                    let buffer: AVAudioPCMBuffer
                    if let customURL, let custom = try? DrumSoundFactory.loadAndConvert(url: customURL) {
                        buffer = custom
                    } else {
                        buffer = DrumSoundFactory.makeSound(index: pad.index)
                    }

                    var padVoices: [(AVAudioPlayerNode, AVAudioMixerNode)] = []
                    for _ in 0..<4 {
                        let player = AVAudioPlayerNode()
                        let mixer = AVAudioMixerNode()
                        engine.attach(player)
                        engine.attach(mixer)
                        engine.connect(player, to: mixer, format: buffer.format)
                        engine.connect(mixer, to: engine.mainMixerNode, format: nil)
                        mixer.outputVolume = max(0, min(1.5, pow(10, pad.gainDB / 20)))
                        mixer.pan = max(-1, min(1, pad.pan))
                        padVoices.append((player, mixer))
                        players.append(player)
                        retainedNodes.append(mixer)
                    }

                    var voiceIndex = 0
                    var velocityBuffers: [Int: AVAudioPCMBuffer] = [:]
                    var cycleStart = 0.0
                    while cycleStart < duration {
                        for event in padEvents {
                            let sixteenth = Int((event.beat * 4).rounded())
                            let swingOffset = sixteenth.isMultiple(of: 2) ? 0 : 0.25 * pattern.swing
                            let eventTime = cycleStart + (event.beat + swingOffset) * 60 / max(40, pattern.bpm)
                            guard eventTime < duration else { continue }
                            let voice = padVoices[voiceIndex % padVoices.count]
                            voiceIndex += 1
                            let velocityKey = max(1, min(8, Int((event.velocity * 8).rounded())))
                            let eventBuffer: AVAudioPCMBuffer
                            if let existing = velocityBuffers[velocityKey] {
                                eventBuffer = existing
                            } else {
                                let scaled = scaledBuffer(buffer, gain: Float(velocityKey) / 8)
                                velocityBuffers[velocityKey] = scaled
                                eventBuffer = scaled
                            }
                            let when = AVAudioTime(
                                sampleTime: AVAudioFramePosition(eventTime * eventBuffer.format.sampleRate),
                                atRate: eventBuffer.format.sampleRate
                            )
                            voice.0.scheduleBuffer(
                                eventBuffer,
                                at: when,
                                options: [],
                                completionCallbackType: .dataConsumed,
                                completionHandler: nil
                            )
                        }
                        cycleStart += cycleDuration
                    }
                }
            }

            try engine.enableManualRenderingMode(.offline, format: outputFormat, maximumFrameCount: 4_096)
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: outputFormat.sampleRate,
                AVNumberOfChannelsKey: outputFormat.channelCount,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMIsNonInterleaved: false
            ]
            let outputFile = try AVAudioFile(forWriting: destination, settings: settings)
            try engine.start()
            players.forEach { $0.play() }

            let totalFrames = AVAudioFramePosition(max(1, duration * outputFormat.sampleRate))
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: engine.manualRenderingFormat,
                frameCapacity: engine.manualRenderingMaximumFrameCount
            ) else { throw ExportError.renderingFailed }

            while engine.manualRenderingSampleTime < totalFrames {
                try Task.checkCancellation()
                let remaining = totalFrames - engine.manualRenderingSampleTime
                let frames = AVAudioFrameCount(min(AVAudioFramePosition(buffer.frameCapacity), remaining))
                let status = try engine.renderOffline(frames, to: buffer)
                switch status {
                case .success:
                    try outputFile.write(from: buffer)
                    progress(Double(engine.manualRenderingSampleTime) / Double(totalFrames))
                case .insufficientDataFromInputNode:
                    continue
                case .cannotDoInCurrentContext:
                    await Task.yield()
                case .error:
                    throw ExportError.renderingFailed
                @unknown default:
                    throw ExportError.renderingFailed
                }
            }
            players.forEach { $0.stop() }
            engine.stop()
            _ = retainedNodes
            progress(1)
        }.value
    }

    private static func configureTone(_ equalizer: AVAudioUnitEQ, value: Float) {
        guard equalizer.bands.count >= 2 else { return }
        let tone = max(-1, min(1, value))
        let low = equalizer.bands[0]
        low.filterType = .lowShelf
        low.frequency = 180
        low.gain = -tone * 7
        low.bandwidth = 0.8
        low.bypass = false

        let high = equalizer.bands[1]
        high.filterType = .highShelf
        high.frequency = 5_800
        high.gain = tone * 7
        high.bandwidth = 0.8
        high.bypass = false
    }

    private static func scaledBuffer(_ source: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer {
        guard gain < 0.999,
              let destination = AVAudioPCMBuffer(
                pcmFormat: source.format,
                frameCapacity: source.frameLength
              ),
              let sourceChannels = source.floatChannelData,
              let destinationChannels = destination.floatChannelData else {
            return source
        }
        destination.frameLength = source.frameLength
        for channel in 0..<Int(source.format.channelCount) {
            for frame in 0..<Int(source.frameLength) {
                destinationChannels[channel][frame] = sourceChannels[channel][frame] * gain
            }
        }
        return destination
    }
}
