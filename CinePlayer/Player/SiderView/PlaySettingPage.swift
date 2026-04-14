import SwiftUI

struct PlaySettingPage: View {
    @ObservedObject var adapter: PlaySettingParityAdapter

    var hideBackground: Bool = false

    private var gestureSectionTitleKey: LocalizedStringKey {
        #if os(iOS) || os(visionOS) || os(tvOS)
            return "手势"
        #else
            return "按键"
        #endif
    }

    var body: some View {
        Form {
            Section(gestureSectionTitleKey) {
                #if os(iOS) || os(visionOS)
                    PlaySettingPicker("双击后退", selection: $adapter.skipBackwardSeconds)
                    PlaySettingPicker("双击前进", selection: $adapter.skipForwardSeconds)
                    Toggle(isOn: $adapter.longPressSpeedUpEnabled) {
                        Text("长按倍速播放")
                    }
                #elseif os(tvOS)
                    PlaySettingPicker("手势后退", selection: $adapter.skipBackwardSeconds)
                    PlaySettingPicker("手势前进", selection: $adapter.skipForwardSeconds)
                #else
                    PlaySettingPicker("左键后退", selection: $adapter.skipBackwardSeconds)
                    PlaySettingPicker("右键前进", selection: $adapter.skipForwardSeconds)
                #endif
            }
        }
        .formStyle(.grouped)
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
