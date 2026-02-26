import Foundation
import SwiftUI
import Combine

@MainActor
final class PlayerSessionStore: ObservableObject {
    @Published var currentSource: PlayerSource?
    @Published var controlConfig: PlayerControlConfig = .default

    private var securityScopedURLs: [URL] = []

    func open(url: URL) {
        open(urls: [url], startAt: 0)
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
