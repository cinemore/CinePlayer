import CinePlayerSDK
import AVFoundation
//
//  SiderAudioSettingView.swift
//  Cinemore
//
//  Created by lf on 2024/12/25.
//

import SwiftUI

// MARK: 音频设置

struct SiderAudioSettingView: View {
    @EnvironmentObject var playerControlModel: PlayerControlModel
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator
    @State private var pendingAudioTrackIndex: Int32? = nil
    @State private var selectionScheduler = DeferredMainActorCommandScheduler()

    var body: some View {
        let tracks = audioTracks
        VStack(alignment: .leading, spacing: 0) {
            Text("音轨")
                .playerPanelTitleStyle()

            #if !os(tvOS)
                PlayerTrackSelectionList {
                    ForEach(tracks, id: \.streamIndex) { audioTrack in
                        trackRow(audioTrack)
                            .nativeSelectionRow
                    }
                }
            #else
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(tracks, id: \.streamIndex) { audioTrack in
                            trackRow(audioTrack)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            #endif
        }
        .onAppear {
            pendingAudioTrackIndex = nil
            selectionScheduler.cancel()
        }
        .compatibleOnChange(of: playerCoordinator.audioTrack?.streamIndex) { _ in
            pendingAudioTrackIndex = nil
        }
        .compatibleOnChange(of: playerControlModel.showAudioContainer) { isShown in
            if !isShown {
                pendingAudioTrackIndex = nil
                selectionScheduler.cancel()
            }
        }
    }

    private func trackRow(_ audioTrack: FFmpegStreamAsset) -> AudioTrackRowView {
        AudioTrackRowView(
            isSelected: audioTrack.streamIndex == selectedTrackIndex,
            profileName: audioTrack.profileName,
            language: audioTrack.language,
            codecName: audioTrack.codecName,
            channelDescription: audioTrack.audioChannelLayoutDescription,
            audioDescriptorSampleRate: audioTrack.audioSampleRate,
            bitRate: audioTrack.bitRate,
            streamIndex: audioTrack.streamIndex
        ) {
            selectAudioTrack(audioTrack)
        }
    }

    /// 获取音轨数据
    private var audioTracks: [FFmpegStreamAsset] {
        guard let controller = playerCoordinator.controller else {
            return []
        }
        return controller.sortByLanguageTracks(mediaType: .audio)
    }

    /// 获取当前选中的音轨索引
    private var selectedTrackIndex: Int32 {
        pendingAudioTrackIndex ?? playerCoordinator.audioTrack?.streamIndex ?? -1
    }

    private func selectAudioTrack(_ audioTrack: FFmpegStreamAsset) {
        guard selectedTrackIndex != audioTrack.streamIndex else {
            return
        }
        pendingAudioTrackIndex = audioTrack.streamIndex
        selectionScheduler.schedule {
            playerCoordinator.controller?.select(track: audioTrack)
        }
    }
}
