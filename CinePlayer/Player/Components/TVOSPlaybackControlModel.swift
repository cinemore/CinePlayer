#if os(tvOS)
import CinePlayerSDK
import Combine
import Foundation
import SwiftUI
import UIKit


@MainActor
final class TVOSPlaybackControlModel: ObservableObject {
    @Published var isSeeking = false
    @Published var showSeekingHint = false
    @Published var previewCurrentTime = 0
    @Published var previewTotalTime = 0

    private var wasPlayingBeforeSeeking = false
    private nonisolated(unsafe) var longPressTimer: Timer?

    deinit {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }

    func syncSeekingProgress(progress: PlayingProgress) {
        previewCurrentTime = progress.currentTime
        previewTotalTime = progress.totalTime
    }

    func startSeeking(
        wasPlaying: Bool,
        progress: PlayingProgress,
        pauseAction: @escaping () -> Void
    ) {
        if !isSeeking {
            isSeeking = true
            showSeekingHint = true
            wasPlayingBeforeSeeking = wasPlaying
            syncSeekingProgress(progress: progress)
            if wasPlayingBeforeSeeking {
                pauseAction()
            }
        }
    }

    func endSeeking(onEnd: @escaping () -> Void) {
        if isSeeking {
            isSeeking = false
            if wasPlayingBeforeSeeking {
                onEnd()
            }
        }
    }

    func cancelSeeking(
        progress: PlayingProgress,
        restorePlaybackStatus: @escaping () -> Void
    ) {
        stopLongPressSeeking()

        if isSeeking {
            isSeeking = false
            showSeekingHint = false
            syncSeekingProgress(progress: progress)
            if wasPlayingBeforeSeeking {
                restorePlaybackStatus()
            }
        }
    }

    func seekBackward(
        seconds: Int = 5,
        wasPlaying: Bool,
        progress: PlayingProgress,
        pauseAction: @escaping () -> Void
    ) {
        startSeeking(wasPlaying: wasPlaying, progress: progress, pauseAction: pauseAction)
        previewCurrentTime = max(0, previewCurrentTime - seconds)
    }

    func seekForward(
        seconds: Int = 5,
        wasPlaying: Bool,
        progress: PlayingProgress,
        pauseAction: @escaping () -> Void
    ) {
        startSeeking(wasPlaying: wasPlaying, progress: progress, pauseAction: pauseAction)
        previewCurrentTime = min(
            previewTotalTime,
            previewCurrentTime + seconds
        )
    }

    func performSeek(
        seek: (_ targetTime: TimeInterval) -> Void,
        onEnd: @escaping () -> Void
    ) {
        stopLongPressSeeking()

        if isSeeking {
            let targetTime = TimeInterval(previewCurrentTime)
            seek(targetTime)
            showSeekingHint = false

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.endSeeking(onEnd: onEnd)
            }
        }
    }

    func startLongPressSeeking(
        direction: UISwipeGestureRecognizer.Direction,
        wasPlaying: Bool,
        progress: PlayingProgress,
        pauseAction: @escaping () -> Void
    ) {
        stopLongPressSeeking()
        startSeeking(wasPlaying: wasPlaying, progress: progress, pauseAction: pauseAction)

        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                switch direction {
                case .left:
                    self.previewCurrentTime = max(0, self.previewCurrentTime - 10)
                case .right:
                    self.previewCurrentTime = min(
                        self.previewTotalTime,
                        self.previewCurrentTime + 10
                    )
                default:
                    break
                }
            }
        }
    }

    func stopLongPressSeeking() {
        longPressTimer?.invalidate()
        longPressTimer = nil
    }
}
#endif
