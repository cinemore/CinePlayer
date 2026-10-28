import SwiftUI

#if !os(tvOS)
// MARK: 侧边弹出窗口 - 字幕
struct SiderSubtitleView: View {
    @EnvironmentObject var playerControlModel: PlayerControlModel

    var body: some View {
        VStack(spacing: 0) {
            AdaptiveSegmentedPicker("字幕", selection: $playerControlModel.subtitleTab) {
                Text("内封字幕").tag(0)
                Text("外部字幕").tag(1)
                Text("字幕调整").tag(2)
            }
            .padding(.bottom)
            .padding(.horizontal)

            if playerControlModel.subtitleTab == 0 {
                EmbeddedSubtitleView()
            } else if playerControlModel.subtitleTab == 1 {
                ExternalSubtitleView()
            } else if playerControlModel.subtitleTab == 2 {
                SubtitleAdjustmentView()
            }
        }
        .padding(.top)
    }
}
#else
struct SiderSubtitleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("字幕")
                .font(.headline)
            Text("tvOS 使用系统焦点交互，不展示分段字幕面板。")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.65))
        }
        .padding()
    }
}
#endif
