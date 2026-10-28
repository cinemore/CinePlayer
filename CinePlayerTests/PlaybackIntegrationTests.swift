import CinePlayerSDK
import CoreGraphics
import Foundation
import Testing
#if os(macOS)
import AppKit
#else
import UIKit
#endif
@testable import CinePlayer

extension PlayerStateTests {
    @Test func systemAudioPathPreferenceReachesActiveController() async throws {
        let bundle = Bundle(for: FixtureBundle.self)
        let videoURL = try #require(bundle.url(forResource: "playback", withExtension: "mp4"))
        let model = VideoPlayerModel()
        var settings = PlayerControlConfig.default
        settings.systemAudioPathEnabled = false
        model.open(url: videoURL, controlConfig: settings)
        let host = try PlaybackSurfaceHost(view: model.playerCoordinator.makeView(config: model.config))
        defer { model.close(); host.close() }
        let controller = try #require(model.playerCoordinator.controller)
        try await waitUntil { controller.isItemReadyToPlay && controller.playbackState == .playing }
        #expect(!controller.config.systemAudioPathEnabled)

        controller.pause()
        try await waitUntil { controller.playbackState == .paused }
        let mediaID = controller.mediaIdentifier
        let pausedTime = controller.currentPlaybackTime
        model.applySystemAudioPathPreferenceToActivePlayer(true)
        #expect(controller.config.systemAudioPathEnabled)
        #expect(model.config.systemAudioPathEnabled)
        #expect(controller.mediaIdentifier == mediaID)
        #expect(controller.playbackState == .paused)
        #expect(abs(controller.currentPlaybackTime - pausedTime) < 1)

        controller.play()
        try await waitUntil { controller.playbackState == .playing }
        model.applySystemAudioPathPreferenceToActivePlayer(false)
        #expect(!controller.config.systemAudioPathEnabled)
        #expect(controller.playbackState == .playing)
        model.open(url: videoURL, controlConfig: settings)
        try await waitUntil { controller.isItemReadyToPlay && controller.playbackState == .playing }
        #expect(controller.mediaIdentifier != mediaID)
        #expect(!controller.config.systemAudioPathEnabled)
    }

    @Test func playbackTracksSubtitlesSeekReplaceAndShutdown() async throws {
        let bundle = Bundle(for: FixtureBundle.self)
        let videoURL = try #require(bundle.url(forResource: "playback", withExtension: "mp4"))
        let subtitleURL = try #require(bundle.url(forResource: "subtitles", withExtension: "srt"))
        let model = VideoPlayerModel()
        model.open(url: videoURL, controlConfig: .default)
        let surface = model.playerCoordinator.makeView(config: model.config)
        let host = try PlaybackSurfaceHost(view: surface)
        defer { model.close(); host.close() }
        let controller = try #require(model.playerCoordinator.controller)
        try await waitUntil { controller.isItemReadyToPlay && controller.playbackState == .playing }
        #expect(controller.duration >= 19)
        #expect(controller.videoTracks.count == 1)
        #expect(controller.audioTracks.count == 2)
        #expect(controller.subtitleTracks.count == 1)
        model.refreshEnhancementCapabilities()
        #expect(PlayerEnhancementModel.shared.anime4kSectionVisible)
        #expect(PlayerEnhancementModel.shared.enhancementCurrentVideoFrameRate == 24)

        controller.pause()
        try await waitUntil { controller.playbackState == .paused }
        let scrub = PlayerScrubPlaybackSession()
        scrub.begin(controller: controller)
        let seekSucceeded = await withCheckedContinuation { continuation in
            scrub.commit(time: 7, controller: controller) { continuation.resume(returning: $0) }
        }
        #expect(seekSucceeded)
        print("[PlaybackRegression] seek target=7 actual=\(controller.currentPlaybackTime) state=\(controller.playbackState)")
        try await waitUntil { abs(controller.currentPlaybackTime - 7) < 1 }
        #expect(controller.playbackState == .paused)
        let pausedTime = controller.currentPlaybackTime
        #expect(abs(pausedTime - 7) < 1)

        let otherAudio = try #require(controller.audioTracks.last)
        controller.select(track: otherAudio)
        try await waitUntil { controller.audioTrack?.streamIndex == otherAudio.streamIndex }
        #expect(controller.playbackState == .paused)
        try await controller.loadSubtitleFile(subtitleID: "regression-local", url: subtitleURL)
        #expect(controller.externalSubtitleID == "regression-local")
        #expect(!controller.isExternalSubtitleLoading)
        controller.clearSubtitle()
        #expect(controller.externalSubtitleID == nil)

        let controls = PlayerControlModel()
        controls.selectLocalSubtitle(.init(id: "missing", url: subtitleURL.appendingPathComponent("missing"),
                                          displayName: "Missing", sizeDescription: ""), controller: controller)
        try await waitUntil { controls.pendingLocalSubtitleID == nil }
        #expect(controls.subtitleOperationError != nil)
        #expect(controls.currentSubtitlePath.isEmpty)

        let thumbnail = await controller.requestScrubThumbnail(
            time: 10, targetPointSize: CGSize(width: 160, height: 90), scale: 1, immediately: true)
        #expect(thumbnail?.imageData.isEmpty == false)
        let previousMedia = controller.mediaIdentifier
        scrub.begin(controller: controller)
        model.open(url: videoURL, startTime: 2, controlConfig: .default)
        #expect(PlayerEnhancementModel.shared.videoEnhancementStrategy == .off)
        #expect(controller.mediaIdentifier != previousMedia)
        let staleSeekAccepted = await withCheckedContinuation { continuation in
            scrub.commit(time: 15, controller: controller) { continuation.resume(returning: $0) }
        }
        #expect(!staleSeekAccepted)
        try await waitUntil { controller.isItemReadyToPlay && controller.playbackState == .playing }
        #expect(controller.currentPlaybackTime < 6)
        let reachedEnd = await withCheckedContinuation { continuation in
            controller.seek(time: controller.duration, playbackBehavior: .resumePlayback) {
                continuation.resume(returning: $0)
            }
        }
        #expect(reachedEnd)
        try await waitUntil { controller.playbackState == .finished }
        print("[PlaybackRegression] replay request state=\(controller.playbackState) time=\(controller.currentPlaybackTime)")
        controller.togglePlaybackFromControls()
        do {
            try await waitUntil { controller.playbackState == .playing && controller.currentPlaybackTime < 3 }
        } catch {
            print("[PlaybackRegression] replay timeout state=\(controller.playbackState) time=\(controller.currentPlaybackTime) loading=\(controller.isLoadingMedia) ready=\(controller.isItemReadyToPlay)")
            throw error
        }
        print("[PlaybackRegression] replay observed state=\(controller.playbackState) time=\(controller.currentPlaybackTime)")
        model.close()
        #expect(model.sourceURL == nil)
        #expect(model.config.url == nil)
        #expect(model.playerCoordinator.controller == nil)
    }

