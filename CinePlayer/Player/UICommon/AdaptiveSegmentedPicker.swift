import SwiftUI

/// 优先显示分段选择器，国际化文案放不下时自动切换为菜单。
struct AdaptiveSegmentedPicker<SelectionValue: Hashable, Content: View>: View {
    private let label: LocalizedStringKey
    @Binding private var selection: SelectionValue
    private let content: Content
    init(
        _ label: LocalizedStringKey,
        selection: Binding<SelectionValue>,
        @ViewBuilder content: () -> Content
    ) {
        self.label = label
        _selection = selection
        self.content = content()
    }

    var body: some View {
        #if os(tvOS)
            segmentedPicker
        #else
            ViewThatFits(in: .horizontal) {
                #if os(visionOS)
                    // 仅依赖 Picker 的理想宽度仍可能截断标题，复用完整标签的测量布局。
                    VisionSegmentedPickerLayout {
                        segmentedPicker
                        content
                            .fixedSize()
                            .hidden()
                            .accessibilityHidden(true)
                            .allowsHitTesting(false)
                    }
                    .fixedSize(horizontal: true, vertical: false)
                #else
                    // 原生分段控件不会压缩标题，固定理想宽度才能让 ViewThatFits 正确判断溢出。
                    segmentedPicker
                        .fixedSize(horizontal: true, vertical: false)
                #endif

                menuPicker
            }
        #endif
    }

    private var segmentedPicker: some View {
        Picker(selection: $selection) {
            content
        } label: {
            Text(label)
        }
        .labelsHidden()
        .pickerStyle(.segmented)
    }

    #if !os(tvOS)
        private var menuPicker: some View {
            Picker(selection: $selection) {
                content
            } label: {
                Text(label)
            }
            .labelsHidden()
            .pickerStyle(.menu)
            #if os(visionOS)
                .frame(maxWidth: .infinity, alignment: .leading)
            #else
                .frame(maxWidth: .infinity)
            #endif
        }
    #endif
}

#if os(visionOS)
/// 原生分段等宽排布，按最长标题为每段预留完整文字及两侧控件空间。
struct VisionSegmentedPickerLayout: Layout {
    private func pickerSize(subviews: Subviews) -> CGSize {
        guard let picker = subviews.first else {
            return .zero
        }
        let labels = subviews.dropFirst()
        let widestTitle = labels.map { $0.sizeThatFits(.unspecified).width }.max() ?? 0
        let width = ceil((widestTitle + 40) * CGFloat(max(labels.count, 1)) + 8)
        let size = picker.sizeThatFits(ProposedViewSize(width: width, height: nil))
        return CGSize(width: max(width, size.width), height: size.height)
    }

    func sizeThatFits(proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        pickerSize(subviews: subviews)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        guard let picker = subviews.first else {
            return
        }
        picker.place(at: bounds.origin, proposal: ProposedViewSize(pickerSize(subviews: subviews)))
    }
}
#endif
