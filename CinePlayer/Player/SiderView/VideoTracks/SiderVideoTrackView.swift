import CinePlayerSDK
//
//  SiderVideoTrackView.swift
//  Cinemore
//
//  Created by Zero on 2026/1/19.
//

import SwiftUI

// MARK: 视频轨道设置

struct SiderVideoTrackView: View {
    @EnvironmentObject var playerControlModel: PlayerControlModel
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator
    @State private var pendingVideoTrackIndex: Int32? = nil
    @State private var selectionScheduler = DeferredMainActorCommandScheduler()

    var body: some View {
        let tracks = videoTracks
        VStack(alignment: .leading, spacing: 0) {
            Text("视频轨道")
                .playerPanelTitleStyle()

            #if !os(tvOS)
                PlayerTrackSelectionList {
                    ForEach(tracks, id: \.streamIndex) { videoTrack in
                        trackRow(videoTrack)
                            .nativeSelectionRow
                    }
                }
            #else
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 12) {
                        ForEach(tracks, id: \.streamIndex) { videoTrack in
                            trackRow(videoTrack)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                }
            #endif
        }
        .onAppear {
            pendingVideoTrackIndex = nil
            selectionScheduler.cancel()
        }
        .compatibleOnChange(of: playerCoordinator.videoTrack?.streamIndex) { _ in
            pendingVideoTrackIndex = nil
        }
        .compatibleOnChange(of: playerControlModel.showVideoTrackContainer) { isShown in
            if !isShown {
                pendingVideoTrackIndex = nil
                selectionScheduler.cancel()
            }
        }
    }

    private func trackRow(_ videoTrack: FFmpegStreamAsset) -> VideoTrackRowView {
        VideoTrackRowView(
            isSelected: videoTrack.streamIndex == selectedTrackIndex,
            profileName: videoTrack.profileName,
            language: videoTrack.language,
            codecName: videoTrack.codecName,
            resolution: videoTrack.naturalSize,
            frameRate: videoTrack.nominalFrameRate,
            bitRate: videoTrack.bitRate,
            dynamicRange: videoTrack.dynamicRange != .sdr ? videoTrack.dynamicRange.description : nil,
            streamIndex: videoTrack.streamIndex
        ) {
            selectVideoTrack(videoTrack)
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
        pendingVideoTrackIndex ?? playerCoordinator.videoTrack?.streamIndex ?? -1
    }

    private func selectVideoTrack(_ videoTrack: FFmpegStreamAsset) {
        guard selectedTrackIndex != videoTrack.streamIndex else {
            return
        }
        pendingVideoTrackIndex = videoTrack.streamIndex
        selectionScheduler.schedule {
            playerCoordinator.controller?.select(track: videoTrack)
        }
    }
}
