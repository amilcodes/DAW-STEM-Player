import SwiftUI

struct PadSurface: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            padHeader
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            GeometryReader { proxy in
                ZStack {
                    PadGrid(interactive: !app.isTrackpadArmed, rowHeight: 58)
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
                                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
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
                            Text("TRACKPAD LIVE  ·  T / ESC")
                                .font(.system(size: 5.5, weight: .semibold, design: .monospaced))
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
            .frame(height: 192)
            Rectangle().fill(Color.instrumentLine).frame(height: 1)
            VoiceControlDeck().frame(height: 115)
        }
        .background(Color.instrumentPlate.opacity(0.52))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    private var padHeader: some View {
        HStack(spacing: 5) {
            HardwareLED(color: app.isTrackpadArmed ? .instrumentYellow : .instrumentOrange, isOn: true, size: 4)
            Text("PAD FIELD")
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
            Text(app.isTrackpadArmed ? "MULTI-TOUCH" : "4 × 3")
                .font(.system(size: 5, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.instrumentTextSecondary)
            Spacer(minLength: 0)
            HStack(spacing: 3) {
                ForEach(["1 2 3 4", "Q W E R", "A S D F"], id: \.self) { row in
                    Text(row)
                        .font(.system(size: 5, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 3)
                        .frame(height: 14)
                        .background(Color.instrumentRaised)
                        .overlay(Rectangle().stroke(Color.instrumentLine))
                }
            }
        }
        .padding(.horizontal, 6)
        .frame(height: 22)
        .background(Color.instrumentSurface.opacity(0.55))
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
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(active ? Color.instrumentRaised : Color(red: 0.23, green: 0.235, blue: 0.225))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(selected ? Color.padColor(pad.index) : Color.instrumentInk.opacity(0.62), lineWidth: selected ? 2 : 1)
                    )
                    .shadow(color: Color.instrumentInk.opacity(0.28), radius: 0, y: active || pointerDown ? 1 : 2)
                Rectangle()
                    .fill(Color.padColor(pad.index))
                    .frame(height: 3)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(String(format: "%02d", pad.index + 1))
                        Spacer()
                        Text(keyName)
                            .frame(width: 15, height: 12)
                            .background(active ? Color.padColor(pad.index) : Color.instrumentRaised)
                            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.32)))
                    }
                    .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                    .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.64))
                    Spacer()
                    Text(pad.name)
                        .font(.system(size: min(8, proxy.size.width * 0.11), weight: .semibold))
                        .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.88))
                        .lineLimit(1)
                }
                .padding(5)
            }
            .offset(y: active || pointerDown ? 1 : 0)
            .animation(.easeOut(duration: 0.055), value: active)
            .contentShape(RoundedRectangle(cornerRadius: 3))
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
                        Text(String(format: "PAD %02d", pad.index + 1))
                        Spacer()
                        HardwareLED(color: Color.padColor(pad.index), isOn: true, size: 3)
                    }
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.42))
                    Text(pad.name)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.instrumentYellow)
                        .lineLimit(1)
                    Text(pad.relativePath == nil ? "FACTORY" : "USER SAMPLE")
                        .font(.system(size: 5, weight: .medium, design: .monospaced))
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
                    accent: Color.padColor(pad.index),
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
                    accent: Color.padColor(pad.index),
                    size: 32,
                    formatter: panText
                )

                VStack(spacing: 3) {
                    Button("Preview") { app.triggerPad(index: pad.index) }
                        .buttonStyle(InstrumentButtonStyle(accent: Color.padColor(pad.index), isLatched: true, compact: true))
                    Button("Load") { app.loadSampleForSelectedPad() }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
            }

            HStack(spacing: 4) {
                chokeControl
                Button(app.isPatternRecording ? "Rec on" : "Record") { app.isPatternRecording.toggle() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isPatternRecording, compact: true))
                Button(app.isTrackpadArmed ? "Pad off" : "Pad on") { app.armTrackpad(!app.isTrackpadArmed) }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentYellow, isLatched: app.isTrackpadArmed, compact: true))
                    .keyboardShortcut("t", modifiers: [])
                    .help("Map the full Magic Trackpad to the 4 × 3 field — T")
                if pad.relativePath != nil {
                    Button("↺") { app.restoreFactoryPad() }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                    .help("Restore factory voice")
                }
            }

            HStack(spacing: 4) {
                HardwareLED(color: app.isTrackpadArmed ? .instrumentYellow : .instrumentOrange, isOn: true, size: 3)
                Text(app.isTrackpadArmed ? "MULTI-TOUCH LIVE" : "12 VOICE / 48K")
                    .font(.system(size: 5, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.instrumentTextSecondary)
                Spacer(minLength: 0)
                HStack(spacing: 2) {
                    ForEach(0..<9, id: \.self) { _ in
                        Circle().fill(Color.instrumentInk.opacity(0.22)).frame(width: 2, height: 2)
                    }
                }
            }
            .frame(height: 12)
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
            Text("CHOKE")
            Text(pad.chokeGroup.map { String($0) } ?? "–")
        }
        .font(.system(size: 6, weight: .medium, design: .monospaced))
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
