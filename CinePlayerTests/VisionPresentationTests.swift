#if os(visionOS)
import CoreGraphics
import SwiftUI
import Testing
@testable import CinePlayer

extension PlayerStateTests {
    @Test func visionImmersionBindingKeepsSystemAndSettingsInSync() {
        var setting = VisionImmersionStyleSetting.progressive
        let binding = Binding(get: { setting }, set: { setting = $0 })
        let erased = binding.styleErased
        #expect(erased.wrappedValue is ProgressiveImmersionStyle)
        erased.wrappedValue = MixedImmersionStyle()
        #expect(setting == .mixed)
        setting = .full
        #expect(erased.wrappedValue is FullImmersionStyle)
        erased.wrappedValue = ProgressiveImmersionStyle()
        #expect(setting == .progressive)
    }

    @Test func visionPanelsKeepOppositeSideAndMediaInfo() {
        let controls = PlayerControlModel()
        controls.toggleVisionPanel(.settings)
        controls.toggleVisionPanel(.subtitle)
        controls.showMediaInfoCard = true
        controls.showPlaybackSpeedContainer = true
        controls.toggleVisionPanel(.enhancement)
        #expect(controls.leadingVisionPanel == .enhancement)
        #expect(controls.trailingVisionPanel == .subtitle)
        #expect(controls.showMediaInfoCard)
        #expect(!controls.showPlaybackSpeedContainer)
        controls.toggleVisionPanel(.enhancement)
        #expect(controls.leadingVisionPanel == nil)
        #expect(controls.trailingVisionPanel == .subtitle)
        #expect(controls.showMediaInfoCard)
    }

    @Test func visionWindowRespectsRotationAndPixelAspect() throws {
        let ratio = try #require(VisionPlayerWindowSizing.aspectRatio(
            size: CGSize(width: 1440, height: 1080), pixelAspect: CGSize(width: 4, height: 3), rotation: 90))
        #expect(abs(ratio - 0.5625) < 0.0001)
        let size = try #require(VisionPlayerWindowSizing.size(preserving: CGSize(width: 1200, height: 675), aspectRatio: ratio))
        #expect(abs(size.width / size.height - ratio) < 0.0001)
        #expect(abs(size.width * size.height - 1200 * 675) < 1)
        #expect(VisionPlayerWindowSizing.aspectRatio(size: .zero, pixelAspect: .zero, rotation: 0) == nil)
    }

    @Test func visionImmersiveCancellationKeepsWindowPlayback() async {
        let coordinator = VisionImmersivePlaybackCoordinator()
        await coordinator.requestOpen(openAction: { .userCancelled }, dismissAction: {
            Issue.record("Cancelled opening must not dismiss another space")
        })
        #expect(coordinator.state.isClosed)
        #expect(!coordinator.spaceDidDisappear())
    }

    @Test func visionCloseWhileOpeningDismissesLateSpaceExactlyOnce() async {
        let coordinator = VisionImmersivePlaybackCoordinator()
        let gate = TestGate()
        let started = AsyncStream<Void>.makeStream()
        var dismissCount = 0
        let opening = Task { @MainActor in
            await coordinator.requestOpen {
                started.continuation.yield()
                await gate.wait()
                return .opened
            } dismissAction: { dismissCount += 1 }
        }
        var starts = started.stream.makeAsyncIterator()
        await starts.next()
        await coordinator.requestDismiss { dismissCount += 1 }
        await gate.open()
        await opening.value
        #expect(dismissCount == 1)
        #expect(coordinator.state.isClosed)
        #expect(coordinator.spaceDidDisappear())
        #expect(!coordinator.spaceDidDisappear())
    }
}
#endif
