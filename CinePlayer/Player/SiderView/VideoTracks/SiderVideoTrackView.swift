//
//  SiderVideoTrackView.swift
//  Cinemore
//
//  Created by Zero on 2026/1/19.
//

import SwiftUI
import CinePlayerSDK

// MARK: 视频轨道设置

struct SiderVideoTrackView: View {
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("视频轨道")
                .f17s()
                .padding()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 12) {
                    ForEach(videoTracks, id: \.streamIndex) { videoTrack in
                        let isSelected = videoTrack.streamIndex == selectedTrackIndex
                        VideoTrackRowView(
                            isSelected: isSelected,
                            profileName: videoTrack.profileName,
                            language: videoTrack.language,
                            codecName: videoTrack.codecName,
                            resolution: videoTrack.naturalSize,
                            frameRate: videoTrack.nominalFrameRate,
                            bitRate: videoTrack.bitRate,
                            dynamicRange: videoTrack.dynamicRange != .sdr ? videoTrack.dynamicRange.description : nil,
                            streamIndex: videoTrack.streamIndex
                        ) {
                            guard let controller = playerCoordinator.controller else {
                                return
                            }
                            controller.select(track: videoTrack)
                            playerCoordinator.videoTrack = videoTrack
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }

    /// 获取视频轨道数据
    private var videoTracks: [FFmpegStreamAsset] {
        guard let controller = playerCoordinator.controller else {
            return []
        }
        return controller.videoTracks
    }

    /// 获取当前选中的视频轨道索引
    private var selectedTrackIndex: Int32 {
        playerCoordinator.videoTrack?.streamIndex ?? -1
    }
}
