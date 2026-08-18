import SwiftUI

struct ShortcutOverlay: View {
    @EnvironmentObject private var app: AppState

    private let commands: [(String, String)] = [
        ("SPACE / K", "PLAY OR PAUSE"), ("J / L", "BACK OR FORWARD 5 SEC"), ("I / O", "SET LOOP IN OR OUT"),
        ("1 — 4", "SELECT STEM"), ("M / S", "MUTE OR SOLO SELECTED"), ("↑ / ↓", "LEVEL ±1 DB"),
        ("T", "ARM TRACKPAD"), ("ESC", "EXIT TRACKPAD MODE"), ("⌘ R", "RECORD PATTERN HITS"), ("⌘ E", "EXPORT MIX")
    ]

    var body: some View {
        ZStack {
            Color.instrumentInk.opacity(0.68).ignoresSafeArea().onTapGesture { app.showShortcutOverlay = false }
            ZStack {
                Color.instrumentSurface
                PanelScrews()
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("CONTROL REFERENCE").font(.system(size: 16, weight: .black, design: .monospaced))
                            Text("EVERY PERFORMANCE CONTROL HAS A PHYSICAL KEY").instrumentLabel()
                        }
                        Spacer()
                        Button("CLOSE ×") { app.showShortcutOverlay = false }.buttonStyle(InstrumentButtonStyle(compact: true))
                    }
                    Rectangle().fill(Color.instrumentInk.opacity(0.45)).frame(height: 1)
                    HStack(alignment: .top, spacing: 30) {
                        VStack(spacing: 7) {
                            ForEach(commands, id: \.0) { command in
                                HStack { KeyCap(text: command.0, wide: true); Text(command.1).font(.system(size: 8, weight: .bold, design: .monospaced)); Spacer() }
                            }
                        }
                        .frame(width: 330)
                        VStack(alignment: .leading, spacing: 12) {
                            Text("PAD / PHYSICAL POSITION").instrumentLabel()
                            VStack(spacing: 7) {
                                HStack(spacing: 7) { ForEach(["1", "2", "3", "4"], id: \.self) { KeyCap(text: $0) } }
                                HStack(spacing: 7) { ForEach(["Q", "W", "E", "R"], id: \.self) { KeyCap(text: $0) } }
                                HStack(spacing: 7) { ForEach(["A", "S", "D", "F"], id: \.self) { KeyCap(text: $0) } }
                            }
                            HStack(spacing: 5) { ForEach(0..<4, id: \.self) { index in Rectangle().fill(Color.padColor(index)).frame(width: 25, height: 5) } }
                            Text("THE SAME 4 × 3 GEOMETRY IS USED BY CLICK, KEYBOARD AND TRACKPAD MULTI-TOUCH.")
                                .font(.system(size: 8, weight: .bold, design: .monospaced)).foregroundStyle(Color.instrumentTextSecondary).lineSpacing(3).frame(width: 175, alignment: .leading)
                        }
                    }
                }
                .padding(28)
            }
            .frame(width: 610, height: 430)
            .overlay(Rectangle().stroke(Color.instrumentInk.opacity(0.82), lineWidth: 1))
            .shadow(color: .black.opacity(0.38), radius: 0, y: 8)
        }
    }
}
