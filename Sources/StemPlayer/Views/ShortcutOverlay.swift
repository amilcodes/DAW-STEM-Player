import SwiftUI

struct ShortcutOverlay: View {
    @EnvironmentObject private var app: AppState

    private let commands: [(String, String)] = [
        ("⌘1 / ⌘2 / ⌘3", "stem / drum / sequence"),
        ("Space or K", "play / pause"),
        ("J / L", "back / forward five seconds"),
        ("I / O", "set loop in / out"),
        ("1 — 4", "select a stem"),
        ("M / S", "mute / solo selected stem"),
        ("↑ / ↓", "selected stem level"),
        ("T", "arm the trackpad"),
        ("B", "system-audio beat sync"),
        ("Escape", "leave trackpad mode"),
        ("⌘R", "record pad hits"),
        ("⌘E", "export mix")
    ]

    var body: some View {
        ZStack {
            Color.instrumentSurface.opacity(0.97).ignoresSafeArea()
                .onTapGesture { app.showShortcutOverlay = false }
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    HStack(spacing: 5) {
                        HardwareLED(color: .instrumentOrange, isOn: true, size: 3)
                        Text("keys").font(.instrument(10, weight: .medium))
                    }
                    Spacer()
                    Button("close") { app.showShortcutOverlay = false }
                        .buttonStyle(HardwareKeyStyle(width: 38, height: 24, accent: .instrumentOrange, isPrimary: true))
                }
                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.7)

                VStack(spacing: 3) {
                    ForEach(commands, id: \.0) { command in
                        HStack(spacing: 6) {
                            KeyCap(text: command.0, wide: true)
                            Text(command.1)
                                .font(.instrument(6.5, weight: .regular))
                                .foregroundStyle(Color.white.opacity(0.58))
                            Spacer()
                        }
                    }
                }

                Rectangle().fill(Color.white.opacity(0.12)).frame(height: 0.7)
                HStack(spacing: 4) {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) { ForEach(["1", "2", "3", "4"], id: \.self) { KeyCap(text: $0) } }
                        HStack(spacing: 3) { ForEach(["Q", "W", "E", "R"], id: \.self) { KeyCap(text: $0) } }
                        HStack(spacing: 3) { ForEach(["A", "S", "D", "F"], id: \.self) { KeyCap(text: $0) } }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        Rectangle().fill(Color.instrumentOrange).frame(width: 14, height: 2)
                        Text("keyboard · pointer · touch")
                            .font(.instrument(5.5, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.42))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 112, alignment: .leading)
                }
            }
            .padding(12)
            .frame(width: 292, height: 452)
            .foregroundStyle(Color.instrumentRaised)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.instrumentDisplay))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.instrumentInk.opacity(0.6), lineWidth: 0.7))
        }
    }
}
