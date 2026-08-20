import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            Color.instrumentBackground.ignoresSafeArea()

            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.instrumentSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.instrumentInk.opacity(0.2), lineWidth: 0.7)
                )
                .padding(3)

            VStack(spacing: 0) {
                deviceHeader
                    .fixedSize(horizontal: false, vertical: true)
                WaveformTimeline()
                    .fixedSize(horizontal: false, vertical: true)
                GeometryReader { proxy in
                    workspace
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
                .padding(.vertical, 8)
                Rectangle().fill(Color.instrumentLine).frame(height: 0.7)
                commandRail
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 10)
            .padding(.top, 7)
            .padding(.bottom, 6)

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
                Spacer(minLength: 0)
                ModeSelector(selection: $app.mode)
                sessionMenu
            }
        }
        .frame(height: 37)
    }

    private var productMark: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("sp–4")
                .font(.instrument(11, weight: .medium))
                .tracking(-0.3)
            Text("field instrument")
                .font(.instrument(5, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .frame(width: 69, alignment: .leading)
    }

    @ViewBuilder private var sessionMenu: some View {
        if ProcessInfo.processInfo.environment["SP4_RENDERING_PREVIEW"] == "1" {
            sessionMenuLabel
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
                sessionMenuLabel
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var sessionMenuLabel: some View {
        ZStack {
            Circle()
                .fill(Color.instrumentRaised)
                .overlay(Circle().stroke(Color.instrumentInk.opacity(0.24), lineWidth: 0.7))
            HStack(spacing: 1.5) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Color.instrumentInk.opacity(0.66)).frame(width: 2, height: 2)
                }
            }
        }
        .frame(width: 22, height: 22)
    }

    private var commandRail: some View {
        HStack(spacing: 3) {
            Button("|◀") { audio.seek(to: 0) }
                .buttonStyle(HardwareKeyStyle())
                .help("Return to start — Return")
            Button("−5") { audio.skip(seconds: -5) }
                .buttonStyle(HardwareKeyStyle())
                .help("Back five seconds — J")
            Button { audio.togglePlayback() } label: {
                Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 8, weight: .semibold))
                    .offset(x: audio.isPlaying ? 0 : 0.5)
            }
            .buttonStyle(HardwareKeyStyle(width: 32, accent: .instrumentOrange, isPrimary: true))
            .help("Play or pause — Space")
            Button("+5") { audio.skip(seconds: 5) }
                .buttonStyle(HardwareKeyStyle())
                .help("Forward five seconds — L")
            Spacer(minLength: 3)
            Button("↻") { app.toggleLoop() }
                .buttonStyle(HardwareKeyStyle(accent: .instrumentOrange, isLatched: app.project.loop.isEnabled))
                .help("Loop — Command-L")
            Button("I") { app.setLoopIn() }
                .buttonStyle(HardwareKeyStyle(width: 25))
                .help("Set loop in — I")
            Button("O") { app.setLoopOut() }
                .buttonStyle(HardwareKeyStyle(width: 25))
                .help("Set loop out — O")
            Spacer(minLength: 3)
            Button("↓") { app.presentAudioImporter() }
                .buttonStyle(HardwareKeyStyle())
                .help("Load audio — Command-O")
            Button("↑") { app.exportMix() }
                .buttonStyle(HardwareKeyStyle())
                .disabled(app.project.stems.isEmpty)
                .help("Export mix — Command-E")
        }
        .frame(height: 39)
    }

    private var dropOverlay: some View {
        Rectangle()
            .fill(Color.instrumentSurface.opacity(0.985))
            .overlay(Rectangle().fill(Color.instrumentOrange).frame(width: 2).padding(.vertical, 12), alignment: .leading)
            .overlay(
                VStack(spacing: 8) {
                    Text("drop audio").font(.instrument(12, weight: .medium))
                    Text("song or prepared stems")
                        .font(.instrument(6.5, weight: .regular))
                        .foregroundStyle(Color.instrumentTextSecondary)
                }
            )
            .padding(10)
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

private struct EmptyInstrumentView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 9) {
            Text("load audio")
                .font(.instrument(11, weight: .medium))
            Text("wav · aiff · mp3 · m4a · flac")
                .font(.instrument(6.5, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
            HStack(spacing: 5) {
                Button("load") { app.presentAudioImporter() }
                    .buttonStyle(HardwareKeyStyle(width: 48, height: 28, accent: .instrumentOrange, isPrimary: true))
                Button("project") { app.presentProjectImporter() }
                    .buttonStyle(HardwareKeyStyle(width: 52, height: 28))
            }
            Text("drop files anywhere")
                .font(.instrument(6, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
