import SwiftUI

struct MixSurface: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController

    private var slotCount: Int { max(4, app.project.stems.count) }

    var body: some View {
        VStack(spacing: 0) {
            if slotCount <= 4 {
                VStack(spacing: 0) {
                    ForEach(0..<slotCount, id: \.self) { index in
                        channel(index: index)
                        if index < slotCount - 1 { Rectangle().fill(Color.instrumentLine).frame(height: 1) }
                    }
                }
            } else {
                ScrollView(.vertical) {
                    LazyVStack(spacing: 0) {
                        ForEach(0..<slotCount, id: \.self) { index in
                            channel(index: index).frame(height: 76)
                            Rectangle().fill(Color.instrumentLine).frame(height: 1)
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }
        }
        .background(Color.instrumentPlate.opacity(0.52))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
    }

    @ViewBuilder private func channel(index: Int) -> some View {
        if app.project.stems.indices.contains(index) {
            let stem = app.project.stems[index]
            StemChannelRow(index: index, stem: stem, meter: audio.meters[stem.id] ?? .init())
                .frame(maxHeight: .infinity)
        } else {
            EmptyChannelRow(index: index).frame(maxHeight: .infinity)
        }
    }

}

private struct StemChannelRow: View {
    @EnvironmentObject private var app: AppState
    let index: Int
    let stem: StemModel
    let meter: AudioEngineController.Meter

    private var isSelected: Bool { app.selectedStemID == stem.id }
    private var controlTint: Color {
        isSelected ? .instrumentOrange : .instrumentInk.opacity(0.55)
    }

    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(isSelected ? Color.instrumentOrange : Color.instrumentInk.opacity(0.13))
                .frame(width: 2)

            Button { app.selectStem(stem.id) } label: {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 3) {
                        Text(String(format: "%02d", index + 1))
                        HardwareLED(color: .instrumentOrange, isOn: isSelected, size: 3)
                    }
                    .font(.instrumentNumber(5.5, weight: .medium))
                    .foregroundStyle(Color.instrumentTextSecondary)
                    Text(stem.name)
                        .font(.instrument(8, weight: .regular))
                        .lineLimit(1)
                }
                .frame(width: 47, alignment: .leading)
            }
            .buttonStyle(.plain)

            LevelMeter(value: meter.peak, tint: controlTint)
                .frame(width: 6, height: 50)

            HorizontalFader(
                value: Binding(
                    get: { stem.gainDB },
                    set: { value in app.updateStem(stem.id) { $0.gainDB = value } }
                ),
                tint: controlTint
            )
            .frame(minWidth: 46, maxWidth: .infinity, minHeight: 28, maxHeight: 32)

            Text(stem.gainDB.decibelString)
                .font(.instrumentNumber(6.5, weight: .medium))
                .foregroundStyle(isSelected ? Color.instrumentOrange : Color.white.opacity(0.58))
            .padding(.horizontal, 4)
            .frame(width: 31, height: 21, alignment: .leading)
            .background(Color.instrumentDisplay)

            RotaryKnob(
                "Pan",
                value: Binding(
                    get: { stem.pan },
                    set: { value in app.updateStem(stem.id) { $0.pan = value } }
                ),
                in: -1...1,
                accent: controlTint,
                size: 24,
                formatter: panText
            )
            RotaryKnob(
                "Tone",
                value: Binding(
                    get: { stem.tone },
                    set: { value in app.updateStem(stem.id) { $0.tone = value } }
                ),
                in: -1...1,
                accent: controlTint,
                size: 24,
                formatter: toneText
            )

            VStack(spacing: 2) {
                Button("m") { app.updateStem(stem.id) { $0.isMuted.toggle() } }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: stem.isMuted, compact: true))
                    .help("Mute selected stem — M")
                Button("s") { app.updateStem(stem.id) { $0.isSolo.toggle() } }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: stem.isSolo, compact: true))
                    .help("Solo selected stem — S")
                Button("↺") { app.resetStem(stem.id) }
                    .buttonStyle(InstrumentButtonStyle(compact: true))
                    .help("Reset channel")
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .background(isSelected ? Color.instrumentInk.opacity(0.045) : Color.clear)
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

    private func panText(_ value: Float) -> String {
        if abs(value) < 0.02 { return "C" }
        return value < 0 ? "L\(Int(abs(value) * 100))" : "R\(Int(value * 100))"
    }

    private func toneText(_ value: Float) -> String {
        if abs(value) < 0.02 { return "0" }
        return value < 0 ? "−\(Int(abs(value) * 100))" : "+\(Int(value * 100))"
    }
}

private struct EmptyChannelRow: View {
    let index: Int

    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Color.instrumentInk.opacity(0.12)).frame(width: 2)
            Text(String(format: "%02d", index + 1))
            Text("empty")
            Spacer()
            Capsule().fill(Color.instrumentInk.opacity(0.09)).frame(width: 116, height: 3)
            Spacer()
            HStack(spacing: 2) { KeyCap(text: "M"); KeyCap(text: "S"); KeyCap(text: "↺") }.opacity(0.24)
        }
        .font(.instrument(6, weight: .regular))
        .foregroundStyle(Color.instrumentTextSecondary.opacity(0.62))
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
    }
}
