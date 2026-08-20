import SwiftUI

struct PadSurface: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        VStack(spacing: 9) {
            GeometryReader { proxy in
                ZStack {
                    PadGrid(interactive: !app.isTrackpadArmed, rowHeight: 66)

                    if app.isTrackpadArmed {
                        TrackpadTouchView(
                            onBegan: app.trackpadTouchBegan,
                            onMoved: app.trackpadTouchMoved,
                            onEnded: app.trackpadTouchEnded
                        )

                        ForEach(app.trackpadTouches) { touch in
                            ZStack {
                                Circle().fill(Color.instrumentInk.opacity(0.84))
                                Circle().stroke(Color.instrumentOrange, lineWidth: 1)
                                Text("\(touch.padIndex + 1)")
                                    .font(.instrumentNumber(6, weight: .medium))
                                    .foregroundStyle(Color.instrumentRaised)
                            }
                            .frame(width: 19, height: 19)
                            .position(
                                x: touch.normalizedX * proxy.size.width,
                                y: (1 - touch.normalizedY) * proxy.size.height
                            )
                            .allowsHitTesting(false)
                        }

                        Text("touch")
                            .font(.instrument(5.5, weight: .medium))
                            .foregroundStyle(Color.instrumentRaised.opacity(0.76))
                            .padding(.horizontal, 6)
                            .frame(height: 14)
                            .background(Color.instrumentInk.opacity(0.86))
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                            .padding(4)
                            .allowsHitTesting(false)
                    }
                }
            }
            .frame(height: 206)

            VoiceControlDeck()
                .frame(height: 139)
        }
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
        ZStack {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(active ? Color.instrumentInk : Color.instrumentRaised)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color.instrumentInk.opacity(active ? 0.7 : 0.18), lineWidth: 0.7)
                )
                .overlay(alignment: .bottom) {
                    if !active {
                        Capsule().fill(Color.instrumentInk.opacity(0.1)).frame(width: 22, height: 1).padding(.bottom, 3)
                    }
                }

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(String(format: "%02d", pad.index + 1))
                        .font(.instrumentNumber(5, weight: .medium))
                    Spacer()
                    HardwareLED(color: .instrumentOrange, isOn: selected, size: 3)
                }
                Spacer()
                Text(keyName)
                    .font(.instrument(8, weight: .medium))
            }
            .foregroundStyle(active ? Color.instrumentRaised : Color.instrumentInk.opacity(0.66))
            .padding(7)
        }
        .offset(y: active || pointerDown ? 0.7 : 0)
        .animation(.easeOut(duration: 0.05), value: active)
        .contentShape(RoundedRectangle(cornerRadius: 5))
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
        VStack(spacing: 7) {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(String(format: "%02d", pad.index + 1))
                            .font(.instrumentNumber(5.5, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.36))
                        HardwareLED(color: .instrumentOrange, isOn: true, size: 3)
                    }
                    Spacer(minLength: 0)
                    Text(pad.name.lowercased())
                        .font(.instrument(8, weight: .regular))
                        .foregroundStyle(Color.instrumentRaised.opacity(0.86))
                        .lineLimit(1)
                    Text(app.tempoSync.isEnabled ? app.tempoSync.displayText : (pad.relativePath == nil ? "factory" : "sample"))
                        .font(.instrument(5, weight: .regular))
                        .foregroundStyle(app.tempoSync.isLocked ? Color.instrumentGreen.opacity(0.82) : Color.white.opacity(0.32))
                }
                .padding(7)
                .frame(maxWidth: .infinity, minHeight: 57, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 3).fill(Color.instrumentDisplay))

                RotaryKnob(
                    "level",
                    value: Binding(
                        get: { app.selectedPad.gainDB },
                        set: { value in app.updateSelectedPad { $0.gainDB = value } }
                    ),
                    in: -24...6,
                    accent: .instrumentOrange,
                    size: 31,
                    formatter: { $0.decibelString }
                )
                RotaryKnob(
                    "pan",
                    value: Binding(
                        get: { app.selectedPad.pan },
                        set: { value in app.updateSelectedPad { $0.pan = value } }
                    ),
                    in: -1...1,
                    accent: .instrumentInk.opacity(0.62),
                    size: 31,
                    formatter: panText
                )

                VStack(spacing: 3) {
                    Button("▶") { app.triggerPad(index: pad.index) }
                        .buttonStyle(HardwareKeyStyle(width: 30, height: 27, accent: .instrumentOrange, isPrimary: true))
                        .help("Preview selected pad")
                    Button("↓") { app.loadSampleForSelectedPad() }
                        .buttonStyle(HardwareKeyStyle(width: 30, height: 27))
                        .help("Load a sample")
                }
            }

            HStack(spacing: 4) {
                chokeControl
                Button("rec") { app.isPatternRecording.toggle() }
                    .buttonStyle(HardwareKeyStyle(width: 38, height: 25, accent: .instrumentOrange, isLatched: app.isPatternRecording))
                Button("touch") { app.armTrackpad(!app.isTrackpadArmed) }
                    .buttonStyle(HardwareKeyStyle(width: 43, height: 25, accent: .instrumentOrange, isLatched: app.isTrackpadArmed))
                    .keyboardShortcut("t", modifiers: [])
                    .help("Map the full Magic Trackpad to the 4 × 3 field — T")
                Button("sync") { app.toggleSystemTempoSync() }
                    .buttonStyle(HardwareKeyStyle(width: 39, height: 25, accent: .instrumentGreen, isLatched: app.tempoSync.isEnabled))
                    .help("Quantize pads to system audio — B")
                Spacer(minLength: 0)
                if pad.relativePath != nil {
                    Button("↺") { app.restoreFactoryPad() }
                        .buttonStyle(HardwareKeyStyle(width: 25, height: 25))
                        .help("Restore factory voice")
                }
            }
        }
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
            Text(pad.chokeGroup.map(String.init) ?? "–")
                .font(.instrumentNumber(6, weight: .medium))
        }
        .font(.instrument(6, weight: .medium))
        .padding(.horizontal, 7)
        .frame(height: 25)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.instrumentRaised)
                .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.instrumentInk.opacity(0.18), lineWidth: 0.7))
        )
    }

    private func panText(_ value: Float) -> String {
        if abs(value) < 0.02 { return "C" }
        return value < 0 ? "L\(Int(abs(value) * 100))" : "R\(Int(value * 100))"
    }
}
