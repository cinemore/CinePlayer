import SwiftUI

struct PlayerCloseButton: View {
    var action: () -> Void

    var body: some View {
        GlassControlButton(
            icon: "xmark",
            accessibilityLabel: "关闭",
            diameter: 44,
            action: action
        )
    }
}
