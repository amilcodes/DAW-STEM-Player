import AppKit
import AVFoundation
import Foundation
import UniformTypeIdentifiers

struct TrackpadTouch: Identifiable, Equatable {
    var id: Int
    var normalizedX: CGFloat
    var normalizedY: CGFloat
    var padIndex: Int
}

@MainActor
final class AppState: ObservableObject {
    @Published var project: StemProject
    @Published var projectURL: URL
    @Published var mode: WorkspaceMode = .mix {
        didSet { keyboard.mode = mode }
    }
    @Published var selectedStemID: UUID?
    @Published var selectedPadIndex = 0
    @Published var selectedPatternBar = 0
    @Published var waveforms: [UUID: [Float]] = [:]
    @Published var activePads: Set<Int> = []
    @Published var trackpadTouches: [TrackpadTouch] = []
    @Published var isTrackpadArmed = false
    @Published var isPatternRecording = false
    @Published var isPatternEnabled = true
    @Published var isInspectorVisible = true
    @Published var isImporting = false
    @Published var exportProgress: Double?
    @Published var notice: String?
    @Published var presentedError: String?
    @Published var showShortcutOverlay = false
    @Published var hapticsEnabled = true

    let audio: AudioEngineController
    let separator: SeparationService

    private let store = ProjectStore()
    private let keyboard = KeyboardMonitor()
    private var autosaveWorkItem: DispatchWorkItem?
    private var patternTimer: Timer?
    private var lastPatternBeat: Double?
    private var padHoldCounts: [Int: Int] = [:]

