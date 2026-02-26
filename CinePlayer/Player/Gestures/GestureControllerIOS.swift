import SwiftUI

#if os(iOS)
import CinePlayerSDK
import UIKit

@MainActor
struct GestureController: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var toastModel: PlayerToastModel

    @Binding var brightness: CGFloat
    var geometry: GeometryProxy

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
    }

    var body: some View {
        GestureViewIOS(
            progress: playerCoordinator.progress,
            safeAreaInsets: geometry.safeAreaInsets,
            onProgressChanged: { _ in
                playerCoordinator.controller?.pause()
                toastModel.show(.progressChanged, duration: .infinity)
            },
            onProgressEnded: { _ in
                playerCoordinator.controller?.seek(time: TimeInterval(playerCoordinator.progress.currentTime))
                toastModel.hide()
            },
            onBrightnessChanged: { brightnessValue in
                if let brightnessValue {
                    brightness = brightnessValue
                    toastModel.show(.brightness(value: brightnessValue), duration: .infinity)
                } else {
                    toastModel.hide()
                }
            },
            action: { action in
                switch action {
                case .leftDoubleTap:
                    let skipSeconds = config.skipBackwardSeconds
                    playerCoordinator.controller?.skip(interval: -skipSeconds)
                    toastModel.show(.skip(seconds: -skipSeconds), duration: .infinity)
                case .rightDoubleTap:
                    let skipSeconds = config.skipForwardSeconds
                    playerCoordinator.controller?.skip(interval: skipSeconds)
                    toastModel.show(.skip(seconds: skipSeconds), duration: .infinity)
                case .doubleTapEnd:
                    if let presentedToast = toastModel.presentedToast,
                       presentedToast.id == "skip_\(-config.skipBackwardSeconds)"
                        || presentedToast.id == "skip_\(config.skipForwardSeconds)"
                    {
                        toastModel.hide()
                    }
                case .centerDoubleTap:
                    playerMaskModel.showMask()
                    playerCoordinator.controller?.switchPlayPause()
                case .singleTap:
                    playerControlModel.hideContainer()
                    playerMaskModel.toggleMask()
                case .longPressBegan:
                    guard config.longPressSpeedUpEnabled else {
                        return
                    }
                    playerCoordinator.playbackRate = config.longPressPlaybackRate
                    toastModel.show(.playbackRate, duration: .infinity)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                case .longPressEnded:
                    guard config.longPressSpeedUpEnabled else {
                        return
                    }
                    playerCoordinator.playbackRate = 1.0
                    toastModel.hide()
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        )
    }
}
#endif
