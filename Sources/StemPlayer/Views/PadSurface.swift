import SwiftUI

struct PadSurface: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                ZStack {
                    PadGrid(interactive: !app.isTrackpadArmed, rowHeight: 69)
                        .padding(5)
                    if app.isTrackpadArmed {
                        TrackpadTouchView(
                            onBegan: app.trackpadTouchBegan,
                            onMoved: app.trackpadTouchMoved,
                            onEnded: app.trackpadTouchEnded
                        )
                        ForEach(app.trackpadTouches) { touch in
                            ZStack {
                                Circle().fill(Color.instrumentRaised.opacity(0.84))
                                Circle().stroke(Color.padColor(touch.padIndex), lineWidth: 2)
                                Text("\(touch.padIndex + 1)")
                                    .font(.instrumentNumber(7, weight: .medium))
                            }
                            .frame(width: 22, height: 22)
                            .position(
                                x: touch.normalizedX * proxy.size.width,
                                y: (1 - touch.normalizedY) * proxy.size.height
                            )
                            .allowsHitTesting(false)
                        }
                        VStack {
                            Spacer()
                            Text("touch · esc")
                                .font(.instrument(5.5, weight: .medium))
                                .foregroundStyle(Color.instrumentRaised)
                                .padding(.horizontal, 6)
                                .frame(height: 15)
                                .background(Color.instrumentInk.opacity(0.84))
                        }
                        .padding(5)
                        .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 227)
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            VoiceControlDeck().frame(height: 103)
        }
        .background(Color.instrumentPlate.opacity(0.52))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
    }

}

struct PadGrid: View {
    @EnvironmentObject private var app: AppState
    var interactive = true
    var rowHeight: CGFloat
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(app.project.pads) { pad in
                PerformancePad(pad: pad, interactive: interactive)
                    .frame(height: rowHeight)
            }
        }
    }
}

private struct PerformancePad: View {
    @EnvironmentObject private var app: AppState
    let pad: PadModel
    var interactive: Bool
    @State private var pointerDown = false

    private var active: Bool { app.activePads.contains(pad.index) }
    private var selected: Bool { app.selectedPadIndex == pad.index }
    private var keyName: String { ["1", "2", "3", "4", "Q", "W", "E", "R", "A", "S", "D", "F"][pad.index] }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(active ? Color.instrumentRaised : Color.instrumentDisplay.opacity(0.86))
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(selected ? Color.instrumentOrange : Color.white.opacity(0.09), lineWidth: selected ? 1 : 0.6)
                    )
                if selected {
                    Rectangle()
                        .fill(Color.instrumentOrange)
                        .frame(height: 2)
                        .frame(maxHeight: .infinity, alignment: .top)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(String(format: "%02d", pad.index + 1))
                        Spacer()
                        Text(keyName)
                            .frame(width: 15, height: 12)
                            .background(active ? Color.instrumentInk : Color.instrumentRaised.opacity(0.84))
                            .foregroundStyle(active ? Color.instrumentRaised : Color.instrumentInk)
                            .overlay(Rectangle().stroke(Color.white.opacity(active ? 0 : 0.1), lineWidth: 0.6))
                    }
                    .font(.instrumentNumber(5.5, weight: .medium))
                    .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.48))
                    Spacer()
                    Text(pad.name)
                        .font(.instrument(min(8, proxy.size.width * 0.11), weight: .regular))
                        .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.88))
                        .lineLimit(1)
                }
                .padding(5)
            }
            .offset(y: active || pointerDown ? 1 : 0)
            .animation(.easeOut(duration: 0.055), value: active)
            .contentShape(RoundedRectangle(cornerRadius: 2))
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard interactive, !pointerDown else { return }
                        pointerDown = true
                        app.selectPad(pad.index)
                        app.triggerPad(index: pad.index, hold: true)
                    }
                    .onEnded { _ in
                        guard pointerDown else { return }
                        pointerDown = false
                        app.releasePad(index: pad.index)
                    }
            )
            .onTapGesture { app.selectPad(pad.index) }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Pad \(pad.index + 1), \(pad.name)")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
        .accessibilityAction { app.triggerPad(index: pad.index) }
    }
}

private struct VoiceControlDeck: View {
    @EnvironmentObject private var app: AppState

    private var pad: PadModel { app.selectedPad }

    var body: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(pad.name)
                            .font(.instrument(8, weight: .regular))
                            .foregroundStyle(Color.instrumentRaised.opacity(0.88))
                            .lineLimit(1)
                        Spacer()
                        HardwareLED(color: .instrumentOrange, isOn: true, size: 3)
                    }
                    Text(pad.relativePath == nil ? "factory" : "sample")
                        .font(.instrument(5, weight: .regular))
                        .foregroundStyle(Color.white.opacity(0.38))
                }
                .padding(5)
                .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                .background(Color.instrumentDisplay)

                RotaryKnob(
                    "Level",
                    value: Binding(
                        get: { app.selectedPad.gainDB },
                        set: { value in app.updateSelectedPad { $0.gainDB = value } }
                    ),
                    in: -24...6,
                    accent: .instrumentOrange,
                    size: 32,
                    formatter: { $0.decibelString }
                )
                RotaryKnob(
                    "Pan",
                    value: Binding(
                        get: { app.selectedPad.pan },
                        set: { value in app.updateSelectedPad { $0.pan = value } }
                    ),
                    in: -1...1,
                    accent: .instrumentInk.opacity(0.58),
                    size: 32,
                    formatter: panText
                )

                VStack(spacing: 3) {
                    Button("preview") { app.triggerPad(index: pad.index) }
                        .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, compact: true))
                    Button("load") { app.loadSampleForSelectedPad() }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
            }

            HStack(spacing: 4) {
                chokeControl
                Button("record") { app.isPatternRecording.toggle() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isPatternRecording, compact: true))
                Button("touch") { app.armTrackpad(!app.isTrackpadArmed) }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isTrackpadArmed, compact: true))
                    .keyboardShortcut("t", modifiers: [])
                    .help("Map the full Magic Trackpad to the 4 × 3 field — T")
                if pad.relativePath != nil {
                    Button("↺") { app.restoreFactoryPad() }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                    .help("Restore factory voice")
                }
            }

        }
        .padding(5)
        .frame(maxWidth: .infinity, alignment: .top)
        .background(Color.instrumentSurface.opacity(0.48))
    }

    @ViewBuilder private var chokeControl: some View {
        if ProcessInfo.processInfo.environment["SP4_RENDERING_PREVIEW"] == "1" {
            chokeLabel
        } else {
            Menu {
                Button("No choke") { app.updateSelectedPad { $0.chokeGroup = nil } }
                Button("Choke group 1") { app.updateSelectedPad { $0.chokeGroup = 1 } }
                Button("Choke group 2") { app.updateSelectedPad { $0.chokeGroup = 2 } }
                Button("Choke group 3") { app.updateSelectedPad { $0.chokeGroup = 3 } }
            } label: {
                chokeLabel
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
        }
    }

    private var chokeLabel: some View {
        HStack(spacing: 3) {
            Text("choke")
            Text(pad.chokeGroup.map { String($0) } ?? "–")
        }
        .font(.instrument(6, weight: .medium))
        .padding(.horizontal, 5)
        .frame(height: 20)
        .background(Color.instrumentRaised)
        .overlay(Rectangle().stroke(Color.instrumentLine))
    }

    private func panText(_ value: Float) -> String {
        if abs(value) < 0.02 { return "C" }
        return value < 0 ? "L\(Int(abs(value) * 100))" : "R\(Int(value * 100))"
    }
}
