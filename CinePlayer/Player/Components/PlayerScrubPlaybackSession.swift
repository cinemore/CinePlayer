import CinePlayerSDK
import Foundation

/// 拖动期间暂停解码，提交时恢复拖动前的状态；换片后丢弃旧手势。
@MainActor
final class PlayerScrubPlaybackSession {
    private var mediaIdentifier: UUID?
    private var wasPlaying = false

    func begin(controller: PlayerController?) {
        guard let controller, mediaIdentifier == nil else { return }
        mediaIdentifier = controller.mediaIdentifier
        wasPlaying = controller.playbackState == .playing
        controller.pause()
    }

    func commit(time: TimeInterval, controller: PlayerController?,
                completion: @escaping @Sendable (Bool) -> Void = { _ in }) {
        let mediaID = mediaIdentifier
        let resume = mediaID == nil ? controller?.playbackState == .playing : wasPlaying
        reset()
        guard let controller, mediaID == nil || mediaID == controller.mediaIdentifier,
              !controller.isLoadingMedia else { completion(false); return }
        controller.seek(time: time, playbackBehavior: resume ? .resumePlayback : .pausePlayback,
                        completion: completion)
    }

    func reset() { mediaIdentifier = nil; wasPlaying = false }
}
