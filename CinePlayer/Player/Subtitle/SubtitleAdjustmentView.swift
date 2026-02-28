//
//  SubtitleAdjustmentView.swift
//  Cinemore
//
//  Created by lf on 2024/12/25.
//

import CinePlayerSDK
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // MARK: - 时间偏移调整

                    VStack(spacing: 12) {
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

                    let effectiveCanShow =
                        useParameterMode ? paramCanShowSubtitleStyle! : envCanShowSubtitleStyle
                    let effectiveIsImage =
                        useParameterMode ? paramIsImageSubtitle! : envIsImageSubtitle
                    // 在 EnvironmentObject 模式下，使用 @EnvironmentObject 绑定的 subtitleStyle 以确保 UI 更新
                    let effectiveSubtitleStyle =
                        useParameterMode
                        ? paramSubtitleStyle
                        : envSubtitleStyle

                    VStack(spacing: 12) {
                        VStack(spacing: 8) {
                            SubtitleBrightnessSlider(
                                title: "字幕亮度",
                                value: Binding(
                                    get: { effectiveSubtitleStyle.boostHDRbrightness },
                                    set: { effectiveSubtitleStyle.boostHDRbrightness = $0 }
                                )
                            )
                        }
                    }

                    if effectiveCanShow {
                        // MARK: - 字幕样式总开关

                        SubtitleToggleRow(
                            title: "字幕样式",
                            isOn: Binding(
                                get: {
                                    effectiveIsImage
                                        ? effectiveSubtitleStyle.enableBitmapCustomization
                                        : effectiveSubtitleStyle
                                            .overwriteSubtitleStyle
                                },
                                set: {
                                    if effectiveIsImage {
                                        effectiveSubtitleStyle.enableBitmapCustomization = $0
                                    } else {
                                        effectiveSubtitleStyle.overwriteSubtitleStyle = $0
                                    }
                                }
                            )
                        )

                        // 根据字幕类型显示不同的调整控件
                        if effectiveIsImage {
                            // 图片字幕调整控件
                            if effectiveSubtitleStyle.enableBitmapCustomization {
                                SubtitleBitmapControls()
                                    .environmentObject(effectiveSubtitleStyle)
                            }
                        } else {
                            // 文字字幕调整控件
                            if effectiveSubtitleStyle.overwriteSubtitleStyle {
                                // MARK: - 字体大小调整

                                VStack(spacing: 12) {
                                    SubtitleSectionHeader(title: "字体大小")

                                    SubtitleAdjustmentRow(
                                        title: "\(Int(effectiveSubtitleStyle.textFontSize))"
                                    ) {
                                        Stepper(
                                            value: Binding(
                                                get: { effectiveSubtitleStyle.textFontSize },
                                                set: { effectiveSubtitleStyle.textFontSize = $0 }
                                            ),
                                            in: 9...64,
                                            step: 1.0,
                                            label: { EmptyView() }
                                        )
                                    }
                                }

                                // MARK: - 字体样式

                                VStack(spacing: 12) {
                                    SubtitleSectionHeader(title: "字体样式")

                                    VStack(spacing: 8) {
                                        // 粗体开关
                                        SubtitleToggleRow(
                                            title: "粗体",
                                            isOn: Binding(
                                                get: { effectiveSubtitleStyle.textBold },
                                                set: { effectiveSubtitleStyle.textBold = $0 }
                                            )
                                        )

                                        // 斜体开关
                                        SubtitleToggleRow(
                                            title: "斜体",
                                            isOn: Binding(
                                                get: { effectiveSubtitleStyle.textItalic },
                                                set: { effectiveSubtitleStyle.textItalic = $0 }
                                            )
                                        )

                                        SubtitleAdjustmentRow(
                                            title:
                                                "字间距: \(Int(effectiveSubtitleStyle.letterSpacing))"
                                        ) {
                                            Stepper(
                                                value: Binding(
                                                    get: { effectiveSubtitleStyle.letterSpacing },
                                                    set: {
                                                        effectiveSubtitleStyle.letterSpacing = $0
                                                    }
                                                ),
                                                in: 0...20,
                                                step: 1
                                            ) { EmptyView() }
                                        }
                                    }
                                }

                                // MARK: - 位置调整

                                VStack(spacing: 12) {
                                    SubtitleSectionHeader(title: "位置调整")

                                    VStack(spacing: 12) {
                                        // 水平位置选择
                                        SubtitleHorizontalAlignment()
                                            .environmentObject(effectiveSubtitleStyle)

                                        // 垂直对齐选择
                                        SubtitleVerticalAlignment()
                                            .environmentObject(effectiveSubtitleStyle)

                                        // 垂直位置调整
                                        if effectiveSubtitleStyle.textPosition.verticalAlign == .top
                                            || effectiveSubtitleStyle.textPosition.verticalAlign
                                                == .bottom
                                        {
                                            SubtitlePositionSlider(
                                                title: "垂直位置",
                                                value: Binding(
                                                    get: {
                                                        Double(
                                                            effectiveSubtitleStyle.textPosition
                                                                .verticalMargin)
                                                    },
                                                    set: {
                                                        effectiveSubtitleStyle.textPosition
                                                            .verticalMargin = CGFloat($0)
                                                    }
                                                ),
                                                range: 0...100,
                                                iconLeft: effectiveSubtitleStyle.textPosition
                                                    .verticalAlign == .bottom
                                                    ? "arrow.down" : "arrow.up",
                                                iconRight: effectiveSubtitleStyle.textPosition
                                                    .verticalAlign == .bottom
                                                    ? "arrow.up" : "arrow.down"
                                            )
                                        }
                                    }
                                }

                                // MARK: - 颜色设置

                                VStack(spacing: 12) {
                                    SubtitleSectionHeader(title: "颜色设置")

                                    VStack(spacing: 8) {
                                        // 文字颜色
                                        SubtitleColorRow(
                                            title: "文字颜色",
                                            color: Binding(
                                                get: { effectiveSubtitleStyle.textColor },
                                                set: { effectiveSubtitleStyle.textColor = $0 }
                                            )
                                        )

                                        // 文字透明度
                                        SubtitleOpacitySlider(
                                            title: "文字透明度",
                                            value: Binding(
                                                get: { effectiveSubtitleStyle.textColorOpacity },
                                                set: {
                                                    effectiveSubtitleStyle.textColorOpacity = $0
                                                }
                                            )
                                        )
                                    }
                                }

                                VStack(spacing: 12) {
                                    SubtitleSectionHeader(title: "边框和阴影")

                                    HStack {
                                        Text("样式")
                                            .f14r()
                                            .foregroundColor(.white)
                                        Spacer()
                                        Picker(
                                            "",
                                            selection: Binding(
                                                get: { effectiveSubtitleStyle.borderStyle },
                                                set: { effectiveSubtitleStyle.borderStyle = $0 }
                                            )
                                        ) {
                                            Text("边框").tag(1)
                                            Text("底色").tag(3)
                                        }
                                        .pickerStyle(.segmented)
                                        .labelsHidden()
                                        .fixedSize()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                    )

                                    VStack(spacing: 8) {
                                        SubtitleColorRow(
                                            title: "边框颜色",
                                            color: Binding(
                                                get: { effectiveSubtitleStyle.outlineColor },
                                                set: { effectiveSubtitleStyle.outlineColor = $0 }
                                            )
                                        )

                                        // 边框透明度
                                        SubtitleOpacitySlider(
                                            title: "边框透明度",
                                            value: Binding(
                                                get: { effectiveSubtitleStyle.outlineColorOpacity },
                                                set: {
                                                    effectiveSubtitleStyle.outlineColorOpacity = $0
                                                }
                                            )
                                        )

                                        SubtitleAdjustmentRow(
                                            title:
                                                "边框宽度: \(Int(effectiveSubtitleStyle.outlineWidth))"
                                        ) {
                                            Stepper(
                                                value: Binding(
                                                    get: { effectiveSubtitleStyle.outlineWidth },
                                                    set: {
                                                        effectiveSubtitleStyle.outlineWidth = $0
                                                    }
                                                ),
                                                in: 0...10,
                                                step: 1
                                            ) { EmptyView() }
                                        }
                                    }

                                    // 阴影颜色
                                    VStack(spacing: 8) {
                                        SubtitleColorRow(
                                            title: "阴影颜色",
                                            color: Binding(
                                                get: { effectiveSubtitleStyle.shadowColor },
                                                set: { effectiveSubtitleStyle.shadowColor = $0 }
                                            )
                                        )

                                        // 阴影透明度
                                        SubtitleOpacitySlider(
                                            title: "阴影透明度",
                                            value: Binding(
                                                get: { effectiveSubtitleStyle.shadowColorOpacity },
                                                set: {
                                                    effectiveSubtitleStyle.shadowColorOpacity = $0
                                                }
                                            )
                                        )

                                        SubtitleAdjustmentRow(
                                            title:
                                                "阴影宽度: \(Int(effectiveSubtitleStyle.shadowWidth))"
                                        ) {
                                            Stepper(
                                                value: Binding(
                                                    get: { effectiveSubtitleStyle.shadowWidth },
                                                    set: { effectiveSubtitleStyle.shadowWidth = $0 }
                                                ),
                                                in: 0...10,
                                                step: 1
                                            ) { EmptyView() }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 24)
                .padding(.horizontal, 2)
            }
            .onAppear {
                // 如果是参数模式，不需要从 EnvironmentObject 获取
                if useParameterMode {
                    return
                }

                // EnvironmentObject 模式：从 playerCoordinator 获取信息
                guard let controller = playerCoordinator.controller else {
                    return
                }
                guard let subtitleTrack = controller.subtitleTrack else {
                    return
                }

                // 设置字幕类型和是否显示样式控制
                envIsImageSubtitle = subtitleTrack.isImageSubtitle

                // ASS 字幕不显示样式控制，其他类型都显示
                if !subtitleTrack.isASS {
                    envCanShowSubtitleStyle = true
                }
            }
        }
    }

    // MARK: - 子组件

    struct SubtitleSectionHeader: View {
        let title: String

        var body: some View {
            HStack {
                Text(title.uppercased())
                    .f13m()
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 16)
        }
    }

    struct SubtitleAdjustmentRow<Trailing: View>: View {
        let title: String
        let trailing: () -> Trailing

        init(title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
            self.title = title
            self.trailing = trailing
        }

        var body: some View {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .f14r()
                        .foregroundColor(.white)
                }

                Spacer()

                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
    }

#endif
