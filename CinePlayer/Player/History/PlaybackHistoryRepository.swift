import Foundation
import SwiftData

enum PlaybackHistoryRepository {
    static let maxRecordCount = 200

    @MainActor
    static func ensureRecordExists(
        for source: PlayerSource,
        initialPlaybackTime: TimeInterval,
        totalDuration: TimeInterval,
        in context: ModelContext
    ) {
        if let existing = findRecord(for: source, in: context) {
            existing.playedAt = Date()
            save(context)
            return
        }

        let record = PlaybackHistoryRecord(
            sourceIdentifier: source.url.absoluteString,
            sourceURL: source.url.absoluteString,
            displayPath: source.url.isFileURL ? source.url.path : source.url.absoluteString,
            playedAt: Date(),
            initialPlaybackTime: initialPlaybackTime,
            totalDuration: totalDuration,
            bookmarkData: createBookmarkData(for: source.url),
            thumbnailData: nil
        )
        context.insert(record)
        pruneExcessRecords(in: context)
        save(context)
    }

    @MainActor
    static func saveThumbnailIfNeeded(
        for source: PlayerSource,
        thumbnailData: Data,
        in context: ModelContext
    ) {
        guard let record = findRecord(for: source, in: context), record.thumbnailData == nil else {
            return
        }
        record.thumbnailData = thumbnailData
        save(context)
    }

    @MainActor
    static func hasThumbnail(for source: PlayerSource, in context: ModelContext) -> Bool {
        findRecord(for: source, in: context)?.thumbnailData != nil
    }

    @MainActor
    static func updatePlaybackProgress(
        for source: PlayerSource,
        currentTime: TimeInterval,
        totalDuration: TimeInterval,
        in context: ModelContext
    ) {
        guard let record = findRecord(for: source, in: context) else {
            return
        }
        record.initialPlaybackTime = currentTime
        if totalDuration > 0 {
            record.totalDuration = totalDuration
        }
        save(context)
    }

    @MainActor
    static func delete(_ record: PlaybackHistoryRecord, in context: ModelContext) {
        context.delete(record)
        save(context)
    }

    @MainActor
    private static func findRecord(for source: PlayerSource, in context: ModelContext) -> PlaybackHistoryRecord? {
        let identifier = source.url.absoluteString
        let descriptor = FetchDescriptor<PlaybackHistoryRecord>(
            predicate: #Predicate { $0.sourceIdentifier == identifier }
        )
        return try? context.fetch(descriptor).first
    }

    @MainActor
    private static func pruneExcessRecords(in context: ModelContext) {
        var descriptor = FetchDescriptor<PlaybackHistoryRecord>(
            sortBy: [SortDescriptor(\PlaybackHistoryRecord.playedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1000

        guard let allRecords = try? context.fetch(descriptor), allRecords.count > maxRecordCount else {
            return
        }

        for record in allRecords.dropFirst(maxRecordCount) {
            context.delete(record)
        }
    }

    @MainActor
    private static func save(_ context: ModelContext) {
        do {
            try context.save()
        } catch {
            print("[PlaybackHistory] failed to save context: \(error.localizedDescription)")
        }
    }

    private static func createBookmarkData(for url: URL) -> Data? {
        guard url.isFileURL else {
            return nil
        }
        do {
            #if os(macOS)
            let options: URL.BookmarkCreationOptions = [.withSecurityScope]
            #else
            let options: URL.BookmarkCreationOptions = []
            #endif
            return try url.bookmarkData(
                options: options,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            return nil
        }
    }
}
