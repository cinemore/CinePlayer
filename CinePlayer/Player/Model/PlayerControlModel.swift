import Foundation
import CinePlayerSDK
import SwiftUI
import Combine

@MainActor
final class PlayerControlModel: ObservableObject {
    @Published var showAudioContainer = false
    @Published var showVideoTrackContainer = false
    @Published var showPlaybackSpeedContainer = false
    @Published var showSubtitleContainer = false
    @Published var subtitleTab = 0
    @Published var showSettingContainer = false
    @Published var showEnhancementContainer = false
    @Published var showMediaInfoCard = false
    @Published var localSubtitleItems: [LocalSubtitleItem] = []
    @Published var currentSubtitlePath = ""
    @Published private(set) var pendingLocalSubtitleID: String?
    @Published var subtitleOperationError: String?
    private var subtitleLoadTask: Task<Void, Never>?
    private var subtitleSelectionRevision = 0

    struct LocalSubtitleItem: Identifiable, Equatable {
        let id: String
        let url: URL
        let displayName: String
        let sizeDescription: String
    }

    var isSiderContainerShow: Bool {
        showAudioContainer
            || showVideoTrackContainer
            || showPlaybackSpeedContainer
            || showSubtitleContainer
            || showSettingContainer
            || showEnhancementContainer
    }

    func hideContainer() {
        withAnimation {
            showAudioContainer = false
            showVideoTrackContainer = false
            showPlaybackSpeedContainer = false
            showSubtitleContainer = false
            showSettingContainer = false
            showEnhancementContainer = false
        }
    }

    func addLocalSubtitle(_ item: LocalSubtitleItem) {
        if !localSubtitleItems.contains(where: { $0.id == item.id }) {
            localSubtitleItems.append(item)
        }
    }

    func cancelSubtitleLoad() {
        subtitleSelectionRevision &+= 1
        subtitleLoadTask?.cancel()
        subtitleLoadTask = nil
        pendingLocalSubtitleID = nil
    }

    func selectLocalSubtitle(_ item: LocalSubtitleItem, controller: PlayerController?) {
        cancelSubtitleLoad()
        subtitleOperationError = nil
        guard let controller else { return }
        // SDK 会在加载前撤下旧字幕；界面也先清空，失败时不能继续勾选旧条目。
        currentSubtitlePath = ""
        let revision = subtitleSelectionRevision
        let mediaID = controller.mediaIdentifier
        pendingLocalSubtitleID = item.id
        subtitleLoadTask = Task { @MainActor [weak self] in
            do {
                try await controller.loadSubtitleFile(subtitleID: item.id, url: item.url)
                guard let self, !Task.isCancelled, subtitleSelectionRevision == revision,
                      controller.mediaIdentifier == mediaID else { return }
                currentSubtitlePath = item.id
                pendingLocalSubtitleID = nil
                subtitleLoadTask = nil
            } catch {
                guard let self, !Task.isCancelled, subtitleSelectionRevision == revision,
                      controller.mediaIdentifier == mediaID else { return }
                pendingLocalSubtitleID = nil
                subtitleLoadTask = nil
                if !(error is CancellationError) { subtitleOperationError = error.localizedDescription }
            }
        }
    }

    func selectEmbeddedSubtitle(_ index: Int32, controller: PlayerController?) {
        cancelSubtitleLoad()
        currentSubtitlePath = ""
        controller?.loadSubtitleTrack(subtitlesTrackIndex: index)
    }

    func clearSubtitle(controller: PlayerController?) {
        cancelSubtitleLoad()
        currentSubtitlePath = ""
        controller?.clearSubtitle()
    }

    func removeLocalSubtitle(_ item: LocalSubtitleItem, controller: PlayerController?) {
        do {
            if currentSubtitlePath == item.id || pendingLocalSubtitleID == item.id {
                clearSubtitle(controller: controller)
            }
            if FileManager.default.fileExists(atPath: item.url.path) {
                try FileManager.default.removeItem(at: item.url)
            }
            localSubtitleItems.removeAll { $0.id == item.id }
        } catch { subtitleOperationError = error.localizedDescription }
    }

    var shouldShowSourceSwitch: Bool {
        PurePlayerUIPolicy.allowsSourceSwitch
    }

    #if os(visionOS)
    enum VisionPanel: CaseIterable, Hashable {
        case settings, enhancement, subtitle, audio, videoTrack
        var isLeading: Bool { self == .settings || self == .enhancement }
    }
    var leadingVisionPanel: VisionPanel? {
        if showEnhancementContainer { return .enhancement }
        if showSettingContainer { return .settings }
        return nil
    }
    var trailingVisionPanel: VisionPanel? {
        if showSubtitleContainer { return .subtitle }
        if showAudioContainer { return .audio }
        if showVideoTrackContainer { return .videoTrack }
        return nil
    }
    func toggleVisionPanel(_ panel: VisionPanel) {
        showPlaybackSpeedContainer = false
        let wasSelected = panel.isLeading ? leadingVisionPanel == panel : trailingVisionPanel == panel
        if panel.isLeading {
            showSettingContainer = false; showEnhancementContainer = false
        } else {
            showSubtitleContainer = false; showAudioContainer = false; showVideoTrackContainer = false
        }
        guard !wasSelected else { return }
        switch panel {
        case .settings: showSettingContainer = true
        case .enhancement: showEnhancementContainer = true
        case .subtitle: showSubtitleContainer = true
        case .audio: showAudioContainer = true
        case .videoTrack: showVideoTrackContainer = true
        }
    }
    #endif

    var shouldShowEpisodeList: Bool {
        PurePlayerUIPolicy.allowsEpisodeList
    }

    var shouldShowFileSourceSubtitleImport: Bool {
        PurePlayerUIPolicy.allowsSubtitleImportFromFileSource
    }
}
