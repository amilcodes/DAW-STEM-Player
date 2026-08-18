import SwiftUI

struct Inspector: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PARAMETER BAY").font(.system(size: 8, weight: .black, design: .monospaced)).tracking(0.8)
                Spacer()
                Button("CLOSE ×") { app.isInspectorVisible = false }.buttonStyle(.plain)
                    .font(.system(size: 8, weight: .bold, design: .monospaced))
            }
            .foregroundStyle(Color.instrumentRaised).padding(.horizontal, 13).frame(height: 23).background(Color.instrumentInk.opacity(0.92))
            Group {
                switch app.mode {
                case .mix: stemInspector
                case .pads, .pattern: padInspector
                }
            }
            .padding(14)
            Spacer()
        }
        .background(Color.instrumentPlate)
    }

    @ViewBuilder private var stemInspector: some View {
        if let stem = app.selectedStem {
            VStack(alignment: .leading, spacing: 16) {
                objectHeader(number: stemNumber(stem.id), color: stem.role.color, title: stem.name, subtitle: "\(stem.role.displayName.uppercased()) STEM")
                parameterDivider("CHANNEL")
                InspectorSlider(title: "LEVEL", valueText: "\(stem.gainDB.decibelString) DB", value: Binding(get: { stem.gainDB }, set: { value in app.updateStem(stem.id) { $0.gainDB = value } }), range: -60...6, tint: stem.role.color)
                InspectorSlider(title: "PAN", valueText: panText(stem.pan), value: Binding(get: { stem.pan }, set: { value in app.updateStem(stem.id) { $0.pan = value } }), range: -1...1, tint: stem.role.color)
                InspectorSlider(title: "TONE", valueText: toneText(stem.tone), value: Binding(get: { stem.tone }, set: { value in app.updateStem(stem.id) { $0.tone = value } }), range: -1...1, tint: stem.role.color)
                HStack(spacing: 8) {
                    Button(stem.isMuted ? "MUTE ON" : "MUTE") { app.updateStem(stem.id) { $0.isMuted.toggle() } }.buttonStyle(InstrumentButtonStyle(accent: stem.role.color, isLatched: stem.isMuted, compact: true))
                    Button(stem.isSolo ? "SOLO ON" : "SOLO") { app.updateStem(stem.id) { $0.isSolo.toggle() } }.buttonStyle(InstrumentButtonStyle(accent: stem.role.color, isLatched: stem.isSolo, compact: true))
                }
                Button("RESET CHANNEL") { app.resetStem(stem.id) }.buttonStyle(.plain).instrumentLabel()
            }
        } else {
            Text("SELECT A CHANNEL TO EDIT LEVEL, PAN AND TONE.").font(.system(size: 9, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
        }
    }

    private var padInspector: some View {
        let pad = app.selectedPad
        return VStack(alignment: .leading, spacing: 16) {
            objectHeader(number: pad.index + 1, color: Color.padColor(pad.index), title: pad.name, subtitle: pad.relativePath == nil ? "FACTORY SAMPLE" : "USER SAMPLE")
            parameterDivider("VOICE")
            InspectorSlider(title: "LEVEL", valueText: "\(pad.gainDB.decibelString) DB", value: Binding(get: { app.selectedPad.gainDB }, set: { value in app.updateSelectedPad { $0.gainDB = value } }), range: -24...6, tint: Color.padColor(pad.index))
            InspectorSlider(title: "PAN", valueText: panText(pad.pan), value: Binding(get: { app.selectedPad.pan }, set: { value in app.updateSelectedPad { $0.pan = value } }), range: -1...1, tint: Color.padColor(pad.index))
            HStack(spacing: 8) {
                Button("PREVIEW") { app.triggerPad(index: pad.index) }.buttonStyle(InstrumentButtonStyle(accent: Color.padColor(pad.index), isLatched: true, compact: true))
                Button("LOAD AUDIO") { app.loadSampleForSelectedPad() }.buttonStyle(InstrumentButtonStyle(compact: true))
            }
            if pad.relativePath != nil { Button("RESTORE FACTORY") { app.restoreFactoryPad() }.buttonStyle(.plain).instrumentLabel() }
            parameterDivider("PATTERN")
            HStack {
                Text("BARS").instrumentLabel(); Spacer()
                Stepper("\(app.project.pattern.bars)", value: Binding(get: { app.project.pattern.bars }, set: app.setPatternBars), in: 1...8).labelsHidden()
                Text("\(app.project.pattern.bars)").font(.system(size: 10, weight: .bold, design: .monospaced)).frame(width: 18)
            }
            InspectorSlider(title: "SWING", valueText: "\(Int(app.project.pattern.swing * 100))%", value: Binding(get: { Float(app.project.pattern.swing) }, set: { app.setPatternSwing(Double($0)) }), range: 0...0.75, tint: .instrumentYellow)
        }
    }

    private func objectHeader(number: Int, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            VStack(spacing: 0) {
                Rectangle().fill(color).frame(height: 6)
                Text(String(format: "%02d", number)).font(.system(size: 16, weight: .black, design: .monospaced)).frame(width: 48, height: 40)
            }
            .background(Color.instrumentRaised).overlay(Rectangle().stroke(Color.instrumentLine))
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased()).font(.system(size: 13, weight: .black, design: .monospaced)).lineLimit(1)
                Text(subtitle).instrumentLabel()
            }
        }
    }

    private func parameterDivider(_ title: String) -> some View {
        HStack(spacing: 8) { Text(title).instrumentLabel(); Rectangle().fill(Color.instrumentLine).frame(height: 1) }
    }

    private func stemNumber(_ id: UUID) -> Int { (app.project.stems.firstIndex(where: { $0.id == id }) ?? 0) + 1 }
    private func panText(_ pan: Float) -> String { abs(pan) < 0.01 ? "CENTER" : (pan < 0 ? "L \(Int(abs(pan) * 100))" : "R \(Int(pan * 100))") }
    private func toneText(_ tone: Float) -> String { abs(tone) < 0.01 ? "NEUTRAL" : (tone < 0 ? "WARM \(Int(abs(tone) * 100))" : "BRIGHT \(Int(tone * 100))") }
}

private struct InspectorSlider: View {
    var title: String
    var valueText: String
    @Binding var value: Float
    var range: ClosedRange<Float>
    var tint: Color

    var body: some View {
        VStack(spacing: 7) {
            HStack { Text(title); Spacer(); Text(valueText).foregroundStyle(Color.instrumentInk) }
                .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
            Slider(value: $value, in: range).tint(tint)
            HStack { Text("MIN"); Spacer(); Rectangle().fill(Color.instrumentLine).frame(width: 1, height: 5); Spacer(); Text("MAX") }
                .font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
        }
    }
}
