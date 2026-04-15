import SwiftUI

#if os(tvOS)
import CinePlayerSDK
import UIKit

private enum GestureConstants {
    static let showMaskDelay: TimeInterval = 0.18
}

@MainActor
struct GestureController: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var toastModel: PlayerToastModel
    @EnvironmentObject private var tvOSPlaybackControlModel: TVOSPlaybackControlModel

    @State private var continuousSeekTask: Task<Void, Never>?
    @State private var continuousSeekDirection: UISwipeGestureRecognizer.Direction?

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
    }

    var body: some View {
        GestureViewTVOS(
            swipeAction: handleSwipe,
            pressAction: handlePress,
            playPauseAction: handlePlayPause,
            selectAction: handleSelect,
            pageAction: handlePage,
            longPressAction: handleLongPress
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
        .onDisappear {
            stopContinuousSeek()
        }
    }
}

private extension GestureController {
    func handleSwipe(_ direction: UISwipeGestureRecognizer.Direction) {
        guard !playerMaskModel.isMaskShow else {
            return
        }

        switch direction {
        case .left:
            let seconds = Int(Double(config.skipBackwardSeconds) * config.tvOSSwipeSkipMultiplier)
            playerCoordinator.controller?.skip(interval: -seconds)
            toastModel.show(.skip(seconds: -seconds))
        case .right:
            let seconds = Int(Double(config.skipForwardSeconds) * config.tvOSSwipeSkipMultiplier)
            playerCoordinator.controller?.skip(interval: seconds)
            toastModel.show(.skip(seconds: seconds))
        case .up:
            showControlPanelDelayed()
        case .down:
            break
        default:
            break
        }
    }

    func handlePress(_ direction: UISwipeGestureRecognizer.Direction) {
        guard !playerMaskModel.isMaskShow else {
            return
        }

        switch direction {
        case .up, .down:
            showControlPanelDelayed()
        case .left:
            playerCoordinator.controller?.skip(interval: -config.skipBackwardSeconds)
            toastModel.show(.skip(seconds: -config.skipBackwardSeconds))
        case .right:
            playerCoordinator.controller?.skip(interval: config.skipForwardSeconds)
            toastModel.show(.skip(seconds: config.skipForwardSeconds))
        default:
            break
        }
    }

    func handlePage(_ event: TVRemotePageEvent) {
        switch event {
        case .pageUp:
            break
        case .pageDown:
            break
        }
    }

    func handleLongPress(_ event: TVRemoteLongPressEvent) {
        guard !playerMaskModel.isMaskShow else {
            return
        }

        switch event {
        case let .began(direction):
            beginContinuousSeek(direction: direction)
        case let .ended(direction):
            stopContinuousSeek(expectedDirection: direction)
        }
    }

    func handlePlayPause() {
        playerCoordinator.controller?.switchPlayPause()
    }

    func handleSelect() {
        if playerMaskModel.isMaskShow {
            return
        }
        // 用户主动按下 Select 唤起面板，关闭自动隐藏，避免打断操作；
        // 后续由 .onExitCommand 中的 enableAutoHide()+hideMask() 恢复默认行为。
        playerMaskModel.disableAutoHide()
    }

    func showControlPanelDelayed() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(GestureConstants.showMaskDelay))
            guard !tvOSPlaybackControlModel.isSeeking else {
                return
            }
            // 用户主动通过上/下滑动或按键唤起面板，与 handleSelect 同样关闭自动隐藏。
            playerMaskModel.disableAutoHide()
        }
    }

    func beginContinuousSeek(direction: UISwipeGestureRecognizer.Direction) {
        guard direction == .left || direction == .right else {
            return
        }

        if continuousSeekDirection == direction {
            return
        }

        stopContinuousSeek()
        continuousSeekDirection = direction

        let seekStep = direction == .right ? config.tvOSContinuousSeekStep : -config.tvOSContinuousSeekStep
        toastModel.showContinuousSeek(seconds: 0)

        continuousSeekTask = Task { @MainActor in
            var accumulatedSeconds = 0
            while !Task.isCancelled {
                playerCoordinator.controller?.skip(interval: seekStep)
                accumulatedSeconds += seekStep
                toastModel.showContinuousSeek(seconds: accumulatedSeconds)
                try? await Task.sleep(for: .seconds(config.tvOSContinuousSeekTick))
            }
        }
    }

    func stopContinuousSeek(expectedDirection: UISwipeGestureRecognizer.Direction? = nil) {
        if let expectedDirection,
           let currentDirection = continuousSeekDirection,
           expectedDirection != currentDirection
        {
            return
        }

        continuousSeekTask?.cancel()
        continuousSeekTask = nil
        continuousSeekDirection = nil
        toastModel.hide()
    }
}
#endif
