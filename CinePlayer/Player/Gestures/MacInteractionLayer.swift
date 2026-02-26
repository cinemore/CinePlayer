import SwiftUI

#if os(macOS)
import AppKit

struct MacInteractionLayer: NSViewRepresentable {
    let onMouseMoved: () -> Void
    let onKeyDown: (NSEvent) -> Void

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        view.onMouseMoved = onMouseMoved
        view.onKeyDown = onKeyDown
        return view
    }

    func updateNSView(_ nsView: InteractionView, context: Context) {
        nsView.onMouseMoved = onMouseMoved
        nsView.onKeyDown = onKeyDown
        nsView.window?.makeFirstResponder(nsView)
    }
}

final class InteractionView: NSView {
    var onMouseMoved: () -> Void = {}
    var onKeyDown: (NSEvent) -> Void = { _ in }
    private var trackingAreaRef: NSTrackingArea?

    override var acceptsFirstResponder: Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef {
            removeTrackingArea(trackingAreaRef)
        }
        let newArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(newArea)
        trackingAreaRef = newArea
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
        window?.makeFirstResponder(self)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        onMouseMoved()
    }

    override func keyDown(with event: NSEvent) {
        onKeyDown(event)
    }
}
#endif
