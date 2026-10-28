import CinePlayerSDK
//
//  SubtitleTimeOffsetInput.swift
//  Cinemore
//
//  Created by Zero on 2025/6/2.
//

import SwiftUI

struct SubtitleTimeOffsetInput: View {
    @Binding var value: Double
    @State private var inputText: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var isTextFieldFocused: Bool

    private let range: ClosedRange<Double> = -300.0 ... 300.0

    var body: some View {
        VStack(alignment: .leading) {
            LabeledContent("时间偏移", value: formatTimeOffset(value))
                .accessibilityElement(children: .combine)
                .accessibilityLabel("时间偏移")
                .accessibilityValue(formatTimeOffset(value))

            HStack {
                // 减少按钮
                Button {
                    updateValue(max(range.lowerBound, value - 0.1))
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 20, height: 16)
                }
                .accessibilityLabel("减少时间偏移")

                // 手动输入框，保留焦点切换和提交时的范围校验。
                TextField("时间偏移", text: $inputText)
                    .labelsHidden()
                    .multilineTextAlignment(.center)
                    .focused($isTextFieldFocused)
                #if !os(tvOS)
                    .textFieldStyle(.roundedBorder)
                #endif
                #if canImport(UIKit)
                .keyboardType(.numbersAndPunctuation)
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

                // 增加按钮
                Button {
                    updateValue(min(range.upperBound, value + 0.1))
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 20, height: 16)
                }
                .accessibilityLabel("增加时间偏移")
            }

            if isEditing {
                Text("输入范围: -300.0s ~ +300.0s")
                    .playerPanelFormFont(.footnote)
                    .foregroundStyle(.secondary)
            }

            // 快速调整按钮保持单行，沿用直接设置偏移预设值的行为。
            HStack {
                ForEach([-5, -1, 0.0, 1, 5], id: \.self) { offset in
                    Button {
                        if offset == 0 {
                            updateValue(offset)
                        }
                        if offset > 0 {
                            updateValue(min(range.upperBound, value + offset))
                        }
                        if offset < 0 {
                            updateValue(max(range.lowerBound, value + offset))
                        }

                    } label: {
                        Text(
                            offset == 0
                                ? String(localized: "重置")
                                : formatQuickOffset(offset, compact: true)
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .controlSize(.small)
        }
        .buttonStyle(.bordered)
    }

    private func updateValue(_ newValue: Double) {
        value = newValue
        inputText = String(format: "%.1f", newValue)
    }

    private func commitInputValue() {
        // 解析输入的文本
        let cleanText = inputText.replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespacesAndNewlines)

        if let inputValue = Double(cleanText) {
            let clampedValue = max(range.lowerBound, min(range.upperBound, inputValue))
            updateValue(clampedValue)
        } else {
            // 如果输入无效，恢复原值
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
        } else {
            return "\(sign)\(String(format: "%.1f", offset))s"
        }
    }
}
