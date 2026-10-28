#if !os(tvOS)
import CinePlayerSDK
import AVFoundation
import SwiftUI

struct EmbeddedSubtitleView: View {
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @State private var pendingSubtitleTrackIndex: Int32?
    @State private var subtitleCommandScheduler = DeferredMainActorCommandScheduler()

    var body: some View {
        Group {
            if subtitleTracks.isEmpty {
                PlayerEmptyStateView(accessibilityName: "当前媒体无内封字幕")
            } else {
                subtitleForm
            }
        }
        .onAppear { pendingSubtitleTrackIndex = nil; subtitleCommandScheduler.cancel() }
        .onDisappear { subtitleCommandScheduler.cancel() }
        .compatibleOnChange(of: playerCoordinator.subtitleTrackIndex) { _ in pendingSubtitleTrackIndex = nil }
        .compatibleOnChange(of: playerControlModel.showSubtitleContainer) { visible in
            if !visible { pendingSubtitleTrackIndex = nil; subtitleCommandScheduler.cancel() }
        }
        .compatibleOnChange(of: playerControlModel.currentSubtitlePath) { path in
            if !path.isEmpty { pendingSubtitleTrackIndex = nil; subtitleCommandScheduler.cancel() }
        }
    }

    private var subtitleForm: some View {
        Form {
            Section {
                Toggle("开启", isOn: Binding(
                    get: { selectedTrackIndex != -1 && playerControlModel.currentSubtitlePath.isEmpty },
                    set: updateToggleState
                ))
                .toggleStyle(.switch)
                PlayerPanelPicker("翻译", selection: setting(\.subtitleTranslateMode)) {
                    ForEach(SubtitleTranslateMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .disabled(!SubtitleTranslationRouter.isAvailable)
                if sessionStore.controlConfig.subtitleTranslateMode.needsTranslation {
                    PlayerPanelPicker("目标语言", selection: setting(\.subtitleTranslationTargetLanguage)) {
                        Text("跟随系统").tag("")
                        ForEach(PlayerControlConfig.subtitleTranslationTargetLanguages, id: \.self) { language in
                            Text(Locale.current.localizedString(forIdentifier: language) ?? language).tag(language)
                        }
                    }
                    if sessionStore.controlConfig.subtitleTranslateMode == .bilingual {
                        PlayerPanelPicker("译文位置", selection: setting(\.subtitleTranslationOnTop)) {
                            Text("上方").tag(true)
                            Text("下方").tag(false)
                        }
                    }
                    if SubtitleTranslationRouter.isAvailable {
                        Button("重启 Apple 翻译") { playerModel.restartSubtitleTranslationService() }
                    }
                }
            }
            Section {
                ForEach(subtitleTracks, id: \.streamIndex) { track in
                    EmbeddedSubtitleRowView(isSelected: Binding(
                        get: { selectedTrackIndex == track.streamIndex && playerControlModel.currentSubtitlePath.isEmpty },
                        set: { selected in
                            if selected { selectSubtitleTrack(track) } else { updateToggleState(false) }
                        }
                    ), language: track.language, title: track.title, codecName: track.codecName)
                }
            }
        }
        .modifier(PlayerPanelFormModifier())
        .scrollContentBackground(.hidden)
    }

    private func setting<Value>(_ keyPath: WritableKeyPath<PlayerControlConfig, Value>) -> Binding<Value> {
        Binding(get: { sessionStore.controlConfig[keyPath: keyPath] }, set: { value in
            var config = sessionStore.controlConfig
            config[keyPath: keyPath] = value
            sessionStore.controlConfig = config
        })
    }

    private var subtitleTracks: [FFmpegStreamAsset] {
        playerCoordinator.controller?.sortByLanguageTracks(mediaType: .subtitle) ?? []
    }
    private var selectedTrackIndex: Int32 {
        pendingSubtitleTrackIndex ?? playerCoordinator.subtitleTrackIndex
    }
    private func updateToggleState(_ enabled: Bool) {
        if enabled {
            if let first = subtitleTracks.first { selectSubtitleTrack(first) }
        } else if playerControlModel.currentSubtitlePath.isEmpty {
            pendingSubtitleTrackIndex = -1
            subtitleCommandScheduler.schedule {
                playerControlModel.clearSubtitle(controller: playerCoordinator.controller)
            }
        }
    }
    private func selectSubtitleTrack(_ track: FFmpegStreamAsset) {
        guard selectedTrackIndex != track.streamIndex || !playerControlModel.currentSubtitlePath.isEmpty else { return }
        pendingSubtitleTrackIndex = track.streamIndex
        subtitleCommandScheduler.schedule {
            playerControlModel.selectEmbeddedSubtitle(track.streamIndex, controller: playerCoordinator.controller)
        }
    }
}
#endif
