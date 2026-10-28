import CinePlayerSDK
import SwiftUI

#if !os(tvOS)
    /// 音轨和视频轨道共用播放器分组表单适配，切换仍由调用方处理。
    struct PlayerTrackSelectionList<Content: View>: View {
        @ViewBuilder var content: Content

        var body: some View {
            Form {
                Section {
                    content
                }
            }
            .modifier(PlayerPanelFormModifier())
            .scrollContentBackground(.hidden)
            .scrollIndicators(.hidden)
        }
    }
#endif
