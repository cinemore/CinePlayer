import SwiftUI
#if os(macOS)
import AppKit
import Combine

private struct MacPlayerFormFocusKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var macPlayerFormFocused: Bool? {
        get { self[MacPlayerFormFocusKey.self] }
        set { self[MacPlayerFormFocusKey.self] = newValue }
    }
}

@MainActor
final class MacPlayerKeyboardFocus: ObservableObject {
    var isFormFocused = false
}

/// SwiftUI 控件的焦点代理不一定是 NSControl，由焦点树标记表单归属。
struct MacPlayerKeyboardFocusObserver: ViewModifier {
    @FocusedValue(\.macPlayerFormFocused) private var formFocused
    let focus: MacPlayerKeyboardFocus

    func body(content: Content) -> some View {
        content.onChange(of: formFocused, initial: true) { _, value in
            focus.isFormFocused = value == true
        }
    }
}

struct MacPlayerFormKeyboardScope: ViewModifier {
    let isPresented: Bool

    func body(content: Content) -> some View {
        content
            .focusedValue(\.macPlayerFormFocused, isPresented ? true : nil)
            .disabled(!isPresented)
            .accessibilityHidden(!isPresented)
    }
}

struct MacInteractionLayer: NSViewRepresentable {
    let onMouseMoved: () -> Void
    let onKeyDown: (NSEvent) -> Bool
    let keyboardFocus: MacPlayerKeyboardFocus
    var onWindowAttached: (NSWindow) -> Void = { _ in }

    func makeNSView(context: Context) -> InteractionView {
        let view = InteractionView()
        updateNSView(view, context: context)
        return view
    }
    func updateNSView(_ view: InteractionView, context: Context) {
        view.onMouseMoved = onMouseMoved
        view.onKeyDown = onKeyDown
        view.keyboardFocus = keyboardFocus
        view.onWindowAttached = onWindowAttached
    }
    static func dismantleNSView(_ view: InteractionView, coordinator: ()) { view.stopMonitoring() }
}

final class InteractionView: NSView {
    var onMouseMoved: () -> Void = {}
    var onKeyDown: (NSEvent) -> Bool = { _ in false }
    var onWindowAttached: (NSWindow) -> Void = { _ in }
    weak var keyboardFocus: MacPlayerKeyboardFocus?
    private var keyboardMonitor: Any?
    private var trackingAreaRef: NSTrackingArea?

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingAreaRef { removeTrackingArea(trackingAreaRef) }
        let area = NSTrackingArea(rect: bounds, options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved], owner: self)
        addTrackingArea(area)
        trackingAreaRef = area
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        stopMonitoring()
        guard let window else { return }
        window.acceptsMouseMovedEvents = true
        onWindowAttached(window)
        keyboardMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handleKeyDown(event)
        }
    }

    func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let window, event.window === window,
              event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty else { return event }
        // 全屏 Esc 保留窗口语义，其他按键优先交给已聚焦的控件。
        if event.keyCode == 53 { return onKeyDown(event) ? nil : event }
        guard keyboardFocus?.isFormFocused != true,
              !(window.firstResponder is NSControl),
              !(window.firstResponder is NSTextView) else { return event }
        return onKeyDown(event) ? nil : event
    }

    func stopMonitoring() {
        if let keyboardMonitor { NSEvent.removeMonitor(keyboardMonitor) }
        keyboardMonitor = nil
    }
    override func mouseMoved(with event: NSEvent) { onMouseMoved() }
}
#endif
