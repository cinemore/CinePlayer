import SwiftUI

struct PlayerTitleView: View {
    let title: String

    var body: some View {
        Text(title)
            .f12r()
            .fontWeight(.medium)
            .foregroundStyle(.white)
            .lineLimit(1)
    }
}
