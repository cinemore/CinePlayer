import CinePlayerSDK
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
            Section {
                SubtitleFormSlider(
                    title: "缩放", value: $subtitleStyle.bitmapScale,
                    range: 0.1 ... 3, step: 0.1,
                    lowerLabel: "0.1×", upperLabel: "3.0×",
                    valueLabel: String(format: "%.1f×", subtitleStyle.bitmapScale)
                )
            } header: {
                HStack {
                    Text("缩放大小")

                    Spacer()

                    Button("重置") {
                        subtitleStyle.bitmapScale = 1
                    }
                }
            }

            // MARK: - 位置调整

            Section {
                // 水平偏移
                SubtitleFormSlider(
                    title: "水平位置", value: $subtitleStyle.bitmapHorizontalOffset,
                    range: -500 ... 500,
                    lowerLabel: "-500", upperLabel: "+500",
                    valueLabel: "\(Int(subtitleStyle.bitmapHorizontalOffset))"
                )
                // 垂直偏移
                SubtitleFormSlider(
                    title: "垂直位置", value: $subtitleStyle.bitmapVerticalOffset,
                    range: -500 ... 500,
                    lowerLabel: "-500", upperLabel: "+500",
                    valueLabel: "\(Int(subtitleStyle.bitmapVerticalOffset))"
                )
            } header: {
                HStack {
                    Text("位置调整")

                    Spacer()

                    Button("重置") {
                        subtitleStyle.bitmapHorizontalOffset = 0
                        subtitleStyle.bitmapVerticalOffset = 0
                    }
                }
            }

            // MARK: - 透明度调整

            Section {
                SubtitleFormSlider(
                    title: "透明度", value: $subtitleStyle.bitmapOpacity,
                    range: 0 ... 1, step: 0.05,
                    lowerLabel: "0%", upperLabel: "100%",
                    valueLabel: subtitleStyle.bitmapOpacity.formatted(.percent.precision(.fractionLength(0)))
                )
            } header: {
                HStack {
                    Text("透明度设置")

                    Spacer()

                    Button("重置") {
                        subtitleStyle.bitmapOpacity = 1
                    }
                }
            }
        }
    }
#endif
