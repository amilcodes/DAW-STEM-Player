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
    // A deliberately small, industrial palette. Color communicates function only.
    static let instrumentBackground = Color(red: 0.70, green: 0.69, blue: 0.64)
    static let instrumentSurface = Color(red: 0.83, green: 0.81, blue: 0.74)
    static let instrumentRaised = Color(red: 0.91, green: 0.89, blue: 0.81)
    static let instrumentPlate = Color(red: 0.76, green: 0.75, blue: 0.69)
    static let instrumentInk = Color(red: 0.105, green: 0.108, blue: 0.102)
    static let instrumentDisplay = Color(red: 0.075, green: 0.081, blue: 0.076)
    static let instrumentTextSecondary = Color.instrumentInk.opacity(0.58)
    static let instrumentLine = Color.instrumentInk.opacity(0.28)
    static let instrumentOrange = Color(red: 0.94, green: 0.31, blue: 0.12)
    static let instrumentYellow = Color(red: 0.97, green: 0.74, blue: 0.12)
    static let instrumentGreen = Color(red: 0.29, green: 0.63, blue: 0.35)
    static let instrumentBlue = Color(red: 0.16, green: 0.43, blue: 0.74)
}

extension URL {
    var deletingPathExtensionSafe: String {
        deletingPathExtension().lastPathComponent
    }
}

extension View {
    func instrumentPanel(cornerRadius: CGFloat = 3) -> some View {
        self
            .background(
                RoundedRectangle(cornerRadius: min(cornerRadius, 5), style: .continuous)
                    .fill(Color.instrumentSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: min(cornerRadius, 5), style: .continuous)
                            .stroke(Color.instrumentInk.opacity(0.34), lineWidth: 1)
                    )
                    .shadow(color: Color.instrumentInk.opacity(0.18), radius: 0, y: 3)
            )
    }

    func instrumentLabel() -> some View {
        self.font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.7)
            .foregroundStyle(Color.instrumentTextSecondary)
    }
}
