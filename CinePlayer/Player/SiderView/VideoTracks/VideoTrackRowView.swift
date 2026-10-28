import CinePlayerSDK
//
//  VideoTrackRowView.swift
//  Cinemore
//
//  Created by Zero on 2026/1/19.
//

import SwiftUI

struct VideoTrackRowView: View {
    let isSelected: Bool
    var profileName: String?
    var language: String?
    var codecName: String
    var resolution: CGSize
    var frameRate: Float
    var bitRate: Int64?
    var dynamicRange: String?
    var streamIndex: Int32

    var onClick: () -> Void
    private let selectionAnimation = Animation.easeOut(duration: 0.12)
    private var titleColor: Color {
        #if os(visionOS)
            .primary
        #else
            isSelected ? .white : .white.opacity(0.4)
        #endif
    }

    private var detailColor: Color {
        #if os(visionOS)
            .secondary
        #else
            .white.opacity(isSelected ? 0.68 : 0.4)
        #endif
    }

    var body: some View {
        Button {
            onClick()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let profileName, !profileName.isEmpty {
                    HStack {
                        Text("\(profileName)")
                            .playerTrackDetailFont(fallback: .caption)
                            .foregroundColor(titleColor)
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)

                    #if os(visionOS)
                        Divider()
                    #else
                        Rectangle()
                            .fill(isSelected ? Color.white : Color.white.opacity(0.5))
                            .frame(height: 0.5)
                    #endif
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        if let language, !language.isEmpty {
                            Text(language)
                                .playerSemanticFont(.body.weight(.medium), fallback: .body.weight(.medium))
                                .foregroundColor(titleColor)
                        }
                        Spacer()
                        Text("\(codecName.uppercased())")
                            .playerSemanticFont(.callout.weight(.medium), fallback: .footnote.weight(.medium))
                            .foregroundColor(titleColor)
                        #if os(visionOS)
                            CheckMarkView(checked: isSelected)
                                .padding(.leading, 8)
                                .accessibilityHidden(true)
                        #endif
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 2)

                    Group {
                        HStack(spacing: 0) {
                            // 第一列：分辨率
                            Text("\(Int(resolution.width))×\(Int(resolution.height))")
                                .frame(maxWidth: .infinity, alignment: .leading)

                            // 第二列：帧率
                            Text(String(format: "%.2f fps", frameRate))
                                .frame(maxWidth: .infinity, alignment: .center)

                            // 第三列：比特率或动态范围
                            if let bitRate, bitRate > 0 {
                                if let formattedBitrate = formatBitrate(Int(bitRate)) {
                                    Text(formattedBitrate)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                } else {
                                    Text("") // 占位
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            } else if let dynamicRange, !dynamicRange.isEmpty {
                                Text(dynamicRange)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            } else {
                                Text("") // 占位
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                    }
                    .playerTrackDetailFont(fallback: .footnote)
                    .foregroundColor(detailColor)
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            #if !os(visionOS)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(isSelected ? 0.08 : 0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? Color.white : Color.white.opacity(0.2),
                            lineWidth: 1
                        )
                )
                .roundedCorner(10)
            #endif
                .animation(selectionAnimation, value: isSelected)
            #if !os(visionOS)
                .contentShape(Rectangle())
            #endif
        }
        #if !os(visionOS)
        .buttonStyle(.plain)
        #endif
        #if os(visionOS)
        .visionPlayerSelectionStyle(isSelected: isSelected)
        .buttonBorderShape(.roundedRectangle(radius: 10))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        #endif
        .id(streamIndex) // 添加稳定的ID
    }

    #if !os(tvOS)
        /// 动态范围与码率同时展示，不因另一字段存在而省略。
        var nativeSelectionRow: some View {
            let titleParts = ["\(Int(resolution.width))×\(Int(resolution.height))", dynamicRange]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return PlayerTrackSelectionRow(
                isSelected: isSelected,
                title: titleParts.joined(separator: " · "),
                profileName: profileName,
                details: [
                    language,
                    codecName.uppercased(),
                    frameRate > 0 ? String(format: "%.2f fps", frameRate) : nil,
                    bitRate.flatMap { formatBitrate(Int($0)) }
                ].compactMap(\.self),
                onSelect: onClick
            )
        }
    #endif

    /// 格式化比特率显示
    private func formatBitrate(_ bitrate: Int) -> String? {
        if bitrate <= 0 {
            nil
        } else if bitrate >= 1_000_000 {
            String(format: "%.2f Mbps", Double(bitrate) / 1_000_000)
        } else {
            "\(bitrate / 1000) kbps"
        }
    }
}
