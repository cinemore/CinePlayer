import SwiftUI

struct ExternalSubtitleRowView: View {
    var isSelected: Bool
    var subtitleName: String
    var subtitleLanguage: String
    var subtitleSize: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(subtitleName)
                    .multilineTextAlignment(.leading)
                    .if(isSelected) { $0.f15b() }
                    .if(!isSelected) { $0.f14r() }
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
    }
}
