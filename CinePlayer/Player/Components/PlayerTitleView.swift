import CinePlayerSDK
//
//  PlayerTitleView.swift
//  Cinemore
//
//  Created by Zero on 2026/3/4.
//

import SwiftUI

struct PlayerTitleView: View {
    let title: String

    var body: some View {
        #if os(visionOS)
            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
        #else
            HStack {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 40)
            }
            // 其他平台保留紧凑标题的原字号与留白。
            #if os(iOS) || os(macOS)
            .contentTextFont(.caption, weight: .medium)
            #else
            .font(.caption)
            .fontWeight(.medium)
            #endif
            .foregroundColor(.white)
            .brightness(0.2)
        #endif
    }
}
