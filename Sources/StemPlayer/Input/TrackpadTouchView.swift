import AppKit
import SwiftUI

struct TrackpadTouchView: NSViewRepresentable {
    var onBegan: (TrackpadTouch) -> Void
    var onMoved: (TrackpadTouch) -> Void
    var onEnded: (Int) -> Void

    func makeNSView(context: Context) -> TouchCaptureNSView {
        let view = TouchCaptureNSView()
        view.onBegan = onBegan
        view.onMoved = onMoved
        view.onEnded = onEnded
        return view
    }

    func updateNSView(_ nsView: TouchCaptureNSView, context: Context) {
        nsView.onBegan = onBegan
        nsView.onMoved = onMoved
        nsView.onEnded = onEnded
    }
}

final class TouchCaptureNSView: NSView {
    var onBegan: ((TrackpadTouch) -> Void)?
    var onMoved: ((TrackpadTouch) -> Void)?
    var onEnded: ((Int) -> Void)?
    private var knownTouches: Set<Int> = []

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        allowedTouchTypes = [.indirect]
        wantsRestingTouches = true
    }

    override var acceptsFirstResponder: Bool { true }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func touchesBegan(with event: NSEvent) {
        super.touchesBegan(with: event)
        for touch in event.touches(matching: .began, in: self) where !touch.isResting {
            let item = mapped(touch)
            knownTouches.insert(item.id)
            onBegan?(item)
        }
    }

    override func touchesMoved(with event: NSEvent) {
        super.touchesMoved(with: event)
        for touch in event.touches(matching: .moved, in: self) {
            let item = mapped(touch)
            if knownTouches.contains(item.id) { onMoved?(item) }
        }
    }

    override func touchesEnded(with event: NSEvent) {
        super.touchesEnded(with: event)
        endTouches(event.touches(matching: .ended, in: self))
    }

    override func touchesCancelled(with event: NSEvent) {
        super.touchesCancelled(with: event)
        let cancelled = event.touches(matching: .cancelled, in: self)
        if cancelled.isEmpty {
            let ids = knownTouches
            knownTouches.removeAll()
            ids.forEach { onEnded?($0) }
        } else {
            endTouches(cancelled)
        }
    }

    private func endTouches(_ touches: Set<NSTouch>) {
        for touch in touches {
            let id = touch.identity.hash
            knownTouches.remove(id)
            onEnded?(id)
        }
    }

    private func mapped(_ touch: NSTouch) -> TrackpadTouch {
        let x = max(0, min(0.999_999, touch.normalizedPosition.x))
        let y = max(0, min(0.999_999, touch.normalizedPosition.y))
        let column = max(0, min(3, Int(x * 4)))
        let row = max(0, min(2, 2 - Int(y * 3)))
        return TrackpadTouch(
            id: touch.identity.hash,
            normalizedX: x,
            normalizedY: y,
            padIndex: row * 4 + column
        )
    }
}
