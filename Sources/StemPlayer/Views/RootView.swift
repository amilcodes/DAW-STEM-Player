import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            Color.instrumentBackground.ignoresSafeArea()

            VStack(spacing: 3) {
                deviceHeader
                WaveformTimeline()
                modeDeck
                workspace.frame(maxWidth: .infinity, maxHeight: .infinity)
                transportDeck
                fileDeck
            }
            .padding(.horizontal, 5)
            .padding(.top, 4)
            .padding(.bottom, 6)
            .background(Color.instrumentSurface)
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.28), lineWidth: 0.7))

            if dropTargeted { dropOverlay }
            if app.isImporting { WorkingOverlay(label: "READING AUDIO") }
            if let progress = app.exportProgress { ExportOverlay(progress: progress) }
            if app.showShortcutOverlay { ShortcutOverlay() }
            if let notice = app.notice { noticeView(notice) }
        }
        .foregroundStyle(Color.instrumentInk)
        .animation(.easeInOut(duration: 0.1), value: app.showShortcutOverlay)
        .dropDestination(
            for: URL.self,
            action: { urls, _ in
                Task { await app.importAudioFiles(urls) }
                return !urls.isEmpty
            },
            isTargeted: { dropTargeted = $0 }
        )
        .onOpenURL { url in
            if url.pathExtension.lowercased() == "stemproject" { app.openProject(at: url) }
            else { Task { await app.importAudioFiles([url]) } }
        }
        .alert(
            "Stem Player",
            isPresented: Binding(get: { app.presentedError != nil }, set: { if !$0 { app.presentedError = nil } })
        ) {
            Button("OK") { app.presentedError = nil }
        } message: {
            Text(app.presentedError ?? "Unknown error")
        }
        .onChange(of: app.notice) { _, value in
            guard value != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                if app.notice == value { app.notice = nil }
            }
        }
    }

    @ViewBuilder private var workspace: some View {
        switch app.mode {
        case .mix:
            if app.project.stems.isEmpty { EmptyInstrumentView() }
            else { MixSurface() }
        case .pads:
            PadSurface()
        case .pattern:
            PatternSurface()
        }
    }

    private var deviceHeader: some View {
        ZStack {
            if ProcessInfo.processInfo.environment["SP4_RENDERING_PREVIEW"] == "1" {
                Color.clear
            } else {
                WindowDragArea()
            }
            HStack(spacing: 6) {
                productMark
                sessionMenu
                Spacer(minLength: 0)
                Button { audio.togglePlayback() } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .offset(x: audio.isPlaying ? 0 : 1)
                }
                .buttonStyle(CircleTransportButtonStyle(tint: .instrumentOrange, size: 28))
                .help("Play or pause — Space")
            }
            .padding(.leading, 48)
            .padding(.trailing, 1)
        }
        .frame(height: 34)
    }

    private var productMark: some View {
        HStack(spacing: 4) {
            Rectangle().fill(Color.instrumentOrange).frame(width: 2, height: 14)
            Text("sp–4")
                .font(.instrument(13, weight: .medium))
                .tracking(-0.4)
        }
        .frame(width: 49, alignment: .leading)
    }

    @ViewBuilder private var sessionMenu: some View {
        if ProcessInfo.processInfo.environment["SP4_RENDERING_PREVIEW"] == "1" {
            sessionLabel
        } else {
            Menu {
                Button("Import song or stems…") { app.presentAudioImporter() }
                Button("Open project…") { app.presentProjectImporter() }
                Divider()
                Button("Save project as…") { app.saveProjectAs() }
                Button("Export mix…") { app.exportMix() }.disabled(app.project.stems.isEmpty)
                if app.canSeparate {
                    Divider()
                    Button("Separate song into four stems") { app.separateCurrentSong() }
                }
                if !app.project.stems.isEmpty {
                    Divider()
                    Menu("Channels") {
                        ForEach(Array(app.project.stems.enumerated()), id: \.element.id) { index, stem in
                            Button("\(index + 1)  \(stem.name)") { app.selectStem(stem.id) }
                        }
                    }
                }
                Divider()
                Button("New session") { app.newSession() }
                Button("Keyboard map") { app.showShortcutOverlay = true }
            } label: {
                sessionLabel
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var sessionLabel: some View {
        HStack(spacing: 5) {
            HardwareLED(color: app.project.stems.isEmpty ? .instrumentOrange : .instrumentGreen, isOn: true, size: 3)
            Text(app.project.title)
                .font(.instrument(7.5, weight: .medium))
                .lineLimit(1)
            Spacer(minLength: 1)
            Text(app.project.stems.isEmpty ? "–" : "\(app.project.stems.count)")
                .font(.instrumentNumber(6, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)
            Image(systemName: "chevron.down")
                .font(.instrument(5, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .padding(.horizontal, 6)
        .frame(width: 108, height: 27)
        .background(Color.instrumentRaised.opacity(0.72))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
    }

    private var modeDeck: some View {
        HStack {
            HardwareLED(color: audio.isPlaying ? .instrumentGreen : .instrumentInk, isOn: true, size: 3)
            Spacer(minLength: 0)
            ModeSelector(selection: $app.mode)
            Spacer(minLength: 0)
            Color.clear.frame(width: 3, height: 3)
        }
        .padding(.horizontal, 7)
        .frame(height: 31)
        .background(Color.instrumentPlate.opacity(0.48))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
    }

    private var transportDeck: some View {
        HStack(spacing: 4) {
            Button("|◀") { audio.seek(to: 0) }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .help("Return to start — Return")
            Button("−5") { audio.skip(seconds: -5) }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .help("Back five seconds — J")
            Button("+5") { audio.skip(seconds: 5) }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .help("Forward five seconds — L")
            Spacer(minLength: 0)
            Button("loop") { app.toggleLoop() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.project.loop.isEnabled, compact: true))
            Button("in") { app.setLoopIn() }.buttonStyle(InstrumentButtonStyle(compact: true))
            Button("out") { app.setLoopOut() }.buttonStyle(InstrumentButtonStyle(compact: true))
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
        .background(Color.instrumentPlate.opacity(0.62))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
    }

    private var fileDeck: some View {
        HStack(spacing: 4) {
            HardwareLED(color: app.project.stems.isEmpty ? .instrumentInk : .instrumentOrange, isOn: true, size: 3)
            Text(app.project.stems.isEmpty ? "–" : "\(app.project.stems.count)")
                .font(.instrumentNumber(6, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)
            if app.canSeparate {
                Button("split") { app.separateCurrentSong() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, compact: true))
            }
            Spacer(minLength: 0)
            Button("keys") { app.showShortcutOverlay = true }
                .buttonStyle(InstrumentButtonStyle(compact: true))
            Button("load") { app.presentAudioImporter() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, compact: true))
            Button("export") { app.exportMix() }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .disabled(app.project.stems.isEmpty)
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
        .background(Color.instrumentPlate.opacity(0.62))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
    }

    private var dropOverlay: some View {
        Rectangle()
            .fill(Color.instrumentSurface.opacity(0.97))
            .overlay(Rectangle().stroke(Color.instrumentOrange, style: StrokeStyle(lineWidth: 2, dash: [4, 4])).padding(7))
            .overlay(
                VStack(spacing: 8) {
                    StemGlyph(size: 52)
                    Text("drop audio").font(.instrument(12, weight: .medium))
                    Text("song or prepared stems")
                        .font(.instrument(6.5, weight: .regular))
                        .foregroundStyle(Color.instrumentTextSecondary)
                }
            )
            .padding(5)
            .allowsHitTesting(false)
    }

    private func noticeView(_ notice: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 6) {
                HardwareLED(color: .instrumentGreen, isOn: true)
                Text(notice).font(.instrument(7, weight: .medium))
            }
            .padding(.horizontal, 9)
            .frame(height: 23)
            .background(Color.instrumentRaised)
            .overlay(Rectangle().stroke(Color.instrumentLine))
            .padding(.bottom, 6)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}

struct StemGlyph: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.instrumentRaised).overlay(Circle().stroke(Color.instrumentInk.opacity(0.42), lineWidth: 1))
            Capsule()
                .fill(Color.instrumentOrange)
                .frame(width: size * 0.055, height: size * 0.25)
                .offset(y: -size * 0.2)
            Circle().fill(Color.instrumentInk).frame(width: size * 0.23, height: size * 0.23)
        }
        .frame(width: size, height: size)
    }
}

private struct EmptyInstrumentView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 9) {
            StemGlyph(size: 64)
            Text("load audio")
                .font(.instrument(11, weight: .medium))
            Text("wav · aiff · mp3 · m4a · flac")
                .font(.instrument(6.5, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
            HStack(spacing: 5) {
                Button("load") { app.presentAudioImporter() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: true, compact: true))
                Button("project") { app.presentProjectImporter() }
                    .buttonStyle(InstrumentButtonStyle(compact: true))
            }
            Text("drop files anywhere")
                .font(.instrument(6, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.instrumentPlate.opacity(0.36))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }
}

private struct WorkingOverlay: View {
    var label: String

    var body: some View {
        ZStack {
            Color.instrumentInk.opacity(0.42).ignoresSafeArea()
            HStack(spacing: 7) {
                ProgressView().controlSize(.small)
                Text(label.lowercased()).font(.instrument(8, weight: .medium))
            }
            .padding(.horizontal, 12)
            .frame(height: 30)
            .background(Color.instrumentRaised)
            .overlay(Rectangle().stroke(Color.instrumentLine))
        }
    }
}

private struct ExportOverlay: View {
    var progress: Double

    var body: some View {
        ZStack {
            Color.instrumentInk.opacity(0.52).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    Text("render mix").font(.instrument(9, weight: .medium))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.instrumentNumber(9, weight: .medium))
                }
                ProgressView(value: progress).progressViewStyle(.linear).tint(.instrumentOrange).frame(width: 220)
            }
            .padding(13)
            .background(Color.instrumentRaised)
            .overlay(Rectangle().stroke(Color.instrumentLine))
        }
    }
}
