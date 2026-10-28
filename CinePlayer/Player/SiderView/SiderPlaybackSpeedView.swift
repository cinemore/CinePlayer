import CinePlayerSDK
//
//  SiderPlaybackSpeedView.swift
//  Cinemore
//
//  Created by lf on 2025/7/31.
//

import SwiftUI

// MARK: 底部弹出窗口 - 倍速控制

struct SiderPlaybackSpeedView: View {
    @EnvironmentObject var playerControlModel: PlayerControlModel
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator

    let speedOptions: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]

    var body: some View {
        #if os(visionOS)
            // Popover 自带系统背景；按一整行原生预设按钮的理想宽度呈现。
            speedControls
                .fixedSize(horizontal: true, vertical: true)
                .padding(16)
        #else
            speedControls
                .frame(minWidth: 100)
                .padding(16)
                // 恢复原预设行的面板宽度上限，按钮仅在面板内部均分，窄屏时允许收窄。
                .frame(maxWidth: 360)
                .modifier(GlassEffectModifier(
                    cornerRadius: 24,
                    material: .regularMaterial,
                    useCapsule: false
                ))
                .background {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.black.opacity(0.001))
                        .contentShape(RoundedRectangle(cornerRadius: 24))
                        .onTapGesture {}
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
        #endif
    }

    private var speedControls: some View {
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
                    #if os(visionOS)
                        .font(.body.weight(.medium))
                    #else
                        .font(.body.weight(.medium))
                        .brightness(0.2)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .contentShape(Circle())
                    #endif
                }
                #if os(visionOS)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                #else
                .playerControlButtonStyle()
                .playerControlHoverEffect(in: Circle())
                #endif
                .disabled(playerCoordinator.playbackRate <= 0.25)
                .accessibilityLabel("降低播放速度")

                // 当前倍速显示
                let text = "\(playerCoordinator.playbackRate)x"
                Text(text)
                #if os(visionOS)
                    .font(.title3.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                #else
                    #if os(iOS) || os(macOS)
                        .contentTextFont(.sheetTitle, weight: .medium)
                    #else
                        .font(.title3.weight(.medium))
                    #endif
                        .foregroundColor(.font)
                        .frame(width: 120)
                #endif

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
                    #if os(visionOS)
                        .font(.body.weight(.medium))
                    #else
                        .font(.body.weight(.medium))
                        .brightness(0.2)
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.2))
                        .foregroundColor(.white)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .contentShape(Circle())
                    #endif
                }
                #if os(visionOS)
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .controlSize(.large)
                #else
                .playerControlButtonStyle()
                .playerControlHoverEffect(in: Circle())
                #endif
                .disabled(playerCoordinator.playbackRate >= 6.0)
                .accessibilityLabel("提高播放速度")
            }
            .padding(.bottom, 16)

            // 预设按钮
            HStack(spacing: 12) {
                presetButtons
            }
        }
    }

    private var presetButtons: some View {
        ForEach(speedOptions, id: \.self) { speed in
            Button {
                playerCoordinator.playbackRate = speed
                #if os(visionOS)
                    playerControlModel.showPlaybackSpeedContainer = false
                #else
                    playerControlModel.hideContainer()
                #endif
                playerMaskModel.showMask()
            } label: {
                // 当前倍速显示
                let text = "\(speed)x"
                Text(text)
                #if os(visionOS)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
                #else
                    #if os(iOS) || os(macOS)
                        .contentTextFont(.title, lineHeight: 19)
                    #else
                        .font(.body.weight(.medium))
                    #endif
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            playerCoordinator.playbackRate == speed
                                ? Color.white.opacity(0.5) : Color.black.opacity(0.2)
                        )
                        .foregroundColor(.white)
                        .roundedCorner(16)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                        .contentShape(Rectangle())
                #endif
            }
            #if os(visionOS)
            .visionPlayerSelectionStyle(isSelected: playerCoordinator.playbackRate == speed)
            .controlSize(.large)
            .accessibilityAddTraits(playerCoordinator.playbackRate == speed ? .isSelected : [])
            #else
            .playerControlButtonStyle()
            .playerControlHoverEffect(in: RoundedRectangle(cornerRadius: 16))
            #endif
        }
    }
}
