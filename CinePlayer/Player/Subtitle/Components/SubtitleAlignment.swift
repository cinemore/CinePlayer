import CinePlayerSDK
//
//  SubtitleAlignment.swift
//  Cinemore
//
//  Created by Zero on 2025/6/2.
//

import SwiftUI

struct SubtitleHorizontalAlignment: View {
    @EnvironmentObject var subtitleStyle: SubtitleStyleModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "水平对齐"))
                    .font(.body)
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(Array([HorizontalAlignment.leading, HorizontalAlignment.center, HorizontalAlignment.trailing].enumerated()),
                        id: \.offset)
                { _, alignment in
                    Button {
                        subtitleStyle.textPosition.horizontalAlign = alignment
                    } label: {
                        Text(alignment.displayName)
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                subtitleStyle.textPosition.horizontalAlign == alignment
                                    ? Color.white.opacity(0.3)
                                    : Color.white.opacity(0.1)
                            )
                            .roundedCorner(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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

struct SubtitleVerticalAlignment: View {
    @EnvironmentObject var subtitleStyle: SubtitleStyleModel

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text(String(localized: "垂直对齐"))
                    .font(.body)
                    .foregroundColor(.white)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(Array([VerticalAlignment.top, VerticalAlignment.center, VerticalAlignment.bottom].enumerated()),
                        id: \.offset)
                { _, alignment in
                    Button {
                        subtitleStyle.textPosition.verticalAlign = alignment
                    } label: {
                        Text(alignment.displayName)
                            .font(.body.weight(.medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .background(
                                subtitleStyle.textPosition.verticalAlign == alignment
                                    ? Color.white.opacity(0.3)
                                    : Color.white.opacity(0.1)
                            )
                            .roundedCorner(6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
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

// MARK: - Extensions

extension HorizontalAlignment {
    var displayName: String {
        switch self {
        case .leading: String(localized: "左对齐")
        case .center: String(localized: "居中")
        case .trailing: String(localized: "右对齐")
        default: String(localized: "居中")
        }
    }
}

extension VerticalAlignment {
    var displayName: String {
        switch self {
        case .top: String(localized: "顶部")
        case .center: String(localized: "居中")
        case .bottom: String(localized: "底部")
        default: String(localized: "底部")
        }
    }
}