    @Test func failedLocalSubtitleLoadClearsPreviousSelectionAndCanRetry() async throws {
        let bundle = Bundle(for: FixtureBundle.self)
        let videoURL = try #require(bundle.url(forResource: "playback", withExtension: "mp4"))
        let subtitleURL = try #require(bundle.url(forResource: "subtitles", withExtension: "srt"))
        let model = VideoPlayerModel()
        model.open(url: videoURL, controlConfig: .default)
        let host = try PlaybackSurfaceHost(view: model.playerCoordinator.makeView(config: model.config))
        defer { model.close(); host.close() }
        let controller = try #require(model.playerCoordinator.controller)
        try await waitUntil { controller.isItemReadyToPlay }
        let controls = PlayerControlModel()
        let valid = PlayerControlModel.LocalSubtitleItem(id: "valid", url: subtitleURL,
                                                        displayName: "Valid", sizeDescription: "")
        let missing = PlayerControlModel.LocalSubtitleItem(id: "missing", url: subtitleURL.appendingPathComponent("missing"),
                                                          displayName: "Missing", sizeDescription: "")
        controls.selectLocalSubtitle(valid, controller: controller)
        try await waitUntil { controls.pendingLocalSubtitleID == nil }
        try #require(controls.currentSubtitlePath == valid.id)
        #expect(controller.externalSubtitleID == valid.id)

        controls.selectLocalSubtitle(missing, controller: controller)
        try await waitUntil { controls.pendingLocalSubtitleID == nil }
        #expect(controls.subtitleOperationError != nil)
        #expect(controls.currentSubtitlePath.isEmpty)
        #expect(controller.externalSubtitleID == nil)
        #expect(!controller.isExternalSubtitleLoading)

        controls.selectLocalSubtitle(valid, controller: controller)
        #expect(controls.subtitleOperationError == nil)
        try await waitUntil { controls.pendingLocalSubtitleID == nil }
        #expect(controls.currentSubtitlePath == valid.id)
        #expect(controller.externalSubtitleID == valid.id)

        // 被取消的失败请求不能覆盖随后成功的选择。
        controls.selectLocalSubtitle(missing, controller: controller)
        let latest = PlayerControlModel.LocalSubtitleItem(id: "latest", url: subtitleURL,
                                                         displayName: "Latest", sizeDescription: "")
        controls.selectLocalSubtitle(latest, controller: controller)
        try await waitUntil { controls.pendingLocalSubtitleID == nil }
        #expect(controls.currentSubtitlePath == latest.id)
        #expect(controller.externalSubtitleID == latest.id)
        #expect(controls.subtitleOperationError == nil)
    }

