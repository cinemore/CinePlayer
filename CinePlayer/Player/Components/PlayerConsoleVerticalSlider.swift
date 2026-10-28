import SwiftUI
#if os(iOS)
struct PlayerConsoleVerticalSlider: View {
    @Binding var value: CGFloat
    let title: LocalizedStringKey
    let icon: String
    var onChange: (CGFloat) -> Void
    var body: some View {
        VStack(spacing: 8) {
            Text(value, format: .percent.precision(.fractionLength(0))).monospacedDigit()
            GeometryReader { geometry in
                Slider(value: $value, in: 0...1)
                    .frame(width: max(0, geometry.size.height))
                    .rotationEffect(.degrees(-90))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .accessibilityLabel(Text(title))
            }
            Image(systemName: icon)
        }
        .padding(.vertical, 12)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
        .compatibleOnChange(of: value) { onChange($0) }
    }
}
#endif
