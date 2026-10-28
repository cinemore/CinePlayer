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
            #if os(macOS)
            .font(.title3.weight(.semibold))
            #elseif os(iOS)
            .font(.headline)
            #else
            .font(.caption)
            .fontWeight(.medium)
            #endif
            .foregroundColor(.white)
            .brightness(0.2)
        #endif
    }
}
