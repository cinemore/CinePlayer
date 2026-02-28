import Foundation

struct PlayerSource: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL
    let startTime: TimeInterval

    var displayName: String {
        if url.isFileURL {
            return url.lastPathComponent
        }
        return url.absoluteString
    }

    init(url: URL, startTime: TimeInterval = 0) {
        self.url = url
        self.startTime = max(0, startTime)
    }
}
