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
            controlHeader
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            sequencerGrid
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            parameterDeck
        }
        .background(Color.instrumentPlate.opacity(0.52))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
        .onChange(of: app.selectedPadIndex) { _, index in
            voiceBank = max(0, min(2, index / 4))
        }
    }

    private var controlHeader: some View {
        HStack(spacing: 10) {
            HardwareLED(color: .instrumentGreen, isOn: app.isPatternEnabled)
            Text("16-step sequencer")
                .font(.system(size: 10, weight: .semibold))
            Text("four voices visible / three banks / right-click a step for velocity")
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
            Spacer()
            Text("VOICE BANK")
                .font(.system(size: 7, weight: .semibold))
                .foregroundStyle(Color.instrumentTextSecondary)
            ForEach(0..<3, id: \.self) { bank in
                Button(["A", "B", "C"][bank]) { voiceBank = bank }
                    .buttonStyle(
                        InstrumentButtonStyle(
                            accent: Color.padColor(bank),
                            isLatched: voiceBank == bank,
                            compact: true
                        )
                    )
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.instrumentSurface.opacity(0.55))
    }

    private var sequencerGrid: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 108
            let gap: CGFloat = 5
            let stepWidth = max(26, (proxy.size.width - labelWidth - gap * 15) / 16)
            VStack(spacing: 7) {
                HStack(spacing: gap) {
                    Text("BANK \(["A", "B", "C"][voiceBank])")
                        .frame(width: labelWidth, alignment: .leading)
                    ForEach(0..<16, id: \.self) { step in
                        VStack(spacing: 2) {
                            Text(step % 4 == 0 ? "\(step / 4 + 1)" : "·")
                            if currentStep == step {
                                Rectangle().fill(Color.instrumentGreen).frame(height: 2)
                            } else {
                                Rectangle().fill(Color.clear).frame(height: 2)
                            }
                        }
                        .frame(width: stepWidth)
                    }
                }
                .font(.system(size: 7, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary)

                ForEach(bankPads) { pad in
                    HStack(spacing: gap) {
                        Button {
                            app.selectPad(pad.index)
                            app.triggerPad(index: pad.index)
                        } label: {
                            HStack(spacing: 8) {
                                Rectangle().fill(Color.padColor(pad.index)).frame(width: 4, height: 26)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(String(format: "%02d", pad.index + 1))
                                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                                        .foregroundStyle(Color.instrumentTextSecondary)
                                    Text(pad.name)
                                        .font(.system(size: 9, weight: .semibold))
                                        .lineLimit(1)
                                }
                                Spacer()
                                HardwareLED(color: Color.padColor(pad.index), isOn: app.selectedPadIndex == pad.index)
                            }
                            .frame(width: labelWidth, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        ForEach(0..<16, id: \.self) { step in
                            let velocity = app.stepVelocity(step, padIndex: pad.index)
                            StepKey(
                                step: step,
                                width: stepWidth,
                                color: Color.padColor(pad.index),
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
        HStack(spacing: 16) {
            RotaryKnob(
                "Tempo",
                value: Binding(
                    get: { Float(app.project.pattern.bpm) },
                    set: { app.setPatternBPM(Double($0)) }
                ),
                in: 40...240,
                default: 100,
                accent: .instrumentGreen,
                size: 44,
                formatter: { "\(Int($0)) bpm" }
            )
            RotaryKnob(
                "Swing",
                value: Binding(
                    get: { Float(app.project.pattern.swing) },
                    set: { app.setPatternSwing(Double($0)) }
                ),
                in: 0...0.75,
                accent: .instrumentYellow,
                size: 44,
                formatter: { "\(Int($0 * 100))%" }
            )
            Rectangle().fill(Color.instrumentLine).frame(width: 1, height: 48)

            VStack(alignment: .leading, spacing: 5) {
                Text("BARS")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.instrumentTextSecondary)
                HStack(spacing: 7) {
                    Button("−") { app.setPatternBars(app.project.pattern.bars - 1) }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                    Text("\(app.project.pattern.bars)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .frame(width: 20)
                    Button("+") { app.setPatternBars(app.project.pattern.bars + 1) }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("EDIT BAR")
                    .font(.system(size: 7, weight: .semibold))
                    .foregroundStyle(Color.instrumentTextSecondary)
                HStack(spacing: 7) {
                    Button("◀") { app.selectPatternBar(app.selectedPatternBar - 1) }
                        .disabled(app.selectedPatternBar == 0)
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                    Text("\(app.selectedPatternBar + 1)/\(app.project.pattern.bars)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .frame(width: 34)
                    Button("▶") { app.selectPatternBar(app.selectedPatternBar + 1) }
                        .disabled(app.selectedPatternBar >= app.project.pattern.bars - 1)
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
            }

            Spacer()

            Button(app.isPatternEnabled ? "Run on" : "Run") { app.isPatternEnabled.toggle() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentGreen, isLatched: app.isPatternEnabled, compact: true))
            Button(app.isPatternRecording ? "Recording" : "Record hits") { app.isPatternRecording.toggle() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isPatternRecording, compact: true))
            Button("Clear") { app.clearPattern() }
                .buttonStyle(InstrumentButtonStyle(compact: true))
        }
        .padding(.horizontal, 13)
        .frame(height: 74)
        .background(Color.instrumentSurface.opacity(0.48))
    }
}

private struct StepKey: View {
    let step: Int
    let width: CGFloat
    let color: Color
    let velocity: Float?
    let isCurrent: Bool
    let action: () -> Void
    let setVelocity: (Float?) -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(fillColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(isCurrent ? Color.instrumentGreen : Color.instrumentInk.opacity(0.25), lineWidth: isCurrent ? 2 : 1)
                    )
                    .shadow(color: Color.instrumentInk.opacity(velocity == nil ? 0.08 : 0.2), radius: 0, y: velocity == nil ? 0 : 2)
                if let velocity {
                    Rectangle()
                        .fill(Color.instrumentRaised.opacity(0.75))
                        .frame(height: max(2, CGFloat(velocity) * 6))
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                }
                if step.isMultiple(of: 4) {
                    Rectangle().fill(Color.instrumentInk.opacity(0.3)).frame(width: 2, height: 2).padding(.bottom, 4)
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
        return color.opacity(0.35 + Double(velocity) * 0.65)
    }
}
