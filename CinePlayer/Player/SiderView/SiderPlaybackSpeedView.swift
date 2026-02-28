//
//  SiderPlaybackSpeedView.swift
//  Cinemore
//
//  Created by lf on 2025/7/31.
//

import SwiftUI
import CinePlayerSDK

// MARK: 底部弹出窗口 - 倍速控制

struct SiderPlaybackSpeedView: View {
    @EnvironmentObject var playerControlModel: PlayerControlModel
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator

    let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        VStack(spacing: 0) {
            // 加减调节按钮
            HStack {
                Button {
                    if playerCoordinator.playbackRate > 0.25 {
                        if playerCoordinator.playbackRate > 2.0 {
                            // 超过2.0时每次减少1
                            playerCoordinator.playbackRate = (playerCoordinator.playbackRate - 1.0)
                                .rounded(to: 2)
                        } else {
                            // 2.0及以下时每次减少0.05
                            playerCoordinator.playbackRate = (playerCoordinator.playbackRate - 0.05)
                                .rounded(to: 2)
                        }
                    }
                } label: {
                    Image(systemName: "minus")
                        .brightness(0.2)
                        .f14m()
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(playerCoordinator.playbackRate <= 0.25)
                .accessibilityLabel("降低播放速度")

                // 当前倍速显示
                let text = "\(playerCoordinator.playbackRate.playbackRateText)x"
                Text(text)
                    .f20m()
                    .foregroundColor(.foreground)
                    .frame(width: 120)

                Button {
                    if playerCoordinator.playbackRate < 6.0 {
                        if playerCoordinator.playbackRate >= 2.0 {
                            // 超过2.0时每次增加1
                            playerCoordinator.playbackRate = (playerCoordinator.playbackRate + 1.0)
                                .rounded(to: 2)
                        } else {
                            // 2.0以下时每次增加0.05
                            playerCoordinator.playbackRate = (playerCoordinator.playbackRate + 0.05)
                                .rounded(to: 2)
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                        .brightness(0.2)
                        .f14m()
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .contentShape(Circle())
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(playerCoordinator.playbackRate >= 6.0)
                .accessibilityLabel("提高播放速度")
            }
            .padding(.bottom, 16)

            // 预设按钮
            HStack(spacing: 12) {
                ForEach(speedOptions, id: \.self) { speed in
                    Button {
                        playerCoordinator.playbackRate = speed
                        playerControlModel.hideContainer()
                    } label: {
                        // 当前倍速显示
                        let text = "\(speed.playbackRateText)x"
                        Text(text)
                            .f14m()
                            .frame(width: 56, height: 32)
                            .background(
                                playerCoordinator.playbackRate == speed
                                    ? Color.white.opacity(0.5) : Color.black.opacity(0.2)
                            )
                            .foregroundColor(.white)
                            .roundedCorner(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .frame(minWidth: 100)
        .padding(16)
        .modifier(GlassEffectModifier(
            cornerRadius: 24,
            material: .regularMaterial,
            useCapsule: false
        ))
        .padding(.horizontal)
        .padding(.bottom, 32)
    }
}
