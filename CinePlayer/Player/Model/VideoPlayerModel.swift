import CinePlayerSDK
import Foundation
import SwiftUI
import Combine

@MainActor
final class VideoPlayerModel: ObservableObject {
    let translationRuntime = SubtitleTranslationRuntime()
    let translationRouter: SubtitleTranslationRouter

    @Published var playerCoordinator = CinePlayer.Coordinator()
    @Published var config: CinePlayerConfig = .init()

    private(set) var sourceURL: URL?

    init() {
        translationRouter = SubtitleTranslationRouter(runtime: translationRuntime)
    }

    func open(url: URL, controlConfig: PlayerControlConfig) {
        sourceURL = url
        config.url = url
        config.startTime = 0
        config.autoPlay = true
        configureSubtitleTranslate(for: config, mode: controlConfig.subtitleTranslateMode)
    }

    func close() {
        playerCoordinator.controller?.shutdown()
        playerCoordinator.resetPlayer()
        sourceURL = nil
        translationRuntime.desiredApplePair = nil
        Task { [translationRouter] in
            await translationRouter.applySettings(mode: .off)
        }
        config = .init()
    }

    func applySubtitleTranslationSettings(mode: SubtitleTranslateMode) {
        config.subtitleTranslateMode = mode
        Task { [translationRouter] in
            await translationRouter.applySettings(mode: mode)
        }
    }

    private func configureSubtitleTranslate(for options: CinePlayerConfig, mode: SubtitleTranslateMode) {
        options.subtitleTranslateMode = mode
        let router = translationRouter
        options.subtitleTranslate = { text, from, to in
            try await router.translate(text: text, from: from, to: to)
        }
        Task { [translationRouter] in
            await translationRouter.applySettings(mode: mode)
        }
    }
}
