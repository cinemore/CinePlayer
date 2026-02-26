import SwiftUI

// MARK: 侧边弹出窗口 - 设置

struct SiderSettingView: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @StateObject private var playSettingAdapter = PlaySettingParityAdapter()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("播放设置")
                .f17s()
                .padding()

            PlaySettingPage(adapter: playSettingAdapter, hideBackground: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            playSettingAdapter.bind(sessionStore: sessionStore)
        }
        .compatibleOnChange(of: sessionStore.controlConfig) { _ in
            playSettingAdapter.bind(sessionStore: sessionStore)
        }
    }
}
