import Foundation
import ImageIO
import SwiftData
import SwiftUI

struct PlaybackHistoryListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: PlayerSessionStore

    @Query(sort: \PlaybackHistoryRecord.playedAt, order: .reverse)
    private var records: [PlaybackHistoryRecord]

    @State private var isEditing = false
    @State private var selectedRecordIDs = Set<PersistentIdentifier>()
    @State private var missingFileAlertRecord: PlaybackHistoryRecord?
    @State private var isShowingMissingFileAlert = false

    var body: some View {
        List(selection: isEditing ? $selectedRecordIDs : nil) {
            ForEach(records) { record in
                if isEditing {
                    rowContent(for: record)
                    #if os(macOS)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            toggleSelection(for: record.persistentModelID)
                        }
                    #else
                        .tag(record.persistentModelID)
                    #endif
                        .contextMenu {
                            #if os(macOS)
                            Button("删除", role: .destructive) {
                                PlaybackHistoryRepository.delete(record, in: modelContext)
                                selectedRecordIDs.remove(record.persistentModelID)
                            }
                            #endif
                        }
                } else {
                    rowContent(for: record)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            reopen(record: record)
                        }
                        .contextMenu {
                            #if os(macOS)
                            Button("删除", role: .destructive) {
                                PlaybackHistoryRepository.delete(record, in: modelContext)
                                selectedRecordIDs.remove(record.persistentModelID)
                            }
                            #endif
                        }
                }
            }
            .if(!isEditing) {
                $0.onDelete(perform: delete)
            }
        }
        .navigationTitle("历史记录")
        #if os(iOS)
            .environment(\.editMode, .constant(isEditing ? .active : .inactive))
            .navigationBarTitleDisplayMode(.large)
        #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    if !records.isEmpty {
                        editToggleButton
                    }
                }

                #if os(iOS)
                if isEditing {
                    ToolbarItemGroup(placement: .bottomBar) {
                        Button("全选") {
                            selectedRecordIDs = Set(records.map(\.persistentModelID))
                        }
                        .disabled(records.isEmpty)

                        Button("取消") {
                            selectedRecordIDs.removeAll()
                        }
                        .disabled(selectedRecordIDs.isEmpty)

                        Spacer(minLength: 0)

                        Button(role: .destructive) {
                            deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                        .disabled(selectedRecordIDs.isEmpty)
                    }
                }
                #elseif os(tvOS) || os(visionOS)
                if isEditing {
                    ToolbarItemGroup(placement: .automatic) {
                        Button("全选") {
                            selectedRecordIDs = Set(records.map(\.persistentModelID))
                        }
                        .disabled(records.isEmpty)

                        Button("取消") {
                            selectedRecordIDs.removeAll()
                        }
                        .disabled(selectedRecordIDs.isEmpty)

                        Button(role: .destructive) {
                            deleteSelected()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .tint(.red)
                        .disabled(selectedRecordIDs.isEmpty)
                    }
                }
                #endif
            }
        #if os(iOS)
            .toolbar(isEditing ? .hidden : .visible, for: .tabBar)
        #endif
        #if os(macOS)
            .safeAreaInset(edge: .bottom) {
                if isEditing {
                    bottomSelectionBar
                }
        }
        #endif
        .overlay {
            if records.isEmpty {
                ContentUnavailableView(
                    "暂无历史记录",
                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                )
            }
        }
        .alert(
            "文件不存在",
            isPresented: $isShowingMissingFileAlert,
            presenting: missingFileAlertRecord
        ) { record in
            Button("删除", role: .destructive) {
                PlaybackHistoryRepository.delete(record, in: modelContext)
                selectedRecordIDs.remove(record.persistentModelID)
            }
            Button("取消", role: .cancel) {}
        } message: { _ in
            Text("原始文件已被删除或移动，无法播放。是否从历史记录中删除这条记录？")
        }
        .onChange(of: records.count) {
            selectedRecordIDs = selectedRecordIDs.filter { id in
                records.contains(where: { $0.persistentModelID == id })
            }
            if records.isEmpty {
                isEditing = false
            }
        }
    }

    private var editToggleButton: some View {
        Button(isEditing ? "完成" : "编辑") {
            if isEditing {
                selectedRecordIDs.removeAll()
            }
            isEditing.toggle()
        }
    }

    private var bottomSelectionBar: some View {
        HStack(spacing: 16) {
            Button("全选") {
                selectedRecordIDs = Set(records.map(\.persistentModelID))
            }
            .disabled(records.isEmpty)

            Button("取消") {
                selectedRecordIDs.removeAll()
            }
            .disabled(selectedRecordIDs.isEmpty)

            Spacer(minLength: 0)

            Button("删除", role: .destructive) {
                deleteSelected()
            }
            .tint(.red)
            .disabled(selectedRecordIDs.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private func rowContent(for record: PlaybackHistoryRecord) -> some View {
        HStack(spacing: 12) {
            #if os(macOS)
            if isEditing {
                Image(systemName: selectedRecordIDs.contains(record.persistentModelID) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selectedRecordIDs.contains(record.persistentModelID) ? Color.accentColor : Color.secondary)
                    .font(.system(size: 16, weight: .regular))
            }
            #endif
            thumbnailView(for: record)

            VStack(alignment: .leading, spacing: 4) {
                Text(historyDisplayTitle(for: record))
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .truncationMode(usesMiddleTruncation(for: record) ? .middle : .tail)
                    .multilineTextAlignment(.leading)

                Text(record.playedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text("\(record.initialPlaybackTime.toString(for: .minOrHour))/\(record.totalDuration.toString(for: .minOrHour))")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func thumbnailView(for record: PlaybackHistoryRecord) -> some View {
        if let image = decodeImage(data: record.thumbnailData) {
            image
                .resizable()
                .scaledToFill()
                .frame(width: 88, height: 50)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(.secondary.opacity(0.2))
                .frame(width: 88, height: 50)
                .overlay {
                    Image(systemName: "film")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
        }
    }

    private func deleteSelected() {
        let targets = records.filter { selectedRecordIDs.contains($0.persistentModelID) }
        for record in targets {
            PlaybackHistoryRepository.delete(record, in: modelContext)
        }
        selectedRecordIDs.removeAll()
    }

    private func toggleSelection(for id: PersistentIdentifier) {
        if selectedRecordIDs.contains(id) {
            selectedRecordIDs.remove(id)
        } else {
            selectedRecordIDs.insert(id)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            PlaybackHistoryRepository.delete(records[index], in: modelContext)
        }
    }

    private func reopen(record: PlaybackHistoryRecord) {
        if isMissingLocalFile(record: record) {
            missingFileAlertRecord = record
            isShowingMissingFileAlert = true
            return
        }

        guard let url = resolveURL(for: record) else {
            return
        }
        sessionStore.open(url: url, startTime: record.initialPlaybackTime)
    }

    private func isMissingLocalFile(record: PlaybackHistoryRecord) -> Bool {
        guard
            let sourceURL = URL(string: record.sourceURL),
            sourceURL.isFileURL
        else {
            return false
        }

        let path = record.displayPath.isEmpty ? sourceURL.path : record.displayPath
        return !FileManager.default.fileExists(atPath: path)
    }

    private func resolveURL(for record: PlaybackHistoryRecord) -> URL? {
        if let bookmarkData = record.bookmarkData {
            var isStale = false
            #if os(macOS)
            let options: URL.BookmarkResolutionOptions = [.withSecurityScope, .withoutUI]
            #else
            let options: URL.BookmarkResolutionOptions = [.withoutUI]
            #endif
            if let bookmarkedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: options,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return bookmarkedURL
            }
        }
        if let url = URL(string: record.sourceURL) {
            return url
        }
        if !record.displayPath.isEmpty {
            return URL(fileURLWithPath: record.displayPath)
        }
        return nil
    }

    private func historyDisplayTitle(for record: PlaybackHistoryRecord) -> String {
        if let sourceURL = URL(string: record.sourceURL), sourceURL.isFileURL {
            if !record.displayPath.isEmpty {
                let fileName = (record.displayPath as NSString).lastPathComponent
                return fileName.isEmpty ? record.displayPath : fileName
            }
            return sourceURL.lastPathComponent
        }

        if let sourceURL = URL(string: record.sourceURL) {
            let scheme = sourceURL.scheme?.lowercased()
            if scheme == "http" || scheme == "https" {
                return record.displayPath.isEmpty ? sourceURL.absoluteString : record.displayPath
            }
        }

        if !record.displayPath.isEmpty {
            let fileName = (record.displayPath as NSString).lastPathComponent
            return fileName.isEmpty ? record.displayPath : fileName
        }

        return record.sourceURL
    }

    private func usesMiddleTruncation(for record: PlaybackHistoryRecord) -> Bool {
        if let sourceURL = URL(string: record.sourceURL) {
            let scheme = sourceURL.scheme?.lowercased()
            return scheme == "http" || scheme == "https"
        }
        return record.displayPath.lowercased().hasPrefix("http://")
            || record.displayPath.lowercased().hasPrefix("https://")
    }

    private func decodeImage(data: Data?) -> Image? {
        guard
            let data,
            let source = CGImageSourceCreateWithData(data as CFData, nil),
            let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        #if os(macOS)
        return Image(decorative: cgImage, scale: 1)
        #else
        return Image(decorative: cgImage, scale: 1, orientation: .up)
        #endif
    }
}
