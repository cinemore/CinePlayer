import SwiftUI

/// Native empty state sized by the available player panel area.
struct PlayerEmptyStateView: View {
    var accessibilityName: LocalizedStringKey = "暂无内容"

    var body: some View {
        ContentUnavailableView {
            Label("暂无内容", systemImage: "tray")
                .accessibilityLabel(Text(accessibilityName))
        }
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
    }
}
