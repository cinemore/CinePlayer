#if os(visionOS)
import RealityKit
import SwiftUI

/// 环境不持有视频；打开取消或失败时仍在原播放窗口继续。
struct VisionImmersiveSpaceView: View {
    static let spaceID = "cineplayer.immersive.player"
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject private var immersiveCoordinator: VisionImmersivePlaybackCoordinator
    @EnvironmentObject private var visionSettings: VisionSettings
    @Environment(\.dismissImmersiveSpace) private var dismissImmersiveSpace
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        RealityView { _ in }
            .onAppear { updateAudio(isImmersive: true) }
            .onChange(of: visionSettings.immersionStyle) { _, _ in updateAudio(isImmersive: true) }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .background else { return }
                Task { await immersiveCoordinator.requestDismiss { await dismissImmersiveSpace() } }
            }
            .onDisappear {
                updateAudio(isImmersive: false)
                if immersiveCoordinator.spaceDidDisappear() { playerModel.close(); sessionStore.close() }
            }
    }
    private func updateAudio(isImmersive: Bool) {
        VisionSpatialAudio.apply(isImmersive: isImmersive, immersionStyle: visionSettings.immersionStyle)
    }
}
#endif
