import AppKit
import Foundation

@MainActor
final class KeyboardMonitor {
    enum Action {
        case togglePlayback
        case returnToStart
        case skip(Double)
        case toggleLoop
        case setLoopIn
        case setLoopOut
        case toggleTrackpad
        case toggleTempoSync
        case escape
        case selectStem(Int)
        case adjustStem(Float)
        case toggleMute
        case toggleSolo
        case triggerPad(Int, Bool)
    }

    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    var mode: WorkspaceMode = .mix
    var handler: ((Action) -> Void)?

    func start() {
        guard keyDownMonitor == nil else { return }
        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, !self.isEditingText else { return event }
            return self.handle(event: event, isDown: true) ? nil : event
        }
        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            guard let self, !self.isEditingText else { return event }
            return self.handle(event: event, isDown: false) ? nil : event
        }
    }

    func stop() {
        if let keyDownMonitor { NSEvent.removeMonitor(keyDownMonitor) }
        if let keyUpMonitor { NSEvent.removeMonitor(keyUpMonitor) }
        keyDownMonitor = nil
        keyUpMonitor = nil
    }

    private var isEditingText: Bool {
        guard let responder = NSApp.keyWindow?.firstResponder else { return false }
        return responder is NSTextView || responder is NSTextField
    }

    private func handle(event: NSEvent, isDown: Bool) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if modifiers.contains(.command) { return false }

        let padCodes: [UInt16: Int] = [
            18: 0, 19: 1, 20: 2, 21: 3,
            12: 4, 13: 5, 14: 6, 15: 7,
            0: 8, 1: 9, 2: 10, 3: 11
        ]

        if mode == .pads || mode == .pattern, let index = padCodes[event.keyCode] {
            handler?(.triggerPad(index, isDown))
            return true
        }

        guard isDown, !event.isARepeat else { return false }
        switch event.keyCode {
        case 49, 40: handler?(.togglePlayback); return true // Space, K
        case 36: handler?(.returnToStart); return true
        case 38: handler?(.skip(modifiers.contains(.shift) ? -1 : -5)); return true
        case 37: handler?(.skip(modifiers.contains(.shift) ? 1 : 5)); return true
        case 34: handler?(.setLoopIn); return true
        case 31: handler?(.setLoopOut); return true
        case 17: handler?(.toggleTrackpad); return true
        case 11: handler?(.toggleTempoSync); return true
        case 53: handler?(.escape); return true
        case 46: handler?(.toggleMute); return true
        case 1: handler?(.toggleSolo); return true
        case 126: handler?(.adjustStem(modifiers.contains(.shift) ? 0.1 : 1)); return true
        case 125: handler?(.adjustStem(modifiers.contains(.shift) ? -0.1 : -1)); return true
        case 18, 19, 20, 21:
            handler?(.selectStem(Int(event.keyCode - 18)))
            return true
        default: return false
        }
    }
}
