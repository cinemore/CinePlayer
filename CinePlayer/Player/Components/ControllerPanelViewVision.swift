import CinePlayerSDK
import SwiftUI

#if os(visionOS)
@MainActor
struct ControllerPanelViewVision: View {
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

    var body: some View {
        ZStack {
            // 点击面板空白处收起控件，与 iOS 上 singleTap 行为一致。
            // 放在 ZStack 最底层，让上层 Button / Slider 优先接管自身点击。
            LinearGradient(
                colors: [
                    Color.black.opacity(0.56),
                    Color.clear,
                    Color.black.opacity(0.64)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .contentShape(Rectangle())
            .onTapGesture {
                playerMaskModel.hideMask()
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 40)
                    .padding(.top, max(geometry.safeAreaInsets.top, 32))

                Spacer()

                bottomBar
                    .padding(.horizontal, 40)
                    .padding(.bottom, max(geometry.safeAreaInsets.bottom, 32))
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            PlayerCloseButton {
                playerModel.close()
                sessionStore.close()
            }

            PlayerTitleView(title: sessionStore.currentSource?.displayName ?? "")

            Spacer()

            actionButton(icon: "wand.and.rays") {
                playerControlModel.hideContainer()
                playerControlModel.showEnhancementContainer = true
            }

            actionButton(icon: "info.circle") {
                playerMaskModel.hideMask()
                playerControlModel.hideContainer()
                playerControlModel.showMediaInfoCard.toggle()
            }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 12) {
            PlayerSliderView(
                coordinator: playerCoordinator,
                progress: playerCoordinator.progress,
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
            .frame(height: 36)

            HStack(spacing: 12) {
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

                actionButton(icon: "rectangle.arrowtriangle.2.inward") {
                    playerCoordinator.isScaleAspectFill.toggle()
                }
            }
        }
    }

    private func actionButton(icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .f14m()
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(GlassEffectModifier(cornerRadius: 20))
    }
}
#endif
