import CinePlayerSDK
import Foundation
//
//  PlayerNetworkSpeed.swift
//  Cinemore
//
//  Created by Zero on 2025/5/19.
//

import SwiftUI

struct PlayerNetworkSpeed: View {
    @ObservedObject var controller: PlayerController
    var isPreparingSource = false

    var body: some View {
        if let playerInfo = controller.playerInfo {
            PlayerNetworkSpeedContent(
                playerInfo: playerInfo,
                isLoading: isPreparingSource || controller.isLoadingMedia
            )
        }
    }
}

private struct PlayerNetworkSpeedContent: View {
    @ObservedObject var playerInfo: PlayerInfo
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 6) {
            #if os(tvOS)
                // 始终为原生加载器留位，切换加载状态时保持网速标签尺寸。
                ProgressView()
                    .progressViewStyle(.circular)
                    .tint(.white)
                    .controlSize(.small)
                    .opacity(isLoading ? 1 : 0)
                    .accessibilityLabel(Text("加载中"))
                    .accessibilityHidden(!isLoading)
            #else
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .controlSize(.mini)
                        .accessibilityLabel(Text("加载中"))
                }
            #endif
            Text(formatSpeed(playerInfo.networkSpeed))
                .monospacedDigit()
                .lineLimit(1)
        }
        #if os(iOS) || os(macOS)
        .contentTextFont(.value, weight: .medium)
        #endif
        .fixedSize(horizontal: true, vertical: false)
    }
}

private func formatSpeed(_ speed: Double) -> String {
    guard speed.isFinite, speed >= 0, speed < Double(Int64.max) else { return "0 B/s" }
    return ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
}
