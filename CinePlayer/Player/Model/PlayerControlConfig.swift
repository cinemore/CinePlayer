import Foundation
import CinePlayerSDK

struct PlayerControlConfig: Equatable, Sendable {
    var skipForwardSeconds: Int = 10
    var skipBackwardSeconds: Int = 10
    var longPressSpeedUpEnabled: Bool = true
    var subtitleTranslateMode: SubtitleTranslateMode = .off
    var longPressPlaybackRate: Float = 2.0
    var macOSPlaybackRateStep: Float = 0.05
    var tvOSSwipeSkipMultiplier: Double = 2.0
    var tvOSContinuousSeekStep: Int = 3
    var tvOSContinuousSeekTick: TimeInterval = 0.2

    static let `default` = PlayerControlConfig()
}
