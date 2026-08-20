import SwiftUI

struct MixSurface: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController

    private var visibleSlots: Int { min(4, max(4, app.project.stems.count)) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<visibleSlots, id: \.self) { index in
                if app.project.stems.indices.contains(index) {
                    let stem = app.project.stems[index]
                    ChannelStrip(
                        index: index,
                        stem: stem,
                        meter: audio.meters[stem.id] ?? .init()
                    )
                } else {
                    EmptyChannelStrip(index: index)
                }

                if index < visibleSlots - 1 {
                    Rectangle()
                        .fill(Color.instrumentInk.opacity(0.1))
                        .frame(width: 0.7)
                        .padding(.vertical, 5)
                }
            }
        }
    }
}

private struct ChannelStrip: View {
    @EnvironmentObject private var app: AppState
    let index: Int
    let stem: StemModel
    let meter: AudioEngineController.Meter

    private var isSelected: Bool { app.selectedStemID == stem.id }
    private var tint: Color { isSelected ? .instrumentOrange : .instrumentInk.opacity(0.6) }

    var body: some View {
        VStack(spacing: 5) {
            Button { app.selectStem(stem.id) } label: {
                HStack(spacing: 3) {
                    Text(String(format: "%02d", index + 1))
                        .font(.instrumentNumber(5.5, weight: .medium))
                        .foregroundStyle(Color.instrumentTextSecondary)
                    Spacer(minLength: 0)
                    HardwareLED(color: .instrumentOrange, isOn: isSelected, size: 3)
                }
            }
            .buttonStyle(.plain)

            Text(stem.name)
                .font(.instrument(7.5, weight: .regular))
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 1) {
                RotaryKnob(
                    "pan",
                    value: Binding(
                        get: { stem.pan },
                        set: { value in app.updateStem(stem.id) { $0.pan = value } }
                    ),
                    in: -1...1,
                    accent: tint,
                    size: 28,
                    formatter: panText
                )
                RotaryKnob(
                    "tone",
                    value: Binding(
                        get: { stem.tone },
                        set: { value in app.updateStem(stem.id) { $0.tone = value } }
                    ),
                    in: -1...1,
                    accent: tint,
                    size: 28,
                    formatter: toneText
                )
            }

            HStack(spacing: 1) {
                PhysicalFader(
                    value: Binding(
                        get: { stem.gainDB },
                        set: { value in app.updateStem(stem.id) { $0.gainDB = value } }
                    ),
                    tint: tint
                )
                .frame(maxWidth: .infinity)

                LevelMeter(value: meter.peak, tint: tint)
                    .frame(width: 6)
            }
            .frame(maxHeight: .infinity)

            Text(stem.gainDB.decibelString)
                .font(.instrumentNumber(7, weight: .medium))
                .foregroundStyle(isSelected ? Color.instrumentOrange : Color.instrumentInk.opacity(0.74))

            HStack(spacing: 3) {
                Button("m") { app.updateStem(stem.id) { $0.isMuted.toggle() } }
                    .buttonStyle(HardwareKeyStyle(width: 25, height: 24, accent: .instrumentOrange, isLatched: stem.isMuted))
                    .help("Mute selected stem — M")
                Button("s") { app.updateStem(stem.id) { $0.isSolo.toggle() } }
                    .buttonStyle(HardwareKeyStyle(width: 25, height: 24, accent: .instrumentOrange, isLatched: stem.isSolo))
                    .help("Solo selected stem — S")
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
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

private struct EmptyChannelStrip: View {
    let index: Int

    var body: some View {
        VStack(spacing: 8) {
            Text(String(format: "%02d", index + 1))
                .font(.instrumentNumber(5.5, weight: .medium))
            Spacer()
            Capsule()
                .fill(Color.instrumentInk.opacity(0.08))
                .frame(width: 3, height: 132)
            Spacer()
            Text("–")
                .font(.instrument(8, weight: .regular))
        }
        .foregroundStyle(Color.instrumentTextSecondary.opacity(0.45))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 5)
    }
}
