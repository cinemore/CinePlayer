import CinePlayerSDK
import AVFoundation
import SwiftUI

#if os(visionOS)
/// 系统 Ornament 中的三行控制栏；播放器业务仍由独立会话提供。
struct ControllerPanelViewVision: View {
    @ObservedObject var scrubState: PlayerSliderScrubState
    var isInitializing: Bool
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var toastModel: PlayerToastModel
    @State private var leadingControlsWidth: CGFloat = 0
    @State private var trailingControlsWidth: CGFloat = 0

    private var sideControlsWidth: CGFloat {
        max(leadingControlsWidth, trailingControlsWidth)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                control("关闭", icon: "xmark") { playerModel.close(); sessionStore.close() }
                PlayerTitleView(title: sessionStore.currentSource?.displayName ?? "")
                if !isInitializing {
                    if let controller = playerCoordinator.controller {
                        PlayerNetworkSpeed(controller: controller)
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    control("媒体信息", icon: "info.circle", isSelected: playerControlModel.showMediaInfoCard) {
                        playerControlModel.showPlaybackSpeedContainer = false
                        playerControlModel.showMediaInfoCard.toggle()
                    }
                }
            }
            if !isInitializing {
                PlayerSliderView(coordinator: playerCoordinator, progress: playerCoordinator.progress,
                                 scrubState: scrubState, onProgressEditingChanged: scrub)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        leadingControls
                            .frame(minWidth: sideControlsWidth, maxWidth: .infinity, alignment: .leading)
                        transportControls
                        trackControls
                            .frame(minWidth: sideControlsWidth, maxWidth: .infinity, alignment: .trailing)
                    }
                    VStack(spacing: 12) {
                        transportControls
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                leadingControls
                                Spacer()
                                trackControls
                            }
                            VStack(spacing: 12) {
                                leadingControls
                                trackControls
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .onDisappear { scrubState.reset() }
        .onChange(of: isInitializing) { _, initializing in
            if initializing {
                scrubState.reset()
            }
        }
    }

    private var leadingControls: some View {
        HStack(spacing: 8) {
            control("播放设置", icon: "gearshape", isSelected: playerControlModel.showSettingContainer) {
                playerControlModel.toggleVisionPanel(.settings)
            }
            control("视频增强", icon: "wand.and.rays", isSelected: playerControlModel.showEnhancementContainer) {
                playerControlModel.toggleVisionPanel(.enhancement)
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { leadingControlsWidth = $0 }
    }
    private var transportControls: some View {
        HStack(spacing: 8) {
            Button {
                playerCoordinator.controller?.skip(interval: -max(1, sessionStore.controlConfig.skipBackwardSeconds))
            } label: {
                playerSkipLabel(seconds: max(1, sessionStore.controlConfig.skipBackwardSeconds), forward: false)
            }
            .visionPlayerControlStyle()
            .accessibilityLabel("后退")
            control(playerCoordinator.playbackState == .playing ? "暂停" : "播放",
                    icon: playerCoordinator.playbackState == .playing ? "pause.fill" : "play.fill") {
                playerCoordinator.controller?.togglePlaybackFromControls()
            }
            Button {
                playerCoordinator.controller?.skip(interval: max(1, sessionStore.controlConfig.skipForwardSeconds))
            } label: {
                playerSkipLabel(seconds: max(1, sessionStore.controlConfig.skipForwardSeconds), forward: true)
            }
            .visionPlayerControlStyle()
            .accessibilityLabel("前进")
        }
        .fixedSize(horizontal: true, vertical: false)
        .disabled(playerCoordinator.controller == nil)
    }
    private var trackControls: some View {
        HStack(spacing: 8) {
            VisionPlaybackSpeedButton()
            control("字幕", icon: "captions.bubble", isSelected: playerControlModel.showSubtitleContainer) {
                playerControlModel.toggleVisionPanel(.subtitle)
            }
            if (playerCoordinator.controller?.tracks(mediaType: .audio).count ?? 0) > 1 {
                control("音轨", icon: "waveform", isSelected: playerControlModel.showAudioContainer) {
                    playerControlModel.toggleVisionPanel(.audio)
                }
            }
            if (playerCoordinator.controller?.videoTracks.count ?? 0) > 1 {
                control("视频轨道", icon: "video", isSelected: playerControlModel.showVideoTrackContainer) {
                    playerControlModel.toggleVisionPanel(.videoTrack)
                }
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { trailingControlsWidth = $0 }
    }
    private func control(_ title: LocalizedStringKey, icon: String, isSelected: Bool = false,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: icon) }
            .visionPlayerControlStyle(isSelected: isSelected)
            .accessibilityLabel(Text(title))
    }
    private func scrub(_ editing: Bool, seconds: Int) {
        if editing {
            playerMaskModel.showMask()
            playerCoordinator.controller?.pause()
        } else if let target = scrubState.end() {
            guard let controller = playerCoordinator.controller else {
                scrubState.reset()
                return
            }
            // 与主仓库一致：定位后恢复播放，目标时间保留到当前 seek 回执。
            controller.seek(time: TimeInterval(target.time)) { [scrubState] _ in
                Task { @MainActor in scrubState.complete(generation: target.generation) }
            }
        }
    }
}

/// 每个候选布局由实际点击的按钮呈现 Popover，避免 ViewThatFits 同时呈现多个弹窗。
private struct VisionPlaybackSpeedButton: View {
    @EnvironmentObject private var controls: PlayerControlModel
    @EnvironmentObject private var coordinator: CinePlayer.Coordinator
    @EnvironmentObject private var mask: PlayerMaskModel
    @State private var isPopoverPresented = false

    var body: some View {
        Button { isPopoverPresented.toggle() } label: {
            if coordinator.playbackRate == 1 {
                Label("播放速度", systemImage: "barometer")
            } else {
                Text(verbatim: "\(coordinator.playbackRate.playbackRateText)x")
                    .monospacedDigit()
            }
        }
        .visionPlayerControlStyle()
        .accessibilityLabel("播放速度")
        .accessibilityValue(Text(verbatim: "\(coordinator.playbackRate.playbackRateText)x"))
        .popover(isPresented: $isPopoverPresented, arrowEdge: .bottom) {
            SiderPlaybackSpeedView()
                .environmentObject(controls)
                .environmentObject(coordinator)
                .environmentObject(mask)
        }
        .onChange(of: isPopoverPresented) { _, presented in
            controls.showPlaybackSpeedContainer = presented
        }
        .onChange(of: controls.showPlaybackSpeedContainer) { _, presented in
            if !presented { isPopoverPresented = false }
        }
        .onDisappear {
            if isPopoverPresented { controls.showPlaybackSpeedContainer = false }
        }
    }
}
#endif
