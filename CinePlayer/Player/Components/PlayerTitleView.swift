import SwiftUI

struct PlayerTitleView: View {
    let title: String

    var body: some View {
        HStack {
            Text(title)
                .lineLimit(1)
        }
        .f12r()
        .fontWeight(.medium)
        .foregroundColor(.white)
        .brightness(0.2)
    }
}
