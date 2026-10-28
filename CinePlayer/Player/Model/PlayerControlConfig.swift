import Foundation
import CinePlayerSDK

nonisolated struct PlayerControlConfig: Equatable, Sendable {
    var skipForwardSeconds: Int = 10
    var skipBackwardSeconds: Int = 10
    var longPressSpeedUpEnabled: Bool = true
    var subtitleTranslateMode: SubtitleTranslateMode = .off
    var subtitleTranslationTargetLanguage = ""
    var subtitleTranslationOnTop = true
    var longPressPlaybackRate: Float = 2.0
    var macOSPlaybackRateStep: Float = 0.05
    var tvOSSwipeSkipMultiplier: Double = 2.0
    var tvOSContinuousSeekStep: Int = 3
    var tvOSContinuousSeekTick: TimeInterval = 0.2

    static let `default` = PlayerControlConfig()

    var resolvedSubtitleTranslationTargetLanguage: String {
        subtitleTranslationTargetLanguage.isEmpty
            ? Locale.preferredLanguages.first ?? "en" : subtitleTranslationTargetLanguage
    }

    static let subtitleTranslationTargetLanguages = [
        "zh-Hans", "zh-Hant", "en", "ja", "ko", "fr", "de", "es", "pt", "it",
        "ru", "ar", "hi", "th", "vi", "id", "tr", "uk", "pl", "nl"
    ]
}
