import CinePlayerSDK
import AVFoundation
import SwiftUI
#if os(iOS)
import UIKit
#endif

#if os(iOS)
@MainActor
struct ControllerPanelViewIOS: View {
    var geometry: GeometryProxy

    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var toastModel: PlayerToastModel

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
    }

    private var titleText: String {
        sessionStore.currentSource?.displayName ?? ""
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var isPortraitLayout: Bool {
        if UIDevice.current.userInterfaceIdiom == .phone {
            return PlatformServices.isIOSPlayerPortraitLock()
        }
        return geometry.size.height > geometry.size.width
    }

    var body: some View {
        Group {
            if isPortraitLayout {
                portraitLayout
            } else {
                landscapeLayout
            }
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                PlayerTitleView(title: titleText)
                Spacer()
            }
            .frame(height: 24)

            HStack(spacing: 8) {
                PlayerCloseButton {
                    playerModel.close()
                    sessionStore.close()
                }

                playerControlButtonGroup

                Spacer()

                settingsButtonGroup
            }

            Spacer()

            VStack(spacing: 8) {
                progressSlider

                HStack {
                    playControlButtonGroup
                        .padding(.leading, 8)

                    Spacer()

                    playbackControlButtonGroup
                }
            }
            .padding(.bottom, isPad ? 24 : 0)
        }
        .padding(.horizontal, isPad ? 16 : 0)
        .background { backgroundGradient }
    }

    private var portraitLayout: some View {
        VStack(spacing: 0) {
            PlayerTitleView(title: titleText)
                .frame(height: 24)

            HStack(spacing: 8) {
                PlayerCloseButton {
                    playerModel.close()
                    sessionStore.close()
                }

                Spacer()

                playerControlButtonGroup
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            HStack(spacing: 8) {
                Spacer()
                settingsButtonGroup
            }
            .padding(.horizontal, 16)

            Spacer()

            VStack(spacing: 8) {
                progressSlider

                playbackControlButtonGroup

                HStack {
                    Spacer()
                    playControlButtonGroup
                    Spacer()
                }
            }
            .padding(.bottom, isPad ? 24 : 0)
        }
        .padding(.horizontal, isPad ? 16 : 0)
        .background { backgroundGradient }
    }

    private var backgroundGradient: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.black.opacity(0.60), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: isPad ? 240 : 120)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.80)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: isPad ? 240 : 120)
            }
        }
        .ignoresSafeArea()
    }

    private var progressSlider: some View {
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
    }

    private var playerControlButtonGroup: some View {
        HStack(spacing: 8) {
            if PlayerController.isPictureInPictureSupported() {
                groupIconButton(
                    icon: playerCoordinator.isPictureInPictureActive
                        ? "pip.exit" : "pip.enter"
                ) {
                    playerCoordinator.controller?.togglePictureInPicture()
                }
            }

            groupIconButton(
                icon: playerCoordinator.isScaleAspectFill
                    ? "rectangle.arrowtriangle.2.inward"
                    : "rectangle.arrowtriangle.2.outward"
            ) {
                playerCoordinator.isScaleAspectFill.toggle()
            }

            if UIDevice.current.userInterfaceIdiom == .phone {
                groupIconButton(
                    icon: PlatformServices.isIOSPlayerPortraitLock() ? "rotate.right" : "rotate.left"
                ) {
                    PlatformServices.toggleIOSPlaybackOrientationLock()
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

    private var playbackControlButtonGroup: some View {
        HStack(spacing: 8) {
            speedButton

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

    private var speedButton: some View {
        Button {
            playerControlModel.hideContainer()
            playerControlModel.showPlaybackSpeedContainer = true
        } label: {
            if playerCoordinator.playbackRate == 1.0 {
                Image(systemName: "barometer")
                    .brightness(0.2)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 44, height: 44)
                    .background(Color.clear)
                    .contentShape(Rectangle())
            } else {
                Text("\(playerCoordinator.playbackRate.playbackRateText)x")
                    .brightness(0.2)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(minWidth: 44)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
    }

    private var playControlButtonGroup: some View {
        HStack(spacing: 8) {
            groupIconButton(icon: "gobackward.\(config.skipBackwardSeconds)", useGlass: false) {
                playerCoordinator.controller?.skip(interval: -config.skipBackwardSeconds)
                toastModel.show(.skip(seconds: -config.skipBackwardSeconds))
            }

            groupIconButton(
                icon: playerCoordinator.playbackState == .playing ? "pause.fill" : "play.fill",
                useGlass: false,
                font: .system(size: 24, weight: .regular)
            ) {
                playerCoordinator.controller?.switchPlayPause()
            }

            groupIconButton(icon: "goforward.\(config.skipForwardSeconds)", useGlass: false) {
                playerCoordinator.controller?.skip(interval: config.skipForwardSeconds)
                toastModel.show(.skip(seconds: config.skipForwardSeconds))
            }
        }
    }

    private func groupIconButton(
        icon: String,
        useGlass: Bool = false,
        font: Font = .system(size: 20, weight: .regular),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .brightness(0.2)
                .foregroundColor(.white)
                .font(font)
                .frame(width: 44, height: 44)
                .background(Color.clear)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .if(useGlass) {
            $0.modifier(GlassEffectModifier(cornerRadius: 22))
        }
    }

    private var hasMultipleAudioTracks: Bool {
        (playerCoordinator.controller?.tracks(mediaType: .audio).count ?? 0) > 1
    }

    private var hasMultipleVideoTracks: Bool {
        (playerCoordinator.controller?.videoTracks.count ?? 0) > 1
    }
}
#endif
