import Foundation
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

    var shouldShowSourceSwitch: Bool {
        PurePlayerUIPolicy.allowsSourceSwitch
    }

    var shouldShowEpisodeList: Bool {
        PurePlayerUIPolicy.allowsEpisodeList
    }

    var shouldShowFileSourceSubtitleImport: Bool {
        PurePlayerUIPolicy.allowsSubtitleImportFromFileSource
    }
}
