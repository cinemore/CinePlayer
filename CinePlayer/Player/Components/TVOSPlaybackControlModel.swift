#if os(tvOS)
import CinePlayerSDK
import Combine
import Foundation
import SwiftUI
import UIKit

/// 与正式宿主共用寻址契约；预览值属于应用，不创建 SDK 内部的 PlayingProgress。
@MainActor
final class TVOSPlaybackControlModel: ObservableObject {
    @Published private(set) var isSeeking = false
    @Published private(set) var previewCurrentTime = 0
    @Published private(set) var previewTotalTime = 0
    @Published private(set) var showsSeekingThumbnail = false
    var showSeekingHint: Bool { isSeeking }
    private var wasPlayingBeforeSeeking = false
    private var seekingMediaIdentifier: UUID?
    private weak var seekingController: PlayerController?
    private nonisolated(unsafe) var longPressTimer: Timer?

    deinit { longPressTimer?.invalidate() }

    func handleExitCommand(controls: PlayerControlModel, mask: PlayerMaskModel,
                           coordinator: CinePlayer.Coordinator, close: () -> Void) {
        if controls.showMediaInfoCard {
            controls.showMediaInfoCard = false
            mask.disableAutoHide()
            return
        }
        if isSeeking {
            cancelSeeking(progress: coordinator.progress) {
                coordinator.controller?.play()
            }
            return
        }
        if mask.isMaskShow {
            mask.enableAutoHide()
            mask.hideMask()
            return
        }
        close()
    }

    func syncSeekingProgress(progress: PlayingProgress) {
        previewCurrentTime = progress.currentTime
        previewTotalTime = progress.totalTime
    }

    func startSeeking(wasPlaying: Bool, progress: PlayingProgress, controller: PlayerController? = nil,
                      pauseAction: @escaping () -> Void) {
        guard progress.totalTime > 0 else { return }
        if !isSeeking {
            seekingMediaIdentifier = controller?.mediaIdentifier
            seekingController = controller
            wasPlayingBeforeSeeking = wasPlaying
            syncSeekingProgress(progress: progress)
            isSeeking = true
            showsSeekingThumbnail = true
            if wasPlaying { pauseAction() }
        }
    }

    func finishSeeking() -> Bool {
        stopLongPressSeeking()
        let resume = wasPlayingBeforeSeeking
        wasPlayingBeforeSeeking = false
        seekingMediaIdentifier = nil
        seekingController = nil
        isSeeking = false
        showsSeekingThumbnail = false
        return resume
    }

    func cancelSeeking(progress: PlayingProgress, restorePlaybackStatus: @escaping () -> Void) {
        let canRestore = seekingController.map {
            $0.mediaIdentifier == seekingMediaIdentifier && $0.playbackState == .paused && !$0.isLoadingMedia
        } ?? false
        let resume = finishSeeking()
        syncSeekingProgress(progress: progress)
        if resume && canRestore { restorePlaybackStatus() }
    }

    func seekBackward(seconds: Int = 5, wasPlaying: Bool, progress: PlayingProgress, controller: PlayerController? = nil,
                      pauseAction: @escaping () -> Void) {
        startSeeking(wasPlaying: wasPlaying, progress: progress, controller: controller, pauseAction: pauseAction)
        guard isSeeking else { return }
        previewCurrentTime = max(0, previewCurrentTime - seconds)
    }

    func seekForward(seconds: Int = 5, wasPlaying: Bool, progress: PlayingProgress, controller: PlayerController? = nil,
                     pauseAction: @escaping () -> Void) {
        startSeeking(wasPlaying: wasPlaying, progress: progress, controller: controller, pauseAction: pauseAction)
        guard isSeeking else { return }
        previewCurrentTime = min(previewTotalTime, previewCurrentTime + seconds)
    }

    func performSeek(seek: (TimeInterval, Bool) -> Void) {
        guard isSeeking else { return }
        guard seekingController?.mediaIdentifier == seekingMediaIdentifier else { _ = finishSeeking(); return }
        let target = TimeInterval(previewCurrentTime)
        let resume = finishSeeking()
        seek(target, resume)
    }

    func startLongPressSeeking(direction: UISwipeGestureRecognizer.Direction, wasPlaying: Bool,
                               progress: PlayingProgress, controller: PlayerController? = nil,
                               pauseAction: @escaping () -> Void) {
        stopLongPressSeeking()
        startSeeking(wasPlaying: wasPlaying, progress: progress, controller: controller, pauseAction: pauseAction)
        guard isSeeking else { return }
        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            let timerID = ObjectIdentifier(timer)
            Task { @MainActor [weak self] in
                guard let self, isSeeking, longPressTimer.map(ObjectIdentifier.init) == timerID else { return }
                switch direction {
                case .left: previewCurrentTime = max(0, previewCurrentTime - 10)
                case .right: previewCurrentTime = min(previewTotalTime, previewCurrentTime + 10)
                default: break
                }
            }
        }
    }
    func stopLongPressSeeking() { longPressTimer?.invalidate(); longPressTimer = nil }
}
#endif
