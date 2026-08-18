import AppKit
import SwiftUI

struct InstrumentButtonStyle: ButtonStyle {
    var accent: Color = .instrumentRaised
    var isLatched = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 9 : 10, weight: .bold, design: .monospaced))
            .textCase(.uppercase)
            .foregroundStyle(Color.instrumentInk.opacity(configuration.isPressed ? 0.64 : 0.94))
            .padding(.horizontal, compact ? 8 : 11)
            .padding(.vertical, compact ? 5 : 8)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(isLatched ? accent : Color.instrumentRaised)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.instrumentInk.opacity(isLatched ? 0.64 : 0.38), lineWidth: 1))
                    .shadow(color: Color.instrumentInk.opacity(0.36), radius: 0, y: configuration.isPressed ? 0 : 2)
            )
            .offset(y: configuration.isPressed ? 2 : 0)
            .animation(.easeOut(duration: 0.055), value: configuration.isPressed)
    }
}

struct CircleTransportButtonStyle: ButtonStyle {
    var tint: Color = .instrumentOrange
    var size: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.31, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.instrumentInk)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.instrumentRaised)
                    .overlay(Circle().stroke(Color.instrumentInk.opacity(0.62), lineWidth: 1))
                    .overlay(alignment: .top) {
                        Capsule().fill(tint).frame(width: size * 0.25, height: 3).padding(.top, 5)
                    }
                    .shadow(color: Color.instrumentInk.opacity(0.38), radius: 0, y: configuration.isPressed ? 0 : 3)
            )
            .offset(y: configuration.isPressed ? 3 : 0)
            .animation(.easeOut(duration: 0.055), value: configuration.isPressed)
    }
}

struct LevelMeter: View {
    var value: Float
    var tint: Color
    var vertical = true

    var body: some View {
        GeometryReader { proxy in
            let count = vertical ? 18 : 24
            let amount = max(0, min(1, CGFloat(value)))
            Group {
                if vertical {
                    VStack(spacing: 2) {
                        ForEach((0..<count).reversed(), id: \.self) { index in
                            Rectangle().fill(CGFloat(index + 1) / CGFloat(count) <= amount ? tint : Color.white.opacity(0.09))
                        }
                    }
                } else {
                    HStack(spacing: 2) {
                        ForEach(0..<count, id: \.self) { index in
                            Rectangle().fill(CGFloat(index + 1) / CGFloat(count) <= amount ? tint : Color.white.opacity(0.09))
                        }
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .background(Color.black.opacity(0.38))
    }
}

struct PhysicalFader: View {
    @Binding var value: Float
    var range: ClosedRange<Float> = -60...6
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let fraction = normalized(value)
            let knobY = (1 - fraction) * max(1, proxy.size.height - 34) + 17
            ZStack(alignment: .top) {
                HStack(spacing: 8) {
                    scaleMarks
                    Rectangle()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: 5)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(tint).frame(width: 2, height: max(2, proxy.size.height * fraction - 16)).padding(.bottom, 8)
                        }
                    scaleMarks
                }
                .padding(.vertical, 9)

                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.instrumentRaised)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.instrumentInk.opacity(0.8), lineWidth: 1))
                    .overlay(Rectangle().fill(tint).frame(width: 34, height: 2))
                    .overlay(alignment: .top) {
                        HStack(spacing: 4) {
                            ForEach(0..<6, id: \.self) { _ in Rectangle().fill(Color.instrumentInk.opacity(0.22)).frame(width: 1) }
                        }.padding(.top, 5)
                    }
                    .frame(width: 46, height: 32)
                    .shadow(color: .black.opacity(0.48), radius: 0, y: 3)
                    .position(x: proxy.size.width / 2, y: knobY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let y = max(17, min(proxy.size.height - 17, gesture.location.y))
                        let fraction = 1 - (y - 17) / max(1, proxy.size.height - 34)
                        value = range.lowerBound + Float(fraction) * (range.upperBound - range.lowerBound)
                    }
            )
            .onTapGesture(count: 2) { value = 0 }
        }
        .accessibilityElement()
        .accessibilityLabel("Level")
        .accessibilityValue("\(value.decibelString) decibels")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + 1)
            case .decrement: value = max(range.lowerBound, value - 1)
            @unknown default: break
            }
        }
    }

    private var scaleMarks: some View {
        VStack(spacing: 0) {
            ForEach(0..<11, id: \.self) { index in
                Rectangle().fill(Color.white.opacity(index == 1 ? 0.55 : 0.25)).frame(width: index % 5 == 0 ? 8 : 4, height: 1)
                if index < 10 { Spacer() }
            }
        }
    }

    private func normalized(_ value: Float) -> CGFloat {
        CGFloat((max(range.lowerBound, min(range.upperBound, value)) - range.lowerBound) / (range.upperBound - range.lowerBound))
    }
}

