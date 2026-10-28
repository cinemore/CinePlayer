import SwiftUI

/// Only apply at a sheet, popover, full-screen cover, or dedicated playback window.
/// The system presentation boundary keeps this preference out of the main app window.
struct PlayerPresentationAppearance: ViewModifier {
    func body(content: Content) -> some View {
        content
            #if os(macOS)
            .background(Color(nsColor: .windowBackgroundColor))
            #endif
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
            .foregroundStyle(Color.primary)
    }
}
