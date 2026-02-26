//
//  SubtitlePositionSlider.swift
//  Cinemore
//
//  Created by Zero on 2025/6/2.
//

import SwiftUI

#if !os(tvOS)
    struct SubtitlePositionSlider: View {
        let title: String
        @Binding var value: Double
        let range: ClosedRange<Double>
        let iconLeft: String
        let iconRight: String

        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text(title)
                        .f14r()
                        .foregroundColor(.white)
                    Spacer()
                    Text("\(Int(value))")
                        .f14r()
                        .foregroundColor(.white.opacity(0.6))
                }

                HStack(spacing: 8) {
                    Button {
                        let step = (range.upperBound - range.lowerBound) / 100 // 1% 步长
                        value = max(range.lowerBound, value - step)
                    } label: {
                        Image(systemName: iconLeft)
                            .f14m()
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("减少\(title)")

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            // 背景轨道
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.white.opacity(0.6))
                                .frame(height: 3)

                            // 已填充部分
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.white)
                                .frame(
                                    width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)),
                                    height: 3
                                )

                            // 滑块
                            Circle()
                                .fill(Color.white)
                                .frame(width: 15, height: 15)
                                .offset(x: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)) - 7.5)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { dragValue in
                                    let percent = dragValue.location.x / geometry.size.width
                                    let newValue = range.lowerBound + (range.upperBound - range.lowerBound) * Double(percent)
                                    value = max(range.lowerBound, min(range.upperBound, newValue))
                                }
                        )
                    }
                    .frame(height: 15)

                    Button {
                        let step = (range.upperBound - range.lowerBound) / 100 // 1% 步长
                        value = min(range.upperBound, value + step)
                    } label: {
                        Image(systemName: iconRight)
                            .f14m()
                            .foregroundColor(.white)
                            .frame(width: 20, height: 20)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("增加\(title)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }
#endif
