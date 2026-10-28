import CinePlayerSDK
import SwiftUI

/// 播放器嵌入表单使用普通滚动布局，避免系统列表在侧滑结束后重新分配内容边距。
struct PlayerPanelFormModifier: ViewModifier {
    /// 自绘表单的行留白与指针范围共用同一配置。
    static let rowInsets = EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12)
    var enabled = true

    func body(content: Content) -> some View {
        #if os(iOS)
            if #available(iOS 18.0, *), enabled {
                content.formStyle(PlayerPanelFormStyle())
            } else {
                content.formStyle(.grouped)
            }
        #else
            content.formStyle(.grouped)
        #endif
    }
}
