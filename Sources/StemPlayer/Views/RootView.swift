import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController
    @State private var dropTargeted = false

    var body: some View {
        ZStack {
            Color.instrumentBackground.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Rectangle().fill(Color.instrumentInk.opacity(0.55)).frame(height: 1)

                HStack(spacing: 0) {
                    Sidebar(separator: app.separator).frame(width: 232)
                    Rectangle().fill(Color.instrumentInk.opacity(0.42)).frame(width: 1)

                    VStack(spacing: 10) {
                        if !app.project.stems.isEmpty { WaveformTimeline() }
                        Group {
                            switch app.mode {
                            case .mix:
                                if app.project.stems.isEmpty { EmptyInstrumentView() } else { MixSurface() }
                            case .pads: PadSurface()
                            case .pattern: PatternSurface()
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .padding(12)

                    if app.isInspectorVisible {
                        Rectangle().fill(Color.instrumentInk.opacity(0.42)).frame(width: 1)
                        Inspector().frame(width: 236)
                    }
                }
            }

            if dropTargeted { dropOverlay }
            if let progress = app.exportProgress { ExportOverlay(progress: progress) }
            if app.showShortcutOverlay { ShortcutOverlay() }
            if let notice = app.notice { noticeView(notice) }
        }
        .foregroundStyle(Color.instrumentInk)
        .animation(.easeInOut(duration: 0.14), value: app.isInspectorVisible)
        .animation(.easeInOut(duration: 0.12), value: app.showShortcutOverlay)
        .dropDestination(
            for: URL.self,
            action: { urls, _ in Task { await app.importAudioFiles(urls) }; return !urls.isEmpty },
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
        } message: { Text(app.presentedError ?? "Unknown error") }
        .onChange(of: app.notice) { _, value in
            guard value != nil else { return }
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(2.4))
                if app.notice == value { app.notice = nil }
            }
        }
    }

    private var topBar: some View {
        ZStack {
            WindowDragArea()
            HStack(spacing: 14) {
                HStack(spacing: 11) {
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { index in
                            Rectangle().fill(Color.padColor(index)).frame(width: 4, height: CGFloat(12 + index * 3))
                        }
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text("SP–4").font(.system(size: 14, weight: .black, design: .monospaced)).tracking(-0.6)
                        Text("STEM PERFORMANCE SYSTEM").font(.system(size: 7, weight: .bold, design: .monospaced)).tracking(0.55)
                    }
                }

                Spacer()
                ModePicker(selection: $app.mode)
                Spacer()

                HStack(spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(audio.currentTime.transportString)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.instrumentYellow)
                        Text(app.project.stems.isEmpty ? "NO MEDIA" : (audio.isPlaying ? "RUN" : "STANDBY"))
                            .font(.system(size: 7, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.48))
                    }
                    .frame(width: 95, alignment: .leading)
                    .padding(.horizontal, 9)
                    .frame(height: 34)
                    .background(Rectangle().fill(Color.instrumentDisplay))
                    .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.8), lineWidth: 1))

                    Button { audio.togglePlayback() } label: { Text(audio.isPlaying ? "Ⅱ" : "▶") }
                        .buttonStyle(CircleTransportButtonStyle(tint: .instrumentOrange, size: 34))

                    if !app.isInspectorVisible {
                        Button("EDIT") { app.isInspectorVisible = true }
                            .buttonStyle(InstrumentButtonStyle(compact: true))
                    }
                }
            }
            .padding(.leading, 78)
            .padding(.trailing, 13)
        }
        .frame(height: 58)
        .background(Color.instrumentSurface)
    }

    private var dropOverlay: some View {
        Rectangle()
            .fill(Color.instrumentSurface.opacity(0.94))
            .overlay(Rectangle().stroke(Color.instrumentOrange, style: StrokeStyle(lineWidth: 2, dash: [6, 5])).padding(24))
            .overlay(
                VStack(spacing: 10) {
                    StemGlyph(size: 62)
                    Text("LOAD AUDIO").font(.system(size: 18, weight: .black, design: .monospaced))
                    Text("ONE SONG OR MULTIPLE PREPARED STEMS").instrumentLabel()
                }
            )
            .padding(24)
            .allowsHitTesting(false)
    }

    private func noticeView(_ notice: String) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 8) {
                HardwareLED(color: .instrumentGreen, isOn: true)
                Text(notice.uppercased()).font(.system(size: 9, weight: .bold, design: .monospaced))
            }
            .padding(.horizontal, 14).frame(height: 34)
            .background(Rectangle().fill(Color.instrumentRaised).overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.55))))
            .shadow(color: Color.instrumentInk.opacity(0.28), radius: 0, y: 3)
            .padding(.bottom, 16)
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .allowsHitTesting(false)
    }
}

private struct StemGlyph: View {
    var size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(Color.instrumentRaised).overlay(Circle().stroke(Color.instrumentInk.opacity(0.65), lineWidth: 1))
            ForEach(0..<4, id: \.self) { index in
                Capsule().fill(Color.padColor(index)).frame(width: size * 0.095, height: size * 0.27).offset(y: -size * 0.19).rotationEffect(.degrees(Double(index) * 90))
            }
            Circle().fill(Color.instrumentInk).frame(width: size * 0.25, height: size * 0.25)
        }
        .frame(width: size, height: size)
    }
}

private struct EmptyInstrumentView: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            PanelScrews()
            HStack(spacing: 54) {
                StemGlyph(size: 228)
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("LOAD A RECORDING").font(.system(size: 21, weight: .black, design: .monospaced)).tracking(-0.8)
                        Text("Start with one complete song, or select multiple already-separated files. WAV, AIFF, MP3, M4A, FLAC and most common audio formats are accepted.")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.instrumentTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: 360, alignment: .leading)
                    }
                    HStack(spacing: 9) {
                        Button("OPEN SONG") { app.presentAudioImporter() }
                            .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: true))
                        Button("OPEN STEMS") { app.presentAudioImporter() }
                            .buttonStyle(InstrumentButtonStyle())
                    }
                    Text("TIP  DRAG FILES ANYWHERE ONTO THE INSTRUMENT").instrumentLabel()
                }
            }
            .padding(46)
        }
        .instrumentPanel(cornerRadius: 3)
    }
}

private struct ExportOverlay: View {
    var progress: Double

    var body: some View {
        ZStack {
            Color.instrumentInk.opacity(0.58).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("RENDER MIX").font(.system(size: 13, weight: .black, design: .monospaced))
                    Spacer()
                    Text("\(Int(progress * 100))%").font(.system(size: 13, weight: .bold, design: .monospaced))
                }
                ProgressView(value: progress).progressViewStyle(.linear).tint(.instrumentOrange).frame(width: 310)
                Text("OFFLINE / FULL QUALITY").instrumentLabel()
            }
            .padding(22).instrumentPanel(cornerRadius: 2)
        }
    }
}
