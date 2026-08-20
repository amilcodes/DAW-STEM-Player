import AppKit
import SwiftUI

struct InstrumentButtonStyle: ButtonStyle {
    var accent: Color = .instrumentRaised
    var isLatched = false
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.instrument(compact ? 7 : 8.5, weight: .medium))
            .foregroundStyle(isLatched ? Color.instrumentRaised : Color.instrumentInk.opacity(configuration.isPressed ? 0.55 : 0.88))
            .padding(.horizontal, compact ? 6 : 9)
            .frame(minHeight: compact ? 20 : 26)
            .background(
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(isLatched ? Color.instrumentInk : Color.instrumentRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 1, style: .continuous)
                            .stroke(isLatched ? Color.instrumentInk : Color.instrumentLine, lineWidth: 0.7)
                    )
                    .overlay(alignment: .top) {
                        if isLatched { Rectangle().fill(accent).frame(height: 1.5) }
                    }
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
            .offset(y: configuration.isPressed ? 0.5 : 0)
            .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
    }
}

struct CircleTransportButtonStyle: ButtonStyle {
    var tint: Color = .instrumentOrange
    var size: CGFloat = 30

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.instrument(size * 0.28, weight: .semibold))
            .foregroundStyle(Color.instrumentInk)
            .frame(width: size, height: size)
            .background(
                Circle()
                    .fill(Color.instrumentRaised)
                    .overlay(Circle().stroke(Color.instrumentInk.opacity(0.48), lineWidth: 0.8))
                    .overlay(alignment: .top) {
                        Circle().fill(tint).frame(width: 3, height: 3).padding(.top, 4)
                    }
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .offset(y: configuration.isPressed ? 0.5 : 0)
            .animation(.easeOut(duration: 0.05), value: configuration.isPressed)
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

struct HorizontalFader: View {
    @Binding var value: Float
    var range: ClosedRange<Float> = -60...6
    var tint: Color

    var body: some View {
        GeometryReader { proxy in
            let fraction = normalized(value)
            let travel = max(1, proxy.size.width - 16)
            let knobX = fraction * travel + 8
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.instrumentInk.opacity(0.58))
                    .frame(height: 2)
                    .overlay(alignment: .leading) {
                        Capsule().fill(tint).frame(width: max(1, travel * fraction), height: 1.5)
                    }
                    .padding(.horizontal, 4)

                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(Color.instrumentRaised)
                    .overlay(RoundedRectangle(cornerRadius: 1).stroke(Color.instrumentInk.opacity(0.46), lineWidth: 0.7))
                    .overlay(Rectangle().fill(tint).frame(width: 1.5, height: 14))
                    .frame(width: 16, height: 22)
                    .position(x: knobX, y: proxy.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { gesture in
                    let x = max(8, min(proxy.size.width - 8, gesture.location.x))
                    let newFraction = (x - 8) / max(1, proxy.size.width - 16)
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
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index == 2 ? accent : Color.instrumentInk.opacity(0.2))
                        .frame(width: 1, height: index == 2 ? 3 : 2)
                        .offset(y: -size * 0.48)
                        .rotationEffect(.degrees(-135 + Double(index) * 67.5))
                }
                Circle()
                    .fill(Color.instrumentInk)
                    .frame(width: size * 0.72, height: size * 0.72)
                Capsule()
                    .fill(accent)
                    .frame(width: 1.5, height: size * 0.22)
                    .offset(y: -size * 0.16)
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
        VStack(spacing: 3) {
            GeometryReader { proxy in
                let modes = WorkspaceMode.allCases
                let slot = proxy.size.width / CGFloat(modes.count)
                let selectedIndex = modes.firstIndex(of: selection) ?? 0
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.instrumentInk.opacity(0.14))
                        .overlay(Capsule().stroke(Color.instrumentInk.opacity(0.26), lineWidth: 1))
                        .frame(height: 8)
                        .padding(.horizontal, slot * 0.24)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.instrumentInk)
                        .overlay(alignment: .top) {
                            Capsule().fill(selection.accent).frame(width: 8, height: 2).padding(.top, 3)
                        }
                        .frame(width: slot * 0.62, height: 18)
                        .offset(x: CGFloat(selectedIndex) * slot + slot * 0.19)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { gesture in
                        let index = max(0, min(modes.count - 1, Int(gesture.location.x / max(1, slot))))
                        selection = modes[index]
                    }
                )
            }
            .frame(height: 20)

            HStack(spacing: 0) {
                ForEach(WorkspaceMode.allCases) { mode in
                    Text(mode.shortName.lowercased())
                        .font(.instrument(6, weight: selection == mode ? .semibold : .regular))
                        .foregroundStyle(selection == mode ? Color.instrumentInk : Color.instrumentTextSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(width: 92, height: 31)
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

struct PanelScrews: View {
    var body: some View {
        GeometryReader { proxy in
            ForEach(0..<4, id: \.self) { index in
                Circle()
                    .fill(Color.instrumentInk.opacity(0.24))
                    .frame(width: 5, height: 5)
                    .position(
                        x: index % 2 == 0 ? 9 : proxy.size.width - 9,
                        y: index < 2 ? 9 : proxy.size.height - 9
                    )
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
        .instrumentOrange
    }
}

extension WorkspaceMode {
    var accent: Color {
        .instrumentOrange
    }
}
