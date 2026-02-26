import CinePlayerSDK
import SwiftUI

#if os(tvOS)
@MainActor
struct ControllerPanelViewTvOS: View {
    var geometry: GeometryProxy

    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var toastModel: PlayerToastModel

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.horizontal, 20)
                .padding(.top, max(geometry.safeAreaInsets.top, 20))

            Spacer()

            bottomBar
                .padding(.horizontal, 20)
                .padding(.bottom, max(geometry.safeAreaInsets.bottom, 20))
        }
        .background(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.60),
                    Color.clear,
                    Color.black.opacity(0.70)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
    }

    private var topBar: some View {
        HStack(spacing: 16) {
            PlayerTitleView(title: sessionStore.currentSource?.displayName ?? "")
            Spacer()

            actionButton(icon: "music.note") {
                playerControlModel.hideContainer()
                playerControlModel.showAudioContainer = true
            }

            actionButton(icon: "film") {
                playerControlModel.hideContainer()
                playerControlModel.showVideoTrackContainer = true
            }

            actionButton(icon: "speedometer") {
                playerControlModel.hideContainer()
                playerControlModel.showPlaybackSpeedContainer = true
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 16) {
            PlayerSliderView(
                coordinator: playerCoordinator,
                progress: playerCoordinator.progress,
                isHovering: true,
                onProgressEditingChanged: { editing, seconds in
                    if editing {
                        playerMaskModel.pauseTimer()
                        playerCoordinator.controller?.pause()
                    } else {
                        playerMaskModel.restartTimer()
                        playerCoordinator.controller?.seek(time: TimeInterval(seconds))
                    }
                }
            )
            .frame(height: 40)

            HStack(spacing: 16) {
                actionButton(icon: "gobackward.\(config.skipBackwardSeconds)") {
                    playerCoordinator.controller?.skip(interval: -config.skipBackwardSeconds)
                    toastModel.show(.skip(seconds: -config.skipBackwardSeconds))
                }

                actionButton(icon: playerCoordinator.playbackState == .playing ? "pause.fill" : "play.fill") {
                    playerCoordinator.controller?.switchPlayPause()
                }

                actionButton(icon: "goforward.\(config.skipForwardSeconds)") {
                    playerCoordinator.controller?.skip(interval: config.skipForwardSeconds)
                    toastModel.show(.skip(seconds: config.skipForwardSeconds))
                }

                Spacer(minLength: 0)

                actionButton(icon: "rectangle.arrowtriangle.2.inward") {
                    playerCoordinator.isScaleAspectFill.toggle()
                }
            }
        }
    }

    private func actionButton(icon: String, isDisabled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .f14m()
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .modifier(GlassEffectModifier(cornerRadius: 26))
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.45 : 1)
    }
}
#endif
