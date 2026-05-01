import SwiftUI

struct GlassEffectModifier: ViewModifier {
    let topLeading: CGFloat
    let topTrailing: CGFloat
    let bottomLeading: CGFloat
    let bottomTrailing: CGFloat
    let material: Material
    let useCapsule: Bool
    let clipsContent: Bool

    init(
        topLeading: CGFloat = 0,
        topTrailing: CGFloat = 0,
        bottomLeading: CGFloat = 0,
        bottomTrailing: CGFloat = 0,
        cornerRadius: CGFloat? = nil,
        material: Material = .ultraThinMaterial,
        useCapsule: Bool = true,
        clipsContent: Bool = false
    ) {
        if let cornerRadius {
            self.topLeading = cornerRadius
            self.topTrailing = cornerRadius
            self.bottomLeading = cornerRadius
            self.bottomTrailing = cornerRadius
        } else {
            self.topLeading = topLeading
            self.topTrailing = topTrailing
            self.bottomLeading = bottomLeading
            self.bottomTrailing = bottomTrailing
        }
        self.material = material
        self.useCapsule = useCapsule
        self.clipsContent = clipsContent
    }

    func body(content: Content) -> some View {
        let allSame =
            topLeading == topTrailing && topTrailing == bottomLeading
            && bottomLeading == bottomTrailing
        return applyEffect(to: clipIfNeeded(content, allSame: allSame), allSame: allSame)
    }

    @ViewBuilder
    private func clipIfNeeded(_ content: Content, allSame: Bool) -> some View {
        if !clipsContent {
            content
        } else if useCapsule {
            content.clipShape(Capsule())
        } else if allSame {
            content.clipShape(RoundedRectangle(cornerRadius: topLeading))
        } else {
            content.clipShape(
                UnevenRoundedRectangle(
                    topLeadingRadius: topLeading,
                    bottomLeadingRadius: bottomLeading,
                    bottomTrailingRadius: bottomTrailing,
                    topTrailingRadius: topTrailing
                )
            )
        }
    }

    @ViewBuilder
    private func applyEffect(to content: some View, allSame: Bool) -> some View {
        #if !os(visionOS)
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, *) {
                if useCapsule {
                    content.glassEffect(.regular.interactive(), in: .capsule)
                } else if allSame {
                    content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: topLeading))
                } else {
                    content.glassEffect(
                        .regular.interactive(),
                        in: .rect(
                            topLeadingRadius: topLeading,
                            bottomLeadingRadius: bottomLeading,
                            bottomTrailingRadius: bottomTrailing,
                            topTrailingRadius: topTrailing
                        )
                    )
                }
            } else {
                fallbackEffect(content, allSame: allSame)
            }
        #else
            fallbackEffect(content, allSame: allSame)
        #endif
    }

    @ViewBuilder
    private func fallbackEffect(_ content: some View, allSame: Bool) -> some View {
        if useCapsule {
            content
                .background(material, in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
        } else if allSame {
            let shape = RoundedRectangle(cornerRadius: topLeading)
            content
                .background(material, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
        } else {
            let shape = UnevenRoundedRectangle(
                topLeadingRadius: topLeading,
                bottomLeadingRadius: bottomLeading,
                bottomTrailingRadius: bottomTrailing,
                topTrailingRadius: topTrailing
            )
            content
                .background(material, in: shape)
                .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
        }
    }
}

/// 浮在视频帧之上的 toast 必须用 `.regularMaterial` 而非 `.glassEffect(in: .rect)`：
/// macOS 26 的矩形玻璃折射会把上方 Text 在透过 AVSampleBufferDisplayLayer 时
/// 映射成镜像（`.capsule` 形状不会出现该伪影）。
struct LoadingOverlayBackground: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
        content
            .background(.regularMaterial, in: shape)
            .overlay(shape.stroke(Color.white.opacity(0.18), lineWidth: 1))
    }
}
