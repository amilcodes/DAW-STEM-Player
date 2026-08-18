import SwiftUI

struct PatternSurface: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            Color.instrumentSurface
            PanelScrews()
            VStack(spacing: 12) {
                controlDeck
                Rectangle().fill(Color.instrumentInk.opacity(0.45)).frame(height: 1)
                sequencerGrid
                footer
            }
            .padding(20)
        }
        .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.75), lineWidth: 1))
    }

    private var controlDeck: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("SQ–16 PATTERN PROGRAMMER").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(0.4)
                Text("ONE BAR / SIXTEEN STEPS / TWELVE VOICES").font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
            }
            Spacer()
            HStack(spacing: 0) {
                lcdCell(title: "TEMPO", value: "\(Int(app.project.pattern.bpm))")
                lcdCell(title: "BAR", value: "\(app.selectedPatternBar + 1)/\(app.project.pattern.bars)")
                lcdCell(title: "SWING", value: "\(Int(app.project.pattern.swing * 100))%")
            }
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.78), lineWidth: 1))
            Button("◀") { app.selectPatternBar(app.selectedPatternBar - 1) }.disabled(app.selectedPatternBar == 0).buttonStyle(InstrumentButtonStyle(compact: true))
            Button("▶") { app.selectPatternBar(app.selectedPatternBar + 1) }.disabled(app.selectedPatternBar >= app.project.pattern.bars - 1).buttonStyle(InstrumentButtonStyle(compact: true))
            Button(app.isPatternEnabled ? "RUN ON" : "RUN") { app.isPatternEnabled.toggle() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentGreen, isLatched: app.isPatternEnabled, compact: true))
            Button("CLEAR") { app.clearPattern() }.buttonStyle(InstrumentButtonStyle(compact: true))
        }
        .frame(height: 45)
    }

    private func lcdCell(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.38))
            Text(value).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentGreen)
        }
        .padding(.horizontal, 9).frame(width: 62, height: 37, alignment: .leading)
        .background(Color.instrumentDisplay).overlay(alignment: .trailing) { Rectangle().fill(Color.white.opacity(0.1)).frame(width: 1) }
    }

    private var sequencerGrid: some View {
        GeometryReader { proxy in
            let labelWidth: CGFloat = 105
            let gap: CGFloat = 4
            let stepWidth = max(18, (proxy.size.width - labelWidth - gap * 15) / 16)
            ScrollView(.vertical) {
                VStack(spacing: 4) {
                    HStack(spacing: gap) {
                        Text("VOICE").frame(width: labelWidth, alignment: .leading)
                        ForEach(0..<16, id: \.self) { step in
                            Text(step % 4 == 0 ? "\(step / 4 + 1)" : "·").frame(width: stepWidth)
                        }
                    }
                    .font(.system(size: 7, weight: .black, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)

                    ForEach(app.project.pads) { pad in
                        HStack(spacing: gap) {
                            Button { app.selectPad(pad.index); app.triggerPad(index: pad.index) } label: {
                                HStack(spacing: 7) {
                                    Rectangle().fill(Color.padColor(pad.index)).frame(width: 5, height: 19)
                                    Text(String(format: "%02d  %@", pad.index + 1, pad.name.uppercased())).lineLimit(1)
                                }
                                .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentInk)
                                .frame(width: labelWidth, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            ForEach(0..<16, id: \.self) { step in
                                let enabled = app.hasStep(step, padIndex: pad.index)
                                Button { app.selectPad(pad.index); app.toggleStep(step) } label: {
                                    Rectangle()
                                        .fill(enabled ? Color.padColor(pad.index) : Color.instrumentInk.opacity(step % 4 == 0 ? 0.20 : 0.10))
                                        .overlay(Rectangle().stroke(Color.instrumentInk.opacity(enabled ? 0.78 : 0.25), lineWidth: 1))
                                        .overlay(alignment: .bottom) { Rectangle().fill(enabled ? Color.instrumentRaised.opacity(0.5) : .clear).frame(height: 2) }
                                        .frame(width: stepWidth, height: 22)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Text("TEMPO").instrumentLabel()
            Slider(value: Binding(get: { app.project.pattern.bpm }, set: app.setPatternBPM), in: 40...240).tint(.instrumentGreen).frame(width: 150)
            Text("SWING").instrumentLabel()
            Slider(value: Binding(get: { app.project.pattern.swing }, set: app.setPatternSwing), in: 0...0.75).tint(.instrumentYellow).frame(width: 110)
            Spacer()
            HardwareLED(color: .instrumentOrange, isOn: app.isPatternRecording)
            Button(app.isPatternRecording ? "RECORDING" : "RECORD HITS") { app.isPatternRecording.toggle() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isPatternRecording, compact: true))
        }
        .frame(height: 32)
    }
}
