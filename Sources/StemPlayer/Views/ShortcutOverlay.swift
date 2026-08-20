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
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KEY MAP").font(.system(size: 11, weight: .semibold, design: .monospaced))
                        Text("DIRECT PERFORMANCE CONTROL")
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.instrumentTextSecondary)
                    }
                    Spacer()
                    Button("Close") { app.showShortcutOverlay = false }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
                Rectangle().fill(Color.instrumentLine).frame(height: 1)

                HStack(alignment: .top, spacing: 18) {
                    VStack(spacing: 3) {
                        ForEach(commands, id: \.0) { command in
                            HStack(spacing: 7) {
                                KeyCap(text: command.0, wide: true)
                                Text(command.1)
                                    .font(.system(size: 7, weight: .medium))
                                Spacer()
                            }
                        }
                    }
                    .frame(width: 320)

                    VStack(alignment: .leading, spacing: 7) {
                        Text("PAD MAP").font(.system(size: 7, weight: .semibold, design: .monospaced))
                        VStack(spacing: 4) {
                            HStack(spacing: 4) { ForEach(["1", "2", "3", "4"], id: \.self) { KeyCap(text: $0) } }
                            HStack(spacing: 4) { ForEach(["Q", "W", "E", "R"], id: \.self) { KeyCap(text: $0) } }
                            HStack(spacing: 4) { ForEach(["A", "S", "D", "F"], id: \.self) { KeyCap(text: $0) } }
                        }
                        HStack(spacing: 4) {
                            ForEach(0..<4, id: \.self) { index in
                                Rectangle().fill(Color.padColor(index)).frame(width: 23, height: 4)
                            }
                        }
                        Text("KEYS, CLICKS, AND RAW MULTI-TOUCH SHARE ONE 4 × 3 FIELD.")
                            .font(.system(size: 6.5, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.instrumentTextSecondary)
                            .lineSpacing(2)
                            .frame(width: 165, alignment: .leading)
                    }
                }
            }
            .padding(16)
            .frame(width: 570, height: 300)
            .background(Color.instrumentSurface)
            .overlay(Rectangle().stroke(Color.instrumentLine))
            .shadow(color: .black.opacity(0.3), radius: 0, y: 6)
        }
    }
}
