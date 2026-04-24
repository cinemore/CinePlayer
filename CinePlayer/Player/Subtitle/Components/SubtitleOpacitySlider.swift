//
//  SubtitleOpacitySlider.swift
//  Cinemore
//
//  Created by Zero on 2025/6/2.
//

import SwiftUI

#if !os(tvOS)

    struct SubtitleOpacitySlider: View {
        let title: String
        @Binding var value: Double

        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text(title)
                        .f14r()
                        .foregroundColor(.white)
                    Spacer()
                    Text(value, format: .percent.precision(.fractionLength(0)))
                        .f14m()
                        .foregroundColor(.white.opacity(0.8))
                }

                HStack(spacing: 12) {
                    // 透明度图标
                    Image(systemName: "circle.fill")
                        .f12r()
                        .foregroundColor(.white.opacity(0.3))

                    // 滑块
                    Slider(value: $value, in: 0.0 ... 1.0, step: 0.05)
                        .accentColor(.white)
                        .frame(height: 20)

                    // 不透明图标
                    Image(systemName: "circle.fill")
                        .f12r()
                        .foregroundColor(.white)
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
