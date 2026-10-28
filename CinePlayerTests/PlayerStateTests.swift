import CinePlayerSDK
import CoreMedia
import Foundation
import Testing
import SwiftData
@testable import CinePlayer

@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct PlayerStateTests {
    @Test func standaloneFeatureBoundary() {
        let controls = PlayerControlModel()
        #expect(!controls.shouldShowSourceSwitch)
        #expect(!controls.shouldShowEpisodeList)
        #expect(!controls.shouldShowFileSourceSubtitleImport)
        #expect(PurePlayerUIPolicy.allowsLocalSubtitleImport)
    }

    @Test func controlPreferencesSurviveNewSession() throws {
        let name = "CinePlayerTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: name))
        defer { defaults.removePersistentDomain(forName: name) }
        let first = PlayerSessionStore(defaults: defaults)
        first.controlConfig.skipForwardSeconds = 30
        first.controlConfig.skipBackwardSeconds = 5
        first.controlConfig.longPressSpeedUpEnabled = false
        first.controlConfig.longPressPlaybackRate = 3
        first.controlConfig.subtitleTranslationTargetLanguage = "ja"
        first.controlConfig.subtitleTranslationOnTop = false
        first.controlConfig.subtitleTranslateMode = .bilingual

        let restored = PlayerSessionStore(defaults: defaults).controlConfig
        #expect(restored.skipForwardSeconds == 30)
        #expect(restored.skipBackwardSeconds == 5)
        #expect(!restored.longPressSpeedUpEnabled)
        #expect(restored.longPressPlaybackRate == 3)
        #expect(restored.resolvedSubtitleTranslationTargetLanguage == "ja")
        #expect(!restored.subtitleTranslationOnTop)
        #expect(restored.subtitleTranslateMode == (SubtitleTranslationRouter.isAvailable ? .bilingual : .off))
    }

    @Test func historyRetainsResumePositionWithoutDuplicateRecords() throws {
        let container = try ModelContainer(for: PlaybackHistoryRecord.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let source = PlayerSource(url: try #require(URL(string: "https://example.invalid/regression.mp4")))
        PlaybackHistoryRepository.ensureRecordExists(for: source, initialPlaybackTime: 0, totalDuration: 20, in: context)
        PlaybackHistoryRepository.updatePlaybackProgress(for: source, currentTime: 9, totalDuration: 0, in: context)
        PlaybackHistoryRepository.ensureRecordExists(for: PlayerSource(url: source.url), initialPlaybackTime: 0,
                                                     totalDuration: 20, in: context)
        let records = try context.fetch(FetchDescriptor<PlaybackHistoryRecord>())
        #expect(records.count == 1)
        let record = try #require(records.first)
        #expect(record.initialPlaybackTime == 9)
        #expect(record.totalDuration == 20)
        PlaybackHistoryRepository.saveThumbnailIfNeeded(for: source, thumbnailData: Data([1, 2, 3]), in: context)
        PlaybackHistoryRepository.saveThumbnailIfNeeded(for: source, thumbnailData: Data([4]), in: context)
        #expect(record.thumbnailData == Data([1, 2, 3]))
        PlaybackHistoryRepository.delete(record, in: context)
        #expect(try context.fetch(FetchDescriptor<PlaybackHistoryRecord>()).isEmpty)
    }

    @Test func bilingualTranslationPreservesOrderAndTarget() async throws {
        var processor = AppSubtitleTranslationProcessor(mode: .bilingual) { text, source, target in
            #expect(text == "Hello world")
            #expect(source.hasPrefix("en"))
            #expect(target.hasPrefix("ja"))
            return "こんにちは"
        }
        let top = try await processor.process(content: "Hello\\Nworld", fromLang: "en", toLang: "ja")
        #expect(top == "こんにちは\\N{\\fscx75\\fscy75}Hello world")
        processor.translationOnTop = false
        let bottom = try await processor.process(content: "Hello\\Nworld", fromLang: "en", toLang: "ja")
        #expect(bottom == "Hello world\\N{\\fscx75\\fscy75}こんにちは")
    }

    @Test func sameLanguageAndChineseVariantsAvoidTranslationService() async throws {
        let processor = AppSubtitleTranslationProcessor(mode: .translated) { _, _, _ in
            Issue.record("Local language handling must not call the translation service")
            return "unexpected"
        }
        #expect(try await processor.process(content: "Hello", fromLang: "en-GB", toLang: "en-US") == "Hello")
        #expect(try await processor.process(content: "繁體字幕", fromLang: "zh-Hant", toLang: "zh-Hans") == "繁体字幕")
        #expect(!AppSubtitleTranslationProcessor.isSameLanguage("chi", "zh-Hans"))
    }

    @Test func staleSeekAcknowledgementCannotClearNewTarget() throws {
        let state = PlayerSliderScrubState()
        state.begin(at: 5)
        state.update(to: 10)
        let old = try #require(state.end())
        state.update(to: 20)
        state.begin(at: 6)
        state.complete(generation: old.generation)
        #expect(state.targetTime == 20)
        let current = try #require(state.end())
        state.complete(generation: old.generation)
        #expect(state.targetTime == 20)
        state.complete(generation: current.generation)
        #expect(state.targetTime == nil)
        #expect(state.end() == nil)
    }

    @Test func thumbnailReuseHasFixedAnchorAndRejectsPreviousMedia() async throws {
        let state = ScrubThumbnailPreviewState()
        let owner = NSObject()
        let mediaID = UUID()
        let key = ScrubThumbnailRequestKey(second: 10, controllerID: ObjectIdentifier(owner), mediaIdentifier: mediaID)
        await state.request(key: key) { _, _ in nil }
        let near = ScrubThumbnailRequestKey(second: 13, controllerID: key.controllerID, mediaIdentifier: mediaID)
        #expect(state.retainingRequest(near: near) == key)
        let far = ScrubThumbnailRequestKey(second: 14, controllerID: key.controllerID, mediaIdentifier: mediaID)
        #expect(state.retainingRequest(near: far) == far)
        let nextMedia = ScrubThumbnailRequestKey(second: 10, controllerID: key.controllerID, mediaIdentifier: UUID())
        #expect(state.retainingRequest(near: nextMedia) == nextMedia)
        state.reset()
        #expect(!state.hasSession)
    }

    @Test func thumbnailCompletionAfterCloseCannotRestorePreview() async {
        let state = ScrubThumbnailPreviewState()
        let started = AsyncStream<Void>.makeStream()
        let gate = TestGate()
        let owner = NSObject()
        let key = ScrubThumbnailRequestKey(second: 5, controllerID: ObjectIdentifier(owner), mediaIdentifier: UUID())
        let request = Task { @MainActor in
            await state.request(key: key) { _, _ in
                started.continuation.yield()
                await gate.wait()
                return nil
            }
        }
        var iterator = started.stream.makeAsyncIterator()
        await iterator.next()
        #expect(state.isLoading)
        state.reset()
        await gate.open()
        await request.value
        #expect(!state.isLoading)
        #expect(!state.hasSession)
    }

    @Test func spatialAdmissionAndAspectRatio() {
        #expect(SpatialSuperResolutionProcessor.canProcess(width: 1920, height: 1080, fps: 30))
        #expect(!SpatialSuperResolutionProcessor.canProcess(width: 1920, height: 1080, fps: 60))
        #expect(!SpatialSuperResolutionProcessor.canProcess(width: 3840, height: 2160, fps: 24))
        #expect(!SpatialSuperResolutionProcessor.canProcess(width: 0, height: 1080, fps: .nan))
        let portrait = FSROutputResolution.ultraHD.outputSize(width: 720, height: 1280)
        #expect(portrait.width == 1215 && portrait.height == 2160)
        #expect(!FSROutputResolution.fullHD.enlarges(width: 1920, height: 1080))
        #expect(FSRSharpness.off.parameter == nil)
    }

    @Test func cancelledEnhancementWarmupDrainsLateResources() async {
        let gate = TestGate()
        let started = AsyncStream<Void>.makeStream()
        let drained = AsyncStream<Void>.makeStream()
        let updates = AsyncStream<EnhancementStartupProcessor.Update>.makeStream()
        let processor = EnhancementStartupProcessor(
            dimensions: CMVideoDimensions(width: 32, height: 18),
            onUpdate: { updates.continuation.yield($0) },
            factory: { _ in
                started.continuation.yield()
                await gate.wait()
                return DrainProbe(onDrain: { drained.continuation.yield() })
            }
        )
        var starts = started.stream.makeAsyncIterator()
        await starts.next()
        var events = updates.stream.makeAsyncIterator()
        let initial = await events.next()
        #expect(initial?.state == .preparing)
        processor.onDrain()
        #expect(initial?.isCurrent() == false)
        await gate.open()
        var drains = drained.stream.makeAsyncIterator()
        await drains.next()
        #expect(!processor.hasPendingFrames)
    }
}

actor TestGate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []
    func wait() async {
        if isOpen { return }
        await withCheckedContinuation { waiters.append($0) }
    }
    func open() {
        isOpen = true
        let pending = waiters
        waiters.removeAll()
        pending.forEach { $0.resume() }
    }
}

nonisolated final class DrainProbe: VideoFrameProcessor, Sendable {
    let drain: @Sendable () -> Void
    init(onDrain: @escaping @Sendable () -> Void) { drain = onDrain }
    func onFrame(_ context: VideoFrameContext) -> VideoFrameResult { .passthrough }
    func onInvalidate(newGeneration: Int64) {}
    func drainPendingFrames() -> [GeneratedVideoFrame] { [] }
    func onDrain() { drain() }
}
