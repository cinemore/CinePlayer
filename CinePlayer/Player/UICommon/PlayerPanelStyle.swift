import SwiftUI
#if os(iOS)
import UIKit
#endif

/// 独立播放器只提供界面所需的平台信息，不引入 Cinemore 的设备与业务模型。
enum PlayerPlatform {
    enum Kind { case mac, tv, ipad, iphone, vision }
    static var deviceType: Kind {
        #if os(macOS)
        .mac
        #elseif os(tvOS)
        .tv
        #elseif os(visionOS)
        .vision
        #else
        UIDevice.current.userInterfaceIdiom == .pad ? .ipad : .iphone
        #endif
    }
}

enum AppCornerRadius {
    static let card: CGFloat = 16
    static let featureEntry: CGFloat = 12
    static let poster: CGFloat = 14
}

extension EnvironmentValues {
    @Entry var usesVisionPlayerTypography = false
    @Entry var usesPlayerPanelTypography = false
}

enum PlayerContentTextRole {
    case title, value, secondary, technical, caption, heading, detail, sheetTitle, message, playbackRate
    var font: Font {
        switch self {
        case .title, .value, .message: .body
        case .secondary, .technical, .detail: .subheadline
        case .caption: .caption
        case .heading: .headline
        case .sheetTitle: .title2
        case .playbackRate: .title3
        }
    }
}

private struct PlayerContentFont: ViewModifier {
    let role: PlayerContentTextRole
    var weight: Font.Weight?

    func body(content: Content) -> some View {
        content.font(weight.map { role.font.weight($0) } ?? role.font)
    }
}

struct PlayerSemanticFontModifier: ViewModifier {
    @Environment(\.usesVisionPlayerTypography) private var visionTypography
    @Environment(\.usesPlayerPanelTypography) private var panelTypography
    let font: Font
    let fallback: Font
    func body(content: Content) -> some View {
        #if os(visionOS)
        content.font(visionTypography ? font : fallback)
        #else
        content.font(panelTypography ? font : fallback)
        #endif
    }
}

extension Color {
    static let font = Color.primary
    static let customLabel = Color.secondary
    static let checkedDefault = Color.blue
}

extension View {
    func contentTextFont(_ role: PlayerContentTextRole, weight: Font.Weight? = nil, lineHeight: CGFloat? = nil) -> some View {
        modifier(PlayerContentFont(role: role, weight: weight))
    }

    func playerSemanticFont(_ font: Font, fallback: Font, fallbackLineHeight: CGFloat? = nil) -> some View {
        modifier(PlayerSemanticFontModifier(font: font, fallback: fallback))
    }

    func playerTrackDetailFont(fallback: Font) -> some View {
        #if os(macOS)
        playerSemanticFont(.callout, fallback: fallback)
        #else
        playerSemanticFont(.caption, fallback: fallback)
        #endif
    }

    @ViewBuilder
    func playerPanelTitleStyle() -> some View {
        #if os(visionOS)
        font(.title2.weight(.semibold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24).padding(.top, 24).padding(.bottom, 16)
        #else
        contentTextFont(.heading).padding()
        #endif
    }

    func pageHorizontalPadding() -> some View { padding(.horizontal, 16) }

    @ViewBuilder
    func ifIs<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition { transform(self) } else { self }
    }

    @ViewBuilder
    func playerControlButtonStyle() -> some View {
        #if os(macOS)
        buttonStyle(.borderless)
        #else
        buttonStyle(.plain)
        #endif
    }

    @ViewBuilder
    func playerControlHoverEffect<S: Shape>(in shape: S) -> some View {
        #if os(iOS)
        if PlayerPlatform.deviceType == .ipad {
            contentShape(.hoverEffect, shape).hoverEffect(.highlight)
        } else { self }
        #else
        self
        #endif
    }

    func visionListRowHoverEffect(cornerRadius: CGFloat = 16, insets: EdgeInsets = .init()) -> some View {
        playerControlHoverEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
    }

    @ViewBuilder
    func cardHoverEffect(enabled: Bool = true, cornerRadius: CGFloat = 16) -> some View {
        #if os(visionOS)
        if enabled { contentShape(.hoverEffect, RoundedRectangle(cornerRadius: cornerRadius)).hoverEffect(.highlight) }
        else { self }
        #else
        if enabled { playerControlHoverEffect(in: RoundedRectangle(cornerRadius: cornerRadius)) }
        else { self }
        #endif
    }

    func visionImageButtonStyle(cornerRadius: CGFloat, usesLabelHover: Bool = false) -> some View {
        buttonStyle(.borderless)
    }

    @ViewBuilder
    func visionPlayerSelectionStyle(isSelected: Bool) -> some View {
        #if os(visionOS)
        if isSelected {
            buttonStyle(.borderedProminent)
        } else {
            buttonStyle(.bordered)
        }
        #else
        self
        #endif
    }

    #if os(visionOS)
    /// 空间播放器由外层统一提供玻璃，按钮使用系统高亮与尺寸。
    func visionPlayerControlStyle(isSelected: Bool = false) -> some View {
        buttonStyle(.borderless)
            .tint(isSelected ? Color.accentColor : nil)
            .controlSize(.large)
            .labelStyle(.iconOnly)
            .foregroundStyle(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.primary))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
    #endif
}

struct OpenUrlButtonView: View {
    let url: String
    let title: LocalizedStringKey
    var opensExternally = true
    var body: some View {
        if let destination = URL(string: url) { Link(title, destination: destination) }
    }
}

struct GlassControlButton: View {
    let icon: String
    let accessibilityLabel: LocalizedStringKey
    var diameter: CGFloat = 40
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .brightness(0.2)
                .foregroundStyle(.white)
                #if os(macOS)
                .font(.system(size: 20, weight: .semibold))
                #else
                .font(.system(size: 20, weight: .regular))
                #endif
                .frame(width: diameter, height: diameter)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .playerControlHoverEffect(in: Circle())
        .modifier(GlassEffectModifier(cornerRadius: diameter / 2))
        .accessibilityLabel(Text(accessibilityLabel))
        #if os(macOS)
        .help(Text(accessibilityLabel))
        #endif
    }
}
