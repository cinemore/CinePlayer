import CinePlayerSDK
import SwiftUI

/// 仅补充 iOS 自定义播放器表单的行内文字层级，原生 Form 保留系统字体。
struct PlayerPanelFormFontModifier: ViewModifier {
    @Environment(\.usesPlayerPanelForm) private var usesPlayerPanelForm

    let font: Font

    func body(content: Content) -> some View {
        #if os(iOS)
            if usesPlayerPanelForm {
                content.font(font)
            } else {
                content
            }
        #else
            content
        #endif
    }
}

extension View {
    func playerPanelFormFont(_ font: Font) -> some View {
        modifier(PlayerPanelFormFontModifier(font: font))
    }
}
