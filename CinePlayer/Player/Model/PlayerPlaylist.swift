import Foundation

struct PlayerPlaylist: Equatable, Sendable {
    private(set) var sources: [PlayerSource]
    private(set) var currentIndex: Int

    init(sources: [PlayerSource], currentIndex: Int = 0) {
        self.sources = sources
        if sources.isEmpty {
            self.currentIndex = 0
        } else {
            self.currentIndex = min(max(currentIndex, 0), sources.count - 1)
        }
    }

    static var empty: PlayerPlaylist {
        PlayerPlaylist(sources: [])
    }

    var currentSource: PlayerSource? {
        guard sources.indices.contains(currentIndex) else {
            return nil
        }
        return sources[currentIndex]
    }

    var hasPrevious: Bool {
        currentIndex > 0
    }

    var hasNext: Bool {
        currentIndex + 1 < sources.count
    }

    @discardableResult
    mutating func moveToPrevious() -> PlayerSource? {
        guard hasPrevious else {
            return nil
        }
        currentIndex -= 1
        return currentSource
    }

    @discardableResult
    mutating func moveToNext() -> PlayerSource? {
        guard hasNext else {
            return nil
        }
        currentIndex += 1
        return currentSource
    }

    @discardableResult
    mutating func select(index: Int) -> PlayerSource? {
        guard sources.indices.contains(index) else {
            return nil
        }
        currentIndex = index
        return currentSource
    }
}
