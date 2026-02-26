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
        playerMaskModel.disableAutoHide()
        playerMaskModel.showMask()
    }

    func showControlPanelDelayed() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(GestureConstants.showMaskDelay))
            playerMaskModel.disableAutoHide()
            playerMaskModel.showMask()
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
