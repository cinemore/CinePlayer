import SwiftUI

struct PlaySettingPage: View {
    @ObservedObject var adapter: PlaySettingParityAdapter
    #if os(visionOS)
        @EnvironmentObject private var visionSettings: VisionSettings
    #endif

    var hideBackground: Bool = false

    private var gestureSectionTitleKey: LocalizedStringKey {
        #if os(visionOS)
            return "按钮"
        #elseif os(iOS) || os(tvOS)
            return "手势"
        #else
            return "按键"
        #endif
    }

    var body: some View {
        Form {
            Section(gestureSectionTitleKey) {
                #if os(iOS)
                    PlaySettingPicker("双击后退", selection: $adapter.skipBackwardSeconds)
                    PlaySettingPicker("双击前进", selection: $adapter.skipForwardSeconds)
                    Toggle(isOn: $adapter.longPressSpeedUpEnabled) {
                        Text("长按倍速播放")
                    }
                    if adapter.longPressSpeedUpEnabled {
                        Picker("长按倍速", selection: $adapter.longPressPlaybackRate) {
                            ForEach([Float(1.5), 2, 2.5, 3, 4], id: \.self) { rate in
                                Text("\(rate.playbackRateText)x").tag(rate)
                            }
                        }
                    }
                #elseif os(visionOS)
                    PlaySettingPicker("后退按钮", selection: $adapter.skipBackwardSeconds)
                    PlaySettingPicker("前进按钮", selection: $adapter.skipForwardSeconds)
                #elseif os(tvOS)
                    PlaySettingPicker("手势后退", selection: $adapter.skipBackwardSeconds)
                    PlaySettingPicker("手势前进", selection: $adapter.skipForwardSeconds)
                #else
                    PlaySettingPicker("左键后退", selection: $adapter.skipBackwardSeconds)
                    PlaySettingPicker("右键前进", selection: $adapter.skipForwardSeconds)
                #endif
            }
            #if os(visionOS)
                Section("沉浸模式") {
                    Picker("沉浸风格", selection: visionSettings.immersionStyleBinding) {
                        ForEach(VisionImmersionStyleSetting.allCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                }
            #endif
        }
        .modifier(PlayerPanelFormModifier(enabled: hideBackground))
        .if(!hideBackground) {
            $0.navigationTitle("播放设置")
            #if os(iOS) || os(visionOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        #if !os(tvOS)
        .if(hideBackground) {
            $0.scrollContentBackground(.hidden)
        }
        #endif
    }
}
