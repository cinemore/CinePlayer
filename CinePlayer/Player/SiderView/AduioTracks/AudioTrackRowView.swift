//
//  AudioTrackRowView.swift
//  Cinemore
//
//  Created by lf on 2025/11/25.
//

import SwiftUI
import CinePlayerSDK

struct AudioTrackRowView: View {
    let isSelected: Bool
    var profileName: String?
    var language: String?
    var codecName: String
    var channelDescription: String?
    var audioDescriptorSampleRate: Int32?
    var bitRate: Int64?
    var streamIndex: Int32

    var onClick: () -> Void
    var body: some View {
        Button {
            onClick()
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                if let profileName, !profileName.isEmpty {
                    HStack {
                        Text("\(profileName)")
                            .f12r()
                            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.4))
                            .padding(.horizontal, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)

                    Rectangle()
                        .fill(isSelected ? Color.white : Color.white.opacity(0.5))
                        .frame(height: 0.5)
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .center, spacing: 0) {
                        if let language,!language.isEmpty {
                            Text(language)
                                .if(isSelected) {
                                    $0.f15s()
                                }
                                .if(!isSelected) {
                                    $0.f14r()
                                }
                                .foregroundColor(isSelected ? Color.white : Color.white
                                    .opacity(0.4))
                        }
                        Spacer()
                        Text("\(codecName.uppercased())")
                            .f14r()
                            .foregroundColor(isSelected ? Color.white : Color.white.opacity(0.4))
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
                    .f13r()
                    .foregroundColor(isSelected ? Color.white.opacity(0.68) : Color.white.opacity(0.4))
                    .padding(.horizontal, 12)
                }
                .padding(.vertical, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        isSelected ? Color.white : Color.white.opacity(0.2),
                        lineWidth: 1
                    )
            )
            .roundedCorner(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(streamIndex) // 添加稳定的ID
    }

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
