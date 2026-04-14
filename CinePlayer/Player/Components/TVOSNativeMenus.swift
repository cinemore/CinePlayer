import AVFoundation
import CinePlayerSDK
import SwiftUI

#if os(tvOS)
struct SubtitleTracksMenu: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerControlModel: PlayerControlModel

    var body: some View {
        Menu {
            Button {
                clearSubtitle()
            } label: {
                HStack {
                    Text("关闭")
                    Spacer()
                    if selectedTrackIndex == -1, playerControlModel.currentSubtitlePath.isEmpty {
                        Image(systemName: "checkmark")
                    }
                }
            }

            Divider()

            Menu {
                ForEach(SubtitleTranslateMode.allCases, id: \.self) { mode in
                    Button {
                        updateSubtitleTranslationMode(mode)
                    } label: {
                        HStack {
                            Text(mode.displayName)
                            Spacer()
                            if sessionStore.controlConfig.subtitleTranslateMode == mode {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                Label {
                    HStack {
                        Text("字幕翻译")
                        Spacer()
                        Text(sessionStore.controlConfig.subtitleTranslateMode.displayName)
                            .foregroundColor(.secondary)
                    }
                } icon: {
                    Image(systemName: "globe")
                }
            }

            if !playerControlModel.localSubtitleItems.isEmpty {
                Divider()

                ForEach(playerControlModel.localSubtitleItems) { item in
                    Button {
                        selectLocalSubtitle(item)
                    } label: {
                        HStack {
                            Text(makeLocalInfo(for: item))
                            Spacer()
                            if playerControlModel.currentSubtitlePath == item.id {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            if !subtitleTracks.isEmpty {
                Divider()

                ForEach(subtitleTracks, id: \.streamIndex) { subtitleTrack in
                    Button {
                        selectEmbeddedSubtitle(subtitleTrack)
                    } label: {
                        HStack {
                            Text(makeInfo(for: subtitleTrack))
                            Spacer()
                            if playerControlModel.currentSubtitlePath.isEmpty
                                && selectedTrackIndex == subtitleTrack.streamIndex
                            {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "captions.bubble")
        }
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
    }

    private var subtitleTracks: [FFmpegStreamAsset] {
        guard let controller = playerCoordinator.controller else {
            return []
        }
        return controller.sortByLanguageTracks(mediaType: .subtitle)
    }

    private var selectedTrackIndex: Int32 {
        playerCoordinator.subtitleTrackIndex
    }

    private func selectEmbeddedSubtitle(_ subtitleTrack: FFmpegStreamAsset) {
        playerControlModel.currentSubtitlePath = ""
        playerCoordinator.controller?.loadSubtitleTrack(
            subtitlesTrackIndex: subtitleTrack.streamIndex
        )
    }

    private func selectLocalSubtitle(_ item: PlayerControlModel.LocalSubtitleItem) {
        playerControlModel.currentSubtitlePath = item.id
        playerCoordinator.controller?.loadSubtitleFile(
            subtitleID: item.displayName,
            url: item.url
        )
    }

    private func clearSubtitle() {
        playerControlModel.currentSubtitlePath = ""
        playerCoordinator.controller?.clearSubtitle()
    }

    private func updateSubtitleTranslationMode(_ mode: SubtitleTranslateMode) {
        var updatedConfig = sessionStore.controlConfig
        guard updatedConfig.subtitleTranslateMode != mode else {
            return
        }
        updatedConfig.subtitleTranslateMode = mode
        sessionStore.controlConfig = updatedConfig
    }

    private func makeInfo(for subtitleTrack: FFmpegStreamAsset) -> String {
        var info = ""
        if let language = subtitleTrack.language {
            info += language
        } else {
            info += "未知语言"
        }

        if let title = subtitleTrack.title {
            info += " - \(title)"
        }

        info += "\n[\(subtitleTrack.codecName.uppercased())]"
        return info
    }

    private func makeLocalInfo(for item: PlayerControlModel.LocalSubtitleItem) -> String {
        var info = item.displayName
        if !item.sizeDescription.isEmpty {
            info += "\n[\(item.sizeDescription)]"
        }
        return info
    }
}

struct AudioTracksMenu: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator

    var body: some View {
        Menu {
            ForEach(audioTracks, id: \.streamIndex) { audioTrack in
                Button {
                    playerCoordinator.controller?.select(track: audioTrack)
                } label: {
                    HStack {
                        Text(makeInfo(for: audioTrack))
                        Spacer()
                        if selectedTrackIndex == audioTrack.streamIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "waveform")
        }
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
    }

    private var audioTracks: [FFmpegStreamAsset] {
        guard let controller = playerCoordinator.controller else {
            return []
        }
        return controller.sortByLanguageTracks(mediaType: .audio)
    }

    private var selectedTrackIndex: Int32 {
        playerCoordinator.audioTrack?.streamIndex ?? -1
    }

    private func makeInfo(for audioTrack: FFmpegStreamAsset) -> String {
        var info = ""
        if let language = audioTrack.language {
            info += language + " - "
        }
        if !audioTrack.audioChannelLayoutDescription.isEmpty {
            info += audioTrack.audioChannelLayoutDescription
        }
        info += "\n"

        if let profileVal = audioTrack.profileName, !profileVal.isEmpty {
            info += "[\(profileVal)]"
        } else {
            info += "[\(audioTrack.codecName.uppercased())]"
        }
        return info
    }
}

struct VideoTracksMenu: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator

    var body: some View {
        Menu {
            ForEach(videoTracks, id: \.streamIndex) { videoTrack in
                Button {
                    playerCoordinator.controller?.select(track: videoTrack)
                } label: {
                    HStack {
                        Text(makeInfo(for: videoTrack))
                        Spacer()
                        if selectedTrackIndex == videoTrack.streamIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "film")
        }
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
    }

    private var videoTracks: [FFmpegStreamAsset] {
        guard let controller = playerCoordinator.controller else {
            return []
        }
        return controller.videoTracks
    }

    private var selectedTrackIndex: Int32 {
        playerCoordinator.videoTrack?.streamIndex ?? -1
    }

    private func makeInfo(for videoTrack: FFmpegStreamAsset) -> String {
        let width = Int(videoTrack.naturalSize.width)
        let height = Int(videoTrack.naturalSize.height)
        let resolution = width > 0 && height > 0 ? "\(width)x\(height)" : nil
        let title = videoTrack.language ?? "默认视频轨"

        var info = title
        if let resolution {
            info += " - \(resolution)"
        }
        info += "\n[\(videoTrack.codecName.uppercased())]"
        return info
    }
}

struct PlaybackRateMenu: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var toastModel: PlayerToastModel

    private let playbackRates: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        Menu {
            ForEach(playbackRates, id: \.self) { value in
                Button {
                    playerCoordinator.playbackRate = value
                    toastModel.show(.playbackRateChanged(num: value))
                } label: {
                    HStack {
                        let text = "\(value.playbackRateText) x"
                        Text(text).tag(value)
                        Spacer()
                        if playerCoordinator.playbackRate == value {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            let text = "\(playerCoordinator.playbackRate.playbackRateText) x"
            Text(text)
        }
        .buttonBorderShape(.capsule)
    }
}

struct AspectFillButton: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator

    var body: some View {
        Button {
            playerCoordinator.isScaleAspectFill.toggle()
        } label: {
            Image(
                systemName: playerCoordinator.isScaleAspectFill
                    ? "rectangle.arrowtriangle.2.inward"
                    : "rectangle.arrowtriangle.2.outward"
            )
        }
        .frame(width: 68, height: 68)
        .buttonBorderShape(.circle)
    }
}
#endif
