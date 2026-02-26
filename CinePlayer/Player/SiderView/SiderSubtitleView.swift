import SwiftUI

#if !os(tvOS)
// MARK: 侧边弹出窗口 - 字幕
struct SiderSubtitleView: View {
    @EnvironmentObject var playerControlModel: PlayerControlModel

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $playerControlModel.subtitleTab) {
                Text("内封字幕").tag(0)
                Text("外部字幕").tag(1)
                Text("字幕调整").tag(2)
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .padding(.bottom, 20)

            if playerControlModel.subtitleTab == 0 {
                EmbeddedSubtitleView()
            } else if playerControlModel.subtitleTab == 1 {
                ExternalSubtitleView()
            } else if playerControlModel.subtitleTab == 2 {
                SubtitleAdjustmentView()
            }
        }
        .padding(.top)
        .padding(.horizontal)
    }
}
#else
struct SiderSubtitleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("字幕")
                .f17s()
            Text("tvOS 使用系统焦点交互，不展示分段字幕面板。")
                .f12r()
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding()
    }
}
#endif
