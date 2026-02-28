import Foundation
import SwiftData

@Model
final class PlaybackHistoryRecord {
    @Attribute(.unique) var sourceIdentifier: String
    var sourceURL: String
    var displayPath: String
    var playedAt: Date
    var initialPlaybackTime: TimeInterval = 0
    var totalDuration: TimeInterval = 0
    @Attribute(.externalStorage) var bookmarkData: Data?
    @Attribute(.externalStorage) var thumbnailData: Data?

    init(
        sourceIdentifier: String,
        sourceURL: String,
        displayPath: String,
        playedAt: Date,
        initialPlaybackTime: TimeInterval = 0,
        totalDuration: TimeInterval = 0,
        bookmarkData: Data? = nil,
        thumbnailData: Data?
    ) {
        self.sourceIdentifier = sourceIdentifier
        self.sourceURL = sourceURL
        self.displayPath = displayPath
        self.playedAt = playedAt
        self.initialPlaybackTime = initialPlaybackTime
        self.totalDuration = totalDuration
        self.bookmarkData = bookmarkData
        self.thumbnailData = thumbnailData
    }
}
