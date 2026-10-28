#if os(tvOS)
import CinePlayerSDK
import SwiftUI

/// 遥控器使用明确的减小、增大按钮，保留稳定焦点。
struct TVPlayerValueControl<Value: BinaryFloatingPoint>: View {
    let title: LocalizedStringKey
    @Binding var value: Value
    let range: ClosedRange<Value>
    let step: Value

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Button {
                value = max(range.lowerBound, value - step)
            } label: {
                Image(systemName: "minus")
            }
            .accessibilityLabel(Text("减少") + Text(title))
            .disabled(value <= range.lowerBound)
            Text(Double(value).formatted(.number.precision(.fractionLength(0 ... 2))))
                .monospacedDigit()
                .frame(minWidth: 100)
            Button {
                value = min(range.upperBound, value + step)
            } label: {
                Image(systemName: "plus")
            }
            .accessibilityLabel(Text("增加") + Text(title))
            .disabled(value >= range.upperBound)
        }
        .buttonStyle(.bordered)
    }
}

#endif
