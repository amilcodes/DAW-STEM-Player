import AppKit
import SwiftUI

@main
struct StemPlayerApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .environmentObject(appState.audio)
                .preferredColorScheme(.light)
                .frame(minWidth: 1_080, minHeight: 700)
                .onAppear {
                    appState.activate()
                    NSApp.appearance = NSAppearance(named: .aqua)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1_320, height: 840)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Session") { appState.newSession() }
                    .keyboardShortcut("n", modifiers: .command)
                Button("Open Project…") { appState.presentProjectImporter() }
                    .keyboardShortcut("o", modifiers: [.command, .shift])
                Button("Import Audio…") { appState.presentAudioImporter() }
                    .keyboardShortcut("o", modifiers: .command)
                Divider()
                Button("Save Project As…") { appState.saveProjectAs() }
                    .keyboardShortcut("s", modifiers: [.command, .shift])
                Button("Export Mix…") { appState.exportMix() }
                    .keyboardShortcut("e", modifiers: .command)
            }
            CommandMenu("Transport") {
                Button(appState.audio.isPlaying ? "Pause" : "Play") { appState.audio.togglePlayback() }
                    .keyboardShortcut(.space, modifiers: [])
                Button("Return to Start") { appState.audio.seek(to: 0) }
                Divider()
                Button(appState.project.loop.isEnabled ? "Disable Loop" : "Enable Loop") { appState.toggleLoop() }
                    .keyboardShortcut("l", modifiers: .command)
                Button("Set Loop In") { appState.setLoopIn() }
                    .keyboardShortcut("i", modifiers: [])
                Button("Set Loop Out") { appState.setLoopOut() }
                    .keyboardShortcut("o", modifiers: [])
            }
            CommandMenu("Performance") {
                Button(appState.isTrackpadArmed ? "Disarm Trackpad" : "Arm Trackpad") {
                    appState.mode = .pads
                    appState.armTrackpad(!appState.isTrackpadArmed)
                }
                .keyboardShortcut("t", modifiers: [])
                Button(appState.isPatternRecording ? "Stop Recording" : "Record Pattern") {
                    appState.isPatternRecording.toggle()
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("Keyboard Map") { appState.showShortcutOverlay = true }
                    .keyboardShortcut("/", modifiers: [.command])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(appState)
                .frame(width: 480, height: 330)
        }
    }
}
