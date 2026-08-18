import SwiftUI

struct Sidebar: View {
    @EnvironmentObject private var app: AppState
    @ObservedObject private var separator: SeparationService

    init(separator: SeparationService) { self.separator = separator }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("MEDIA / SESSION")
            VStack(alignment: .leading, spacing: 6) {
                TextField("SESSION NAME", text: Binding(get: { app.project.title }, set: app.renameProject))
                    .textFieldStyle(.plain)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .lineLimit(1)
                Text(app.project.stems.isEmpty ? "EMPTY" : "\(app.project.stems.count) ACTIVE CHANNEL\(app.project.stems.count == 1 ? "" : "S")")
                    .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
            }
            .padding(13)

            HStack(spacing: 7) {
                Button("+ AUDIO") { app.presentAudioImporter() }.buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, compact: true))
                Button("OPEN") { app.presentProjectImporter() }.buttonStyle(InstrumentButtonStyle(compact: true))
            }
            .padding(.horizontal, 13).padding(.bottom, 13)

            sectionLabel("CHANNEL BAY")
            if app.project.stems.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 4) { ForEach(0..<4, id: \.self) { HardwareLED(color: Color.padColor($0), isOn: false) } }
                    Text("NO AUDIO FITTED\nDROP A SONG OR OPEN FILES")
                        .font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary).lineSpacing(3)
                }
                .padding(13)
            } else {
                ScrollView {
                    VStack(spacing: 0) { ForEach(Array(app.project.stems.enumerated()), id: \.element.id) { index, stem in StemSidebarRow(index: index, stem: stem) } }
                }.scrollIndicators(.hidden)
            }

            Spacer(minLength: 8)
            separationPanel.padding(13)
            sectionLabel("I/O")
            HStack(spacing: 7) {
                Button("SAVE") { app.saveProjectAs() }.buttonStyle(InstrumentButtonStyle(compact: true))
                Button("EXPORT") { app.exportMix() }.buttonStyle(InstrumentButtonStyle(compact: true))
                Spacer()
                Button("KEYS") { app.showShortcutOverlay = true }.buttonStyle(InstrumentButtonStyle(compact: true))
            }
            .padding(13)
        }
        .background(Color.instrumentPlate)
    }

    private func sectionLabel(_ text: String) -> some View {
        Text(text).font(.system(size: 8, weight: .black, design: .monospaced)).tracking(0.8)
            .foregroundStyle(Color.instrumentRaised).padding(.horizontal, 13).frame(maxWidth: .infinity, minHeight: 23, alignment: .leading)
            .background(Color.instrumentInk.opacity(0.92))
    }

    @ViewBuilder private var separationPanel: some View {
        switch separator.state {
        case .preparing: progressPanel(progress: nil, message: "PREPARING SEPARATOR")
        case .running(let progress, let message): progressPanel(progress: progress, message: message.uppercased())
        case .failed:
            if app.canSeparate { Button("RETRY SEPARATION") { app.separateCurrentSong() }.buttonStyle(InstrumentButtonStyle(accent: .instrumentGreen, isLatched: true)) }
        default:
            if app.canSeparate {
                VStack(alignment: .leading, spacing: 7) {
                    Text("CREATE FOUR STEMS LOCALLY").instrumentLabel()
                    Button("SEPARATE SONG") { app.separateCurrentSong() }.buttonStyle(InstrumentButtonStyle(accent: .instrumentGreen, isLatched: true))
                    Text("DRUMS / VOCALS / OTHER / BASS").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
                }
            }
        }
    }

    private func progressPanel(progress: Double?, message: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack { Text("PROCESS").instrumentLabel(); Spacer(); Button("×") { separator.cancel() }.buttonStyle(.plain) }
            if let progress { ProgressView(value: progress).progressViewStyle(.linear).tint(.instrumentGreen) } else { ProgressView().controlSize(.small) }
            Text(message).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary).lineLimit(2)
        }
        .padding(9).background(Rectangle().fill(Color.instrumentSurface).overlay(Rectangle().stroke(Color.instrumentLine)))
    }
}

private struct StemSidebarRow: View {
    @EnvironmentObject private var app: AppState
    let index: Int
    let stem: StemModel

    var body: some View {
        Button { app.selectStem(stem.id) } label: {
            HStack(spacing: 9) {
                Text(String(format: "%02d", index + 1)).font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
                Rectangle().fill(stem.role.color).frame(width: 5, height: 29)
                VStack(alignment: .leading, spacing: 2) {
                    Text(stem.name.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced)).lineLimit(1)
                    Text("\(stem.gainDB.decibelString) DB").font(.system(size: 7, weight: .medium, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
                }
                Spacer()
                if stem.isMuted { Text("M") }
                if stem.isSolo { Text("S") }
            }
            .foregroundStyle(Color.instrumentInk).padding(.horizontal, 11).frame(height: 45)
            .background(app.selectedStemID == stem.id ? stem.role.color.opacity(0.22) : Color.clear)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.instrumentLine).frame(height: 0.5) }
            .overlay(alignment: .leading) { Rectangle().fill(app.selectedStemID == stem.id ? Color.instrumentInk : .clear).frame(width: 3) }
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(stem.isMuted ? "Unmute" : "Mute") { app.updateStem(stem.id) { $0.isMuted.toggle() } }
            Button(stem.isSolo ? "Unsolo" : "Solo") { app.updateStem(stem.id) { $0.isSolo.toggle() } }
            Button("Reset Controls") { app.resetStem(stem.id) }
            Divider(); Button("Remove Stem", role: .destructive) { app.removeStem(stem.id) }
        }
    }
}
