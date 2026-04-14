#if os(tvOS)
import CinePlayerSDK
import SwiftUI
import UIKit

enum TVOSControlFocusItem: Hashable {
    case subtitleMenu
    case audioMenu
    case videoMenu
    case playbackRateMenu
    case scaleButton
    case progressSlider
    case rewindButton
    case playPauseButton
    case forwardButton
}

struct TVOSProgressSliderView: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var playbackControlModel: TVOSPlaybackControlModel

    let isFocused: Bool
    let onMoveFocus: (MoveCommandDirection) -> Void

    var body: some View {
        VStack(spacing: 16) {
            PlayerSliderView(
                coordinator: playerCoordinator,
                progress: playerCoordinator.progress,
                isHovering: isFocused,
                isSeeking: playbackControlModel.isSeeking,
                seekingPreviewTime: playbackControlModel.previewCurrentTime,
                seekingTotalTime: playbackControlModel.previewTotalTime,
                onProgressEditingChanged: { _, _ in }
            )
            .frame(height: 44)
            .overlay {
                GestureViewTVOS(
                    swipeAction: handleSwipe,
                    pressAction: handlePress,
                    playPauseAction: handlePlayPause,
                    selectAction: handleSelect,
                    longPressAction: handleLongPress
                )
                .contentShape(Rectangle())
            }

            if playbackControlModel.showSeekingHint {
                Text("按选择键跳转")
                    .font(.system(size: 31, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
            }
        }
    }

    private func handleSwipe(_ direction: UISwipeGestureRecognizer.Direction) {
        playerMaskModel.resetAutoHideTimer()

        let seekSeconds = max(1, Int(playerCoordinator.progress.totalTime / 20))
        switch direction {
        case .left:
            withAnimation(.snappy(duration: 0.3)) {
                playbackControlModel.seekBackward(
                    seconds: seekSeconds,
                    wasPlaying: playerCoordinator.playbackState == .playing,
                    progress: playerCoordinator.progress
                ) {
                    playerCoordinator.controller?.pause()
                }
            }
        case .right:
            withAnimation(.snappy(duration: 0.3)) {
                playbackControlModel.seekForward(
                    seconds: seekSeconds,
                    wasPlaying: playerCoordinator.playbackState == .playing,
                    progress: playerCoordinator.progress
                ) {
                    playerCoordinator.controller?.pause()
                }
            }
        default:
            break
        }
    }

    private func handlePress(_ direction: UISwipeGestureRecognizer.Direction) {
        playerMaskModel.resetAutoHideTimer()

        if playbackControlModel.isSeeking {
            switch direction {
            case .left:
                playbackControlModel.seekBackward(
                    seconds: 5,
                    wasPlaying: playerCoordinator.playbackState == .playing,
                    progress: playerCoordinator.progress
                ) {
                    playerCoordinator.controller?.pause()
                }
            case .right:
                playbackControlModel.seekForward(
                    seconds: 5,
                    wasPlaying: playerCoordinator.playbackState == .playing,
                    progress: playerCoordinator.progress
                ) {
                    playerCoordinator.controller?.pause()
                }
            case .up, .down:
                playbackControlModel.cancelSeeking(progress: playerCoordinator.progress) {
                    playerCoordinator.controller?.play()
                }
            default:
                break
            }
            return
        }

        switch direction {
        case .left:
            playbackControlModel.seekBackward(
                seconds: 5,
                wasPlaying: playerCoordinator.playbackState == .playing,
                progress: playerCoordinator.progress
            ) {
                playerCoordinator.controller?.pause()
            }
        case .right:
            playbackControlModel.seekForward(
                seconds: 5,
                wasPlaying: playerCoordinator.playbackState == .playing,
                progress: playerCoordinator.progress
            ) {
                playerCoordinator.controller?.pause()
            }
        case .up:
            onMoveFocus(.up)
        case .down:
            break
        default:
            break
        }
    }

    private func handleSelect() {
        if playbackControlModel.isSeeking {
            playbackControlModel.performSeek { targetTime in
                playerCoordinator.controller?.seek(time: targetTime)
            } onEnd: {
                playerCoordinator.controller?.play()
            }
        }
    }

    private func handlePlayPause() {
        playerCoordinator.controller?.switchPlayPause()
    }

    private func handleLongPress(_ event: TVRemoteLongPressEvent) {
        switch event {
        case let .began(direction):
            guard direction == .left || direction == .right else {
                return
            }
            playbackControlModel.startLongPressSeeking(
                direction: direction,
                wasPlaying: playerCoordinator.playbackState == .playing,
                progress: playerCoordinator.progress
            ) {
                playerCoordinator.controller?.pause()
            }
        case let .ended(direction):
            if direction == .left || direction == .right {
                playbackControlModel.stopLongPressSeeking()
            }
        }
    }
}
#endif
