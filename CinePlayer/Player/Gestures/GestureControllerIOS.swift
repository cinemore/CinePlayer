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
    @Environment(\.hasSeparatedPlayerControls) private var hasSeparatedPlayerControls
    @State private var scrubPlayback = PlayerScrubPlaybackSession()
    @State private var rateBeforeLongPress: Float?
    @State private var rateMediaIdentifier: UUID?

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
                scrubPlayback.begin(controller: playerCoordinator.controller)
                toastModel.show(.progressChanged, duration: .infinity)
            },
            onProgressEnded: { _ in
                scrubPlayback.commit(time: TimeInterval(playerCoordinator.progress.currentTime), controller: playerCoordinator.controller)
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
                    playerCoordinator.controller?.togglePlaybackFromControls()
                case .singleTap:
                    playerControlModel.hideContainer()
                    playerMaskModel.toggleMask()
                case .longPressBegan:
                    guard config.longPressSpeedUpEnabled, rateBeforeLongPress == nil,
                          let controller = playerCoordinator.controller else {
                        return
                    }
                    rateBeforeLongPress = playerCoordinator.playbackRate
                    rateMediaIdentifier = controller.mediaIdentifier
                    playerCoordinator.playbackRate = config.longPressPlaybackRate
                    toastModel.show(.playbackRate, duration: .infinity)
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                case .longPressEnded:
                    restoreLongPressRate()
                    toastModel.hide()
                    let generator = UIImpactFeedbackGenerator(style: .light)
                    generator.impactOccurred()
                }
            }
        )
        .id(playerCoordinator.controller?.mediaIdentifier)
        .allowsHitTesting(!hasSeparatedPlayerControls)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("显示播放控制")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { playerMaskModel.disableAutoHide() }
        .accessibilityAction(named: Text("播放或暂停")) { playerCoordinator.controller?.togglePlaybackFromControls() }
        .onDisappear { restoreLongPressRate(); scrubPlayback.reset() }
        .onChange(of: playerCoordinator.controller?.mediaIdentifier) { _, _ in
            rateBeforeLongPress = nil
            rateMediaIdentifier = nil
            scrubPlayback.reset()
        }
    }

    private func restoreLongPressRate() {
        if let rateBeforeLongPress, playerCoordinator.controller?.mediaIdentifier == rateMediaIdentifier {
            playerCoordinator.playbackRate = rateBeforeLongPress
        }
        rateBeforeLongPress = nil
        rateMediaIdentifier = nil
    }
}
#endif
