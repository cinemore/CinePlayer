import SwiftUI

#if !os(tvOS)
struct SubtitleTimeOffsetInput: View {
    @Binding var value: Double
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private let range: ClosedRange<Double> = -300.0 ... 300.0

    var body: some View {
        VStack(spacing: 8) {
            headerRow
            inputRow
            quickAdjustRow
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var headerRow: some View {
        HStack {
            Text("时间偏移")
                .f14r()
                .foregroundColor(.white)

            Spacer()

            if isEditing {
                Text("输入范围: -300.0s ~ +300.0s")
                    .f12r()
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text(formatTimeOffset(value))
                    .f14r()
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("时间偏移")
        .accessibilityValue(formatTimeOffset(value))
    }

    private var inputRow: some View {
        HStack(spacing: 8) {
            minusButton
            inputField
            plusButton
        }
    }

    private var minusButton: some View {
        Button {
            let newValue = max(range.lowerBound, value - 0.1)
            updateValue(newValue)
        } label: {
            Image(systemName: "minus")
                .f14m()
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.1))
                .roundedCorner(6)
        }
        .buttonStyle(.plain)
        #if os(iOS)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        #endif
        .accessibilityLabel("减少时间偏移")
    }

    private var plusButton: some View {
        Button {
            let newValue = min(range.upperBound, value + 0.1)
            updateValue(newValue)
        } label: {
            Image(systemName: "plus")
                .f14m()
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.1))
                .roundedCorner(6)
        }
        .buttonStyle(.plain)
        #if os(iOS)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
        #endif
        .accessibilityLabel("增加时间偏移")
    }

    private var inputField: some View {
        ZStack {
            TextField("", text: $inputText)
                .f14m()
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .focused($isTextFieldFocused)
                .textFieldStyle(.plain)
                #if canImport(UIKit)
                    .keyboardType(.decimalPad)
                #endif
                .onAppear {
                    inputText = String(format: "%.1f", value)
                }
                .compatibleOnChange(of: value) { newValue in
                    if !isEditing {
                        inputText = String(format: "%.1f", newValue)
                    }
                }
                .compatibleOnChange(of: isTextFieldFocused) { focused in
                    isEditing = focused
                    if focused {
                        inputText = String(format: "%.1f", value)
                    } else {
                        commitInputValue()
                    }
                }
                .onSubmit {
                    commitInputValue()
                    isTextFieldFocused = false
                }

            if !isEditing {
                Button {
                    isTextFieldFocused = true
                } label: {
                    Text(String(format: "%.1f", value))
                        .f14m()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 32)
        .background(Color.white.opacity(0.1))
        .roundedCorner(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isEditing ? Color.white.opacity(0.5) : Color.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var quickAdjustRow: some View {
        HStack(spacing: 8) {
            ForEach([-10, -5, -1, 0.0, 1, 5, 10], id: \.self) { offset in
                Button {
                    updateValue(offset)
                } label: {
                    Text(offset == 0.0 ? "重置" : formatQuickOffset(offset, compact: true))
                        .f12m()
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 28)
                        .background(Color.white.opacity(offset == 0.0 ? 0.2 : 0.1))
                        .roundedCorner(4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func updateValue(_ newValue: Double) {
        value = newValue
        inputText = String(format: "%.1f", newValue)
    }

    private func commitInputValue() {
        let cleanText = inputText
            .replacingOccurrences(of: "s", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if let inputValue = Double(cleanText) {
            let clampedValue = max(range.lowerBound, min(range.upperBound, inputValue))
            updateValue(clampedValue)
        } else {
            inputText = String(format: "%.1f", value)
        }
    }

    private func formatTimeOffset(_ offset: Double) -> String {
        let sign = offset >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", offset))s"
    }

    private func formatQuickOffset(_ offset: Double, compact: Bool = false) -> String {
        let sign = offset > 0 ? "+" : ""
        if compact {
            return "\(sign)\(Int(offset))"
        }
        return "\(sign)\(String(format: "%.1f", offset))s"
    }
}
#endif
