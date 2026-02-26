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
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator

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
                            channelDescription: nil,
                            audioDescriptorSampleRate: nil,
                            bitRate: audioTrack.bitRate,
                            streamIndex: audioTrack.streamIndex
                        ) {
                            guard let controller = playerCoordinator.controller else {
                                return
                            }
                            controller.select(track: audioTrack)
                            playerCoordinator.audioTrack = audioTrack
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
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
        playerCoordinator.audioTrack?.streamIndex ?? -1
    }
}
