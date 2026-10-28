import SwiftUI

enum ToggleLabelPlacement {
    case leading
    case trailing
}

struct CheckMarkView: View {
    var checked: Bool
    var unSelectedColor: Color = .secondary
    var focused: Bool = false
    var disabled = false
    var size: CGFloat = 22
    var selectedColor: Color = .checkedDefault
    var checkmarkColor: Color = .white
    var body: some View {
        Group {
            if !checked {
                Circle()
                    .fill(.regularMaterial)
                    .frame(width: size, height: size)
                    .overlay {
                        Circle()
                            .stroke(unSelectedColor, lineWidth: 1.5)
                    }
            } else {
                Circle()
                    .fill(selectedColor)
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "checkmark")
                            .foregroundStyle(checkmarkColor)
                            .font(.system(size: size * 0.55, weight: .bold))
                    }
            }
        }
        .opacity(disabled ? 0.4 : 1)
    }
}

struct RadioToggleStyle: ToggleStyle {
    @Environment(\.isEnabled) private var isEnabled
    /// 非播放器选择行与普通列表保持四边 6pt 的高亮留白。
    nonisolated static var selectionListHoverInsets: EdgeInsets {
        EdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
    }

    /// 无内部留白的列表选项共用的高亮边距；仅在 visionOS 分支读取。
    nonisolated static var listHoverInsets: EdgeInsets {
        EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8)
    }

    var labelPlacement: ToggleLabelPlacement = .trailing
    var showCheckmark: Bool = true
    var disabled: Bool = false
    /// 与卡片上的勾选器保持相同的未选中描边。
    var unSelectedColor: Color = .secondary
    var focused: Bool = false
    var radioSize: CGFloat = 22
    /// visionOS 的多选背景由实际按钮绘制，与高亮保持同一边界。
    var selectionBackground: Color?
    /// 文件列表可为未选中行提供材质底板；默认不改变其他选择器。
    var unselectedBackground: Material?
    /// visionOS／iPad 为贴边列表行分配 hover 留白；正负 padding 抵消，不改变布局。
    var visionHoverInsets: EdgeInsets = .init()
    /// visionOS／iPad 的 label 自带高亮时，样式内部不再叠加 hover。
    var usesLabelHover: Bool = false
    /// 原生 List/Form 的独立选择行不添加内容 hover；visionOS 另使用系统行按钮样式。
    var usesNativeListStyle: Bool = false

    func getCheckMarkView(_ checked: Bool) -> some View {
        CheckMarkView(
            checked: checked,
            unSelectedColor: unSelectedColor,
            focused: focused,
            disabled: disabled,
            size: radioSize
        )
    }

    func makeBody(configuration: Configuration) -> some View {
        // Return a view that has checklist appearance and behavior.
        Button {
            if disabled {
                return
            }
            configuration.isOn.toggle()
        } label: {
            Group {
                if !showCheckmark {
                    configuration.label
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if labelPlacement == .trailing {
                    HStack(alignment: .center, spacing: 16) {
                        if showCheckmark {
                            getCheckMarkView(configuration.isOn)
                        }
                        configuration.label
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack(alignment: .center, spacing: 16) {
                        configuration.label
                        Spacer(minLength: 0)
                        if showCheckmark {
                            getCheckMarkView(configuration.isOn)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            #if os(visionOS)
            .ifIs(!usesNativeListStyle) { content in
                content
                    .padding(.horizontal, unselectedBackground == nil ? 0 : 12)
                    .padding(visionHoverInsets)
                    .background {
                        // 复用调用方的选中颜色；空间界面仍由按钮自身绘制，避免底板与 hover 错位。
                        if configuration.isOn, showCheckmark, let selectionBackground {
                            RoundedRectangle(cornerRadius: AppCornerRadius.card)
                                .fill(selectionBackground)
                        } else if let unselectedBackground {
                            RoundedRectangle(cornerRadius: AppCornerRadius.card)
                                .fill(unselectedBackground)
                        }
                    }
                    .contentShape(.interaction, RoundedRectangle(cornerRadius: AppCornerRadius.card))
                    .cardHoverEffect(enabled: showCheckmark && !disabled && !usesLabelHover, cornerRadius: AppCornerRadius.card)
                    .padding(EdgeInsets(
                        top: -visionHoverInsets.top,
                        leading: -visionHoverInsets.leading,
                        bottom: -visionHoverInsets.bottom,
                        trailing: -visionHoverInsets.trailing
                    ))
            }
            #elseif os(iOS) || os(macOS)
            .ifIs(!usesNativeListStyle && showCheckmark && !disabled && isEnabled && !usesLabelHover) {
                $0.visionListRowHoverEffect(
                    cornerRadius: AppCornerRadius.card,
                    insets: visionHoverInsets
                )
            }
            #endif
        }
        .padding(0)
        #if os(tvOS)
            .buttonStyle(.automatic)
        #elseif os(visionOS)
            .foregroundStyle(disabled ? .secondary : .primary)
            .ifIs(usesNativeListStyle) { $0.buttonStyle(.automatic) }
            .ifIs(!usesNativeListStyle) {
                $0.visionImageButtonStyle(cornerRadius: AppCornerRadius.card, usesLabelHover: showCheckmark || usesLabelHover)
            }
        #else
            .foregroundStyle(!disabled ? Color.primary : Color.secondary)
            .buttonStyle(.borderless)
        #endif
    }
}
