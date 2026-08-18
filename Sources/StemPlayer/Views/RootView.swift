import SwiftUI

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            Color.instrumentBackground.ignoresSafeArea()

            VStack(spacing: 11) {
                topDeck

                if app.project.stems.isEmpty {
                    IdleDisplay()
                } else {
                    WaveformTimeline()
                }

                Group {
                    switch app.mode {
                    case .mix:
                        app.project.stems.isEmpty ? AnyView(EmptyInstrumentView()) : AnyView(MixSurface())
                    case .pads:
                        AnyView(PadSurface())
                    case .pattern:
                        AnyView(PatternSurface())
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                transportDeck
            }
            .padding(.horizontal, 14)
            .padding(.top, 9)
            .padding(.bottom, 13)
            .background(Color.instrumentSurface)
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.42), lineWidth: 1))

            if dropTargeted { dropOverlay }
            if app.isImporting { WorkingOverlay(label: "Reading audio") }
            if let progress = app.exportProgress { ExportOverlay(progress: progress) }
            if app.showShortcutOverlay { ShortcutOverlay() }
            if let notice = app.notice { noticeView(notice) }
        }
        .foregroundStyle(Color.instrumentInk)
        .animation(.easeInOut(duration: 0.12), value: app.showShortcutOverlay)
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

    private var topDeck: some View {
        ZStack {
            if ProcessInfo.processInfo.environment["SP4_RENDERING_PREVIEW"] == "1" {
                Color.clear
            } else {
                WindowDragArea()
            }
            HStack(spacing: 13) {
                productMark
                sessionMenu
                Spacer(minLength: 10)
                ModeSelector(selection: $app.mode)
                Rectangle().fill(Color.instrumentLine).frame(width: 1, height: 36)
                statusDisplay
                Button { audio.togglePlayback() } label: {
                    Image(systemName: audio.isPlaying ? "pause.fill" : "play.fill")
                        .offset(x: audio.isPlaying ? 0 : 1)
                }
                .buttonStyle(CircleTransportButtonStyle(tint: .instrumentOrange, size: 36))
                .help("Play or pause — Space")
            }
            .padding(.leading, 64)
            .padding(.trailing, 2)
        }
        .frame(height: 48)
    }

    private var productMark: some View {
        HStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<4, id: \.self) { index in
                    Rectangle()
                        .fill(Color.padColor(index))
                        .frame(width: 3.5, height: CGFloat(11 + index * 3))
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("sp–4")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.7)
                Text("stem instrument")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.instrumentTextSecondary)
            }
        }
        .frame(width: 108, alignment: .leading)
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
            Button("Export mix…") { app.exportMix() }
                .disabled(app.project.stems.isEmpty)
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
        HStack(spacing: 9) {
            HardwareLED(color: app.project.stems.isEmpty ? .instrumentOrange : .instrumentGreen, isOn: true)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.project.title)
                    .font(.system(size: 10, weight: .semibold))
                    .lineLimit(1)
                Text(app.project.stems.isEmpty ? "load audio" : "\(app.project.stems.count) channel\(app.project.stems.count == 1 ? "" : "s")")
                    .font(.system(size: 7.5, weight: .medium))
                    .foregroundStyle(Color.instrumentTextSecondary)
            }
            Spacer(minLength: 5)
            Image(systemName: "chevron.down")
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(Color.instrumentTextSecondary)
        }
        .padding(.horizontal, 10)
        .frame(width: 190, height: 36)
        .background(Color.instrumentPlate)
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    private var statusDisplay: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(audio.currentTime.transportString)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentYellow)
            HStack(spacing: 5) {
                HardwareLED(color: audio.isPlaying ? .instrumentGreen : .instrumentOrange, isOn: true, size: 5)
                Text(statusText)
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.48))
            }
        }
        .padding(.horizontal, 10)
        .frame(width: 120, height: 37, alignment: .leading)
        .background(Color.instrumentDisplay)
        .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.62), lineWidth: 1))
    }

    private var statusText: String {
        switch app.separator.state {
        case .preparing: "PREPARING"
        case .running(let progress, _): "SPLIT \(Int(progress * 100))%"
        case .failed: "CHECK SPLIT"
        default:
            app.project.stems.isEmpty ? "NO MEDIA" : (audio.isPlaying ? "RUN" : app.mode.shortName)
        }
    }

    private var transportDeck: some View {
        HStack(spacing: 8) {
            Text("TRANSPORT")
                .font(.system(size: 7, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(Color.instrumentTextSecondary)
            Button("|◀") { audio.seek(to: 0) }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .help("Return to start — Return")
            Button("−5") { audio.skip(seconds: -5) }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .help("Back five seconds — J")
            Button("+5") { audio.skip(seconds: 5) }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .help("Forward five seconds — L")
            Rectangle().fill(Color.instrumentLine).frame(width: 1, height: 25)
            Button(app.project.loop.isEnabled ? "Loop on" : "Loop") { app.toggleLoop() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentYellow, isLatched: app.project.loop.isEnabled, compact: true))
            Button("In") { app.setLoopIn() }.buttonStyle(InstrumentButtonStyle(compact: true))
            Button("Out") { app.setLoopOut() }.buttonStyle(InstrumentButtonStyle(compact: true))

            Spacer()

            HStack(spacing: 4) {
                ForEach(0..<4, id: \.self) { index in
                    HardwareLED(color: Color.padColor(index), isOn: index < app.project.stems.count)
                }
            }
            Text(app.mode.detailName)
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)
            Spacer()

            Button("Keys") { app.showShortcutOverlay = true }
                .buttonStyle(InstrumentButtonStyle(compact: true))
            Button("Load") { app.presentAudioImporter() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, compact: true))
            Button("Export") { app.exportMix() }
                .buttonStyle(InstrumentButtonStyle(compact: true))
                .disabled(app.project.stems.isEmpty)
        }
        .padding(.horizontal, 10)
        .frame(height: 42)
        .background(Color.instrumentPlate)
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    private var dropOverlay: some View {
        Rectangle()
            .fill(Color.instrumentSurface.opacity(0.96))
            .overlay(Rectangle().stroke(Color.instrumentOrange, style: StrokeStyle(lineWidth: 2, dash: [5, 5])).padding(18))
            .overlay(
                VStack(spacing: 8) {
                    StemGlyph(size: 64)
                    Text("Drop audio to load")
                        .font(.system(size: 17, weight: .semibold))
                    Text("one song or a set of prepared stems")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.instrumentTextSecondary)
                }
            )
            .padding(12)
            .allowsHitTesting(false)
    }

    private func noticeView(_ notice: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                HardwareLED(color: .instrumentGreen, isOn: true)
                Text(notice)
                    .font(.system(size: 9, weight: .medium))
            }
            .padding(.horizontal, 13)
            .frame(height: 32)
            .background(Color.instrumentRaised)
            .overlay(Rectangle().stroke(Color.instrumentLine))
            .shadow(color: Color.instrumentInk.opacity(0.22), radius: 0, y: 2)
            .padding(.bottom, 12)
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

