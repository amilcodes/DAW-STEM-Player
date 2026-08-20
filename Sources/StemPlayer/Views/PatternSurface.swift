import SwiftUI

struct PatternSurface: View {
    @EnvironmentObject private var app: AppState
    @EnvironmentObject private var audio: AudioEngineController
    @State private var voiceBank = 0

    private var bankPads: [PadModel] {
        let start = voiceBank * 4
        let end = min(start + 4, app.project.pads.count)
        guard start < end else { return [] }
        return Array(app.project.pads[start..<end])
    }

    private var currentStep: Int? {
        guard audio.isPlaying else { return nil }
        let absoluteBeats = audio.currentTime * app.project.pattern.bpm / 60
        let patternBeat = absoluteBeats.truncatingRemainder(dividingBy: app.project.pattern.lengthInBeats)
        let playingBar = Int(patternBeat / 4)
        guard playingBar == app.selectedPatternBar else { return nil }
        return Int(floor(patternBeat * 4)).quotientAndRemainder(dividingBy: 16).remainder
    }

    var body: some View {
        VStack(spacing: 0) {
            sequencerGrid
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            parameterDeck
        }
        .background(Color.instrumentPlate.opacity(0.52))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
        .onChange(of: app.selectedPadIndex) { _, index in
            voiceBank = max(0, min(2, index / 4))
        }
    }

