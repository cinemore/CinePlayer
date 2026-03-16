import CinePlayerSDK
import AVFoundation
import SwiftUI

struct EmbeddedSubtitleView: View {
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @State private var pendingSubtitleTrackIndex: Int32? = nil
    @State private var subtitleCommandScheduler = DeferredMainActorCommandScheduler()

    var body: some View {
        Group {
            if !subtitleTracks.isEmpty {
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Text("开启")
                            .f16b()
                            .foregroundColor(.white)
                        Spacer()
                        Toggle(
                            isOn: Binding(
                                get: { selectedTrackIndex != -1 && playerControlModel.currentSubtitlePath.isEmpty },
                                set: { newValue in
                                    updateToggleState(newValue)
                                }
                            )
                        ) {}
                        #if !os(tvOS)
                            .toggleStyle(.switch)
                        #endif
                        .labelsHidden()
                        #if os(iOS)
                            .scaleEffect(0.8)
                            .offset(x: 2)
                        #endif
                    }

                    HStack(spacing: 12) {
                        Text("翻译")
                            .f16b()
                            .foregroundColor(.white)

                        if isAppleTranslationEnabled {
                            Button {
                                playerModel.restartSubtitleTranslationService()
                            } label: {
                                Text("重启")
                                    .f12r()
                                    .foregroundStyle(.white.opacity(0.9))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(.white.opacity(0.12), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }

                        Spacer(minLength: 0)

                        Picker("", selection: translationModeBinding) {
                            ForEach(SubtitleTranslateMode.allCases, id: \.self) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .fixedSize(horizontal: true, vertical: false)
                        .layoutPriority(1)
                    }

                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(subtitleTracks, id: \.streamIndex) { subtitleTrack in
                                let isSelected = selectedTrackIndex == subtitleTrack.streamIndex
                                    && playerControlModel.currentSubtitlePath.isEmpty
                                Button {
                                    selectSubtitleTrack(subtitleTrack)
                                } label: {
                                    EmbeddedSubtitleRowView(
                                        isSelected: isSelected,
                                        language: subtitleTrack.language,
                                        title: subtitleTrack.title,
                                        codecName: subtitleTrack.codecName
                                    )
                                }
                                .buttonStyle(.plain)
                                .id(subtitleTrack.streamIndex)
                            }
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 16)
                    }
                }
            } else {
                ScrollView(showsIndicators: false) {
                    VStack {
                        Spacer(minLength: 24)
                        Text("当前媒体无内封字幕")
                            .f12r()
                            .foregroundStyle(.white.opacity(0.65))
                        Spacer(minLength: 0)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)
                }
            }
        }
        .onAppear {
            pendingSubtitleTrackIndex = nil
            subtitleCommandScheduler.cancel()
        }
        .compatibleOnChange(of: playerCoordinator.subtitleTrackIndex) { _ in
            pendingSubtitleTrackIndex = nil
        }
        .compatibleOnChange(of: playerControlModel.showSubtitleContainer) { isShown in
            if !isShown {
                pendingSubtitleTrackIndex = nil
                subtitleCommandScheduler.cancel()
            }
        }
        .compatibleOnChange(of: playerControlModel.currentSubtitlePath) { newPath in
            if !newPath.isEmpty {
                pendingSubtitleTrackIndex = nil
                subtitleCommandScheduler.cancel()
            }
        }
    }

    private var subtitleTracks: [FFmpegStreamAsset] {
        guard let controller = playerCoordinator.controller else {
            return []
        }
        return controller.sortByLanguageTracks(mediaType: .subtitle)
    }

    private var selectedTrackIndex: Int32 {
        pendingSubtitleTrackIndex ?? playerCoordinator.subtitleTrackIndex
    }

    private var translationModeBinding: Binding<SubtitleTranslateMode> {
        Binding(
            get: {
                sessionStore.controlConfig.subtitleTranslateMode
            },
            set: { newValue in
                var config = sessionStore.controlConfig
                guard config.subtitleTranslateMode != newValue else {
                    return
                }
                config.subtitleTranslateMode = newValue
                sessionStore.controlConfig = config
            }
        )
    }

    private var isAppleTranslationEnabled: Bool {
        sessionStore.controlConfig.subtitleTranslateMode.needsTranslation
    }

    private func updateToggleState(_ newValue: Bool) {
        if newValue {
            if let firstTrack = subtitleTracks.first {
                selectSubtitleTrack(firstTrack)
            }
        } else if playerControlModel.currentSubtitlePath.isEmpty {
            pendingSubtitleTrackIndex = -1
            subtitleCommandScheduler.schedule {
                playerCoordinator.controller?.clearSubtitle()
            }
        }
    }

    private func selectSubtitleTrack(_ subtitleTrack: FFmpegStreamAsset) {
        guard selectedTrackIndex != subtitleTrack.streamIndex
            || !playerControlModel.currentSubtitlePath.isEmpty
        else { return }
        pendingSubtitleTrackIndex = subtitleTrack.streamIndex
        playerControlModel.currentSubtitlePath = ""
        subtitleCommandScheduler.schedule {
            playerCoordinator.controller?.loadSubtitleTrack(
                subtitlesTrackIndex: subtitleTrack.streamIndex
            )
        }
    }
}
