import SwiftUI

struct PlayerCloseButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .brightness(0.2)
                .foregroundColor(.white)
                .f20m()
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }
}
