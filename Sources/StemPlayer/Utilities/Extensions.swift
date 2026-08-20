import AppKit
import SwiftUI

extension Float {
    var decibelString: String {
        if self <= -59.5 { return "−∞" }
        let value = abs(self) < 0.05 ? 0 : self
        return String(format: value >= 0 ? "+%.1f" : "%.1f", value)
    }
}

extension Double {
    var transportString: String {
        guard isFinite && self >= 0 else { return "00:00.000" }
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        let milliseconds = Int((self - floor(self)) * 1000)
        return String(format: "%02d:%02d.%03d", minutes, seconds, milliseconds)
    }
}

extension Color {
    // Neutral hardware with one action color and one restrained run-state color.
    static let instrumentBackground = Color(red: 0.76, green: 0.76, blue: 0.73)
    static let instrumentSurface = Color(red: 0.91, green: 0.90, blue: 0.87)
    static let instrumentRaised = Color(red: 0.975, green: 0.97, blue: 0.945)
    static let instrumentPlate = Color(red: 0.865, green: 0.855, blue: 0.82)
    static let instrumentInk = Color(red: 0.075, green: 0.078, blue: 0.075)
    static let instrumentDisplay = Color(red: 0.055, green: 0.058, blue: 0.055)
    static let instrumentTextSecondary = Color.instrumentInk.opacity(0.48)
    static let instrumentLine = Color.instrumentInk.opacity(0.16)
    static let instrumentOrange = Color(red: 0.92, green: 0.255, blue: 0.13)
    static let instrumentYellow = Color.instrumentOrange
    static let instrumentGreen = Color(red: 0.23, green: 0.48, blue: 0.37)
    static let instrumentBlue = Color(red: 0.31, green: 0.35, blue: 0.35)
}

extension Font {
    static func instrument(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom("Helvetica Neue", fixedSize: size).weight(weight)
    }

    static func instrumentNumber(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}

extension URL {
    var deletingPathExtensionSafe: String {
        deletingPathExtension().lastPathComponent
    }
}

extension View {
    func instrumentPanel(cornerRadius: CGFloat = 1) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: min(cornerRadius, 2), style: .continuous)
                    .fill(Color.instrumentSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: min(cornerRadius, 2), style: .continuous)
                            .stroke(Color.instrumentLine, lineWidth: 0.7)
                    )
            )
    }

    func instrumentLabel() -> some View {
        self.font(.instrument(8, weight: .medium))
            .foregroundStyle(Color.instrumentTextSecondary)
    }
}
