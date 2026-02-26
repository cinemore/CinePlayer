#if os(macOS)

import AppKit
import Combine
import SwiftUI

@MainActor
final class PlayerWindowController: ObservableObject {
    @Published var isFloating: Bool = false

    func toggleWindowLevel() {
        guard let window = NSApplication.shared.keyWindow else {
            return
        }

        if isFloating {
            window.level = .normal
            isFloating = false
        } else {
            window.level = .floating
            isFloating = true
            window.makeKeyAndOrderFront(nil)
        }
    }
}

#endif


