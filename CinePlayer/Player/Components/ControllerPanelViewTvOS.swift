import AVFoundation
import CinePlayerSDK
import SwiftUI

#if os(tvOS)
private extension View {
    @ViewBuilder
    func tvOS26GlassButtonStyle() -> some View {
        if #available(tvOS 26.0, *) {
            buttonStyle(.glass)
        } else {
            self
        }
    }

    @ViewBuilder
    func tvOS26GlassEffectContainer(spacing: CGFloat = 24) -> some View {
        if #available(tvOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                self
            }
        } else {
            self
        }
    }
}

private enum ControllerPanelLayoutConstants {
    static let horizontalPadding: CGFloat = 80
    static let bottomPadding: CGFloat = 60
    static let itemSpacing: CGFloat = 24
    static let sectionSpacing: CGFloat = 40
}

@MainActor
struct ControllerPanelViewTvOS: View {
    var geometry: GeometryProxy

    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var toastModel: PlayerToastModel
    @EnvironmentObject private var tvOSPlaybackControlModel: TVOSPlaybackControlModel
    @EnvironmentObject private var playerControlModel: PlayerControlModel

    @FocusState private var focusedItem: TVOSControlFocusItem?

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
    }

    private var hasSubtitleMenu: Bool {
        let hasEmbedded = !(playerCoordinator.controller?.sortByLanguageTracks(mediaType: .subtitle).isEmpty ?? true)
        return hasEmbedded || !playerControlModel.localSubtitleItems.isEmpty
    }

    private var hasAudioMenu: Bool {
        !(playerCoordinator.controller?.sortByLanguageTracks(mediaType: .audio).isEmpty ?? true)
    }

    private var hasVideoMenu: Bool {
        !(playerCoordinator.controller?.videoTracks.isEmpty ?? true)
    }

    var body: some View {
        ZStack {
            backgroundGradient
            controlContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            focusedItem = .progressSlider
        }
        .onChange(of: focusedItem) { oldValue, newValue in
            // 焦点切换视为用户操作：重置 3 秒倒计时而不是禁用自动隐藏，
            // 这样既保证用户在面板里导航时不会被中途收起，
            // 又能在停止操作后正常自动隐藏。
            if oldValue != newValue, playerMaskModel.isMaskShow {
                playerMaskModel.resetAutoHideTimer()
            }

            if oldValue == .progressSlider,
               newValue != .progressSlider,
               tvOSPlaybackControlModel.isSeeking
            {
                tvOSPlaybackControlModel.cancelSeeking(progress: playerCoordinator.progress) {
                    playerCoordinator.controller?.play()
                }
            }
        }
        .ignoresSafeArea()
    }

    private var backgroundGradient: some View {
        LinearGradient(
            gradient: Gradient(stops: [
                .init(color: Color.black.opacity(0.0001), location: 0.2),
                .init(color: Color.black.opacity(0.9), location: 0.99),
            ]),
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var controlContent: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            progressSection
                .padding(.horizontal, ControllerPanelLayoutConstants.horizontalPadding)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, ControllerPanelLayoutConstants.bottomPadding))
        }
    }

    private var progressSection: some View {
        VStack(alignment: .trailing, spacing: ControllerPanelLayoutConstants.sectionSpacing) {
            playbackControlButtons
            progressSlider
        }
    }

    private var progressSlider: some View {
        TVOSProgressSliderView(
            isFocused: focusedItem == .progressSlider,
            onMoveFocus: { direction in
                switch direction {
                case .up:
                    focusedItem = .rewindButton
                default:
                    break
                }
            }
        )
        .focused($focusedItem, equals: .progressSlider)
    }

    private var playbackControlButtons: some View {
        HStack(spacing: 0) {
            HStack(spacing: ControllerPanelLayoutConstants.itemSpacing) {
                rewindButton
                playPauseButton
                forwardButton
            }
            .tvOS26GlassEffectContainer(spacing: ControllerPanelLayoutConstants.itemSpacing)

            Spacer(minLength: ControllerPanelLayoutConstants.itemSpacing)

            HStack(spacing: ControllerPanelLayoutConstants.itemSpacing) {
                if hasSubtitleMenu {
                    SubtitleTracksMenu()
                        .focused($focusedItem, equals: .subtitleMenu)
                        .tvOS26GlassButtonStyle()
                }

                if hasAudioMenu {
                    AudioTracksMenu()
                        .focused($focusedItem, equals: .audioMenu)
                        .tvOS26GlassButtonStyle()
                }

                if hasVideoMenu {
                    VideoTracksMenu()
                        .focused($focusedItem, equals: .videoMenu)
                        .tvOS26GlassButtonStyle()
                }

                PlaybackRateMenu()
                    .focused($focusedItem, equals: .playbackRateMenu)
                    .tvOS26GlassButtonStyle()

                AspectFillButton()
                    .focused($focusedItem, equals: .scaleButton)
                    .tvOS26GlassButtonStyle()
            }
            .tvOS26GlassEffectContainer(spacing: ControllerPanelLayoutConstants.itemSpacing)
        }
    }

    private var rewindButton: some View {
        Button {
            playerCoordinator.controller?.skip(interval: -config.skipBackwardSeconds)
            toastModel.show(.skip(seconds: -config.skipBackwardSeconds))
        } label: {
            Image(systemName: "gobackward.\(config.skipBackwardSeconds)")
                .font(.system(size: 29, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
        .focused($focusedItem, equals: .rewindButton)
        .tvOS26GlassButtonStyle()
    }

    private var playPauseButton: some View {
        Button {
            playerCoordinator.controller?.switchPlayPause()
        } label: {
            Image(
                systemName: playerCoordinator.playbackState == .playing
                    ? "pause.fill"
                    : "play.fill"
            )
            .font(.system(size: 29, weight: .semibold))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
        .focused($focusedItem, equals: .playPauseButton)
        .tvOS26GlassButtonStyle()
    }

    private var forwardButton: some View {
        Button {
            playerCoordinator.controller?.skip(interval: config.skipForwardSeconds)
            toastModel.show(.skip(seconds: config.skipForwardSeconds))
        } label: {
            Image(systemName: "goforward.\(config.skipForwardSeconds)")
                .font(.system(size: 29, weight: .semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
        .focused($focusedItem, equals: .forwardButton)
        .tvOS26GlassButtonStyle()
    }
}
#endif
