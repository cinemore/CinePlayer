import CinePlayerSDK
import SwiftUI

/// 复用字幕的圆形勾选样式，轨道仍由调用方维护互斥选择。
struct PlayerTrackSelectionRow: View {
    @Environment(\.usesPlayerPanelForm) private var usesPlayerPanelForm
    let isSelected: Bool
    let title: String
    var profileName: String?
    let details: [String]
    var onDeselect: (() -> Void)?
    var onSelect: () -> Void

    var body: some View {
        Toggle(isOn: Binding(
            get: { isSelected },
            set: { selected in
                // 字幕允许关闭；音／视频轨道不传取消回调，保持互斥选择。
                if selected {
                    onSelect()
                } else {
                    onDeselect?()
                }
            }
        )) {
            trackLabel
        }
        .toggleStyle(RadioToggleStyle(
            labelPlacement: .leading,
            radioSize: PlayerPlatform.deviceType == .tv ? 30 : 18,
            visionHoverInsets: usesPlayerPanelForm ? PlayerPanelFormModifier.rowInsets : EdgeInsets(),
            usesNativeListStyle: !usesPlayerPanelForm
        ))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var trackLabel: some View {
        VStack(alignment: .leading) {
            Text(title)
                .foregroundStyle(.primary)

            if let profileName,
               !profileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                Text(profileName)
                    .playerPanelFormFont(.footnote)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            let detailText = details
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !detailText.isEmpty {
                Text(detailText)
                    .playerPanelFormFont(.footnote)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}