    init() {
        audio = AudioEngineController()
        separator = SeparationService()
        let defaultURL = store.autosaveURL
        projectURL = defaultURL

        if let restored = try? store.load(from: defaultURL) {
            project = restored
        } else {
            project = StemProject()
            try? store.save(project, to: defaultURL)
        }

        selectedStemID = project.stems.first?.id
        keyboard.handler = { [weak self] action in self?.handleKeyboard(action) }
        keyboard.mode = mode
        patternTimer = Timer.scheduledTimer(withTimeInterval: 0.012, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.pollPattern() }
        }
        reloadAudio()
        analyzeAllWaveforms()
    }

    deinit {
        patternTimer?.invalidate()
        autosaveWorkItem?.cancel()
    }

    var selectedStem: StemModel? {
        guard let selectedStemID else { return nil }
        return project.stems.first(where: { $0.id == selectedStemID })
    }

    var selectedPad: PadModel {
        project.pads[max(0, min(project.pads.count - 1, selectedPadIndex))]
    }

    var canSeparate: Bool {
        project.stems.count == 1 && project.stems.first?.role == .mix && !separator.state.isBusy
    }

    func activate() {
        keyboard.start()
    }

    func renameProject(_ title: String) {
        project.title = title.isEmpty ? "Untitled Session" : title
        scheduleAutosave()
    }

    func selectPad(_ index: Int) {
        guard project.pads.indices.contains(index) else { return }
        selectedPadIndex = index
    }

    func setPatternBPM(_ bpm: Double) {
        project.pattern.bpm = max(40, min(240, bpm))
        scheduleAutosave()
    }

    func setPatternSwing(_ swing: Double) {
        project.pattern.swing = max(0, min(0.75, swing))
        scheduleAutosave()
    }

    func setPatternBars(_ bars: Int) {
        project.pattern.bars = max(1, min(8, bars))
        project.pattern.events.removeAll { $0.beat >= project.pattern.lengthInBeats }
        selectedPatternBar = min(selectedPatternBar, project.pattern.bars - 1)
        scheduleAutosave()
    }

    func selectPatternBar(_ bar: Int) {
        selectedPatternBar = max(0, min(project.pattern.bars - 1, bar))
    }

    func newSession() {
        audio.stop()
        let newURL = store.autosaveURL
        try? FileManager.default.removeItem(at: newURL)
        project = StemProject()
        projectURL = newURL
        selectedStemID = nil
        waveforms = [:]
        try? store.save(project, to: newURL)
        notice = "New session ready"
    }

    func presentAudioImporter() {
        let panel = NSOpenPanel()
        panel.title = "Open a song or prepared stems"
        panel.message = "Choose one audio file for a song, or select several files for prepared stems."
        panel.prompt = "Import"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .movie, .data]
        panel.begin { [weak self] response in
            guard response == .OK, !panel.urls.isEmpty else { return }
            Task { @MainActor in await self?.importAudioFiles(panel.urls) }
        }
    }

    func presentProjectImporter() {
        let panel = NSOpenPanel()
        panel.title = "Open Stem Player Project"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowedContentTypes = [UTType(filenameExtension: "stemproject") ?? .package]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in self?.openProject(at: url) }
        }
    }

    func openProject(at url: URL) {
        do {
            let loaded = try store.load(from: url)
            audio.stop()
            project = loaded
            projectURL = url
            selectedStemID = loaded.stems.first?.id
            waveforms = [:]
            reloadAudio()
            analyzeAllWaveforms()
            notice = "Opened \(loaded.title)"
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func saveProjectAs() {
        let panel = NSSavePanel()
        panel.title = "Save Stem Player Project"
        panel.nameFieldStringValue = sanitizedProjectName + ".stemproject"
        panel.allowedContentTypes = [UTType(filenameExtension: "stemproject") ?? .package]
        panel.canCreateDirectories = true
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            do {
                self.audio.pause()
                if destination.standardizedFileURL != self.projectURL.standardizedFileURL {
                    if FileManager.default.fileExists(atPath: destination.path) {
                        try FileManager.default.removeItem(at: destination)
                    }
                    if FileManager.default.fileExists(atPath: self.projectURL.path) {
                        try FileManager.default.copyItem(at: self.projectURL, to: destination)
                    }
                }
                self.projectURL = destination
                try self.store.save(self.project, to: destination)
                self.notice = "Saved \(destination.lastPathComponent)"
            } catch {
                self.presentedError = error.localizedDescription
            }
        }
    }

    func importAudioFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }
        isImporting = true
        defer { isImporting = false }

        do {
            if !project.stems.isEmpty {
                newSession()
            }
            try store.preparePackage(at: projectURL)
            let working = store.applicationSupportURL.appendingPathComponent("Imports", isDirectory: true)
            try FileManager.default.createDirectory(at: working, withIntermediateDirectories: true)

            var imported: [StemModel] = []
            var probes: [AudioImportService.Probe] = []
            let isSingle = urls.count == 1

            for source in urls {
                let readable = try AudioImportService.ensureNativeReadable(url: source, workingDirectory: working)
                let probe = try AudioImportService.probe(url: readable)
                let relative = try store.copyAsset(readable, into: projectURL, folder: "Audio")
                let inferred = isSingle ? StemRole.mix : StemRole.infer(from: source.lastPathComponent)
                let name = inferred == .custom ? source.deletingPathExtensionSafe : inferred.displayName
                imported.append(
                    StemModel(
                        role: inferred,
                        name: name,
                        relativePath: relative,
                        sourcePath: source.path
                    )
                )
                probes.append(probe)
            }

            project.title = urls[0].deletingPathExtensionSafe
            project.stems = imported
            project.durationSeconds = probes.map(\.duration).max() ?? 0
            project.sampleRate = probes.first?.sampleRate ?? 44_100
            selectedStemID = imported.first?.id
            try store.save(project, to: projectURL)
            reloadAudio()
            analyzeAllWaveforms()
            notice = isSingle ? "Song loaded — separate it whenever you’re ready" : "\(imported.count) stems loaded"
        } catch {
            presentedError = error.localizedDescription
        }
    }

    func removeStem(_ id: UUID) {
        guard let index = project.stems.firstIndex(where: { $0.id == id }) else { return }
        let removed = project.stems.remove(at: index)
        try? store.removeAsset(removed.relativePath, in: projectURL)
        waveforms[id] = nil
        selectedStemID = project.stems.first?.id
        persistAndReload()
    }

    func selectStem(_ id: UUID) {
        selectedStemID = id
    }

    func updateStem(_ id: UUID, _ mutation: (inout StemModel) -> Void) {
        guard let index = project.stems.firstIndex(where: { $0.id == id }) else { return }
        mutation(&project.stems[index])
        audio.update(stem: project.stems[index])
        scheduleAutosave()
    }

    func resetStem(_ id: UUID) {
        updateStem(id) {
            $0.gainDB = 0
            $0.pan = 0
            $0.tone = 0
            $0.isMuted = false
            $0.isSolo = false
        }
    }

    func toggleLoop() {
        project.loop.isEnabled.toggle()
        normalizeLoop()
        audio.setLoop(project.loop)
        scheduleAutosave()
    }

    func setLoopIn() {
        project.loop.startSeconds = min(audio.currentTime, max(0, project.loop.endSeconds - 0.05))
        project.loop.isEnabled = true
        normalizeLoop()
        audio.setLoop(project.loop)
        scheduleAutosave()
        notice = "Loop in: \(project.loop.startSeconds.transportString)"
    }

    func setLoopOut() {
        project.loop.endSeconds = max(audio.currentTime, project.loop.startSeconds + 0.05)
        project.loop.isEnabled = true
        normalizeLoop()
        audio.setLoop(project.loop)
        scheduleAutosave()
        notice = "Loop out: \(project.loop.endSeconds.transportString)"
    }

    func setLoop(start: Double, end: Double) {
        project.loop.startSeconds = start
        project.loop.endSeconds = end
        normalizeLoop()
        audio.setLoop(project.loop)
        scheduleAutosave()
    }

    func triggerPad(index: Int, velocity: Float = 0.86, hold: Bool = false) {
        guard project.pads.indices.contains(index) else { return }
        selectedPadIndex = index
        audio.triggerPad(project.pads[index], velocity: velocity)
        padHoldCounts[index, default: 0] += 1
        activePads.insert(index)

        if hapticsEnabled {
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        }
        if isPatternRecording && audio.isPlaying { recordPadHit(index: index, velocity: velocity) }

        if !hold {
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(115))
                self?.releasePad(index: index)
            }
        }
    }

    func releasePad(index: Int) {
        let remaining = max(0, (padHoldCounts[index] ?? 1) - 1)
        padHoldCounts[index] = remaining
        if remaining == 0 { activePads.remove(index) }
    }

    func loadSampleForSelectedPad() {
        let panel = NSOpenPanel()
        panel.title = "Load a sample onto \(selectedPad.name)"
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.audio, .data]
        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            do {
                let buffer = try DrumSoundFactory.loadAndConvert(url: url)
                let relative = try self.store.copyAsset(url, into: self.projectURL, folder: "Samples")
                self.audio.setPadBuffer(buffer, at: self.selectedPadIndex)
                self.project.pads[self.selectedPadIndex].relativePath = relative
                self.project.pads[self.selectedPadIndex].sourcePath = url.path
                self.project.pads[self.selectedPadIndex].name = url.deletingPathExtensionSafe
                self.scheduleAutosave()
                self.notice = "Loaded \(url.lastPathComponent)"
            } catch {
                self.presentedError = error.localizedDescription
            }
        }
    }

    func restoreFactoryPad() {
        let pad = project.pads[selectedPadIndex]
        if let relative = pad.relativePath { try? store.removeAsset(relative, in: projectURL) }
        project.pads[selectedPadIndex] = StemProject.defaultPads[selectedPadIndex]
        audio.restoreFactoryPad(at: selectedPadIndex)
        scheduleAutosave()
    }

    func updateSelectedPad(_ mutation: (inout PadModel) -> Void) {
        guard project.pads.indices.contains(selectedPadIndex) else { return }
        mutation(&project.pads[selectedPadIndex])
        scheduleAutosave()
    }

    func toggleStep(_ step: Int, divisions: Int = 16) {
        let beat = Double(selectedPatternBar * 4) + Double(step) / Double(divisions) * 4
        let tolerance = 2 / Double(divisions)
        if let index = project.pattern.events.firstIndex(where: {
            $0.padIndex == selectedPadIndex && abs($0.beat - beat) < tolerance
        }) {
            project.pattern.events.remove(at: index)
        } else {
            project.pattern.events.append(PatternEvent(padIndex: selectedPadIndex, beat: beat))
            project.pattern.events.sort { $0.beat < $1.beat }
        }
        scheduleAutosave()
    }

    func hasStep(_ step: Int, padIndex: Int, divisions: Int = 16) -> Bool {
        let beat = Double(selectedPatternBar * 4) + Double(step) / Double(divisions) * 4
        let tolerance = 2 / Double(divisions)
        return project.pattern.events.contains { $0.padIndex == padIndex && abs($0.beat - beat) < tolerance }
    }

    func clearPattern() {
        project.pattern.events.removeAll()
        scheduleAutosave()
        notice = "Pattern cleared"
    }

    func armTrackpad(_ armed: Bool) {
        isTrackpadArmed = armed
        if !armed {
            trackpadTouches.removeAll()
            padHoldCounts.removeAll()
            activePads.removeAll()
            NSCursor.unhide()
        }
    }

    func trackpadTouchBegan(_ touch: TrackpadTouch) {
        trackpadTouches.removeAll(where: { $0.id == touch.id })
        trackpadTouches.append(touch)
        triggerPad(index: touch.padIndex, hold: true)
        if trackpadTouches.count == 1 { NSCursor.hide() }
    }

    func trackpadTouchMoved(_ touch: TrackpadTouch) {
        guard let index = trackpadTouches.firstIndex(where: { $0.id == touch.id }) else { return }
        trackpadTouches[index] = touch
    }

    func trackpadTouchEnded(id: Int) {
        if let touch = trackpadTouches.first(where: { $0.id == id }) {
            releasePad(index: touch.padIndex)
        }
        trackpadTouches.removeAll(where: { $0.id == id })
        if trackpadTouches.isEmpty { NSCursor.unhide() }
    }

    func separateCurrentSong() {
        guard canSeparate, let source = project.stems.first else { return }
        let sourceURL = store.resolve(source.relativePath, in: projectURL)
        let output = projectURL
            .appendingPathComponent("Analysis", isDirectory: true)
            .appendingPathComponent("Separation-\(UUID().uuidString)", isDirectory: true)

        Task {
            do {
                let result = try await separator.separate(input: sourceURL, outputDirectory: output)
                let ordered: [(StemRole, URL)] = [
                    (.drums, result.drums), (.vocals, result.vocals),
                    (.instruments, result.other), (.bass, result.bass)
                ]
                var separated: [StemModel] = []
                for (role, url) in ordered {
                    let relative = try store.copyAsset(url, into: projectURL, folder: "Audio")
                    separated.append(StemModel(role: role, relativePath: relative))
                }
                project.stems = separated
                selectedStemID = separated.first?.id
                try store.save(project, to: projectURL)
                waveforms = [:]
                reloadAudio()
                analyzeAllWaveforms()
                notice = "Four stems are ready"
            } catch {
                presentedError = error.localizedDescription
            }
        }
    }

    func exportMix() {
        guard !project.stems.isEmpty else {
            presentedError = "Load a song or stems before exporting."
            return
        }
        let panel = NSSavePanel()
        panel.title = "Export Current Mix"
        panel.nameFieldStringValue = sanitizedProjectName + " — Mix.wav"
        panel.allowedContentTypes = [.wav]
        panel.begin { [weak self] response in
            guard response == .OK, let destination = panel.url, let self else { return }
            let stems = self.project.stems.map { ($0, self.store.resolve($0.relativePath, in: self.projectURL)) }
            let pads = self.project.pads.map { pad -> (PadModel, URL?) in
                let url = pad.relativePath.map { self.store.resolve($0, in: self.projectURL) }
                return (pad, url)
            }
            let pattern = self.isPatternEnabled ? self.project.pattern : nil
            self.exportProgress = 0
            Task {
                do {
                    try await MixExporter.export(
                        stems: stems,
                        pads: pads,
                        pattern: pattern,
                        duration: self.project.durationSeconds,
                        sampleRate: self.project.sampleRate,
                        destination: destination
                    ) { progress in
                        Task { @MainActor in self.exportProgress = progress }
                    }
                    self.exportProgress = nil
                    self.notice = "Exported \(destination.lastPathComponent)"
                    NSWorkspace.shared.activateFileViewerSelecting([destination])
                } catch {
                    self.exportProgress = nil
                    self.presentedError = error.localizedDescription
                }
            }
        }
    }

    private var sanitizedProjectName: String {
        let invalid = CharacterSet(charactersIn: "/:")
        return project.title.components(separatedBy: invalid).joined(separator: "-")
    }

    private func normalizeLoop() {
        project.loop.startSeconds = max(0, min(project.durationSeconds, project.loop.startSeconds))
        project.loop.endSeconds = max(
            project.loop.startSeconds + 0.05,
            min(project.durationSeconds, project.loop.endSeconds)
        )
    }

    private func persistAndReload() {
        scheduleAutosave()
        reloadAudio()
    }

    private func scheduleAutosave() {
        autosaveWorkItem?.cancel()
        let snapshot = project
        let url = projectURL
        let work = DispatchWorkItem { [store] in try? store.save(snapshot, to: url) }
        autosaveWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35, execute: work)
    }

    private func reloadAudio() {
        guard !project.stems.isEmpty else { return }
        let sources = project.stems.compactMap { model -> (StemModel, URL)? in
            let url = store.resolve(model.relativePath, in: projectURL)
            return FileManager.default.fileExists(atPath: url.path) ? (model, url) : nil
        }
        do {
            try audio.load(stems: sources, duration: project.durationSeconds, loop: project.loop)
            loadCustomPadBuffers()
        } catch {
            presentedError = error.localizedDescription
        }
    }

    private func loadCustomPadBuffers() {
        for pad in project.pads {
            guard let relative = pad.relativePath else { continue }
            let url = store.resolve(relative, in: projectURL)
            if let buffer = try? DrumSoundFactory.loadAndConvert(url: url) {
                audio.setPadBuffer(buffer, at: pad.index)
            }
        }
    }

    private func analyzeAllWaveforms() {
        for stem in project.stems {
            let url = store.resolve(stem.relativePath, in: projectURL)
            let stemID = stem.id
            Task { [weak self] in
                let result = await Task.detached(priority: .utility) {
                    try? WaveformAnalyzer.analyze(url: url)
                }.value
                if let result { self?.waveforms[stemID] = result.peaks }
            }
        }
    }

    private func recordPadHit(index: Int, velocity: Float) {
        let beat = (audio.currentTime * project.pattern.bpm / 60)
            .truncatingRemainder(dividingBy: project.pattern.lengthInBeats)
        let divisions = 16.0
        let stepSize = project.pattern.lengthInBeats / divisions
        let quantized = (beat / stepSize).rounded() * stepSize
        let blended = beat + (quantized - beat) * project.pattern.quantization
        project.pattern.events.append(PatternEvent(padIndex: index, beat: blended, velocity: velocity))
        project.pattern.events.sort { $0.beat < $1.beat }
        scheduleAutosave()
    }

    private func pollPattern() {
        guard isPatternEnabled, audio.isPlaying, !project.pattern.events.isEmpty else {
            lastPatternBeat = nil
            return
        }
        let length = project.pattern.lengthInBeats
        let current = (audio.currentTime * project.pattern.bpm / 60).truncatingRemainder(dividingBy: length)
        guard let last = lastPatternBeat else {
            lastPatternBeat = current
            return
        }

        let timedEvents = project.pattern.events.map { ($0, swungBeat(for: $0)) }
        let events: [PatternEvent]
        if current >= last {
            events = timedEvents.filter { $0.1 > last && $0.1 <= current }.map(\.0)
        } else {
            events = timedEvents.filter { $0.1 > last || $0.1 <= current }.map(\.0)
        }
        if !events.isEmpty {
            let host = audio.commonPadHostTime()
            for event in events where project.pads.indices.contains(event.padIndex) {
                audio.triggerPad(project.pads[event.padIndex], velocity: event.velocity, hostTime: host)
                activePads.insert(event.padIndex)
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: .milliseconds(85))
                    self?.activePads.remove(event.padIndex)
                }
            }
        }
        lastPatternBeat = current
    }

    private func swungBeat(for event: PatternEvent) -> Double {
        let sixteenth = Int((event.beat * 4).rounded())
        guard sixteenth.isMultiple(of: 2) == false else { return event.beat }
        return min(project.pattern.lengthInBeats - 0.000_1, event.beat + 0.25 * project.pattern.swing)
    }

    private func handleKeyboard(_ action: KeyboardMonitor.Action) {
        switch action {
        case .togglePlayback: audio.togglePlayback()
        case .returnToStart: audio.seek(to: 0)
        case .skip(let amount): audio.skip(seconds: amount)
        case .toggleLoop: toggleLoop()
        case .setLoopIn: setLoopIn()
        case .setLoopOut: setLoopOut()
        case .toggleTrackpad: armTrackpad(!isTrackpadArmed); mode = .pads
        case .escape:
            if isTrackpadArmed { armTrackpad(false) }
            else { showShortcutOverlay = false }
        case .selectStem(let index):
            if project.stems.indices.contains(index) { selectedStemID = project.stems[index].id }
        case .adjustStem(let amount):
            guard let selectedStemID else { return }
            updateStem(selectedStemID) { $0.gainDB = max(-60, min(6, $0.gainDB + amount)) }
        case .toggleMute:
            guard let selectedStemID else { return }
            updateStem(selectedStemID) { $0.isMuted.toggle() }
        case .toggleSolo:
            guard let selectedStemID else { return }
            updateStem(selectedStemID) { $0.isSolo.toggle() }
        case .triggerPad(let index, let isDown):
            if isDown { triggerPad(index: index, hold: true) }
            else { releasePad(index: index) }
        }
    }
}