struct ModePicker: View {
    @Binding var selection: WorkspaceMode

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(WorkspaceMode.allCases.enumerated()), id: \.element.id) { index, mode in
                Button { selection = mode } label: {
                    VStack(spacing: 2) {
                        Text(String(format: "%02d", index + 1)).font(.system(size: 7, weight: .medium, design: .monospaced))
                        Text(mode.rawValue.uppercased()).font(.system(size: 10, weight: .bold, design: .monospaced))
                    }
                    .foregroundStyle(Color.instrumentInk)
                    .frame(width: 76, height: 34)
                    .background(selection == mode ? mode.accent.opacity(0.92) : Color.instrumentRaised)
                    .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.48), lineWidth: 0.5))
                    .overlay(alignment: .bottom) { Rectangle().fill(selection == mode ? Color.instrumentInk : Color.clear).frame(height: 2) }
                }
                .buttonStyle(.plain)
            }
        }
        .shadow(color: Color.instrumentInk.opacity(0.3), radius: 0, y: 2)
    }
}

struct KeyCap: View {
    var text: String
    var wide = false

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(Color.instrumentInk)
            .frame(minWidth: wide ? 58 : 25, minHeight: 22)
            .padding(.horizontal, wide ? 4 : 0)
            .background(
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.instrumentRaised)
                    .overlay(RoundedRectangle(cornerRadius: 2).stroke(Color.instrumentInk.opacity(0.42), lineWidth: 1))
                    .shadow(color: Color.instrumentInk.opacity(0.28), radius: 0, y: 2)
            )
    }
}

struct HardwareLED: View {
    var color: Color
    var isOn: Bool

    var body: some View {
        Circle().fill(isOn ? color : Color.instrumentInk.opacity(0.18))
            .overlay(Circle().stroke(Color.instrumentInk.opacity(0.55), lineWidth: 0.7))
            .frame(width: 7, height: 7)
    }
}

struct PanelScrews: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<4, id: \.self) { index in
                Circle().fill(Color.instrumentInk.opacity(0.38))
                    .overlay(Rectangle().fill(Color.instrumentSurface.opacity(0.8)).frame(width: 4, height: 0.7))
                    .frame(width: 8, height: 8)
                    .position(x: index % 2 == 0 ? 10 : proxy.size.width - 10, y: index < 2 ? 10 : proxy.size.height - 10)
            }
        }
        .allowsHitTesting(false)
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragNSView { DragNSView() }
    func updateNSView(_ nsView: DragNSView, context: Context) {}
}

final class DragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}

extension Color {
    static func padColor(_ index: Int) -> Color {
        let palette: [Color] = [.instrumentOrange, .instrumentYellow, .instrumentGreen, .instrumentBlue]
        return palette[index % palette.count]
    }
}

extension WorkspaceMode {
    var accent: Color {
        switch self {
        case .mix: .instrumentOrange
        case .pads: .instrumentYellow
        case .pattern: .instrumentGreen
        }
    }
}
