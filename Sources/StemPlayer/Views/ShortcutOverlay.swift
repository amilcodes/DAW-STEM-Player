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
                    Text("keys").font(.instrument(10, weight: .medium))
                    Spacer()
                    Button("close") { app.showShortcutOverlay = false }
                        .buttonStyle(InstrumentButtonStyle(compact: true))
                }
                Rectangle().fill(Color.instrumentLine).frame(height: 1)

                VStack(spacing: 3) {
                    ForEach(commands, id: \.0) { command in
                        HStack(spacing: 6) {
                            KeyCap(text: command.0, wide: true)
                            Text(command.1)
                                .font(.instrument(6.5, weight: .regular))
                            Spacer()
                        }
                    }
                }

                Rectangle().fill(Color.instrumentLine).frame(height: 1)
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
                            .foregroundStyle(Color.instrumentTextSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 112, alignment: .leading)
                }
            }
            .padding(12)
            .frame(width: 292, height: 452)
            .background(Color.instrumentSurface)
            .overlay(Rectangle().stroke(Color.instrumentLine, lineWidth: 0.7))
        }
    }
}
