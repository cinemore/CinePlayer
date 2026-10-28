import CinePlayerSDK
import Combine
//
//  EmbeddedSubtitleRowView.swift
//  Cinemore
//
//  Created by lf on 2025/11/26.
//

import SwiftUI

struct EmbeddedSubtitleRowView: View {
    @Binding var isSelected: Bool
    var language: String?
    var title: String?
    var codecName: String?

    var body: some View {
        let language = (language ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = (title ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        PlayerTrackSelectionRow(
            isSelected: isSelected,
            title: !language.isEmpty ? language : (!title.isEmpty ? title : String(localized: "字幕")),
            details: [language.isEmpty ? "" : title, (codecName ?? "").uppercased()],
            onDeselect: { isSelected = false },
            onSelect: { isSelected = true }
        )
    }
}
