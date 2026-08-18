import SwiftUI

struct PadSurface: View {
    @EnvironmentObject private var app: AppState

    var body: some View {
        ZStack {
            Color.instrumentSurface
            PanelScrews()
            VStack(spacing: 14) {
                header
                GeometryReader { proxy in
                    ZStack {
                        PadGrid(interactive: !app.isTrackpadArmed)
                        if app.isTrackpadArmed {
                            TrackpadTouchView(onBegan: app.trackpadTouchBegan, onMoved: app.trackpadTouchMoved, onEnded: app.trackpadTouchEnded)
                                .background(Color.clear)
                            ForEach(app.trackpadTouches) { touch in
                                ZStack {
                                    Circle().fill(Color.instrumentRaised.opacity(0.7))
                                    Circle().stroke(Color.padColor(touch.padIndex), lineWidth: 4)
                                    Text("\(touch.padIndex + 1)").font(.system(size: 10, weight: .black, design: .monospaced)).foregroundStyle(Color.instrumentInk)
                                }
                                .frame(width: 42, height: 42)
                                .position(x: touch.normalizedX * proxy.size.width, y: (1 - touch.normalizedY) * proxy.size.height)
                                .allowsHitTesting(false)
                            }
                            VStack {
                                Spacer()
                                Text("LIVE TOUCH FIELD  /  KEEP POINTER OVER SURFACE  /  T OR ESC TO EXIT")
                                    .font(.system(size: 8, weight: .black, design: .monospaced))
                                    .foregroundStyle(Color.instrumentRaised)
                                    .padding(.horizontal, 10).frame(height: 24).background(Color.instrumentInk.opacity(0.82))
                            }
                            .allowsHitTesting(false)
                        }
                    }
                }
                footer
            }
            .padding(20)
        }
        .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.75), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    HardwareLED(color: .instrumentOrange, isOn: app.isPatternRecording)
                    Text("SP–12 SAMPLE MATRIX").font(.system(size: 11, weight: .black, design: .monospaced)).tracking(0.4)
                }
                Text(app.isTrackpadArmed ? "MULTI-TOUCH INPUT ACTIVE" : "CLICK / KEYBOARD / TRACKPAD MULTI-TOUCH")
                    .font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary)
            }
            Spacer()
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(String(format: "PAD %02d", app.selectedPadIndex + 1)).font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentYellow)
                    Text(app.selectedPad.name.uppercased()).font(.system(size: 7, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.48)).lineLimit(1)
                }
                .padding(.horizontal, 10).frame(width: 122, height: 36, alignment: .leading).background(Color.instrumentDisplay)
                Rectangle().fill(Color.instrumentInk.opacity(0.5)).frame(width: 1, height: 36)
                VStack(spacing: 1) {
                    Text("BPM").font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(Color.white.opacity(0.4))
                    Text("\(Int(app.project.pattern.bpm))").font(.system(size: 11, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentGreen)
                }
                .frame(width: 54, height: 36).background(Color.instrumentDisplay)
            }
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.7), lineWidth: 1))
            Button(app.isPatternRecording ? "REC ON" : "REC") { app.isPatternRecording.toggle() }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentOrange, isLatched: app.isPatternRecording, compact: true))
            Button(app.isTrackpadArmed ? "DISARM" : "TRACKPAD") { app.armTrackpad(!app.isTrackpadArmed) }
                .buttonStyle(InstrumentButtonStyle(accent: .instrumentYellow, isLatched: app.isTrackpadArmed, compact: true))
                .keyboardShortcut("t", modifiers: [])
        }
        .padding(.horizontal, 5).frame(height: 46)
    }

    private var footer: some View {
        HStack {
            Text("BANK A  /  12 VOICES").instrumentLabel()
            Spacer()
            HStack(spacing: 6) {
                ForEach(["1 2 3 4", "Q W E R", "A S D F"], id: \.self) { Text($0).font(.system(size: 8, weight: .black, design: .monospaced)).padding(.horizontal, 8).frame(height: 22).background(Color.instrumentRaised).overlay(Rectangle().stroke(Color.instrumentLine)) }
            }
            Spacer()
            Text("SELECT A PAD TO EDIT ITS SAMPLE").instrumentLabel()
        }
        .padding(.horizontal, 5).frame(height: 28)
    }
}

struct PadGrid: View {
    @EnvironmentObject private var app: AppState
    var interactive = true
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(app.project.pads) { pad in PerformancePad(pad: pad, interactive: interactive).aspectRatio(1.52, contentMode: .fit) }
        }
        .padding(5)
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
                RoundedRectangle(cornerRadius: 5)
                    .fill(active ? Color.instrumentRaised : Color(red: 0.25, green: 0.25, blue: 0.23))
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(selected ? Color.padColor(pad.index) : Color.instrumentInk.opacity(0.72), lineWidth: selected ? 3 : 1))
                    .shadow(color: Color.instrumentInk.opacity(0.42), radius: 0, y: active || pointerDown ? 1 : 4)
                Rectangle().fill(Color.padColor(pad.index)).frame(height: 6).frame(maxHeight: .infinity, alignment: .top).clipShape(RoundedRectangle(cornerRadius: 5))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(String(format: "%02d", pad.index + 1))
                        Spacer()
                        Text(keyName).padding(.horizontal, 7).frame(height: 21)
                            .background(active ? Color.padColor(pad.index) : Color.instrumentRaised)
                            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.55)))
                    }
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.7))
                    Spacer()
                    Text(pad.name.uppercased())
                        .font(.system(size: min(12, proxy.size.width * 0.085), weight: .black, design: .monospaced))
                        .foregroundStyle(active ? Color.instrumentInk : Color.white.opacity(0.84)).lineLimit(1)
                    Text(pad.relativePath == nil ? "FACTORY" : "USER SAMPLE")
                        .font(.system(size: 6, weight: .bold, design: .monospaced)).foregroundStyle(active ? Color.instrumentInk.opacity(0.55) : Color.white.opacity(0.3))
                }
                .padding(12)
            }
            .offset(y: active || pointerDown ? 3 : 0)
            .animation(.easeOut(duration: 0.06), value: active)
            .contentShape(RoundedRectangle(cornerRadius: 5))
            .gesture(DragGesture(minimumDistance: 0).onChanged { _ in
                guard interactive, !pointerDown else { return }
                pointerDown = true; app.selectPad(pad.index); app.triggerPad(index: pad.index, hold: true)
            }.onEnded { _ in
                guard pointerDown else { return }; pointerDown = false; app.releasePad(index: pad.index)
            })
            .onTapGesture { app.selectPad(pad.index) }
        }
        .accessibilityElement(children: .ignore).accessibilityLabel("Pad \(pad.index + 1), \(pad.name)")
        .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton).accessibilityAction { app.triggerPad(index: pad.index) }
    }
}