    private var sequencerGrid: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 43
            let gap: CGFloat = 1
            let stepWidth = max(8, (proxy.size.width - labelWidth - gap * 15) / 16)
            VStack(spacing: 3) {
                HStack(spacing: gap) {
                    Text(["A", "B", "C"][voiceBank])
                        .frame(width: labelWidth, alignment: .leading)
                    ForEach(0..<16, id: \.self) { step in
                        VStack(spacing: 1) {
                            Text(step % 4 == 0 ? "\(step / 4 + 1)" : "·")
                            Rectangle()
                                .fill(currentStep == step ? Color.instrumentOrange : Color.clear)
                                .frame(height: 1.5)
                        }
                        .frame(width: stepWidth)
                    }
                }
                .font(.instrumentNumber(5, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)

                ForEach(bankPads) { pad in
                    HStack(spacing: gap) {
                        Button {
                            app.selectPad(pad.index)
                            app.triggerPad(index: pad.index)
                        } label: {
                            HStack(spacing: 3) {
                                Rectangle()
                                    .fill(app.selectedPadIndex == pad.index ? Color.instrumentOrange : Color.instrumentInk.opacity(0.14))
                                    .frame(width: 2, height: 18)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(String(format: "%02d", pad.index + 1))
                                        .font(.instrumentNumber(4.5, weight: .medium))
                                        .foregroundStyle(Color.instrumentTextSecondary)
                                    Text(shortName(pad.name))
                                        .font(.instrument(5.5, weight: .regular))
                                        .lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                HardwareLED(color: .instrumentOrange, isOn: app.selectedPadIndex == pad.index, size: 3)
                            }
                            .frame(width: labelWidth, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        ForEach(0..<16, id: \.self) { step in
                            let velocity = app.stepVelocity(step, padIndex: pad.index)
                            StepKey(
                                step: step,
                                width: stepWidth,
                                velocity: velocity,
                                isCurrent: currentStep == step
                            ) {
                                app.selectPad(pad.index)
                                app.toggleStep(step)
                            } setVelocity: { newVelocity in
                                app.selectPad(pad.index)
                                if let newVelocity {
                                    app.setStepVelocity(step, padIndex: pad.index, velocity: newVelocity)
                                } else if app.hasStep(step, padIndex: pad.index) {
                                    app.toggleStep(step)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
    }

    private var parameterDeck: some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                RotaryKnob(
                    "Tempo",
                    value: Binding(
                        get: { Float(app.project.pattern.bpm) },
                        set: { app.setPatternBPM(Double($0)) }
                    ),
                    in: 40...240,
                    default: 100,
                    accent: .instrumentOrange,
                    size: 26,
                    formatter: { "\(Int($0))" }
                )
                RotaryKnob(
                    "Swing",
                    value: Binding(
                        get: { Float(app.project.pattern.swing) },
                        set: { app.setPatternSwing(Double($0)) }
                    ),
                    in: 0...0.75,
                    accent: .instrumentInk.opacity(0.58),
                    size: 26,
                    formatter: { "\(Int($0 * 100))%" }
                )
                Rectangle().fill(Color.instrumentLine).frame(width: 1, height: 33)
                VStack(alignment: .leading, spacing: 2) {
                    Text("bars")
                        .font(.instrument(5, weight: .medium))
                        .foregroundStyle(Color.instrumentTextSecondary)
                    HStack(spacing: 2) {
                        Button("−") { app.setPatternBars(app.project.pattern.bars - 1) }
                            .buttonStyle(InstrumentButtonStyle(compact: true))
                        Text("\(app.project.pattern.bars)")
                            .font(.instrumentNumber(7, weight: .medium))
                            .frame(width: 12)
                        Button("+") { app.setPatternBars(app.project.pattern.bars + 1) }
                            .buttonStyle(InstrumentButtonStyle(compact: true))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("bar")
                        .font(.instrument(5, weight: .medium))
                        .foregroundStyle(Color.instrumentTextSecondary)
                    HStack(spacing: 2) {
                        Button("◀") { app.selectPatternBar(app.selectedPatternBar - 1) }
                            .disabled(app.selectedPatternBar == 0)
                            .buttonStyle(InstrumentButtonStyle(compact: true))
                        Text("\(app.selectedPatternBar + 1)/\(app.project.pattern.bars)")
                            .font(.instrumentNumber(6.5, weight: .medium))
                            .frame(width: 23)
                        Button("▶") { app.selectPatternBar(app.selectedPatternBar + 1) }
                            .disabled(app.selectedPatternBar >= app.project.pattern.bars - 1)
                            .buttonStyle(InstrumentButtonStyle(compact: true))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                Button("run") { app.isPatternEnabled.toggle() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentGreen, isLatched: app.isPatternEnabled, compact: true))
                Button("record") { app.isPatternRecording.toggle() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isPatternRecording, compact: true))
                Spacer(minLength: 0)
                ForEach(0..<3, id: \.self) { bank in
                    Button(["A", "B", "C"][bank]) { voiceBank = bank }
                        .buttonStyle(
                            InstrumentButtonStyle(
                                accent: .instrumentOrange,
                                isLatched: voiceBank == bank,
                                compact: true
                            )
                        )
                }
                Button("clear") { app.clearPattern() }
                    .buttonStyle(InstrumentButtonStyle(compact: true))
            }
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 4)
        .frame(height: 78)
        .background(Color.instrumentSurface.opacity(0.48))
    }

    private func shortName(_ name: String) -> String {
        switch name {
        case "Closed Hat": "Cl Hat"
        case "Open Hat": "Op Hat"
        default: name
        }
    }
}

private struct StepKey: View {
    let step: Int
    let width: CGFloat
    let velocity: Float?
    let isCurrent: Bool
    let action: () -> Void
    let setVelocity: (Float?) -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1.5)
                            .stroke(isCurrent ? Color.instrumentOrange : Color.instrumentInk.opacity(0.22), lineWidth: isCurrent ? 1.2 : 0.6)
                    )
                if let velocity {
                    Rectangle()
                        .fill(Color.instrumentRaised.opacity(0.75))
                        .frame(height: max(1.5, CGFloat(velocity) * 5))
                        .padding(.horizontal, 1.5)
                        .padding(.bottom, 2)
                }
                if step.isMultiple(of: 4) {
                    Rectangle().fill(Color.instrumentInk.opacity(0.3)).frame(width: 1.5, height: 1.5).padding(.bottom, 2)
                }
            }
            .frame(width: width)
            .frame(maxHeight: .infinity)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Accent — 100%") { setVelocity(1) }
            Button("Full — 86%") { setVelocity(0.86) }
            Button("Medium — 62%") { setVelocity(0.62) }
            Button("Soft — 38%") { setVelocity(0.38) }
            Divider()
            Button("Off") { setVelocity(nil) }
        }
        .accessibilityLabel("Step \(step + 1)")
        .accessibilityValue(velocity.map { "Velocity \(Int($0 * 100)) percent" } ?? "Off")
    }

    private var fillColor: Color {
        guard let velocity else {
            return Color.instrumentInk.opacity(step.isMultiple(of: 4) ? 0.12 : 0.075)
        }
        return Color.instrumentInk.opacity(0.38 + Double(velocity) * 0.42)
    }
}
