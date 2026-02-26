//
//  VideoTrackRowView.swift
//  Cinemore
//
//  Created by Zero on 2026/1/19.
//

import SwiftUI
import CinePlayerSDK

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
                        if let language, !language.isEmpty {
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
