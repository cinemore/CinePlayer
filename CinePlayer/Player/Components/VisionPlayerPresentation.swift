import CinePlayerSDK
import SwiftUI
#if os(visionOS)
/// 功能面板分别替换同侧内容；隐藏控制栏时保留表单身份与选项。
struct VisionPlayerPresentation: ViewModifier {
    var geometry: GeometryProxy
    @ObservedObject var sessionStore: PlayerSessionStore
    @ObservedObject var playerModel: VideoPlayerModel
    @ObservedObject var controls: PlayerControlModel
    @ObservedObject var mask: PlayerMaskModel
    @ObservedObject var toast: PlayerToastModel
    @ObservedObject var scrubState: PlayerSliderScrubState
    var isInitializing: Bool
    @State private var controlPanelHeight: CGFloat = 0

    private var controlsVisible: Bool { isInitializing || mask.isMaskShow }
    private var panelsVisible: Bool { controlsVisible && !isInitializing }
    private var controlPanelWidth: CGFloat { min(900, max(0, geometry.size.width)) }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if scrubState.isEditing, let time = scrubState.targetTime,
                   panelsVisible, controlPanelHeight > 0,
                   let controller = playerModel.playerCoordinator.controller {
                    VisionScrubThumbnailPreview(time: time, controller: controller, width: controlPanelWidth)
                        .id(ObjectIdentifier(controller))
                        // 底部 Ornament 中心锚在视频边缘，预览避开其上半部分。
                        .padding(.bottom, controlPanelHeight / 2 + 12)
                }
            }
            .ornament(visibility: controlsVisible ? .visible : .hidden,
                      attachmentAnchor: .scene(.bottom), contentAlignment: .center) {
                ControllerPanelViewVision(scrubState: scrubState, isInitializing: isInitializing)
                    .frame(width: controlPanelWidth)
                    .glassBackgroundEffect()
                    .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { controlPanelHeight = $0 }
                    .environmentObject(sessionStore).environmentObject(playerModel)
                    .environmentObject(playerModel.playerCoordinator)
                    .environmentObject(controls).environmentObject(mask).environmentObject(toast)
            }
            .ornament(visibility: panelsVisible && controls.leadingVisionPanel != nil ? .visible : .hidden,
                      attachmentAnchor: .scene(.leading), contentAlignment: .trailing) {
                panel(isLeading: true).padding(.trailing, 24)
            }
            .ornament(visibility: panelsVisible && controls.trailingVisionPanel != nil ? .visible : .hidden,
                      attachmentAnchor: .scene(.trailing), contentAlignment: .leading) {
                panel(isLeading: false).padding(.leading, 24)
            }
            .ornament(visibility: panelsVisible && controls.showMediaInfoCard ? .visible : .hidden,
                      attachmentAnchor: .scene(.top), contentAlignment: .bottom) {
                if let controller = playerModel.playerCoordinator.controller {
                    PlayerMediaInfoCardView(controller: controller, isPresented: $controls.showMediaInfoCard,
                                            isPlaybackInfoPinned: $playerModel.isPlaybackInfoPinned)
                        .frame(width: max(0, geometry.size.width))
                        .padding(.bottom, 24)
                        .animation(nil, value: controls.showMediaInfoCard)
                        .animation(nil, value: controlsVisible)
                        .allowsHitTesting(panelsVisible && controls.showMediaInfoCard)
                        .accessibilityHidden(!panelsVisible || !controls.showMediaInfoCard)
                }
            }
            .onChange(of: isInitializing) { _, initializing in
                if initializing {
                    scrubState.reset()
                    controls.showPlaybackSpeedContainer = false
                    controls.showMediaInfoCard = false
                }
            }
    }

    private func panel(isLeading: Bool) -> some View {
        let selection = isLeading ? controls.leadingVisionPanel : controls.trailingVisionPanel
        return ZStack {
            ForEach(PlayerControlModel.VisionPanel.allCases.filter { $0.isLeading == isLeading }, id: \.self) { panel in
                panelContent(panel)
                    .environment(\.usesPlayerPanelTypography, !isLeading)
                    .opacity(selection == panel ? 1 : 0)
                    .allowsHitTesting(selection == panel)
                    .accessibilityHidden(selection != panel)
            }
        }
        .frame(width: min(480, max(0, geometry.size.width)), height: max(0, geometry.size.height))
        .glassBackgroundEffect()
        .environmentObject(sessionStore).environmentObject(playerModel)
        .environmentObject(playerModel.playerCoordinator).environmentObject(controls)
        .environmentObject(mask).environmentObject(playerModel.config.subtitleStyle)
        .environment(\.usesVisionPlayerTypography, true)
        .animation(nil, value: selection)
        .animation(nil, value: panelsVisible)
        .allowsHitTesting(panelsVisible && selection != nil)
        .accessibilityHidden(!panelsVisible || selection == nil)
    }

    @ViewBuilder private func panelContent(_ panel: PlayerControlModel.VisionPanel) -> some View {
        switch panel {
        case .settings: SiderSettingView()
        case .enhancement: SiderEnhancementView()
        case .subtitle: SiderSubtitleView()
        case .audio: SiderAudioSettingView()
        case .videoTrack: SiderVideoTrackView()
        }
    }
}
#endif
