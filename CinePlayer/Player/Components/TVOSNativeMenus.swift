import AVFoundation
import CinePlayerSDK
import SwiftUI

#if os(tvOS)
struct SubtitleTracksMenu: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @State private var showsSubtitleAdjustment = false

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

            Button("字幕设置", systemImage: "textformat") { showsSubtitleAdjustment = true }

            if SubtitleTranslationRouter.isAvailable {
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
        .accessibilityLabel("字幕")
        .sheet(isPresented: $showsSubtitleAdjustment) {
            NavigationStack {
                TVSubtitleAdjustmentView(coordinator: playerCoordinator, style: playerModel.config.subtitleStyle)
                    .navigationTitle("字幕设置")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("完成") { showsSubtitleAdjustment = false }
                        }
                    }
            }
            .frame(idealWidth: 960, idealHeight: 800)
            .modifier(PlayerPresentationAppearance())
        }
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
        playerControlModel.selectEmbeddedSubtitle(subtitleTrack.streamIndex, controller: playerCoordinator.controller)
    }

    private func selectLocalSubtitle(_ item: PlayerControlModel.LocalSubtitleItem) {
        playerControlModel.selectLocalSubtitle(item, controller: playerCoordinator.controller)
    }

    private func clearSubtitle() {
        playerControlModel.clearSubtitle(controller: playerCoordinator.controller)
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
            info += String(localized: "未知语言")
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
        let title = videoTrack.language ?? String(localized: "默认视频轨")

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
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var toastModel: PlayerToastModel
    @State private var showsSpeed = false

    var body: some View {
        Button {
            playerMaskModel.disableAutoHide()
            showsSpeed = true
        } label: {
            Text(verbatim: "\(playerCoordinator.playbackRate.playbackRateText) x")
        }
        .accessibilityLabel("播放速度")
        .buttonBorderShape(.capsule)
        .sheet(isPresented: $showsSpeed) {
            NavigationStack {
                VStack(spacing: 32) {
                    HStack(spacing: 48) {
                        Button {
                            setRate(playerCoordinator.playbackRate - (playerCoordinator.playbackRate > 2 ? 1 : 0.05))
                        } label: { Image(systemName: "minus").frame(width: 68, height: 68) }
                        .accessibilityLabel("降低播放速度")
                        .disabled(playerCoordinator.playbackRate <= 0.25)
                        Text("\(playerCoordinator.playbackRate.formatted(.number.precision(.fractionLength(2))))×")
                            .font(.title).monospacedDigit().frame(maxWidth: .infinity)
                        Button {
                            setRate(playerCoordinator.playbackRate + (playerCoordinator.playbackRate >= 2 ? 1 : 0.05))
                        } label: { Image(systemName: "plus").frame(width: 68, height: 68) }
                        .accessibilityLabel("提高播放速度")
                        .disabled(playerCoordinator.playbackRate >= 6)
                    }
                    .buttonStyle(.bordered)
                    Button("正常速度") { setRate(1) }
                }
                .padding(64)
                .navigationTitle("播放速度")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成") { showsSpeed = false }
                    }
                }
            }
            .frame(idealWidth: 960, idealHeight: 432)
            .modifier(PlayerPresentationAppearance())
        }
    }

    private func setRate(_ value: Float) {
        let rate = min(6, max(0.25, value.rounded(to: 2)))
        playerCoordinator.playbackRate = rate
        toastModel.show(.playbackRateChanged(num: rate))
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