    #if os(tvOS)
    @Test(arguments: [true, false])
    func returnDismissesMediaInfoBeforeClosingPlayback(wasPlaying: Bool) async throws {
        let url = try #require(Bundle(for: FixtureBundle.self).url(forResource: "playback", withExtension: "mp4"))
        let model = VideoPlayerModel()
        model.open(url: url, controlConfig: .default)
        let host = try PlaybackSurfaceHost(view: model.playerCoordinator.makeView(config: model.config))
        defer { model.close(); host.close() }
        let coordinator = model.playerCoordinator
        let controller = try #require(coordinator.controller)
        try await waitUntil { controller.isItemReadyToPlay && controller.playbackState == .playing
            && coordinator.progress.totalTime > 0 }
        if !wasPlaying { controller.pause() }
        let expectedState: PlaybackState = wasPlaying ? .playing : .paused
        try await waitUntil { controller.playbackState == expectedState }
        let mediaID = controller.mediaIdentifier
        let controls = PlayerControlModel()
        let playbackControls = TVOSPlaybackControlModel()
        let mask = PlayerMaskModel()
        defer { mask.stopTimer() }
        controls.showMediaInfoCard = true
        mask.hideMask()
        var closeCount = 0
        let pressReturn = {
            playbackControls.handleExitCommand(controls: controls, mask: mask, coordinator: coordinator) {
                closeCount += 1
                model.close()
            }
        }

        pressReturn()
        #expect(!controls.showMediaInfoCard)
        #expect(mask.isMaskShow)
        #expect(!mask.allowAutoHide)
        try #require(closeCount == 0)
        #expect(coordinator.controller === controller)
        #expect(controller.mediaIdentifier == mediaID)
        #expect(controller.playbackState == expectedState)

        pressReturn()
        #expect(!mask.isMaskShow)
        #expect(mask.allowAutoHide)
        #expect(closeCount == 0)

        mask.disableAutoHide()
        playbackControls.seekForward(wasPlaying: wasPlaying, progress: coordinator.progress,
                                     controller: controller, pauseAction: { controller.pause() })
        #expect(playbackControls.isSeeking)
        pressReturn()
        #expect(!playbackControls.isSeeking)
        #expect(mask.isMaskShow)
        #expect(closeCount == 0)
        try await waitUntil { controller.playbackState == expectedState }

        pressReturn()
        #expect(!mask.isMaskShow)
        #expect(closeCount == 0)
        pressReturn()
        #expect(closeCount == 1)
        #expect(coordinator.controller == nil)
    }

    @Test func remoteSeekPreservesPauseAndCancelsPreviousMedia() async throws {
        let url = try #require(Bundle(for: FixtureBundle.self).url(forResource: "playback", withExtension: "mp4"))
        let model = VideoPlayerModel()
        model.open(url: url, controlConfig: .default)
        let surface = model.playerCoordinator.makeView(config: model.config)
        let host = try PlaybackSurfaceHost(view: surface)
        defer { model.close(); host.close() }
        let controller = try #require(model.playerCoordinator.controller)
        try await waitUntil { controller.isItemReadyToPlay && model.playerCoordinator.progress.totalTime > 0 }
        controller.pause()
        let remote = TVOSPlaybackControlModel()
        remote.seekForward(seconds: 5, wasPlaying: false, progress: model.playerCoordinator.progress,
                           controller: controller, pauseAction: { controller.pause() })
        #expect(remote.isSeeking)
        remote.performSeek { time, resume in
            #expect(!resume)
            controller.seek(time: time, playbackBehavior: resume ? .resumePlayback : .pausePlayback)
        }
        try await waitUntil { !controller.isLoadingMedia && controller.playbackState == .paused }
        #expect(!remote.isSeeking)
        remote.startLongPressSeeking(direction: .right, wasPlaying: false,
                                    progress: model.playerCoordinator.progress, controller: controller,
                                    pauseAction: { controller.pause() })
        model.open(url: url, controlConfig: .default)
        remote.performSeek { _, _ in Issue.record("Old remote gesture must not seek the new media") }
        #expect(!remote.isSeeking)
        #expect(!remote.showsSeekingThumbnail)
    }
    #endif

    private func waitUntil(line: Int = #line, _ predicate: @MainActor () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(15))
        while !predicate() {
            guard ContinuousClock.now < deadline else { throw PlaybackTimeout(line: line) }
            try await Task.sleep(for: .milliseconds(50))
        }
    }
}

private final class FixtureBundle: NSObject {}
private struct PlaybackTimeout: Error { let line: Int }

/// 实际挂载渲染视图，让 SDK 的系统时钟及显示回调按应用运行方式工作。
@MainActor
private final class PlaybackSurfaceHost {
    #if os(macOS)
    let window: NSWindow
    init(view: NSView) throws {
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 360),
                          styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.makeKeyAndOrderFront(nil)
    }
    func close() { window.close() }
    #else
    let window: UIWindow
    init(view: UIView) throws {
        let scene = try #require(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        window = UIWindow(windowScene: scene)
        let controller = UIViewController()
        controller.view = view
        window.rootViewController = controller
        window.makeKeyAndVisible()
    }
    func close() { window.isHidden = true; window.rootViewController = nil }
    #endif
}
