import AppKit
import AVFoundation
import Foundation

@MainActor
final class AudioEngineController: ObservableObject {
    struct Meter: Equatable {
        var peak: Float = 0
        var rms: Float = 0
    }

    enum EngineFailure: LocalizedError {
        case noPlayableAudio
        case cannotStart(String)

        var errorDescription: String? {
            switch self {
            case .noPlayableAudio: "No playable audio is loaded."
            case .cannotStart(let detail): "The audio engine could not start: \(detail)"
            }
        }
    }

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var meters: [UUID: Meter] = [:]
    @Published private(set) var outputDeviceName = "System Output"
    @Published var lastError: String?

    private lazy var engine = AVAudioEngine()
    private lazy var drumBus = AVAudioMixerNode()
    private var stemChannels: [UUID: StemChannel] = [:]
    private var orderedStemIDs: [UUID] = []
    private var voices: [DrumVoice] = []
    private var voiceCursor = 0
    private var padBuffers = DrumSoundFactory.makeFactoryKit()
    private var pollTimer: Timer?
    private var duration: Double = 0
    private var parkedPosition: Double = 0
    private var playbackStartHostTime: UInt64 = 0
    private var playbackStartPosition: Double = 0
    private var scheduledThroughHostTime: UInt64 = 0
    private var loop = LoopRange()
    private var currentStemModels: [UUID: StemModel] = [:]

    init() {
        if ProcessInfo.processInfo.environment["SP4_RENDERING_PREVIEW"] != "1" {
            configureBaseGraph()
        }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollTransport() }
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    func load(stems: [(StemModel, URL)], duration: Double, loop: LoopRange) throws {
        stop()
        unloadStemGraph()
        self.duration = max(0, duration)
        self.loop = loop
        currentStemModels = Dictionary(uniqueKeysWithValues: stems.map { ($0.0.id, $0.0) })

        engine.stop()
        for (model, url) in stems {
            do {
                let file = try AVAudioFile(forReading: url)
                let player = AVAudioPlayerNode()
                let equalizer = AVAudioUnitEQ(numberOfBands: 2)
                let mixer = AVAudioMixerNode()
                configureTone(equalizer, value: model.tone)

                engine.attach(player)
                engine.attach(equalizer)
                engine.attach(mixer)
                engine.connect(player, to: equalizer, format: file.processingFormat)
                engine.connect(equalizer, to: mixer, format: file.processingFormat)
                engine.connect(mixer, to: engine.mainMixerNode, format: nil)

                let channel = StemChannel(modelID: model.id, file: file, player: player, equalizer: equalizer, mixer: mixer)
                stemChannels[model.id] = channel
                orderedStemIDs.append(model.id)
                installMeterTap(on: channel)
            } catch {
                lastError = "Could not open \(url.lastPathComponent): \(error.localizedDescription)"
            }
        }

        guard !stemChannels.isEmpty else { throw EngineFailure.noPlayableAudio }
        applyMixState()
        try startEngineIfNeeded()
        parkedPosition = 0
        currentTime = 0
    }

    func update(stem: StemModel) {
        currentStemModels[stem.id] = stem
        guard let channel = stemChannels[stem.id] else { return }
        channel.mixer.pan = max(-1, min(1, stem.pan))
        configureTone(channel.equalizer, value: stem.tone)
        applyMixState()
    }

    func setLoop(_ loop: LoopRange) {
        let wasPlaying = isPlaying
        let position = calculatedPosition()
        self.loop = loop
        if wasPlaying { startPlayback(at: position) }
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        guard !stemChannels.isEmpty else {
            lastError = EngineFailure.noPlayableAudio.localizedDescription
            return
        }
        if parkedPosition >= duration - 0.01 { parkedPosition = 0 }
        startPlayback(at: parkedPosition)
    }

    func pause() {
        guard isPlaying else { return }
        parkedPosition = calculatedPosition()
        stemChannels.values.forEach { $0.player.stop() }
        isPlaying = false
        currentTime = parkedPosition
    }

    func stop() {
        stemChannels.values.forEach { $0.player.stop() }
        isPlaying = false
        parkedPosition = 0
        currentTime = 0
    }

    func seek(to seconds: Double) {
        let target = max(0, min(duration, seconds))
        if isPlaying {
            startPlayback(at: target)
        } else {
            parkedPosition = target
            currentTime = target
        }
    }

    func skip(seconds: Double) {
        seek(to: calculatedPosition() + seconds)
    }

