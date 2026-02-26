//
//  SubtitleBitmapControls.swift
//  Cinemore
//
//  Created by Zero on 2025/6/2.
//

import Foundation
import SwiftUI

#if !os(tvOS)
    struct SubtitleBitmapControls: View {
        @EnvironmentObject var subtitleStyle: SubtitleStyleModel
        var body: some View {
            VStack(spacing: 20) {
                // MARK: - 缩放调整

                VStack(spacing: 12) {
                    HStack {
                        SubtitleSectionHeader(title: "缩放大小")
                        Spacer()
                        Button("重置") {
                            subtitleStyle.bitmapScale = 1.0
                        }
                        .f12r()
                        .foregroundColor(.blue)
                    }

                    VStack(spacing: 8) {
                        HStack {
                            Text("缩放")
                                .f14r()
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(String(format: "%.1f", subtitleStyle.bitmapScale))x")
                                .f14m()
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // 滑块
                        Slider(value: $subtitleStyle.bitmapScale, in: 0.1 ... 3.0, step: 0.1)
                            .accentColor(.white)
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }

                // MARK: - 位置调整

                VStack(spacing: 12) {
                    HStack {
                        SubtitleSectionHeader(title: "位置调整")
                        Spacer()
                        Button("重置") {
                            subtitleStyle.bitmapHorizontalOffset = 0
                            subtitleStyle.bitmapVerticalOffset = 0
                        }
                        .f12r()
                        .foregroundColor(.blue)
                    }

                    // 水平偏移
                    VStack(spacing: 8) {
                        HStack {
                            Text("水平位置")
                                .f14r()
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(subtitleStyle.bitmapHorizontalOffset))")
                                .f14m()
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // 滑块
                        Slider(value: $subtitleStyle.bitmapHorizontalOffset, in: -500 ... 500)
                            .accentColor(.white)
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                    // 垂直偏移
                    VStack(spacing: 8) {
                        HStack {
                            Text("垂直位置")
                                .f14r()
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(subtitleStyle.bitmapVerticalOffset))")
                                .f14m()
                                .foregroundColor(.white.opacity(0.8))
                        }

                        // 滑块
                        Slider(value: $subtitleStyle.bitmapVerticalOffset, in: -500 ... 500)
                            .accentColor(.white)
                            .frame(height: 20)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }

                // MARK: - 透明度调整

                VStack(spacing: 12) {
                    HStack {
                        SubtitleSectionHeader(title: "透明度设置")
                        Spacer()
                        Button("重置") {
                            subtitleStyle.bitmapOpacity = 1.0
                        }
                        .f12r()
                        .foregroundColor(.blue)
                    }

                    SubtitleOpacitySlider(
                        title: "透明度",
                        value: $subtitleStyle.bitmapOpacity
                    )
                }
            }
        }
    }
#endif
