import Foundation
import CinePlayerSDK
import SwiftUI
import Combine

@MainActor
final class PlayerSessionStore: ObservableObject {
    static let shared = PlayerSessionStore()

    @Published var currentSource: PlayerSource?
    @Published var controlConfig: PlayerControlConfig

    private var securityScopedURLs: [URL] = []
    private var cancellables = Set<AnyCancellable>()

    private enum StorageKey {
        static let skipForwardSeconds = "player.control.skipForwardSeconds"
        static let skipBackwardSeconds = "player.control.skipBackwardSeconds"
        static let longPressSpeedUpEnabled = "player.control.longPressSpeedUpEnabled"
        static let longPressPlaybackRate = "player.control.longPressPlaybackRate"
        static let systemAudioPathEnabled = "player.control.systemAudioPathEnabled"
        static let subtitleTranslateMode = "player.control.subtitleTranslateMode"
        static let subtitleTranslationTargetLanguage = "player.control.subtitleTranslationTargetLanguage"
        static let subtitleTranslationOnTop = "player.control.subtitleTranslationOnTop"
    }

    init(defaults: UserDefaults = .standard) {
        var config = PlayerControlConfig.default
        if defaults.object(forKey: StorageKey.skipForwardSeconds) != nil {
            config.skipForwardSeconds = defaults.integer(forKey: StorageKey.skipForwardSeconds)
        }
        if defaults.object(forKey: StorageKey.skipBackwardSeconds) != nil {
            config.skipBackwardSeconds = defaults.integer(forKey: StorageKey.skipBackwardSeconds)
        }
        if defaults.object(forKey: StorageKey.longPressSpeedUpEnabled) != nil {
            config.longPressSpeedUpEnabled = defaults.bool(forKey: StorageKey.longPressSpeedUpEnabled)
        }
        if defaults.object(forKey: StorageKey.longPressPlaybackRate) != nil {
            config.longPressPlaybackRate = min(4, max(1.5, defaults.float(forKey: StorageKey.longPressPlaybackRate)))
        }
        config.systemAudioPathEnabled = defaults.object(forKey: StorageKey.systemAudioPathEnabled) as? Bool ?? true
        if SubtitleTranslationRouter.isAvailable,
           let value = defaults.string(forKey: StorageKey.subtitleTranslateMode),
           let mode = SubtitleTranslateMode(rawValue: value) {
            config.subtitleTranslateMode = mode
        }
        config.subtitleTranslationTargetLanguage = defaults.string(forKey: StorageKey.subtitleTranslationTargetLanguage) ?? ""
        if defaults.object(forKey: StorageKey.subtitleTranslationOnTop) != nil {
            config.subtitleTranslationOnTop = defaults.bool(forKey: StorageKey.subtitleTranslationOnTop)
        }
        self.controlConfig = config

        $controlConfig
            .removeDuplicates()
            .dropFirst()
            .sink { cfg in
                let d = defaults
                d.set(cfg.skipForwardSeconds, forKey: StorageKey.skipForwardSeconds)
                d.set(cfg.skipBackwardSeconds, forKey: StorageKey.skipBackwardSeconds)
                d.set(cfg.longPressSpeedUpEnabled, forKey: StorageKey.longPressSpeedUpEnabled)
                d.set(cfg.longPressPlaybackRate, forKey: StorageKey.longPressPlaybackRate)
                d.set(cfg.systemAudioPathEnabled, forKey: StorageKey.systemAudioPathEnabled)
                d.set(cfg.subtitleTranslateMode.rawValue, forKey: StorageKey.subtitleTranslateMode)
                d.set(cfg.subtitleTranslationTargetLanguage, forKey: StorageKey.subtitleTranslationTargetLanguage)
                d.set(cfg.subtitleTranslationOnTop, forKey: StorageKey.subtitleTranslationOnTop)
            }
            .store(in: &cancellables)
    }

    func open(url: URL, startTime: TimeInterval = 0) {
        open(sources: [PlayerSource(url: url, startTime: startTime)], startAt: 0)
    }

    func open(urls: [URL], startAt: Int = 0) {
        open(sources: urls.map { PlayerSource(url: $0) }, startAt: startAt)
    }

    func open(sources: [PlayerSource], startAt: Int = 0) {
        releaseSecurityScopedURLs()

        let preparedSources = prepareSourcesForPlayback(sources)
        guard !preparedSources.isEmpty else {
            close()
            return
        }

        let clampedIndex = min(max(startAt, 0), preparedSources.count - 1)
        currentSource = preparedSources[clampedIndex]
    }

    func close() {
        currentSource = nil
        releaseSecurityScopedURLs()
    }

    private func prepareSourcesForPlayback(_ sources: [PlayerSource]) -> [PlayerSource] {
        var result: [PlayerSource] = []
        var secured: [URL] = []

        for source in sources {
            let fileURL = source.url
            guard fileURL.isFileURL else {
                result.append(source)
                continue
            }

            let hasSecurityAccess = fileURL.startAccessingSecurityScopedResource()
            let isReadable =
                FileManager.default.fileExists(atPath: fileURL.path)
                    && FileManager.default.isReadableFile(atPath: fileURL.path)

            guard isReadable else {
                if hasSecurityAccess {
                    fileURL.stopAccessingSecurityScopedResource()
                }
                continue
            }

            if hasSecurityAccess {
                secured.append(fileURL)
            }
            result.append(source)
        }

        securityScopedURLs = secured
        return result
    }

    private func releaseSecurityScopedURLs() {
        guard !securityScopedURLs.isEmpty else {
            return
        }
        for url in securityScopedURLs {
            url.stopAccessingSecurityScopedResource()
        }
        securityScopedURLs.removeAll(keepingCapacity: false)
    }
}
