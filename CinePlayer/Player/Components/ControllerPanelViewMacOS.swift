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

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
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
        .contentShape(Rectangle())
        .onHover { hovering in
            // 与 cinemore-apple 一致：鼠标在整块控制面板上时禁用自动隐藏，避免点击按钮时控件消失
            if hovering {
                playerMaskModel.disableAutoHide()
            } else {
                playerMaskModel.enableAutoHide()
            }
        }
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
                PlayerTitleView(title: sessionStore.currentSource?.displayName ?? "")
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
            if isPictureInPictureSupported {
                groupIconButton(
                    icon: playerCoordinator.isPictureInPictureActive
                        ? "pip.exit" : "pip.enter"
                ) {
                    playerCoordinator.controller?.togglePictureInPicture()
                }
            }

            // 填充按钮仅在全屏模式下显示
            if isFullScreen {
                groupIconButton(
                    icon: playerCoordinator.isScaleAspectFill
                        ? "rectangle.arrowtriangle.2.inward"
                        : "rectangle.arrowtriangle.2.outward"
                ) {
                    playerCoordinator.isScaleAspectFill.toggle()
                }
            }

            groupIconButton(
                icon: isFullScreen
                    ? "arrow.down.right.and.arrow.up.left"
                    : "arrow.up.left.and.arrow.down.right"
            ) {
                toggleFullScreen()
            }

            if !isFullScreen {
                groupIconButton(
                    icon: windowController.isFloating
                        ? "lock.rectangle.on.rectangle.fill"
                        : "lock.rectangle.on.rectangle"
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
            groupIconButton(icon: "info.circle") {
                playerMaskModel.hideMask()
                playerControlModel.hideContainer()
                playerControlModel.showMediaInfoCard.toggle()
            }

            groupIconButton(icon: "wand.and.rays") {
                playerControlModel.hideContainer()
                playerControlModel.showEnhancementContainer = true
            }

            groupIconButton(icon: "gearshape") {
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
                PlayerSliderView(
                    coordinator: playerCoordinator,
                    progress: playerCoordinator.progress,
                    onProgressEditingChanged: { editing, seconds in
                        if editing {
                            playerMaskModel.showMask()
                            playerMaskModel.pauseTimer()
                            playerCoordinator.controller?.pause()
                        } else {
                            playerMaskModel.restartTimer()
                            playerCoordinator.controller?.seek(time: TimeInterval(seconds))
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
            Spacer()
        }
    }

    private var playbackControlButtonGroup: some View {
        HStack(spacing: 8) {
            playbackSpeedButton

            groupIconButton(icon: "captions.bubble") {
                playerControlModel.hideContainer()
                playerControlModel.showSubtitleContainer = true
            }

            if hasMultipleAudioTracks {
                groupIconButton(icon: "waveform") {
                    playerControlModel.hideContainer()
                    playerControlModel.showAudioContainer = true
                }
            }

            if hasMultipleVideoTracks {
                groupIconButton(icon: "video.fill") {
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
                    .font(.system(size: 16, weight: .semibold))
                    .frame(height: 44)
                    .frame(minWidth: 44)
                    .padding(.horizontal, 8)
            }
        }
        .buttonStyle(.plain)
    }

    private var playControlButtonGroup: some View {
        HStack(spacing: 16) {
            groupIconButton(
                icon: "gobackward.\(config.skipBackwardSeconds)",
                size: 36,
                font: .system(size: 20, weight: .semibold),
                useGlassEffect: true
            ) {
                playerCoordinator.controller?.skip(interval: -config.skipBackwardSeconds)
                toastModel.show(.skip(seconds: -config.skipBackwardSeconds))
            }

            groupIconButton(
                icon: playerCoordinator.playbackState == .playing ? "pause.fill" : "play.fill",
                size: 48,
                font: .system(size: 30, weight: .semibold),
                useGlassEffect: true
            ) {
                playerCoordinator.controller?.switchPlayPause()
            }

            groupIconButton(
                icon: "goforward.\(config.skipForwardSeconds)",
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
        // 如果窗口处于悬浮锁定状态，先恢复为普通层级
        if windowController.isFloating {
            windowController.toggleWindowLevel()
        }

        let wasPlaying = playerCoordinator.playbackState == .playing
        if wasPlaying {
            playerCoordinator.controller?.pause()
        }

        if let window = NSApplication.shared.keyWindow {
            window.toggleFullScreen(nil)
        }

        syncFullScreenState()

        if wasPlaying {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                playerCoordinator.controller?.play()
            }
        }
    }

    private func syncFullScreenState() {
        if let window = NSApplication.shared.keyWindow {
            isFullScreen = window.styleMask.contains(.fullScreen)
        } else {
            isFullScreen = false
        }
    }
}
#endif
