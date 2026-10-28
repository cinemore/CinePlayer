import CinePlayerSDK
import Combine
//
//  ExternalSubtitleRowView.swift
//  Cinemore
//
//  Created by lf on 2025/11/27.
//

import SwiftUI

struct ExternalSubtitleRowView: View {
    @Binding var isSelected: Bool
    var subtitleName: String
    var subtitleLanguage: String
    var subtitleSize: String
    var body: some View {
        PlayerTrackSelectionRow(
            isSelected: isSelected,
            title: subtitleName.forceCharWrapping,
            details: [subtitleLanguage, subtitleSize],
            onDeselect: { isSelected = false },
            onSelect: { isSelected = true }
        )
    }
}
