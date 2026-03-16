import SwiftUI

struct EmbeddedSubtitleRowView: View {
    var isSelected: Bool
    var language: String?
    var title: String?
    var codecName: String?
    private let selectionAnimation = Animation.easeOut(duration: 0.12)

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 0) {
                if let language, !language.isEmpty {
                    Text(language)
                        .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                        .f13m()
                }
                if let title, !title.isEmpty {
                    Text(title)
                        .f11r()
                        .foregroundColor(.white.opacity(0.5))
                }
            }
            Spacer()
            if let codecName, !codecName.isEmpty {
                Text(codecName.uppercased())
                    .foregroundColor(.white.opacity(0.5))
                    .f11r()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isSelected ? 0.08 : 0.02))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(
                    isSelected ? .white : .white.opacity(0.2),
                    lineWidth: 1
                )
        )
        .roundedCorner(8)
        .animation(selectionAnimation, value: isSelected)
        .contentShape(Rectangle())
        .padding(.horizontal, 2)
    }
}
