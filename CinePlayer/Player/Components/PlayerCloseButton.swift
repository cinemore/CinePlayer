import SwiftUI

struct PlayerCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .foregroundStyle(.white)
                .f20m()
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }
}
