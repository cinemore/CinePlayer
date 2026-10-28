import CinePlayerSDK
//
//  SubtitleAdjustmentView.swift
//  Cinemore
//
//  Created by lf on 2024/12/25.
//

import Combine
import SwiftUI

// MARK: 字幕调整

#if !os(tvOS)
    struct SubtitleAdjustmentView: View {
        // 参数模式：直接传入的值（用于远程控制场景）
        @ObservedObject private var paramSubtitleStyle: SubtitleStyleModel
        private let paramSubtitleDelay: Binding<Double>?
        private let paramIsImageSubtitle: Bool?
        private let paramCanShowSubtitleStyle: Bool?

        @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
        @EnvironmentObject private var envSubtitleStyle: SubtitleStyleModel

        /// 标记是否使用参数模式
        private var useParameterMode: Bool {
            paramSubtitleDelay != nil && paramIsImageSubtitle != nil
                && paramCanShowSubtitleStyle != nil
        }

        /// 参数模式初始化（用于远程控制）
        init(
            subtitleStyle: SubtitleStyleModel,
            subtitleDelay: Binding<Double>,
            isImageSubtitle: Bool,
            canShowSubtitleStyle: Bool
        ) {
            _paramSubtitleStyle = ObservedObject(wrappedValue: subtitleStyle)
            paramSubtitleDelay = subtitleDelay
            paramIsImageSubtitle = isImageSubtitle
            paramCanShowSubtitleStyle = canShowSubtitleStyle
        }

        /// EnvironmentObject 模式初始化（用于本地播放，向后兼容）
        init() {
            // 创建一个临时的 SubtitleStyleModel，会在 onAppear 中从 EnvironmentObject 获取
            _paramSubtitleStyle = ObservedObject(wrappedValue: SubtitleStyleModel())
            paramSubtitleDelay = nil
            paramIsImageSubtitle = nil
            paramCanShowSubtitleStyle = nil
        }

        // 内部状态（仅用于 EnvironmentObject 模式）
        @State private var envCanShowSubtitleStyle = false
        @State private var envIsImageSubtitle = false

        var body: some View {
            // 在 EnvironmentObject 模式下持续观察当前字幕样式。
            let style = useParameterMode ? paramSubtitleStyle : envSubtitleStyle
            let canShow = useParameterMode ? paramCanShowSubtitleStyle! : envCanShowSubtitleStyle
            let isImage = useParameterMode ? paramIsImageSubtitle! : envIsImageSubtitle

            Form {
                // MARK: - 时间偏移调整

                Section {
                    SubtitleTimeOffsetInput(
                        value: useParameterMode
                            ? paramSubtitleDelay!
                            : Binding(
                                get: { playerCoordinator.subtitleDelay },
                                set: { playerCoordinator.subtitleDelay = $0 }
                            )
                    )
                }

                // MARK: - HDR 字幕增强控制（对所有字幕类型都适用）

                Section {
                    SubtitleFormSlider(
                        title: "字幕亮度",
                        value: Binding(
                            get: { style.boostHDRbrightness },
                            set: { style.boostHDRbrightness = $0 }
                        ),
                        range: 0 ... 1,
                        lowerLabel: "0%", upperLabel: "100%",
                        valueLabel: Double(style.boostHDRbrightness).formatted(.percent.precision(.fractionLength(0)))
                    )
                }

                if canShow {
                    // MARK: - 字幕样式总开关

                    Section {
                        Toggle("字幕样式", isOn: Binding(
                            get: { isImage ? style.enableBitmapCustomization : style.overwriteSubtitleStyle },
                            set: {
                                if isImage {
                                    style.enableBitmapCustomization = $0
                                } else {
                                    style.overwriteSubtitleStyle = $0
                                }
                            }
                        ))
                    }

                    // 根据字幕类型显示不同的调整控件。
                    if isImage {
                        if style.enableBitmapCustomization {
                            SubtitleBitmapControls()
                                .environmentObject(style)
                        }
                    } else if style.overwriteSubtitleStyle {
                        SubtitleTextFormControls(style: style)
                    }
                }
            }
            .modifier(PlayerPanelFormModifier())
            .scrollContentBackground(.hidden)
            .toggleStyle(.switch)
            .onAppear {
                // 如果是参数模式，不需要从 EnvironmentObject 获取
                if useParameterMode {
                    return
                }

                // EnvironmentObject 模式：从 playerCoordinator 获取信息
                guard let controller = playerCoordinator.controller else {
                    return
                }
                updateStyleAvailability(controller.subtitleStyleCustomization)
            }
            .onReceive(
                // 参数模式没有本地播放器，创建订阅时就必须避免读取其环境对象。
                useParameterMode
                    ? Empty().eraseToAnyPublisher()
                    : playerCoordinator.controller?
                    .$subtitleStyleCustomization
                    .eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()
            ) { customization in
                guard !useParameterMode else {
                    return
                }
                updateStyleAvailability(customization)
            }
        }

        private func updateStyleAvailability(_ customization: SubtitleStyleCustomization) {
            // 外挂格式按实际解析内容识别；ASS 保留作者样式，只开放 SRT/VTT 文字调整。
            envCanShowSubtitleStyle = customization != .unavailable
            envIsImageSubtitle = customization == .bitmap
        }
    }

    // MARK: - 原生表单控件

    /// 统一保留标题、当前数值和滑块下方的端点说明，不绘制自定义滑轨或刻度。
    struct SubtitleFormSlider<Value: BinaryFloatingPoint>: View where Value.Stride: BinaryFloatingPoint {
        let title: LocalizedStringKey
        @Binding var value: Value
        let range: ClosedRange<Value>
        var step: Value.Stride?
        let lowerLabel: String
        let upperLabel: String
        let valueLabel: String

        var body: some View {
            VStack(alignment: .leading) {
                LabeledContent(title, value: valueLabel)
                if let step {
                    Slider(value: $value, in: range, step: step) {
                        Text(title)
                    }
                    .labelsHidden()
                } else {
                    Slider(value: $value, in: range) {
                        Text(title)
                    }
                    .labelsHidden()
                }
                HStack {
                    Text(lowerLabel)
                    Spacer()
                    Text(upperLabel)
                }
                .playerPanelFormFont(.footnote)
                .foregroundStyle(.secondary)
            }
        }
    }

    private struct SubtitleTextFormControls: View {
        @ObservedObject var style: SubtitleStyleModel

        var body: some View {
            // MARK: - 字体大小和字体样式

            Section("字体样式") {
                Stepper(value: $style.textFontSize, in: 9 ... 64, step: 1) {
                    HStack {
                        Text("字体大小")
                        Spacer()
                        Text("\(Int(style.textFontSize))")
                    }
                }
                Toggle("粗体", isOn: $style.textBold)
                Toggle("斜体", isOn: $style.textItalic)
                Stepper(value: $style.letterSpacing, in: 0 ... 20, step: 1) {
                    HStack {
                        Text("字间距")
                        Spacer()
                        Text("\(Int(style.letterSpacing))")
                    }
                }
            }

            // MARK: - 位置调整

            Section("位置调整") {
                PlayerPanelPicker("水平对齐", selection: Binding(
                    get: {
                        style.textPosition.horizontalAlign == .leading ? 0
                            : style.textPosition.horizontalAlign == .trailing ? 2 : 1
                    },
                    set: {
                        style.textPosition.horizontalAlign = $0 == 0 ? .leading : $0 == 2 ? .trailing : .center
                    }
                )) {
                    Text(HorizontalAlignment.leading.displayName).tag(0)
                    Text(HorizontalAlignment.center.displayName).tag(1)
                    Text(HorizontalAlignment.trailing.displayName).tag(2)
                }
                PlayerPanelPicker("垂直对齐", selection: Binding(
                    get: {
                        style.textPosition.verticalAlign == .top ? 0
                            : style.textPosition.verticalAlign == .bottom ? 2 : 1
                    },
                    set: {
                        style.textPosition.verticalAlign = $0 == 0 ? .top : $0 == 2 ? .bottom : .center
                    }
                )) {
                    Text(VerticalAlignment.top.displayName).tag(0)
                    Text(VerticalAlignment.center.displayName).tag(1)
                    Text(VerticalAlignment.bottom.displayName).tag(2)
                }
                // 居中对齐时不显示垂直边距。
                if style.textPosition.verticalAlign == .top || style.textPosition.verticalAlign == .bottom {
                    SubtitleFormSlider(
                        title: "垂直位置",
                        value: $style.textPosition.verticalMargin,
                        range: 0 ... 100,
                        lowerLabel: "0", upperLabel: "100",
                        valueLabel: "\(Int(style.textPosition.verticalMargin))"
                    )
                }
            }

            // MARK: - 颜色设置

            Section("颜色设置") {
                ColorPicker("文字颜色", selection: $style.textColor)
                opacitySlider("文字透明度", value: $style.textColorOpacity)
            }

            // MARK: - 边框和阴影

            Section("边框和阴影") {
                PlayerPanelPicker("样式", selection: $style.borderStyle) {
                    // 字幕文件可能携带预设之外的值，保留原值并提供对应选项。
                    if style.borderStyle != 1, style.borderStyle != 3 {
                        Text("原始样式").tag(style.borderStyle)
                    }
                    Text("边框").tag(1)
                    Text("底色").tag(3)
                }
                ColorPicker("边框颜色", selection: $style.outlineColor)
                opacitySlider("边框透明度", value: $style.outlineColorOpacity)
                Stepper(value: $style.outlineWidth, in: 0 ... 10, step: 1) {
                    HStack {
                        Text("边框宽度")
                        Spacer()
                        Text("\(Int(style.outlineWidth))")
                    }
                }
                ColorPicker("阴影颜色", selection: $style.shadowColor)
                opacitySlider("阴影透明度", value: $style.shadowColorOpacity)
                Stepper(value: $style.shadowWidth, in: 0 ... 10, step: 1) {
                    HStack {
                        Text("阴影宽度")
                        Spacer()
                        Text("\(Int(style.shadowWidth))")
                    }
                }
            }
        }

        private func opacitySlider(_ title: LocalizedStringKey, value: Binding<Double>) -> some View {
            SubtitleFormSlider(
                title: title, value: value, range: 0 ... 1, step: 0.05,
                lowerLabel: "0%", upperLabel: "100%",
                valueLabel: value.wrappedValue.formatted(.percent.precision(.fractionLength(0)))
            )
        }
    }

#endif
