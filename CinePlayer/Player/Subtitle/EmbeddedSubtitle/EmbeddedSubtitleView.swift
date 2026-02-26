import CinePlayerSDK
import AVFoundation
import SwiftUI

struct EmbeddedSubtitleView: View {
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator

    var body: some View {
        Group {
            if !subtitleTracks.isEmpty {
                VStack(spacing: 12) {
                    HStack {
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

    private func updateToggleState(_ newValue: Bool) {
        if newValue {
            if let firstTrack = subtitleTracks.first {
                selectSubtitleTrack(firstTrack)
            }
        } else if playerControlModel.currentSubtitlePath.isEmpty {
            playerCoordinator.subtitleTrackIndex = -1
            playerCoordinator.controller?.clearSubtitle()
        }
    }

    private func selectSubtitleTrack(_ subtitleTrack: FFmpegStreamAsset) {
        playerCoordinator.subtitleTrackIndex = subtitleTrack.streamIndex
        playerControlModel.currentSubtitlePath = ""
        playerCoordinator.controller?.loadSubtitleTrack(subtitlesTrackIndex: subtitleTrack.streamIndex)
    }
}
