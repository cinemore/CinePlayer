#if os(tvOS)
import CinePlayerSDK
import Combine
import SwiftUI

struct TVSubtitleAdjustmentView: View {
    @ObservedObject var coordinator: CinePlayer.Coordinator
    @ObservedObject var style: SubtitleStyleModel
    @State private var customization: SubtitleStyleCustomization = .unavailable

    var body: some View {
        Form {
            Section("时间偏移") {
                SubtitleTimeOffsetInput(value: $coordinator.subtitleDelay)
            }
            Section("字幕亮度") {
                TVPlayerValueControl(title: "字幕亮度", value: $style.boostHDRbrightness, range: 0 ... 1, step: 0.05)
            }
            if customization == .bitmap {
                Section("图片字幕") {
                    Toggle("字幕样式", isOn: $style.enableBitmapCustomization)
                    if style.enableBitmapCustomization {
                        TVPlayerValueControl(title: "缩放", value: $style.bitmapScale, range: 0.1 ... 3, step: 0.1)
                        TVPlayerValueControl(title: "水平位置", value: $style.bitmapHorizontalOffset, range: -500 ... 500, step: 10)
                        TVPlayerValueControl(title: "垂直位置", value: $style.bitmapVerticalOffset, range: -500 ... 500, step: 10)
                        TVPlayerValueControl(title: "透明度", value: $style.bitmapOpacity, range: 0 ... 1, step: 0.05)
                        Button("重置") {
                            style.bitmapScale = 1
                            style.bitmapHorizontalOffset = 0
                            style.bitmapVerticalOffset = 0
                            style.bitmapOpacity = 1
                        }
                    }
                }
            } else if customization != .unavailable {
                Section("字体样式") {
                    Toggle("字幕样式", isOn: $style.overwriteSubtitleStyle)
                    if style.overwriteSubtitleStyle {
                        TVPlayerValueControl(title: "字体大小", value: $style.textFontSize, range: 9 ... 64, step: 1)
                        Toggle("粗体", isOn: $style.textBold)
                        Toggle("斜体", isOn: $style.textItalic)
                        TVPlayerValueControl(title: "字间距", value: $style.letterSpacing, range: 0 ... 20, step: 1)
                        optionPicker("垂直对齐", selection: Binding(
                            get: { style.textPosition.verticalAlign == .top ? 0 : style.textPosition.verticalAlign == .bottom ? 2 : 1 },
                            set: { style.textPosition.verticalAlign = $0 == 0 ? .top : $0 == 2 ? .bottom : .center }
                        )) {
                            Text("顶部").tag(0)
                            Text("居中").tag(1)
                            Text("底部").tag(2)
                        }
                        optionPicker("水平对齐", selection: Binding(
                            get: { style.textPosition.horizontalAlign == .leading ? 0 : style.textPosition.horizontalAlign == .trailing ? 2 : 1 },
                            set: { style.textPosition.horizontalAlign = $0 == 0 ? .leading : $0 == 2 ? .trailing : .center }
                        )) {
                            Text("左侧").tag(0)
                            Text("居中").tag(1)
                            Text("右侧").tag(2)
                        }
                        TVPlayerValueControl(title: "垂直位置", value: $style.textPosition.verticalMargin, range: 0 ... 100, step: 1)
                        colorPicker("文字颜色", selection: $style.textColor)
                        TVPlayerValueControl(title: "文字透明度", value: $style.textColorOpacity, range: 0 ... 1, step: 0.05)
                        colorPicker("边框颜色", selection: $style.outlineColor)
                        optionPicker("样式", selection: $style.borderStyle) {
                            // 字幕文件可能携带预设之外的值，保留原值并提供对应选项。
                            if style.borderStyle != 1, style.borderStyle != 3 {
                                Text("原始样式").tag(style.borderStyle)
                            }
                            Text("边框").tag(1)
                            Text("底色").tag(3)
                        }
                        TVPlayerValueControl(title: "边框透明度", value: $style.outlineColorOpacity, range: 0 ... 1, step: 0.05)
                        TVPlayerValueControl(title: "边框宽度", value: $style.outlineWidth, range: 0 ... 10, step: 1)
                        colorPicker("阴影颜色", selection: $style.shadowColor)
                        TVPlayerValueControl(title: "阴影透明度", value: $style.shadowColorOpacity, range: 0 ... 1, step: 0.05)
                        TVPlayerValueControl(title: "阴影宽度", value: $style.shadowWidth, range: 0 ... 10, step: 1)
                    }
                }
            }
        }
        .safeAreaPadding(.horizontal, 48)
        .onReceive(coordinator.controller?.$subtitleStyleCustomization.eraseToAnyPublisher() ?? Empty().eraseToAnyPublisher()) {
            customization = $0
        }
    }

    private func colorPicker(_ title: LocalizedStringKey, selection: Binding<Color>) -> some View {
        optionPicker(title, selection: selection) {
            if ![Color.white, .black, .yellow, .red, .green, .blue, .clear].contains(selection.wrappedValue) {
                Text("自定义").tag(selection.wrappedValue)
            }
            Text("白色").tag(Color.white)
            Text("黑色").tag(Color.black)
            Text("黄色").tag(Color.yellow)
            Text("红色").tag(Color.red)
            Text("绿色").tag(Color.green)
            Text("蓝色").tag(Color.blue)
            Text("透明").tag(Color.clear)
        }
    }

    private func optionPicker(
        _ title: LocalizedStringKey, selection: Binding<some Hashable>,
        @ViewBuilder content: () -> some View
    ) -> some View {
        HStack {
            Text(title)
            Spacer()
            Picker(title, selection: selection, content: content)
                .labelsHidden()
                .pickerStyle(.menu)
                .buttonStyle(.bordered)
                .accessibilityLabel(title)
        }
    }
}

#endif
