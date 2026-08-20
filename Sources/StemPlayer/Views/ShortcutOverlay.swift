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
            VStack(alignment: .leading, spacing: 7) {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("KEY MAP").font(.system(size: 10, weight: .semibold, design: .monospaced))
                        Text("DIRECT CONTROL")
                            .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.instrumentTextSecondary)
                    }
                    Spacer()
                    Button("Close") { app.showShortcutOverlay = false }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
                Rectangle().fill(Color.instrumentLine).frame(height: 1)

                VStack(spacing: 3) {
                    ForEach(commands, id: \.0) { command in
                        HStack(spacing: 6) {
                            KeyCap(text: command.0, wide: true)
                            Text(command.1)
                                .font(.system(size: 6.5, weight: .medium))
                            Spacer()
                        }
                    }
                }

                Rectangle().fill(Color.instrumentLine).frame(height: 1)
                Text("PAD MAP").font(.system(size: 6.5, weight: .semibold, design: .monospaced))
                HStack(spacing: 4) {
                    VStack(spacing: 3) {
                        HStack(spacing: 3) { ForEach(["1", "2", "3", "4"], id: \.self) { KeyCap(text: $0) } }
                        HStack(spacing: 3) { ForEach(["Q", "W", "E", "R"], id: \.self) { KeyCap(text: $0) } }
                        HStack(spacing: 3) { ForEach(["A", "S", "D", "F"], id: \.self) { KeyCap(text: $0) } }
                    }
                    Spacer()
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 3) {
                            ForEach(0..<4, id: \.self) { index in
                                Rectangle().fill(Color.padColor(index)).frame(width: 16, height: 3)
                            }
                        }
                        Text("KEYS / POINTER / RAW MULTI-TOUCH")
                            .font(.system(size: 5.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.instrumentTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 112, alignment: .leading)
                }
            }
            .padding(12)
            .frame(width: 292, height: 452)
            .background(Color.instrumentSurface)
            .overlay(Rectangle().stroke(Color.instrumentLine))
            .shadow(color: .black.opacity(0.3), radius: 0, y: 5)
        }
    }
}
