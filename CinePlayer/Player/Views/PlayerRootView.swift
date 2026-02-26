import SwiftUI

struct PlayerRootView: View {
    @EnvironmentObject var sessionStore: PlayerSessionStore
    #if os(macOS)
    @EnvironmentObject var windowController: PlayerWindowController
    #endif

    var body: some View {
        ZStack {
            if sessionStore.currentSource != nil {
                PlayerControlView()
            } else {
                PlayerOpenView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
        #if os(macOS)
        .onAppear {
            // 应用启动或退出播放时，锁定一个合适的初始窗口大小并禁用缩放
            windowController.attachToKeyWindowIfNeeded()
            windowController.isPlaybackActive = false
            windowController.lockWindowToInitialSize()
        }
        .compatibleOnChange(of: sessionStore.currentSource?.id) { newID in
            windowController.attachToKeyWindowIfNeeded()
            if newID != nil {
                // 进入播放：解锁窗口大小，交给播放窗口布局逻辑控制
                windowController.isPlaybackActive = true
                windowController.unlockWindowForPlayback()
            } else {
                // 退出播放：恢复到初始窗口大小，并再次禁用缩放
                windowController.isPlaybackActive = false
                windowController.lockWindowToInitialSize()
            }
        }
        #endif
    }
}
