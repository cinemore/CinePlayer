import CinePlayerSDK
import SwiftUI

#if os(iOS)
    @available(iOS 18.0, *)
    struct PlayerPanelFormStyle: FormStyle {
        func makeBody(configuration: Configuration) -> some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(sections: configuration.content) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(section.header) { header in
                                header
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .accessibilityAddTraits(.isHeader)
                                    .padding(.horizontal, 12)
                            }
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(section.content) { row in
                                    if row.id != section.content.first?.id {
                                        Divider().padding(.horizontal, 12)
                                    }
                                    row
                                        // 自定义滚动布局单独提供正文基准，不影响原生 grouped Form。
                                        .font(.body)
                                        // 普通滚动布局需明确显示 Picker 标签，不能依赖原生 Form 的默认行为。
                                        .labelsVisibility(.visible)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(PlayerPanelFormModifier.rowInsets)
                                }
                            }
                            .background(.primary.opacity(0.06), in: .rect(cornerRadius: 16))
                            ForEach(section.footer) { footer in
                                footer
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 12)
                            }
                        }
                    }
                }
                .padding(16)
            }
            .pickerStyle(.menu)
            .toggleStyle(.switch)
            .environment(\.usesPlayerPanelForm, true)
        }
    }
#endif
