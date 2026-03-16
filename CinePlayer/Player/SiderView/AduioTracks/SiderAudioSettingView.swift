//
//  SiderAudioSettingView.swift
//  Cinemore
//
//  Created by lf on 2024/12/25.
//

import SwiftUI
import CinePlayerSDK
import AVFoundation

// MARK: 音频设置

struct SiderAudioSettingView: View {
    @EnvironmentObject var playerControlModel: PlayerControlModel
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator
    @State private var pendingAudioTrackIndex: Int32? = nil
    @State private var selectionScheduler = DeferredMainActorCommandScheduler()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("音轨")
                .f17s()
                .padding()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(audioTracks, id: \.streamIndex) { audioTrack in
                        let isSelected = audioTrack.streamIndex == selectedTrackIndex
                        AudioTrackRowView(
                            isSelected: isSelected,
                            profileName: audioTrack.profileName,
                            language: audioTrack.language,
                            codecName: audioTrack.codecName,
                            channelDescription: audioTrack.audioChannelLayoutDescription.isEmpty ? nil : audioTrack.audioChannelLayoutDescription,
                            audioDescriptorSampleRate: audioTrack.audioSampleRate > 0 ? audioTrack.audioSampleRate : nil,
                            bitRate: audioTrack.bitRate,
                            streamIndex: audioTrack.streamIndex
                        ) {
                            selectAudioTrack(audioTrack)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
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
        guard selectedTrackIndex != audioTrack.streamIndex else { return }
        pendingAudioTrackIndex = audioTrack.streamIndex
        selectionScheduler.schedule {
            playerCoordinator.controller?.select(track: audioTrack)
        }
    }
}
