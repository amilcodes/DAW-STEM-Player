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
        VStack(spacing: 8) {
            sequencerGrid
            parameterDeck
        }
        .onChange(of: app.selectedPadIndex) { _, index in
            voiceBank = max(0, min(2, index / 4))
        }
    }

    private var sequencerGrid: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 39
            let gap: CGFloat = 1.5
            let stepWidth = max(8, (proxy.size.width - labelWidth - gap * 15) / 16)

            VStack(spacing: 5) {
                HStack(spacing: gap) {
                    Text(["A", "B", "C"][voiceBank])
                        .frame(width: labelWidth, alignment: .leading)
                    ForEach(0..<16, id: \.self) { step in
                        Text(step.isMultiple(of: 4) ? "\(step / 4 + 1)" : "·")
                            .frame(width: stepWidth)
                    }
                }
                .font(.instrumentNumber(5, weight: .medium))
                .foregroundStyle(Color.instrumentTextSecondary)
                .frame(height: 8)

                ForEach(bankPads) { pad in
                    HStack(spacing: gap) {
                        Button {
                            app.selectPad(pad.index)
                            app.triggerPad(index: pad.index)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 3) {
                                    Text(String(format: "%02d", pad.index + 1))
                                        .font(.instrumentNumber(4.5, weight: .medium))
                                    HardwareLED(color: .instrumentOrange, isOn: app.selectedPadIndex == pad.index, size: 3)
                                }
                                Text(shortName(pad.name))
                                    .font(.instrument(5.5, weight: .regular))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(Color.instrumentInk.opacity(0.74))
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
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                RotaryKnob(
                    "tempo",
                    value: Binding(
                        get: { Float(app.project.pattern.bpm) },
                        set: { app.setPatternBPM(Double($0)) }
                    ),
                    in: 40...240,
                    default: 100,
                    accent: .instrumentOrange,
                    size: 29,
                    formatter: { "\(Int($0))" }
                )
                RotaryKnob(
                    "swing",
                    value: Binding(
                        get: { Float(app.project.pattern.swing) },
                        set: { app.setPatternSwing(Double($0)) }
                    ),
                    in: 0...0.75,
                    accent: .instrumentInk.opacity(0.62),
                    size: 29,
                    formatter: { "\(Int($0 * 100))%" }
                )

                Rectangle().fill(Color.instrumentLine).frame(width: 0.7, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text("bars").font(.instrument(5, weight: .regular)).foregroundStyle(Color.instrumentTextSecondary)
                    HStack(spacing: 2) {
                        Button("−") { app.setPatternBars(app.project.pattern.bars - 1) }
                            .buttonStyle(HardwareKeyStyle(width: 23, height: 24))
                        Text("\(app.project.pattern.bars)")
                            .font(.instrumentNumber(7, weight: .medium))
                            .frame(width: 10)
                        Button("+") { app.setPatternBars(app.project.pattern.bars + 1) }
                            .buttonStyle(HardwareKeyStyle(width: 23, height: 24))
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("bar").font(.instrument(5, weight: .regular)).foregroundStyle(Color.instrumentTextSecondary)
                    HStack(spacing: 2) {
                        Button("◀") { app.selectPatternBar(app.selectedPatternBar - 1) }
                            .disabled(app.selectedPatternBar == 0)
                            .buttonStyle(HardwareKeyStyle(width: 23, height: 24))
                        Text("\(app.selectedPatternBar + 1)/\(app.project.pattern.bars)")
                            .font(.instrumentNumber(6.5, weight: .medium))
                            .frame(width: 22)
                        Button("▶") { app.selectPatternBar(app.selectedPatternBar + 1) }
                            .disabled(app.selectedPatternBar >= app.project.pattern.bars - 1)
                            .buttonStyle(HardwareKeyStyle(width: 23, height: 24))
                    }
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 4) {
                Button("run") { app.isPatternEnabled.toggle() }
                    .buttonStyle(HardwareKeyStyle(width: 38, height: 25, accent: .instrumentGreen, isLatched: app.isPatternEnabled))
                Button("rec") { app.isPatternRecording.toggle() }
                    .buttonStyle(HardwareKeyStyle(width: 36, height: 25, accent: .instrumentOrange, isLatched: app.isPatternRecording))
                Spacer(minLength: 0)
                ForEach(0..<3, id: \.self) { bank in
                    Button(["A", "B", "C"][bank]) { voiceBank = bank }
                        .buttonStyle(HardwareKeyStyle(width: 25, height: 25, accent: .instrumentOrange, isLatched: voiceBank == bank))
                }
                Button("clr") { app.clearPattern() }
                    .buttonStyle(HardwareKeyStyle(width: 32, height: 25))
                    .help("Clear pattern")
            }
        }
        .frame(height: 91)
    }

    private func shortName(_ name: String) -> String {
        switch name {
        case "Closed Hat": "cl hat"
        case "Open Hat": "op hat"
        default: name.lowercased()
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

    private var velocityMarks: Int {
        guard let velocity else { return 0 }
        if velocity > 0.8 { return 3 }
        if velocity > 0.5 { return 2 }
        return 1
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(velocity == nil ? Color.instrumentRaised : Color.instrumentInk.opacity(0.82))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2.5)
                            .stroke(Color.instrumentInk.opacity(velocity == nil ? 0.17 : 0.62), lineWidth: 0.7)
                    )
                    .overlay(alignment: .top) {
                        if isCurrent {
                            Capsule().fill(Color.instrumentOrange).frame(width: max(4, width * 0.5), height: 1.5).padding(.top, 2)
                        }
                    }

                if velocityMarks > 0 {
                    HStack(spacing: 1) {
                        ForEach(0..<velocityMarks, id: \.self) { _ in
                            Circle().fill(Color.instrumentRaised.opacity(0.78)).frame(width: 1.5, height: 1.5)
                        }
                    }
                    .padding(.bottom, 3)
                } else if step.isMultiple(of: 4) {
                    Circle().fill(Color.instrumentInk.opacity(0.2)).frame(width: 2, height: 2).padding(.bottom, 3)
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
}