private struct IdleDisplay: View {
    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 3) {
                ForEach(0..<4, id: \.self) { index in
                    Capsule().fill(Color.padColor(index).opacity(0.55)).frame(width: 3, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("NO SIGNAL")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.instrumentYellow)
                Text("DROP A SONG OR OPEN AUDIO TO BEGIN")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            Spacer()
            Text("44.1 kHz  /  32-bit engine")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.3))
        }
        .padding(.horizontal, 13)
        .frame(height: 68)
        .background(Color.instrumentDisplay)
        .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.62), lineWidth: 1))
    }
}

private struct EmptyInstrumentView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(spacing: 34) {
            StemGlyph(size: 116)
            VStack(alignment: .leading, spacing: 13) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Start with audio")
                        .font(.system(size: 19, weight: .semibold))
                    Text("Open one complete song or several prepared stems. WAV, AIFF, MP3, M4A, FLAC, and other common formats are accepted.")
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(Color.instrumentTextSecondary)
                        .lineSpacing(2)
                        .frame(maxWidth: 410, alignment: .leading)
                }
                HStack(spacing: 8) {
                    Button("Load audio") { app.presentAudioImporter() }
                        .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: true))
                    Button("Open project") { app.presentProjectImporter() }
                        .buttonStyle(InstrumentButtonStyle())
                }
                Text("Drag files anywhere onto the instrument")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.instrumentTextSecondary)
            }
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
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 16)
            .frame(height: 40)
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
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Rendering mix").font(.system(size: 12, weight: .semibold))
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                ProgressView(value: progress).progressViewStyle(.linear).tint(.instrumentOrange).frame(width: 300)
                Text("offline / full quality")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.instrumentTextSecondary)
            }
            .padding(18)
            .background(Color.instrumentRaised)
            .overlay(Rectangle().stroke(Color.instrumentLine))
        }
    }
}
