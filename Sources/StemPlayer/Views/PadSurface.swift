import SwiftUI

struct PadSurface: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                padHeader
                Rectangle().fill(Color.instrumentLine).frame(height: 1)
                GeometryReader { proxy in
                    ZStack {
                        PadGrid(interactive: !app.isTrackpadArmed)
                            .padding(12)
                        if app.isTrackpadArmed {
                            TrackpadTouchView(
                                onBegan: app.trackpadTouchBegan,
                                onMoved: app.trackpadTouchMoved,
                                onEnded: app.trackpadTouchEnded
                            )
                            ForEach(app.trackpadTouches) { touch in
                                ZStack {
                                    Circle().fill(Color.instrumentRaised.opacity(0.84))
                                    Circle().stroke(Color.padColor(touch.padIndex), lineWidth: 3)
                                    Text("\(touch.padIndex + 1)")
                                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                }
                                .frame(width: 34, height: 34)
                                .position(
                                    x: touch.normalizedX * proxy.size.width,
                                    y: (1 - touch.normalizedY) * proxy.size.height
                                )
                                .allowsHitTesting(false)
                            }
                            VStack {
                                Spacer()
                                Text("LIVE TRACKPAD FIELD  ·  MOVE BETWEEN CELLS TO RETRIGGER  ·  T OR ESC TO EXIT")
                                    .font(.system(size: 7, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(Color.instrumentRaised)
                                    .padding(.horizontal, 10)
                                    .frame(height: 22)
                                    .background(Color.instrumentInk.opacity(0.84))
                            }
                            .padding(12)
                            .allowsHitTesting(false)
                        }
                    }
                }
            }

            Rectangle().fill(Color.instrumentLine).frame(width: 1)
            VoiceControlDeck().frame(width: 238)
        }
        .background(Color.instrumentPlate.opacity(0.52))
        .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 1))
    }

    private var padHeader: some View {
        HStack(spacing: 9) {
            HardwareLED(color: app.isTrackpadArmed ? .instrumentYellow : .instrumentOrange, isOn: true)
            Text("12-pad performance matrix")
                .font(.system(size: 10, weight: .semibold))
            Text(app.isTrackpadArmed ? "raw multi-touch active" : "click / keys / trackpad")
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
            Spacer()
            HStack(spacing: 5) {
                ForEach(["1 2 3 4", "Q W E R", "A S D F"], id: \.self) { row in
                    Text(row)
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 6)
                        .frame(height: 19)
                        .background(Color.instrumentRaised)
                        .overlay(Rectangle().stroke(Color.instrumentLine))
                }
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 36)
        .background(Color.instrumentSurface.opacity(0.55))
    }
}

struct PadGrid: View {
    @EnvironmentObject private var app: AppState
    var interactive = true
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(app.project.pads) { pad in
                PerformancePad(pad: pad, interactive: interactive)
                    .aspectRatio(1.95, contentMode: .fit)
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
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(active ? Color.instrumentRaised : Color(red: 0.23, green: 0.235, blue: 0.225))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(selected ? Color.padColor(pad.index) : Color.instrumentInk.opacity(0.62), lineWidth: selected ? 2 : 1)
                    )
                    .shadow(color: Color.instrumentInk.opacity(0.28), radius: 0, y: active || pointerDown ? 1 : 3)
                Rectangle()
                    .fill(Color.padColor(pad.index))
                    .frame(height: 4)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(String(format: "%02d", pad.index + 1))
                        Spacer()
                        Text(keyName)
                            .frame(width: 22, height: 18)
                            .background(active ? Color.padColor(pad.index) : Color.instrumentRaised)
                            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.32)))
                    }
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.64))
                    Spacer()
                    Text(pad.name)
                        .font(.system(size: min(12, proxy.size.width * 0.085), weight: .semibold))
                        .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.88))
                        .lineLimit(1)
                    Text(pad.relativePath == nil ? "factory" : "user sample")
                        .font(.system(size: 7, weight: .regular))
                        .foregroundStyle(active ? Color.instrumentInk.opacity(0.5) : Color.white.opacity(0.32))
                }
                .padding(10)
            }
            .offset(y: active || pointerDown ? 2 : 0)
            .animation(.easeOut(duration: 0.055), value: active)
            .contentShape(RoundedRectangle(cornerRadius: 4))
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
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(String(format: "PAD %02d", pad.index + 1))
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.42))
                    Spacer()
                    HardwareLED(color: Color.padColor(pad.index), isOn: true)
                }
                Text(pad.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.instrumentYellow)
                    .lineLimit(1)
                Text(pad.relativePath == nil ? "FACTORY VOICE" : "USER VOICE")
                    .font(.system(size: 7, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.38))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Color.instrumentDisplay)

            HStack(spacing: 22) {
                RotaryKnob(
                    "Level",
                    value: Binding(
                        get: { app.selectedPad.gainDB },
                        set: { value in app.updateSelectedPad { $0.gainDB = value } }
                    ),
                    in: -24...6,
                    accent: Color.padColor(pad.index),
                    size: 51,
                    formatter: { "\($0.decibelString) dB" }
                )
                RotaryKnob(
                    "Pan",
                    value: Binding(
                        get: { app.selectedPad.pan },
                        set: { value in app.updateSelectedPad { $0.pan = value } }
                    ),
                    in: -1...1,
                    accent: Color.padColor(pad.index),
                    size: 51,
                    formatter: panText
                )
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 7) {
                Button("Preview") { app.triggerPad(index: pad.index) }
                    .buttonStyle(InstrumentButtonStyle(accent: Color.padColor(pad.index), isLatched: true, compact: true))
                Button("Load") { app.loadSampleForSelectedPad() }
                    .buttonStyle(InstrumentButtonStyle(compact: true))
            }

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

            if pad.relativePath != nil {
                Button("restore factory voice") { app.restoreFactoryPad() }
                    .buttonStyle(.plain)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(Color.instrumentTextSecondary)
            }

            Spacer(minLength: 0)
            Rectangle().fill(Color.instrumentLine).frame(height: 1)

            HStack(spacing: 7) {
                HardwareLED(color: .instrumentOrange, isOn: app.isPatternRecording)
                Button(app.isPatternRecording ? "Record on" : "Record") { app.isPatternRecording.toggle() }
                    .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isPatternRecording, compact: true))
            }
            Button(app.isTrackpadArmed ? "Disarm trackpad" : "Arm trackpad") {
                app.armTrackpad(!app.isTrackpadArmed)
            }
            .buttonStyle(InstrumentButtonStyle(accent: .instrumentYellow, isLatched: app.isTrackpadArmed))
            .keyboardShortcut("t", modifiers: [])
            Text("The full Magic Trackpad maps to the 4 × 3 grid. Multiple fingers trigger independently.")
                .font(.system(size: 8, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
                .lineSpacing(2)
        }
        .padding(13)
        .background(Color.instrumentSurface.opacity(0.48))
    }

    private var chokeLabel: some View {
        HStack {
            Text("choke")
            Spacer()
            Text(pad.chokeGroup.map { String($0) } ?? "off")
            Image(systemName: "chevron.up.chevron.down").font(.system(size: 7))
        }
        .font(.system(size: 8, weight: .medium))
        .padding(.horizontal, 9)
        .frame(height: 26)
        .background(Color.instrumentRaised)
        .overlay(Rectangle().stroke(Color.instrumentLine))
    }

    private func panText(_ value: Float) -> String {
        if abs(value) < 0.02 { return "center" }
        return value < 0 ? "L \(Int(abs(value) * 100))" : "R \(Int(value * 100))"
    }
}
