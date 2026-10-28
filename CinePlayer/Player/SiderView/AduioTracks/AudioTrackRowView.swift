import CinePlayerSDK
//
//  AudioTrackRowView.swift
//  Cinemore
//
//  Created by lf on 2025/11/25.
//

import SwiftUI

struct AudioTrackRowView: View {
    let isSelected: Bool
    var profileName: String?
    var language: String?
    var codecName: String
    var channelDescription: String?
    var audioDescriptorSampleRate: Int32?
    var bitRate: Int64?
    var streamIndex: Int32
    var foregroundColor: Color = .white

    var onClick: () -> Void
    private let selectionAnimation = Animation.easeOut(duration: 0.12)
    private var titleColor: Color {
        #if os(visionOS)
            .primary
        #else
            isSelected ? foregroundColor : foregroundColor.opacity(0.4)
        #endif
    }

    private var detailColor: Color {
        #if os(visionOS)
            .secondary
        #else
            foregroundColor.opacity(isSelected ? 0.68 : 0.4)
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
                            .fill(isSelected ? foregroundColor : foregroundColor.opacity(0.5))
                            .frame(height: 0.5)
                    #endif
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        if let language,!language.isEmpty {
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
                            // 第一列：左对齐
                            if let channelDescription, !channelDescription.isEmpty {
                                HStack(spacing: 2) {
                                    Text("声道:")
                                    Text("\(channelDescription)")
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                Text("") // 占位
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }

                            // 第二列：居中
                            if let audioDescriptorSampleRate {
                                Text("\(audioDescriptorSampleRate) Hz")
                                    .frame(maxWidth: .infinity, alignment: .center)
                            } else {
                                Text("") // 占位
                                    .frame(maxWidth: .infinity, alignment: .center)
                            }

                            // 第三列：右对齐
                            if let bitRate {
                                if let formattedBitrate = formatBitrate(Int(bitRate)) {
                                    Text(formattedBitrate)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                } else {
                                    Text("") // 占位
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
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
                        .fill(foregroundColor.opacity(isSelected ? 0.08 : 0.02))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isSelected ? foregroundColor : foregroundColor.opacity(0.2),
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
        /// 原生单选行复用轨道字段、格式化和切换动作。
        var nativeSelectionRow: some View {
            let titleParts = [language, channelDescription]
                .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return PlayerTrackSelectionRow(
                isSelected: isSelected,
                title: titleParts.isEmpty ? String(localized: "音轨") : titleParts.joined(separator: " · "),
                profileName: profileName,
                details: [
                    codecName.uppercased(),
                    audioDescriptorSampleRate.flatMap { $0 > 0 ? "\($0.formatted()) Hz" : nil },
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