    func setPadBuffer(_ buffer: AVAudioPCMBuffer, at index: Int) {
        padBuffers[index] = buffer
    }

    func restoreFactoryPad(at index: Int) {
        padBuffers[index] = DrumSoundFactory.makeSound(index: index)
    }

    func triggerPad(_ pad: PadModel, velocity: Float = 0.86, hostTime: UInt64? = nil) {
        guard let buffer = padBuffers[pad.index], !voices.isEmpty else { return }

        if let choke = pad.chokeGroup {
            voices.filter { $0.chokeGroup == choke }.forEach { $0.player.stop() }
        }

        let voice = voices[voiceCursor % voices.count]
        voiceCursor = (voiceCursor + 1) % voices.count
        voice.player.stop()
        voice.chokeGroup = pad.chokeGroup
        voice.mixer.pan = max(-1, min(1, pad.pan))
        let gain = pow(10, pad.gainDB / 20)
        voice.mixer.outputVolume = max(0, min(1.5, gain * velocity))

        let startHost = hostTime ?? (mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.003))
        let time = AVAudioTime(hostTime: startHost)
        voice.player.scheduleBuffer(buffer, at: time, options: [], completionHandler: nil)
        voice.player.play(at: time)
    }

    func commonPadHostTime() -> UInt64 {
        mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.003)
    }

    private func configureBaseGraph() {
        engine.attach(drumBus)
        engine.connect(drumBus, to: engine.mainMixerNode, format: DrumSoundFactory.format)

        for _ in 0..<32 {
            let player = AVAudioPlayerNode()
            let mixer = AVAudioMixerNode()
            engine.attach(player)
            engine.attach(mixer)
            engine.connect(player, to: mixer, format: DrumSoundFactory.format)
            engine.connect(mixer, to: drumBus, format: DrumSoundFactory.format)
            voices.append(DrumVoice(player: player, mixer: mixer))
        }

        engine.mainMixerNode.outputVolume = 0.92
        do {
            try startEngineIfNeeded()
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func startEngineIfNeeded() throws {
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                throw EngineFailure.cannotStart(error.localizedDescription)
            }
        }
    }

    private func startPlayback(at requestedPosition: Double) {
        do {
            try startEngineIfNeeded()
        } catch {
            lastError = error.localizedDescription
            return
        }

        stemChannels.values.forEach { $0.player.stop() }
        let position = normalizedStartPosition(requestedPosition)
        let hostTime = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: 0.055)
        playbackStartHostTime = hostTime
        playbackStartPosition = position
        scheduledThroughHostTime = hostTime

        if loop.isEnabled {
            let firstEnd = min(duration, max(loop.endSeconds, loop.startSeconds + 0.05))
            let firstDuration = max(0.01, firstEnd - position)
            scheduleAll(from: position, duration: firstDuration, at: hostTime)
            scheduledThroughHostTime = hostTime + AVAudioTime.hostTime(forSeconds: firstDuration)
            fillLoopQueue(horizonSeconds: 1.5)
        } else {
            scheduleAll(from: position, duration: max(0.01, duration - position), at: hostTime)
            scheduledThroughHostTime = hostTime + AVAudioTime.hostTime(forSeconds: max(0.01, duration - position))
        }

        let startTime = AVAudioTime(hostTime: hostTime)
        stemChannels.values.forEach { $0.player.play(at: startTime) }
        parkedPosition = position
        currentTime = position
        isPlaying = true
    }

    private func scheduleAll(from seconds: Double, duration requestedDuration: Double, at hostTime: UInt64) {
        for channel in stemChannels.values {
            let sampleRate = channel.file.processingFormat.sampleRate
            let startFrame = AVAudioFramePosition(max(0, seconds * sampleRate))
            let available = max(0, channel.file.length - startFrame)
            let desired = AVAudioFramePosition(max(1, requestedDuration * sampleRate))
            let frames = min(available, desired)
            guard frames > 0 else { continue }
            channel.player.scheduleSegment(
                channel.file,
                startingFrame: startFrame,
                frameCount: AVAudioFrameCount(min(frames, AVAudioFramePosition(UInt32.max))),
                at: AVAudioTime(hostTime: hostTime),
                completionHandler: nil
            )
        }
    }

    private func fillLoopQueue(horizonSeconds: Double) {
        guard loop.isEnabled, isPlaying || playbackStartHostTime > 0 else { return }
        let horizon = mach_absolute_time() + AVAudioTime.hostTime(forSeconds: horizonSeconds)
        let loopDuration = loop.duration
        while scheduledThroughHostTime < horizon {
            scheduleAll(from: loop.startSeconds, duration: loopDuration, at: scheduledThroughHostTime)
            scheduledThroughHostTime += AVAudioTime.hostTime(forSeconds: loopDuration)
        }
    }

    private func calculatedPosition() -> Double {
        guard isPlaying else { return parkedPosition }
        let now = mach_absolute_time()
        guard now > playbackStartHostTime else { return playbackStartPosition }
        let elapsed = AVAudioTime.seconds(forHostTime: now - playbackStartHostTime)
        let raw = playbackStartPosition + elapsed

        guard loop.isEnabled else { return min(duration, raw) }
        let end = max(loop.endSeconds, loop.startSeconds + 0.05)
        if raw < end { return raw }
        return loop.startSeconds + (raw - end).truncatingRemainder(dividingBy: loop.duration)
    }

    private func normalizedStartPosition(_ requested: Double) -> Double {
        var value = max(0, min(duration, requested))
        if loop.isEnabled {
            let end = max(loop.endSeconds, loop.startSeconds + 0.05)
            if value >= end { value = loop.startSeconds }
        }
        return value
    }

    private func pollTransport() {
        guard isPlaying else { return }
        currentTime = calculatedPosition()
        if loop.isEnabled {
            fillLoopQueue(horizonSeconds: 1.5)
        } else if currentTime >= duration - 0.01 {
            stemChannels.values.forEach { $0.player.stop() }
            isPlaying = false
            parkedPosition = duration
        }
    }

    private func applyMixState() {
        let anySolo = currentStemModels.values.contains(where: \.isSolo)
        for (id, channel) in stemChannels {
            guard let model = currentStemModels[id] else { continue }
            let audible = !model.isMuted && (!anySolo || model.isSolo)
            channel.mixer.outputVolume = audible ? max(0, min(1.5, pow(10, model.gainDB / 20))) : 0
            channel.mixer.pan = max(-1, min(1, model.pan))
        }
    }

    private func configureTone(_ equalizer: AVAudioUnitEQ, value: Float) {
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

    private func installMeterTap(on channel: StemChannel) {
        channel.mixer.installTap(onBus: 0, bufferSize: 1_024, format: nil) { [weak self] buffer, _ in
            guard let data = buffer.floatChannelData, buffer.frameLength > 0 else { return }
            let count = Int(buffer.frameLength)
            var peak: Float = 0
            var sum: Float = 0
            let channels = Int(buffer.format.channelCount)
            for channelIndex in 0..<channels {
                let samples = data[channelIndex]
                for index in 0..<count {
                    let sample = samples[index]
                    peak = max(peak, abs(sample))
                    sum += sample * sample
                }
            }
            let rms = sqrt(sum / Float(max(1, count * channels)))
            DispatchQueue.main.async {
                self?.meters[channel.modelID] = Meter(peak: min(1, peak), rms: min(1, rms))
            }
        }
    }

    private func unloadStemGraph() {
        for channel in stemChannels.values {
            channel.mixer.removeTap(onBus: 0)
            channel.player.stop()
            engine.disconnectNodeOutput(channel.player)
            engine.disconnectNodeOutput(channel.equalizer)
            engine.disconnectNodeOutput(channel.mixer)
            engine.detach(channel.player)
            engine.detach(channel.equalizer)
            engine.detach(channel.mixer)
        }
        stemChannels.removeAll()
        orderedStemIDs.removeAll()
        meters.removeAll()
    }
}

private final class StemChannel {
    let modelID: UUID
    let file: AVAudioFile
    let player: AVAudioPlayerNode
    let equalizer: AVAudioUnitEQ
    let mixer: AVAudioMixerNode

    init(
        modelID: UUID,
        file: AVAudioFile,
        player: AVAudioPlayerNode,
        equalizer: AVAudioUnitEQ,
        mixer: AVAudioMixerNode
    ) {
        self.modelID = modelID
        self.file = file
        self.player = player
        self.equalizer = equalizer
        self.mixer = mixer
    }
}

private final class DrumVoice {
    let player: AVAudioPlayerNode
    let mixer: AVAudioMixerNode
    var chokeGroup: Int?

    init(player: AVAudioPlayerNode, mixer: AVAudioMixerNode) {
        self.player = player
        self.mixer = mixer
    }
}
