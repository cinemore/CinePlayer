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
                #if os(macOS)
                    .toolbarBackground(.hidden, for: .windowToolbar)
                #endif
            } else {
                #if os(macOS)
                    if #available(macOS 26.0, *) {
                        PlayerOpenView()
                            .toolbarBackground(.hidden, for: .windowToolbar)
                    } else {
                        // 低版本的会导致按钮看不清，所以不隐藏
                        PlayerOpenView()
                    }
                #else
                    PlayerOpenView()
                #endif
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #if os(macOS)
            .onAppear {
                let windowCount = NSApp.windows.count
                let visibleCount = NSApp.windows.filter { $0.isVisible }.count
                cinemoreLog(
                    level: .debug,
                    "[WindowDebug] PlayerRootView.onAppear currentSource=\(sessionStore.currentSource != nil) windows=\(windowCount) visible=\(visibleCount)"
                )
                // 应用启动或退出播放时，锁定一个合适的初始窗口大小并禁用缩放
                windowController.attachToKeyWindowIfNeeded()
                windowController.isPlaybackActive = false
                windowController.lockWindowToInitialSize()
            }
            .onDisappear {
                let windowCount = NSApp.windows.count
                let visibleCount = NSApp.windows.filter { $0.isVisible }.count
                cinemoreLog(
                    level: .debug,
                    "[WindowDebug] PlayerRootView.onDisappear currentSource=\(sessionStore.currentSource != nil) windows=\(windowCount) visible=\(visibleCount)"
                )
            }
            .compatibleOnChange(of: sessionStore.currentSource?.id) { newID in
                let windowCount = NSApp.windows.count
                let visibleCount = NSApp.windows.filter { $0.isVisible }.count
                cinemoreLog(
                    level: .debug,
                    "[WindowDebug] PlayerRootView.currentSourceDidChange newID=\(String(describing: newID)) windows=\(windowCount) visible=\(visibleCount)"
                )
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
