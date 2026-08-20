import AppKit
import SwiftUI

struct HardwareKeyStyle: ButtonStyle {
    var width: CGFloat = 28
    var height: CGFloat = 28
    var accent: Color = .instrumentOrange
    var isLatched = false
    var isPrimary = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.instrument(7, weight: .medium))
            .foregroundStyle(foreground(configuration))
            .frame(width: width, height: height)
            .background(
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(face)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.instrumentInk.opacity(isLatched ? 0.62 : 0.18), lineWidth: 0.7)
                    )
                    .overlay(alignment: .top) {
                        if isLatched && !isPrimary {
                            Capsule().fill(accent).frame(width: 8, height: 1.5).padding(.top, 3)
                        }
                    }
                    .overlay(alignment: .bottom) {
                        if !isLatched && !isPrimary {
                            Rectangle().fill(Color.instrumentInk.opacity(0.1)).frame(height: 1)
                        }
                    }
            )
            .opacity(configuration.isPressed ? 0.68 : 1)
            .offset(y: configuration.isPressed ? 0.6 : 0)
            .animation(.easeOut(duration: 0.045), value: configuration.isPressed)
    }

    private var face: Color {
        if isPrimary { return accent }
        return isLatched ? .instrumentInk : .instrumentRaised
    }

    private func foreground(_ configuration: Configuration) -> Color {
        if isPrimary { return .instrumentInk }
        if isLatched { return .instrumentRaised }
        return .instrumentInk.opacity(configuration.isPressed ? 0.55 : 0.82)
    }
}

struct HardwareLED: View {
    var color: Color
    var isOn: Bool
    var size: CGFloat = 5

    var body: some View {
        Circle()
            .fill(isOn ? color : Color.instrumentInk.opacity(0.16))
            .frame(width: size, height: size)
    }
}

struct LevelMeter: View {
    var value: Float
    var tint: Color
    var vertical = true

    var body: some View {
        GeometryReader { proxy in
            let count = vertical ? 12 : 16
            let amount = max(0, min(1, CGFloat(value)))
            Group {
                if vertical {
                    VStack(spacing: 1) {
                        ForEach((0..<count).reversed(), id: \.self) { index in
                            meterSegment(index: index, count: count, amount: amount)
                        }
                    }
                } else {
                    HStack(spacing: 1) {
                        ForEach(0..<count, id: \.self) { index in
                            meterSegment(index: index, count: count, amount: amount)
                        }
                    }
                }
            }
            .padding(2)
            .frame(width: proxy.size.width, height: proxy.size.height)
            .background(Color.instrumentDisplay)
            .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.5))
        }
    }

    private func meterSegment(index: Int, count: Int, amount: CGFloat) -> some View {
        let lit = CGFloat(index + 1) / CGFloat(count) <= amount
        let color: Color = index > Int(Double(count) * 0.86) ? .instrumentOrange : tint
        return Rectangle().fill(lit ? color : Color.white.opacity(0.075))
    }
}

struct PhysicalFader: View {
    @Binding var value: Float
    var range: ClosedRange<Float> = -60...6
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let fraction = normalized(value)
            let travel = max(1, proxy.size.height - 18)
            let knobY = (1 - fraction) * travel + 9
            ZStack(alignment: .top) {
                HStack(spacing: 4) {
                    scaleMarks
                    Capsule()
                        .fill(Color.instrumentInk.opacity(0.88))
                        .frame(width: 4)
                        .overlay(alignment: .bottom) {
                            Capsule().fill(tint).frame(width: 1.5, height: max(1, travel * fraction))
                        }
                    scaleMarks
                }
                .padding(.vertical, 5)

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.instrumentRaised)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.instrumentInk.opacity(0.45), lineWidth: 0.7))
                    .overlay(Rectangle().fill(tint).frame(width: 21, height: 1.5))
                    .overlay {
                        HStack(spacing: 2) {
                            ForEach(0..<4, id: \.self) { _ in
                                Rectangle().fill(Color.instrumentInk.opacity(0.2)).frame(width: 1, height: 7)
                            }
                        }
                    }
                    .frame(width: 27, height: 16)
                    .position(x: proxy.size.width / 2, y: knobY)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { gesture in
                    let y = max(9, min(proxy.size.height - 9, gesture.location.y))
                    let newFraction = 1 - (y - 9) / max(1, proxy.size.height - 18)
                    value = range.lowerBound + Float(newFraction) * (range.upperBound - range.lowerBound)
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
            ForEach(0..<9, id: \.self) { index in
                Rectangle()
                    .fill(Color.instrumentInk.opacity(index == 1 ? 0.5 : 0.23))
                    .frame(width: index.isMultiple(of: 4) ? 7 : 4, height: 1)
                if index < 8 { Spacer() }
            }
        }
    }

    private func normalized(_ input: Float) -> CGFloat {
        CGFloat((max(range.lowerBound, min(range.upperBound, input)) - range.lowerBound) / (range.upperBound - range.lowerBound))
    }
}

