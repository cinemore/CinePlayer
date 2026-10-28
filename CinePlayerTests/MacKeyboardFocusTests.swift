#if os(macOS)
import AppKit
import Combine
import SwiftUI
import Testing
@testable import CinePlayer

extension PlayerStateTests {
    @Test func macKeyboardRespectsWindowModifiersAndNativeEditors() throws {
        let window = keyboardWindow()
        let other = keyboardWindow()
        let view = InteractionView()
        let focus = MacPlayerKeyboardFocus()
        view.keyboardFocus = focus
        var handled: [UInt16] = []
        view.onKeyDown = { handled.append($0.keyCode); return [49, 123, 124, 125, 126, 53].contains($0.keyCode) }
        window.contentView?.addSubview(view)
        defer { view.stopMonitoring(); window.close(); other.close() }
        let foreign = try keyboardEvent(126, window: other)
        #expect(view.handleKeyDown(foreign) === foreign)
        for modifiers: NSEvent.ModifierFlags in [.command, .option, .control, .shift, [.command, .shift]] {
            for code: UInt16 in [49, 123, 124, 125, 126, 53] {
                let event = try keyboardEvent(code, window: window, modifiers: modifiers)
                #expect(view.handleKeyDown(event) === event)
            }
        }
        #expect(handled.isEmpty)
        for code: UInt16 in [49, 123, 124, 125, 126] {
            #expect(view.handleKeyDown(try keyboardEvent(code, window: window, modifiers: [.function, .numericPad])) == nil)
        }
        #expect(handled == [49, 123, 124, 125, 126])
        handled.removeAll()
        focus.isFormFocused = true
        for code: UInt16 in [49, 123, 124, 125, 126] {
            let event = try keyboardEvent(code, window: window)
            #expect(view.handleKeyDown(event) === event)
        }
        #expect(handled.isEmpty)
        #expect(view.handleKeyDown(try keyboardEvent(53, window: window)) == nil)
        #expect(handled == [53])

        focus.isFormFocused = false
        let field = NSTextField(string: "123.45")
        window.contentView?.addSubview(field)
        window.makeKeyAndOrderFront(nil)
        field.selectText(nil)
        try #require(window.firstResponder is NSTextView)
        handled.removeAll()
        let arrow = try keyboardEvent(126, window: window)
        #expect(view.handleKeyDown(arrow) === arrow)
        #expect(handled.isEmpty)
    }

    @Test func macSwiftUIFormFocusAndHiddenPanelRouteKeysCorrectly() async throws {
        let state = KeyboardFocusProbeState()
        let focus = MacPlayerKeyboardFocus()
        let host = NSHostingView(rootView: KeyboardFocusProbe(state: state)
            .modifier(MacPlayerKeyboardFocusObserver(focus: focus)))
        let window = keyboardWindow()
        let container = NSView(frame: window.contentLayoutRect)
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        window.contentView = container
        let view = InteractionView()
        view.keyboardFocus = focus
        var handled: [UInt16] = []
        view.onKeyDown = { handled.append($0.keyCode); return true }
        container.addSubview(view)
        window.makeKeyAndOrderFront(nil)
        defer { view.stopMonitoring(); window.close() }
        for target in KeyboardFocusTarget.allCases {
            state.requested = target
            try await waitForKeyboardFocus { state.actual == target && focus.isFormFocused }
            for code: UInt16 in [49, 123, 124, 125, 126] {
                let event = try keyboardEvent(code, window: window)
                #expect(view.handleKeyDown(event) === event)
            }
            #expect(handled.isEmpty)
        }
        state.isPresented = false
        try await waitForKeyboardFocus {
            !focus.isFormFocused && !(window.firstResponder is NSControl) && !(window.firstResponder is NSTextView)
        }
        #expect(view.handleKeyDown(try keyboardEvent(126, window: window)) == nil)
        #expect(handled == [126])
    }

    private func keyboardWindow() -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 480, height: 500),
                              styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        return window
    }

    private func keyboardEvent(_ code: UInt16, window: NSWindow, modifiers: NSEvent.ModifierFlags = []) throws -> NSEvent {
        let text = switch code {
        case 49: " "
        case 123: String(UnicodeScalar(NSLeftArrowFunctionKey)!)
        case 124: String(UnicodeScalar(NSRightArrowFunctionKey)!)
        case 125: String(UnicodeScalar(NSDownArrowFunctionKey)!)
        case 126: String(UnicodeScalar(NSUpArrowFunctionKey)!)
        default: ""
        }
        return try #require(NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers,
            timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
            context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: false, keyCode: code))
    }

    private func waitForKeyboardFocus(_ predicate: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(5))
        while !predicate(), ContinuousClock.now < deadline { try await Task.sleep(for: .milliseconds(25)) }
        try #require(predicate())
    }
}

private enum KeyboardFocusTarget: CaseIterable, Hashable { case slider, toggle, stepper, picker, text }

@MainActor
private final class KeyboardFocusProbeState: ObservableObject {
    @Published var requested: KeyboardFocusTarget?
    var actual: KeyboardFocusTarget?
    @Published var isPresented = true
    @Published var slider = 0.5
    @Published var toggle = false
    @Published var stepper = 16
    @Published var picker = 1
    @Published var text = "123.45"
}

private struct KeyboardFocusProbe: View {
    @ObservedObject var state: KeyboardFocusProbeState
    @FocusState private var focused: KeyboardFocusTarget?
    var body: some View {
        VStack {
            Text("播放区域")
            Form {
                Slider(value: $state.slider) { Text("亮度") }.focused($focused, equals: .slider)
                Toggle("增强", isOn: $state.toggle).focused($focused, equals: .toggle)
                Stepper("字号", value: $state.stepper).focused($focused, equals: .stepper)
                Picker("对齐", selection: $state.picker) {
                    Text("左").tag(0); Text("中").tag(1); Text("右").tag(2)
                }.focused($focused, equals: .picker)
                TextField("偏移", text: $state.text).focused($focused, equals: .text)
            }
            .formStyle(.grouped)
            .modifier(MacPlayerFormKeyboardScope(isPresented: state.isPresented))
            .offset(x: state.isPresented ? 0 : 600)
        }
        .onChange(of: state.requested, initial: true) { _, target in focused = target }
        .onChange(of: focused) { _, target in state.actual = target }
    }
}
#endif
