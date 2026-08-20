import SwiftUI

struct MixSurface: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController

    private var slotCount: Int { max(4, app.project.stems.count) }

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            GeometryReader { proxy in
                let visibleSlots = min(4, slotCount)
                let width = proxy.size.width / CGFloat(visibleSlots)
                if slotCount <= 4 {
                    HStack(spacing: 0) {
                        ForEach(0..<slotCount, id: \.self) { index in channel(index: index, width: width) }
                    }
                } else {
                    ScrollView(.horizontal) {
                        HStack(spacing: 0) {
                            ForEach(0..<slotCount, id: \.self) { index in channel(index: index, width: width) }
                        }
                    }
                    .scrollIndicators(.hidden)
                }
            }
        }
        .background(Color.instrumentPlate.opacity(0.52))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    @ViewBuilder private func channel(index: Int, width: CGFloat) -> some View {
        if app.project.stems.indices.contains(index) {
            let stem = app.project.stems[index]
            StemChannelStrip(index: index, stem: stem, meter: audio.meters[stem.id] ?? .init())
                .frame(width: width)
        } else {
            EmptyChannelStrip(index: index).frame(width: width)
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            HardwareLED(color: .instrumentOrange, isOn: true, size: 4)
            Text("STEM MIX")
                .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
            Text("LEVEL / PAN / TONE")
                .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary)
            Spacer()
            if app.canSeparate {
                Button("Split ×4") { app.separateCurrentSong() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentGreen, isLatched: true, compact: true))
            }
            Text("OUT")
                .font(.system(size: 5.5, weight: .semibold, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary)
            LevelMeter(value: audio.meters.values.map(\.peak).max() ?? 0, tint: .instrumentGreen, vertical: false)
                .frame(width: 82, height: 8)
        }
        .padding(.horizontal, 7)
        .frame(height: 24)
        .background(Color.instrumentSurface.opacity(0.55))
    }
}

private struct StemChannelStrip: View {
    @EnvironmentObject private var app: AppState
    let index: Int
    let stem: StemModel
    let meter: AudioEngineController.Meter

    private var isSelected: Bool { app.selectedStemID == stem.id }

    var body: some View {
        VStack(spacing: 5) {
            channelHeader
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    LevelMeter(value: meter.peak, tint: stem.role.color).frame(width: 7)
                    PhysicalFader(
                        value: Binding(
                            get: { stem.gainDB },
                            set: { value in app.updateStem(stem.id) { $0.gainDB = value } }
                        ),
                        tint: stem.role.color
                    )
                    .frame(width: 38)
                }
                VStack(spacing: 5) {
                    RotaryKnob(
                        "Pan",
                        value: Binding(
                            get: { stem.pan },
                            set: { value in app.updateStem(stem.id) { $0.pan = value } }
                        ),
                        in: -1...1,
                        accent: stem.role.color,
                        formatter: panText
                    )
                    RotaryKnob(
                        "Tone",
                        value: Binding(
                            get: { stem.tone },
                            set: { value in app.updateStem(stem.id) { $0.tone = value } }
                        ),
                        in: -1...1,
                        accent: stem.role.color,
                        formatter: toneText
                    )
                }
                .frame(width: 44)
            }
            .frame(maxHeight: .infinity)

            HStack(spacing: 4) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("LVL").font(.system(size: 5, weight: .semibold))
                        .foregroundStyle(Color.white.opacity(0.34))
                    Text(stem.gainDB.decibelString)
                        .font(.system(size: 7.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(stem.role.color)
                }
                .padding(.horizontal, 5)
                .frame(maxWidth: .infinity, minHeight: 22, alignment: .leading)
                .background(Color.instrumentDisplay)
                Button("M") { app.updateStem(stem.id) { $0.isMuted.toggle() } }
                    .buttonStyle(InstrumentButtonStyle(accent: stem.role.color, isLatched: stem.isMuted, compact: true))
                    .help("Mute selected stem — M")
                Button("S") { app.updateStem(stem.id) { $0.isSolo.toggle() } }
                    .buttonStyle(InstrumentButtonStyle(accent: stem.role.color, isLatched: stem.isSolo, compact: true))
                    .help("Solo selected stem — S")
                Button("↺") { app.resetStem(stem.id) }
                    .buttonStyle(InstrumentButtonStyle(compact: true))
                    .help("Reset channel")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .background(isSelected ? stem.role.color.opacity(0.075) : Color.clear)
        .overlay(alignment: .top) { Rectangle().fill(isSelected ? stem.role.color : Color.clear).frame(height: 2) }
        .overlay(alignment: .trailing) { Rectangle().fill(Color.instrumentLine).frame(width: 1) }
        .contentShape(Rectangle())
        .onTapGesture { app.selectStem(stem.id) }
        .contextMenu {
            Button(stem.isMuted ? "Unmute" : "Mute") { app.updateStem(stem.id) { $0.isMuted.toggle() } }
            Button(stem.isSolo ? "Unsolo" : "Solo") { app.updateStem(stem.id) { $0.isSolo.toggle() } }
            Button("Reset controls") { app.resetStem(stem.id) }
            Divider()
            Button("Remove channel", role: .destructive) { app.removeStem(stem.id) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(stem.name) stem")
    }

    private var channelHeader: some View {
        Button { app.selectStem(stem.id) } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(String(format: "%02d", index + 1))
                    Spacer()
                    HardwareLED(color: stem.role.color, isOn: isSelected, size: 4)
                }
                .font(.system(size: 6, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary)
                Rectangle().fill(stem.role.color).frame(height: 2)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(stem.name)
                        .font(.system(size: 9, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: 1)
                    Text(stem.role.displayName.uppercased())
                        .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.instrumentTextSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
    }

    private func panText(_ value: Float) -> String {
        if abs(value) < 0.02 { return "C" }
        return value < 0 ? "L\(Int(abs(value) * 100))" : "R\(Int(value * 100))"
    }

    private func toneText(_ value: Float) -> String {
        if abs(value) < 0.02 { return "0" }
        return value < 0 ? "−\(Int(abs(value) * 100))" : "+\(Int(value * 100))"
    }
}

private struct EmptyChannelStrip: View {
    let index: Int

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(String(format: "%02d", index + 1))
                Spacer()
                HardwareLED(color: Color.padColor(index), isOn: false, size: 4)
            }
            .font(.system(size: 6, weight: .medium, design: .monospaced))
            .foregroundStyle(Color.instrumentTextSecondary.opacity(0.7))
            Rectangle().fill(Color.padColor(index).opacity(0.24)).frame(height: 2)
            Text("OPEN BAY")
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary.opacity(0.55))
            Spacer()
            Capsule().fill(Color.instrumentInk.opacity(0.08)).frame(width: 3, height: 94)
            Spacer()
            HStack(spacing: 3) { KeyCap(text: "M"); KeyCap(text: "S"); KeyCap(text: "↺") }.opacity(0.28)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 5)
        .overlay(alignment: .trailing) { Rectangle().fill(Color.instrumentLine).frame(width: 1) }
    }
}
