import SwiftUI
import CinePlayerSDK

#if os(visionOS)
struct VisionPlayerHostView: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @Environment(\.pushWindow) private var pushWindow

    var body: some View {
        PlayerOpenView()
            .onChange(of: sessionStore.currentSource?.id, initial: true) { _, sourceID in
                if sourceID != nil {
                    // 系统暂时隐藏首页；关闭播放窗口后恢复原位置和历史页导航。
                    pushWindow(id: VisionPlayerWindowView.windowID)
                }
            }
    }
}

/// 播放窗口与打开文件窗口分开，系统关闭与界面关闭共用 SDK 的公开生命周期。
struct VisionPlayerWindowView: View {
    static let windowID = "cineplayer.playback"

    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject private var immersiveCoordinator: VisionImmersivePlaybackCoordinator
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openImmersiveSpace) private var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace

    var body: some View {
        Group {
            if sessionStore.currentSource != nil { PlayerControlView() }
            else { Color.clear }
        }
        .environment(\.usesVisionPlayerTypography, true)
        .background { VisionPlayerAspectRatio(coordinator: playerModel.playerCoordinator) }
        .task {
            guard sessionStore.currentSource != nil else { dismiss(); return }
            await immersiveCoordinator.requestOpen {
                await openImmersiveSpace(id: VisionImmersiveSpaceView.spaceID)
            } dismissAction: { await dismissImmersiveSpace() }
        }
        .onChange(of: sessionStore.currentSource?.id) { _, id in if id == nil { dismiss() } }
        .onDisappear {
            playerModel.close()
            sessionStore.close()
            Task { await immersiveCoordinator.requestDismiss { await dismissImmersiveSpace() } }
        }
    }
}

private struct VisionPlayerAspectRatio: View {
    @ObservedObject var coordinator: CinePlayer.Coordinator
    var body: some View {
        VisionPlayerWindowGeometry(aspectRatio: coordinator.videoTrack.flatMap {
            VisionPlayerWindowSizing.aspectRatio(size: $0.naturalSize, pixelAspect: $0.aspectRatio,
                                                rotation: Double($0.videoRotation))
        })
    }
}
#endif
