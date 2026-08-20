import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            Color.instrumentBackground.ignoresSafeArea()

            VStack(spacing: 4) {
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
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.5), lineWidth: 1))

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
            HStack(alignment: .bottom, spacing: 1.2) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(Color.padColor(index))
                        .frame(width: 2.3, height: CGFloat(8 + index * 2))
                }
            }
            Text("sp–4")
                .font(.system(size: 13, weight: .semibold))
                .tracking(-0.6)
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
            HardwareLED(color: app.project.stems.isEmpty ? .instrumentOrange : .instrumentGreen, isOn: true, size: 4)
            VStack(alignment: .leading, spacing: 0) {
                Text(app.project.title.uppercased())
                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                Text(app.project.stems.isEmpty ? "LOAD" : "\(app.project.stems.count) CHANNEL")
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.instrumentTextSecondary)
            }
            Spacer(minLength: 1)
            Image(systemName: "chevron.down")
                .font(.system(size: 5.5, weight: .semibold))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .padding(.horizontal, 6)
        .frame(width: 108, height: 27)
        .background(Color.instrumentPlate)
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    private var modeDeck: some View {
        HStack(spacing: 6) {
            VStack(alignment: .leading, spacing: 0) {
                Text(app.mode.detailName.uppercased())
                    .font(.system(size: 6, weight: .semibold, design: .monospaced))
                    .lineLimit(1)
                HStack(spacing: 3) {
                    HardwareLED(color: audio.isPlaying ? .instrumentGreen : app.mode.accent, isOn: true, size: 3)
                    Text(audio.isPlaying ? "RUN" : "READY")
                        .font(.system(size: 5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.instrumentTextSecondary)
                }
            }
            Spacer(minLength: 0)
            ModeSelector(selection: $app.mode)
        }
        .padding(.horizontal, 7)
        .frame(height: 31)
        .background(Color.instrumentPlate.opacity(0.72))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
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
            Button("Loop") { app.toggleLoop() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentYellow, isLatched: app.project.loop.isEnabled, compact: true))
            Button("In") { app.setLoopIn() }.buttonStyle(InstrumentButtonStyle(compact: true))
            Button("Out") { app.setLoopOut() }.buttonStyle(InstrumentButtonStyle(compact: true))
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
        .background(Color.instrumentPlate)
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    private var fileDeck: some View {
        HStack(spacing: 4) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    HardwareLED(color: Color.padColor(index), isOn: index < app.project.stems.count, size: 4)
                }
            }
            Text(app.project.stems.isEmpty ? "EMPTY" : "\(app.project.stems.count)CH")
                .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary)
            Spacer(minLength: 0)
            Button("Keys") { app.showShortcutOverlay = true }
                .buttonStyle(InstrumentButtonStyle(compact: true))
            Button("Load") { app.presentAudioImporter() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, compact: true))
            Button("Export") { app.exportMix() }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .disabled(app.project.stems.isEmpty)
        }
        .padding(.horizontal, 4)
        .frame(height: 26)
        .background(Color.instrumentPlate)
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    private var dropOverlay: some View {
        Rectangle()
            .fill(Color.instrumentSurface.opacity(0.97))
            .overlay(Rectangle().stroke(Color.instrumentOrange, style: StrokeStyle(lineWidth: 2, dash: [4, 4])).padding(7))
            .overlay(
                VStack(spacing: 8) {
                    StemGlyph(size: 52)
                    Text("DROP AUDIO").font(.system(size: 12, weight: .semibold, design: .monospaced))
                    Text("SONG OR PREPARED STEMS")
                        .font(.system(size: 6, weight: .medium, design: .monospaced))
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
                Text(notice.uppercased()).font(.system(size: 7, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 9)
            .frame(height: 23)
            .background(Color.instrumentRaised)
            .overlay(Rectangle().stroke(Color.instrumentLine))
            .shadow(color: Color.instrumentInk.opacity(0.22), radius: 0, y: 2)
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
            ForEach(0..<4, id: \.self) { index in
                Capsule()
                    .fill(Color.padColor(index))
                    .frame(width: size * 0.085, height: size * 0.26)
                    .offset(y: -size * 0.19)
                    .rotationEffect(.degrees(Double(index) * 90))
            }
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
            Text("LOAD AUDIO")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
            Text("WAV  AIFF  MP3  M4A  FLAC")
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary)
            HStack(spacing: 5) {
                Button("Load") { app.presentAudioImporter() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: true, compact: true))
                Button("Project") { app.presentProjectImporter() }
                    .buttonStyle(InstrumentButtonStyle(compact: true))
            }
            Text("DROP FILES ANYWHERE")
                .font(.system(size: 5.5, weight: .medium, design: .monospaced))
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
                Text(label).font(.system(size: 8, weight: .medium, design: .monospaced))
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
                    Text("RENDER MIX").font(.system(size: 9, weight: .semibold, design: .monospaced))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                ProgressView(value: progress).progressViewStyle(.linear).tint(.instrumentOrange).frame(width: 220)
            }
            .padding(13)
            .background(Color.instrumentRaised)
            .overlay(Rectangle().stroke(Color.instrumentLine))
        }
    }
}
