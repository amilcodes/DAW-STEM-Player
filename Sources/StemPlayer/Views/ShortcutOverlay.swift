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
        ("Escape", "leave trackpad mode"),
        ("⌘R", "record pad hits"),
        ("⌘E", "export mix")
    ]

    var body: some View {
        ZStack {
            Color.instrumentInk.opacity(0.58).ignoresSafeArea()
                .onTapGesture { app.showShortcutOverlay = false }
            VStack(alignment: .leading, spacing: 15) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Keyboard map").font(.system(size: 17, weight: .semibold))
                        Text("Every performance control stays reachable without the pointer")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color.instrumentTextSecondary)
                    }
                    Spacer()
                    Button("Close") { app.showShortcutOverlay = false }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
                Rectangle().fill(Color.instrumentLine).frame(height: 1)

                HStack(alignment: .top, spacing: 30) {
                    VStack(spacing: 7) {
                        ForEach(commands, id: \.0) { command in
                            HStack(spacing: 10) {
                                KeyCap(text: command.0, wide: true)
                                Text(command.1)
                                    .font(.system(size: 9, weight: .medium))
                                Spacer()
                            }
                        }
                    }
                    .frame(width: 345)

                    VStack(alignment: .leading, spacing: 11) {
                        Text("Pad layout").font(.system(size: 10, weight: .semibold))
                        VStack(spacing: 7) {
                            HStack(spacing: 7) { ForEach(["1", "2", "3", "4"], id: \.self) { KeyCap(text: $0) } }
                            HStack(spacing: 7) { ForEach(["Q", "W", "E", "R"], id: \.self) { KeyCap(text: $0) } }
                            HStack(spacing: 7) { ForEach(["A", "S", "D", "F"], id: \.self) { KeyCap(text: $0) } }
                        }
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { index in
                                Rectangle().fill(Color.padColor(index)).frame(width: 23, height: 4)
                            }
                        }
                        Text("Click, keyboard, and raw trackpad multi-touch all use the same 4 × 3 physical map.")
                            .font(.system(size: 9, weight: .regular))
                            .foregroundStyle(Color.instrumentTextSecondary)
                            .lineSpacing(2)
                            .frame(width: 180, alignment: .leading)
                    }
                }
            }
            .padding(24)
            .frame(width: 610, height: 410)
            .background(Color.instrumentSurface)
            .overlay(Rectangle().stroke(Color.instrumentLine))
            .shadow(color: .black.opacity(0.3), radius: 0, y: 6)
        }
    }
}
