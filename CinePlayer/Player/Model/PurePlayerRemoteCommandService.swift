import CinePlayerSDK
import Combine
import Foundation

#if canImport(MediaPlayer)
import MediaPlayer

@MainActor
final class PurePlayerRemoteCommandService: ObservableObject {
    private weak var sessionStore: PlayerSessionStore?
    private weak var playerModel: VideoPlayerModel?

    private var playToken: Any?
    private var pauseToken: Any?
    private var toggleToken: Any?
    private var skipForwardToken: Any?
    private var skipBackwardToken: Any?
    private var seekToken: Any?
    private var isActivated = false

    func activate(
        sessionStore: PlayerSessionStore,
        playerModel: VideoPlayerModel
    ) {
        self.sessionStore = sessionStore
        self.playerModel = playerModel
        guard !isActivated else {
            refreshNowPlayingInfo()
            return
        }
        configureRemoteCommands()
        refreshNowPlayingInfo()
        isActivated = true
    }

    func deactivate() {
        guard isActivated else {
            return
        }
        clearRemoteCommands()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
        isActivated = false
    }

    func refreshNowPlayingInfo() {
        guard isActivated,
              let sessionStore,
              let playerModel
        else {
            return
        }

        let coordinator = playerModel.playerCoordinator
        var info: [String: Any] = [:]
        info[MPMediaItemPropertyTitle] = sessionStore.currentSource?.displayName ?? "CinePlayer"

        let duration = TimeInterval(coordinator.progress.totalTime)
        if duration.isFinite, duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }

        let elapsed = TimeInterval(coordinator.progress.currentTime)
        if elapsed.isFinite, elapsed >= 0 {
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = elapsed
        }

        info[MPNowPlayingInfoPropertyPlaybackRate] = coordinator.playbackState == .playing
            ? coordinator.playbackRate
            : 0

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func configureRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        let skipForwardInterval = NSNumber(value: sessionStore?.controlConfig.skipForwardSeconds ?? 10)
        let skipBackwardInterval = NSNumber(value: sessionStore?.controlConfig.skipBackwardSeconds ?? 10)

        commandCenter.playCommand.isEnabled = true
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.isEnabled = true

        commandCenter.skipForwardCommand.preferredIntervals = [skipForwardInterval]
        commandCenter.skipBackwardCommand.preferredIntervals = [skipBackwardInterval]

        playToken = commandCenter.playCommand.addTarget { [weak self] _ in
            self?.playerModel?.playerCoordinator.controller?.play()
            self?.refreshNowPlayingInfo()
            return .success
        }
        pauseToken = commandCenter.pauseCommand.addTarget { [weak self] _ in
            self?.playerModel?.playerCoordinator.controller?.pause()
            self?.refreshNowPlayingInfo()
            return .success
        }
        toggleToken = commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.playerModel?.playerCoordinator.controller?.switchPlayPause()
            self?.refreshNowPlayingInfo()
            return .success
        }
        skipForwardToken = commandCenter.skipForwardCommand.addTarget { [weak self] _ in
            let seconds = self?.sessionStore?.controlConfig.skipForwardSeconds ?? 10
            self?.playerModel?.playerCoordinator.controller?.skip(interval: seconds)
            self?.refreshNowPlayingInfo()
            return .success
        }
        skipBackwardToken = commandCenter.skipBackwardCommand.addTarget { [weak self] _ in
            let seconds = self?.sessionStore?.controlConfig.skipBackwardSeconds ?? 10
            self?.playerModel?.playerCoordinator.controller?.skip(interval: -seconds)
            self?.refreshNowPlayingInfo()
            return .success
        }
        seekToken = commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self?.playerModel?.playerCoordinator.controller?.seek(time: positionEvent.positionTime)
            self?.refreshNowPlayingInfo()
            return .success
        }
    }

    private func clearRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        if let playToken {
            commandCenter.playCommand.removeTarget(playToken)
        }
        if let pauseToken {
            commandCenter.pauseCommand.removeTarget(pauseToken)
        }
        if let toggleToken {
            commandCenter.togglePlayPauseCommand.removeTarget(toggleToken)
        }
        if let skipForwardToken {
            commandCenter.skipForwardCommand.removeTarget(skipForwardToken)
        }
        if let skipBackwardToken {
            commandCenter.skipBackwardCommand.removeTarget(skipBackwardToken)
        }
        if let seekToken {
            commandCenter.changePlaybackPositionCommand.removeTarget(seekToken)
        }

        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false

        playToken = nil
        pauseToken = nil
        toggleToken = nil
        skipForwardToken = nil
        skipBackwardToken = nil
        seekToken = nil
    }
}
#else
@MainActor
final class PurePlayerRemoteCommandService: ObservableObject {
    func activate(sessionStore _: PlayerSessionStore, playerModel _: VideoPlayerModel) {}
    func deactivate() {}
    func refreshNowPlayingInfo() {}
}
#endif
