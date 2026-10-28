import SwiftUI

extension EnvironmentValues {
    @Entry var hasSeparatedPlayerControls = false
}

/// 视频和控制层保持同一身份；系统在半折状态下把控制台移入独立区域。
struct PlayerArrangementModifier<Controls: View>: ViewModifier {
    @ViewBuilder var controls: (Bool) -> Controls
    #if os(iOS)
    @State private var hasInteriorDivision = false
    #endif

    func body(content: Content) -> some View {
        #if os(iOS)
        if #available(iOS 27.1, *) {
            ArrangementView {
                PlayerArrangementPrimary { separated in
                    controls(hasInteriorDivision && separated)
                }
            } secondary: { content.environment(\.hasSeparatedPlayerControls, hasInteriorDivision) }
            .arrangementViewStyle(.overlay)
            .onGeometryChange(for: Bool.self) { geometry in
                geometry.reservedRegions(kind: .division, options: .includeInactive).contains {
                    let region = $0.frame.intersection(CGRect(origin: .zero, size: geometry.size))
                    guard $0.isActive, !region.isEmpty, !region.isNull else { return false }
                    let vertical = region.height >= region.width
                    return (vertical ? region.minX : region.minY) > 1
                        && (vertical ? region.maxX : region.maxY) < (vertical ? geometry.size.width : geometry.size.height) - 1
                }
            } action: { hasInteriorDivision = $0 }
        } else { content.overlay { controls(false) } }
        #else
        content.overlay { controls(false) }
        #endif
    }
}

#if os(iOS)
@available(iOS 27.1, *)
private struct PlayerArrangementPrimary<Content: View>: View {
    @Environment(\.overlayArrangementZIndex) private var overlayArrangementZIndex
    let content: (Bool) -> Content
    var body: some View { content(overlayArrangementZIndex <= 0) }
}
#endif
