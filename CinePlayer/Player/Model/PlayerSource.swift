import Foundation

struct PlayerSource: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: URL

    var displayName: String {
        if url.isFileURL {
            return url.lastPathComponent
        }
        return url.absoluteString
    }
}
