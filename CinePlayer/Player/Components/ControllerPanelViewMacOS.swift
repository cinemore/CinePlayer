import AVFoundation
import CinePlayerSDK
import SwiftUI

#if os(macOS)
import AppKit

@MainActor
struct ControllerPanelViewMacOS: View {
    var geometry: GeometryProxy

    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var toastModel: PlayerToastModel
    @EnvironmentObject private var windowController: PlayerWindowController

    @State private var containerWidth: CGFloat = 900
    @State private var isFullScreen = false
    @State private var scrubPlayback = PlayerScrubPlaybackSession()

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
    }

    private var playerTitle: String {
        guard let source = sessionStore.currentSource else {
            return ""
        }
        if source.url.isFileURL {
            return source.url.lastPathComponent
        } else {
            return source.url.absoluteString
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 10)

            Spacer()

            bottomControlArea
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 10))
        }
        // 顶部贴边显示，忽略窗口安全区顶部间距
        .padding(.top, -geometry.safeAreaInsets.top)
        .onAppear {
            syncFullScreenState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didEnterFullScreenNotification)) { _ in
            syncFullScreenState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didExitFullScreenNotification)) { _ in
            syncFullScreenState()
        }
    }

    private var topBar: some View {
        VStack(spacing: 8) {
            // 第一行：标题，单独占一行居中显示
            HStack {
                Spacer()
                PlayerTitleView(title: playerTitle)
                    .lineLimit(1)
                    .padding(.top, 8)
                Spacer()
            }

            // 第二行：按钮区域
            HStack(spacing: 8) {
                PlayerCloseButton {
                    playerModel.close()
                    sessionStore.close()
                }

                playerControlButtonGroup

                Spacer()

                settingsButtonGroup
            }
        }
    }

    private var playerControlButtonGroup: some View {
        HStack(spacing: 8) {
            if isPictureInPictureSupported && !isFullScreen {
                groupIconButton(
                    icon: playerCoordinator.isPictureInPictureActive
                        ? "pip.exit" : "pip.enter",
                    title: "画中画"
                ) {
                    playerCoordinator.controller?.togglePictureInPicture()
                }
            }

            // 填充按钮仅在全屏模式下显示
            if isFullScreen {
                groupIconButton(
                    icon: playerCoordinator.isScaleAspectFill
                        ? "rectangle.arrowtriangle.2.inward"
                        : "rectangle.arrowtriangle.2.outward",
                    title: "缩放"
                ) {
                    playerCoordinator.isScaleAspectFill.toggle()
                }
            }

            groupIconButton(
                icon: isFullScreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right",
                title: "全屏"
            ) {
                toggleFullScreen()
            }

            if !isFullScreen {
                groupIconButton(
                    icon: windowController.isFloating
                        ? "lock.rectangle.on.rectangle.fill"
                        : "lock.rectangle.on.rectangle",
                    title: "置顶"
                ) {
                    windowController.toggleWindowLevel()
                }
            }
        }
        .padding(.horizontal, 8)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private var settingsButtonGroup: some View {
        HStack(spacing: 8) {
            groupIconButton(icon: "info.circle", title: "媒体信息") {
                playerMaskModel.hideMask()
                playerControlModel.hideContainer()
                playerControlModel.showMediaInfoCard.toggle()
            }

            groupIconButton(icon: "wand.and.rays", title: "视频增强") {
                playerControlModel.hideContainer()
                playerControlModel.showEnhancementContainer = true
            }

            groupIconButton(icon: "gearshape", title: "播放设置") {
                playerControlModel.hideContainer()
                playerControlModel.showSettingContainer = true
            }
        }
        .padding(.horizontal, 8)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private var bottomControlArea: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                if let controller = playerCoordinator.controller {
                    HStack {
                        PlayerNetworkSpeed(controller: controller)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .modifier(GlassEffectModifier(cornerRadius: 14, material: .regularMaterial))
                        Spacer()
                    }
                }
                PlayerSliderView(
                    coordinator: playerCoordinator,
                    progress: playerCoordinator.progress,
                    onProgressEditingChanged: { editing, seconds in
                        if editing {
                            playerMaskModel.showMask()
                            playerMaskModel.pauseTimer()
                            scrubPlayback.begin(controller: playerCoordinator.controller)
                        } else {
                            playerMaskModel.restartTimer()
                            scrubPlayback.commit(time: TimeInterval(seconds), controller: playerCoordinator.controller)
                        }
                    }
                )
                .frame(height: 36)
                .padding(.horizontal, 8)
                .modifier(GlassEffectModifier(cornerRadius: 18, material: .regularMaterial))

                if containerWidth < 820 {
                    HStack(spacing: 0) {
                        playControlButtonGroup
                        Spacer()
                        playbackControlButtonGroup
                    }
                } else {
                    ZStack {
                        HStack(spacing: 0) {
                            Spacer()
                            playbackControlButtonGroup
                        }

                        playControlButtonGroup
                    }
                }
            }
            .frame(maxWidth: 960)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .onAppear {
                            containerWidth = proxy.size.width
                        }
                        .compatibleOnChange(of: proxy.size.width) { newWidth in
                            containerWidth = newWidth
                        }
                }
            )
            // 只在底部控制区域上禁用自动隐藏，避免覆盖整个窗口阻止定时器工作和双击事件
            .onHover { hovering in
                if hovering {
                    playerMaskModel.disableAutoHide()
                } else {
                    playerMaskModel.enableAutoHide()
                }
            }
            Spacer()
        }
    }

    private var playbackControlButtonGroup: some View {
        HStack(spacing: 8) {
            playbackSpeedButton

            groupIconButton(icon: "captions.bubble", title: "字幕") {
                playerControlModel.hideContainer()
                playerControlModel.showSubtitleContainer = true
            }

            if hasMultipleAudioTracks {
                groupIconButton(icon: "waveform", title: "音轨") {
                    playerControlModel.hideContainer()
                    playerControlModel.showAudioContainer = true
                }
            }

            if hasMultipleVideoTracks {
                groupIconButton(icon: "video.fill", title: "视频轨道") {
                    playerControlModel.hideContainer()
                    playerControlModel.showVideoTrackContainer = true
                }
            }
        }
        .padding(.horizontal, 8)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private var playbackSpeedButton: some View {
        Button {
            playerControlModel.hideContainer()
            playerControlModel.showPlaybackSpeedContainer = true
        } label: {
            if playerCoordinator.playbackRate == 1.0 {
                Image(systemName: "barometer")
                    .brightness(0.2)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .background(Color.clear)
                    .contentShape(Rectangle())
            } else {
                Text("\(playerCoordinator.playbackRate.playbackRateText)x")
                    .brightness(0.2)
                    .foregroundColor(.white)
                    .font(.title3.weight(.semibold))
                    .frame(height: 44)
                    .frame(minWidth: 44)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
        }
        .playerControlButtonStyle()
        .accessibilityLabel("播放速度")
        .accessibilityValue(Text(verbatim: "\(playerCoordinator.playbackRate.playbackRateText)x"))
        .help("播放速度")
    }

    private var playControlButtonGroup: some View {
        HStack(spacing: 16) {
            groupIconButton(
                icon: "gobackward.\(config.skipBackwardSeconds)",
                title: "后退",
                size: 36,
                font: .system(size: 20, weight: .semibold),
                useGlassEffect: true
            ) {
                playerCoordinator.controller?.skip(interval: -config.skipBackwardSeconds)
                toastModel.show(.skip(seconds: -config.skipBackwardSeconds))
            }

            groupIconButton(
                icon: playerCoordinator.playbackState == .playing ? "pause.fill" : "play.fill",
                title: playerCoordinator.playbackState == .playing ? "暂停" : "播放",
                size: 48,
                font: .system(size: 30, weight: .semibold),
                useGlassEffect: true
            ) {
                playerCoordinator.controller?.togglePlaybackFromControls()
            }

            groupIconButton(
                icon: "goforward.\(config.skipForwardSeconds)",
                title: "前进",
                size: 36,
                font: .system(size: 20, weight: .semibold),
                useGlassEffect: true
            ) {
                playerCoordinator.controller?.skip(interval: config.skipForwardSeconds)
                toastModel.show(.skip(seconds: config.skipForwardSeconds))
            }
        }
    }

    private func groupIconButton(
        icon: String,
        title: LocalizedStringKey,
        size: CGFloat = 44,
        font: Font = .system(size: 20, weight: .semibold),
        useGlassEffect: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .brightness(0.2)
                .foregroundColor(.white)
                .font(font)
                .frame(width: size, height: size)
                .background(Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(title))
        .help(Text(title))
        .if(useGlassEffect) {
            $0.modifier(GlassEffectModifier(cornerRadius: size / 2, material: .regularMaterial))
        }
    }

    private var hasMultipleAudioTracks: Bool {
        (playerCoordinator.controller?.tracks(mediaType: .audio).count ?? 0) > 1
    }

    private var hasMultipleVideoTracks: Bool {
        (playerCoordinator.controller?.videoTracks.count ?? 0) > 1
    }

    private var isPictureInPictureSupported: Bool {
        PlayerController.isPictureInPictureSupported()
    }

    private func toggleFullScreen() {
        if windowController.isFloating { windowController.toggleWindowLevel() }
        windowController.playbackWindow?.toggleFullScreen(nil)
    }

    private func syncFullScreenState() {
        if let window = windowController.playbackWindow {
            isFullScreen = window.styleMask.contains(.fullScreen)
        } else {
            isFullScreen = false
        }
    }
}
#endif