struct RotaryKnob: View {
    var title: String
    @Binding var value: Float
    var range: ClosedRange<Float>
    var defaultValue: Float
    var accent: Color
    var size: CGFloat
    var formatter: (Float) -> String

    @State private var dragOrigin: Float?

    init(
        _ title: String,
        value: Binding<Float>,
        in range: ClosedRange<Float>,
        default defaultValue: Float = 0,
        accent: Color = .instrumentOrange,
        size: CGFloat = 34,
        formatter: @escaping (Float) -> String = { String(format: "%.2f", $0) }
    ) {
        self.title = title
        _value = value
        self.range = range
        self.defaultValue = defaultValue
        self.accent = accent
        self.size = size
        self.formatter = formatter
    }

    var body: some View {
        VStack(spacing: 2) {
            ZStack {
                Circle()
                    .fill(Color.instrumentRaised)
                    .overlay(Circle().stroke(Color.instrumentInk.opacity(0.28), lineWidth: 0.7))
                    .frame(width: size * 0.78, height: size * 0.78)
                Circle()
                    .fill(Color.instrumentInk)
                    .frame(width: size * 0.48, height: size * 0.48)
                Capsule()
                    .fill(accent)
                    .frame(width: 1.5, height: size * 0.16)
                    .offset(y: -size * 0.13)
                    .rotationEffect(.degrees(angle))
            }
            .frame(width: size, height: size)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if dragOrigin == nil { dragOrigin = value }
                        guard let dragOrigin else { return }
                        let travel = Float(-gesture.translation.height + gesture.translation.width * 0.35)
                        let amount = travel / 115 * (range.upperBound - range.lowerBound)
                        value = max(range.lowerBound, min(range.upperBound, dragOrigin + amount))
                    }
                    .onEnded { _ in dragOrigin = nil }
            )
            .onTapGesture(count: 2) { value = defaultValue }

            Text(title.lowercased())
                .font(.instrument(5.5, weight: .regular))
                .foregroundStyle(Color.instrumentTextSecondary)
            Text(formatter(value))
                .font(.instrumentNumber(7, weight: .medium))
                .foregroundStyle(Color.instrumentInk)
                .lineLimit(1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(formatter(value))
        .accessibilityAdjustableAction { direction in
            let increment = (range.upperBound - range.lowerBound) / 50
            switch direction {
            case .increment: value = min(range.upperBound, value + increment)
            case .decrement: value = max(range.lowerBound, value - increment)
            @unknown default: break
            }
        }
    }

    private var angle: Double {
        let fraction = Double((value - range.lowerBound) / (range.upperBound - range.lowerBound))
        return -135 + fraction * 270
    }
}

struct ModeSelector: View {
    @Binding var selection: WorkspaceMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(WorkspaceMode.allCases) { mode in
                Button { selection = mode } label: {
                    VStack(spacing: 3) {
                        Circle()
                            .fill(selection == mode ? Color.instrumentInk : Color.instrumentRaised)
                            .overlay(Circle().stroke(Color.instrumentInk.opacity(0.26), lineWidth: 0.7))
                            .overlay {
                                Circle()
                                    .fill(selection == mode ? Color.instrumentOrange : Color.instrumentInk.opacity(0.18))
                                    .frame(width: 3, height: 3)
                            }
                            .frame(width: 13, height: 13)
                        Text(mode.shortName.lowercased())
                            .font(.instrument(5.5, weight: selection == mode ? .medium : .regular))
                            .foregroundStyle(selection == mode ? Color.instrumentInk : Color.instrumentTextSecondary)
                    }
                    .frame(width: 25)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 91, height: 30)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Instrument mode")
        .accessibilityValue(selection.detailName)
        .accessibilityAdjustableAction { direction in
            let modes = WorkspaceMode.allCases
            let current = modes.firstIndex(of: selection) ?? 0
            switch direction {
            case .increment: selection = modes[min(modes.count - 1, current + 1)]
            case .decrement: selection = modes[max(0, current - 1)]
            @unknown default: break
            }
        }
    }
}

struct KeyCap: View {
    var text: String
    var wide = false

    var body: some View {
        Text(text)
            .font(.instrument(6.5, weight: .medium))
            .foregroundStyle(Color.instrumentInk)
            .frame(minWidth: wide ? 44 : 18, minHeight: 17)
            .padding(.horizontal, wide ? 4 : 0)
            .background(
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.instrumentRaised)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.instrumentLine, lineWidth: 0.7))
            )
    }
}

struct WindowDragArea: NSViewRepresentable {
    func makeNSView(context: Context) -> DragNSView { DragNSView() }
    func updateNSView(_ nsView: DragNSView, context: Context) {}
}

final class DragNSView: NSView {
    override var mouseDownCanMoveWindow: Bool { true }
}
