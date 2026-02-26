//
//  SubtitleColorRow.swift
//  Cinemore
//
//  Created by Zero on 2025/6/2.
//

import SwiftUI

#if !os(tvOS)
    struct SubtitleColorABGRHexRow: View {
        let title: String
        @Binding var colorABGRHex: String

        private var colorOptions: [String] {
            let colors: [Color] = [
                .white, .black, .red, .blue, .green, .yellow, .purple, .clear
            ]
            return colors.map { color in
                color.toABGRHexString()
            }
        }

        /// 从 ABGR Hex 字符串转换为 Color（用于比较）
        private func colorFromABGRHexString(_ abgrHex: String) -> Color {
            let hex = abgrHex.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "&H", with: "")
                .replacingOccurrences(of: "#", with: "")
                .uppercased()

            guard !hex.isEmpty else {
                return .white
            }

            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)

            if hex.count == 8 {
                // ABGR格式：AABBGGRR
                let b = Int((int >> 16) & 0xFF)
                let g = Int((int >> 8) & 0xFF)
                let r = Int(int & 0xFF)
                return Color(
                    .sRGB,
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: 1.0
                )
            } else {
                // 处理其他长度的格式（1-6位），统一当做BGR格式处理
                let paddedHex = String(format: "%06X", int)
                let paddedInt = UInt64(paddedHex, radix: 16) ?? 0
                let b = Int((paddedInt >> 16) & 0xFF)
                let g = Int((paddedInt >> 8) & 0xFF)
                let r = Int(paddedInt & 0xFF)
                return Color(
                    .sRGB,
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: 1.0
                )
            }
        }

        /// 检查两个 ABGR Hex 字符串是否表示相同的颜色（通过转换为 Color 对象比较）
        private func isSameColor(_ hex1: String, _ hex2: String) -> Bool {
            // 先尝试直接字符串比较（规范化后）
            let normalized1 = hex1.trimmingCharacters(in: .whitespaces).uppercased()
            let normalized2 = hex2.trimmingCharacters(in: .whitespaces).uppercased()

            if normalized1 == normalized2 {
                return true
            }

            // 如果字符串不同，转换为 Color 对象进行比较
            let color1 = colorFromABGRHexString(hex1)
            let color2 = colorFromABGRHexString(hex2)

            // 使用 UIColor/NSColor 来比较颜色值
            #if canImport(UIKit)
                let uiColor1 = UIColor(color1)
                let uiColor2 = UIColor(color2)
                var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
                var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

                guard uiColor1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1),
                      uiColor2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
                else {
                    return false
                }

                // 比较 RGB 值（允许 0.01 的误差，因为浮点数转换可能有微小差异）
                return abs(r1 - r2) < 0.01 &&
                    abs(g1 - g2) < 0.01 &&
                    abs(b1 - b2) < 0.01
            #else
                let nsColor1 = NSColor(color1).usingColorSpace(.deviceRGB)
                let nsColor2 = NSColor(color2).usingColorSpace(.deviceRGB)

                guard let rgb1 = nsColor1, let rgb2 = nsColor2 else {
                    return false
                }

                var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
                var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

                rgb1.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
                rgb2.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

                return abs(r1 - r2) < 0.01 &&
                    abs(g1 - g2) < 0.01 &&
                    abs(b1 - b2) < 0.01
            #endif
        }

        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text(title)
                        .f14r()
                        .foregroundColor(.white)
                    Spacer()
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: colorOptions.count), spacing: 4) {
                    ForEach(colorOptions.indices, id: \.self) { index in
                        ColorABGRHexButton(
                            colorOption: colorOptions[index],
                            isSelected: isSameColor(colorABGRHex, colorOptions[index]),
                            action: {
                                // 确保使用规范化的格式（大写）
                                colorABGRHex = colorOptions[index].uppercased()
                            }
                        )
                    }
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

    private struct ColorABGRHexButton: View {
        let colorOption: String
        let isSelected: Bool
        let action: () -> Void

        /// 从 ABGR Hex 字符串转换为 Color
        private func colorFromABGRHexString(_ abgrHex: String) -> Color {
            let hex = abgrHex.trimmingCharacters(in: .whitespaces)
                .replacingOccurrences(of: "&H", with: "")
                .replacingOccurrences(of: "#", with: "")
                .uppercased()

            guard !hex.isEmpty else {
                return .white
            }

            var int: UInt64 = 0
            Scanner(string: hex).scanHexInt64(&int)

            if hex.count == 8 {
                // ABGR格式：AABBGGRR
//                let a = Int((int >> 24) & 0xFF)
                let b = Int((int >> 16) & 0xFF)
                let g = Int((int >> 8) & 0xFF)
                let r = Int(int & 0xFF)

                // ASS中alpha是反转的（255-alpha），但这里我们只需要颜色，不关心透明度
                return Color(
                    .sRGB,
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: 1.0
                )
            } else {
                // 处理其他长度的格式（1-6位），统一当做BGR格式处理
                let paddedHex = String(format: "%06X", int)
                let paddedInt = UInt64(paddedHex, radix: 16) ?? 0

                // BGR格式：BBGGRR
                let b = Int((paddedInt >> 16) & 0xFF)
                let g = Int((paddedInt >> 8) & 0xFF)
                let r = Int(paddedInt & 0xFF)

                return Color(
                    .sRGB,
                    red: Double(r) / 255.0,
                    green: Double(g) / 255.0,
                    blue: Double(b) / 255.0,
                    opacity: 1.0
                )
            }
        }

        private var fillColor: Color {
            if colorOption == Color.clear.toABGRHexString() {
                Color.white.opacity(0.1)
            } else {
                colorFromABGRHexString(colorOption)
            }
        }

        private var strokeColor: Color {
            isSelected ? Color.white : Color.white.opacity(0.1)
        }

        private var strokeWidth: CGFloat {
            isSelected ? 2 : 1
        }

        private var isClearColor: Bool {
            colorOption == Color.clear.toABGRHexString()
        }

        var body: some View {
            Button(action: action) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
                    .frame(width: 28, height: 28)
                    .padding(2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                    .overlay(clearIcon)
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        private var clearIcon: some View {
            if isClearColor {
                Image(systemName: "square.split.diagonal.2x2")
                    .f12r()
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }

    struct SubtitleColorRow: View {
        let title: String
        @Binding var color: Color

        private let colorOptions: [Color] = [
            .white, .black, .red, .blue, .green, .yellow, .purple, .clear
        ]

        var body: some View {
            VStack(spacing: 8) {
                HStack {
                    Text(title)
                        .f14r()
                        .foregroundColor(.white)
                    Spacer()
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: colorOptions.count), spacing: 4) {
                    ForEach(colorOptions.indices, id: \.self) { index in
                        ColorButton(
                            colorOption: colorOptions[index],
                            isSelected: color == colorOptions[index],
                            action: { color = colorOptions[index] }
                        )
                    }
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

    private struct ColorButton: View {
        let colorOption: Color
        let isSelected: Bool
        let action: () -> Void

        private var fillColor: Color {
            colorOption == .clear ? Color.white.opacity(0.1) : colorOption
        }

        private var strokeColor: Color {
            isSelected ? Color.white : Color.white.opacity(0.1)
        }

        private var strokeWidth: CGFloat {
            isSelected ? 2 : 1
        }

        var body: some View {
            Button(action: action) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(fillColor)
                    .frame(width: 28, height: 28)
                    .padding(2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                    .overlay(clearIcon)
            }
            .buttonStyle(.plain)
        }

        @ViewBuilder
        private var clearIcon: some View {
            if colorOption == .clear {
                Image(systemName: "square.split.diagonal.2x2")
                    .f12r()
                    .foregroundColor(.white.opacity(0.6))
            }
        }
    }
#endif
