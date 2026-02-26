import CinePlayerSDK
import Foundation
import SwiftUI
import Combine

@MainActor
final class VideoPlayerModel: ObservableObject {
    @Published var playerCoordinator = CinePlayer.Coordinator()
    @Published var config: CinePlayerConfig = .init()

    private(set) var sourceURL: URL?

    func open(url: URL) {
        sourceURL = url
        config.url = url
        config.startTime = 0
        config.autoPlay = true
    }

    func close() {
        playerCoordinator.controller?.shutdown()
        playerCoordinator.resetPlayer()
        sourceURL = nil
        config = .init()
    }
}
