import SwiftUI

struct ExternalSubtitleRowView: View {
    var isSelected: Bool
    var subtitleName: String
    var subtitleLanguage: String
    var subtitleSize: String
    private let selectionAnimation = Animation.easeOut(duration: 0.12)

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(subtitleName)
                    .multilineTextAlignment(.leading)
                    .f14m()
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.4))
                Spacer()
            }
            HStack {
                if !subtitleLanguage.isEmpty {
                    Text(subtitleLanguage)
                }

                Spacer()
                if !subtitleSize.isEmpty {
                    Text(subtitleSize)
                }
            }
            .f13r()
            .foregroundStyle(isSelected ? .white.opacity(0.68) : .white.opacity(0.4))
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isSelected ? 0.08 : 0.02))
        )
        .animation(selectionAnimation, value: isSelected)
    }
}
