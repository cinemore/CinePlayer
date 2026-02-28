import CinePlayerSDK
import Foundation
import SwiftUI
import Combine

@MainActor
final class VideoPlayerModel: ObservableObject {
    let translationRuntime = SubtitleTranslationRuntime()
    let translationRouter: SubtitleTranslationRouter

    @Published var playerCoordinator = CinePlayer.Coordinator()
    @Published var config: CinePlayerConfig = .init()

    private(set) var sourceURL: URL?

    #if !os(tvOS)
    private var lastFrameCallbackConfigLog: String?
    #endif

    init() {
        translationRouter = SubtitleTranslationRouter(runtime: translationRuntime)

        #if !os(tvOS)
        PlayerEnhancementModel.shared.onRuntimeConfigChanged = { [weak self] resetPipeline in
            Task { @MainActor [weak self] in
                self?.applyFrameCallbackConfigurationToActivePlayer(resetPipeline: resetPipeline)
            }
        }
        #endif
    }

    func open(url: URL, startTime: TimeInterval = 0, controlConfig: PlayerControlConfig) {
        sourceURL = url
        let newConfig = CinePlayerConfig()

        #if !os(tvOS)
        PlayerEnhancementModel.shared.resetVideoEnhancementForNewVideoSession()
        #endif

        newConfig.url = url
        newConfig.startTime = max(0, startTime)
        newConfig.autoPlay = true
        configureSubtitleTranslate(for: newConfig, mode: controlConfig.subtitleTranslateMode)
        configureFrameCallback(for: newConfig)
        config = newConfig
    }

    func close() {
        playerCoordinator.controller?.shutdown()
        playerCoordinator.resetPlayer()
        sourceURL = nil
        translationRuntime.desiredApplePair = nil
        Task { [translationRouter] in
            await translationRouter.applySettings(mode: .off)
        }

        #if !os(tvOS)
        Anime4KHostEngine.shared.reset()
        #if !targetEnvironment(simulator)
        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
            SystemVideoEnhancementAdapter.shared.endSession()
        }
        #endif
        OpticalFlowFrameInterpolationAdapter.shared.endSession()
        PlayerEnhancementModel.shared.resetVideoEnhancementForNewVideoSession()
        #endif

        config = .init()
    }

    func applySubtitleTranslationSettings(mode: SubtitleTranslateMode) {
        config.subtitleTranslateMode = mode
        Task { [translationRouter] in
            await translationRouter.applySettings(mode: mode)
        }
    }

    func restartSubtitleTranslationService() {
        Task { [translationRouter] in
            await translationRouter.restartTranslationService()
        }
    }

    private func configureSubtitleTranslate(for options: CinePlayerConfig, mode: SubtitleTranslateMode) {
        options.subtitleTranslateMode = mode
        let router = translationRouter
        options.subtitleTranslate = { text, from, to in
            try await router.translate(text: text, from: from, to: to)
        }
        Task { [translationRouter] in
            await translationRouter.applySettings(mode: mode)
        }
    }

    func configureFrameCallback(for options: CinePlayerConfig) {
        let callbackConfig = makeFrameCallbackConfiguration()
        options.frameCallbackPolicy = callbackConfig.policy
        options.onVideoFrame = callbackConfig.onVideoFrame
        options.onAudioFrame = nil
        options.onFrameCallbackEvent = callbackConfig.onFrameCallbackEvent
    }

    /// 热更新当前活跃播放器的帧回调配置。
    func applyFrameCallbackConfigurationToActivePlayer(resetPipeline: Bool) {
        guard let controller = playerCoordinator.controller else {
            return
        }

        let callbackConfig = makeFrameCallbackConfiguration()
        config.frameCallbackPolicy = callbackConfig.policy
        config.onVideoFrame = callbackConfig.onVideoFrame
        config.onAudioFrame = nil
        config.onFrameCallbackEvent = callbackConfig.onFrameCallbackEvent

        controller.setFrameCallbackConfiguration(
            policy: callbackConfig.policy,
            onVideoFrame: callbackConfig.onVideoFrame,
            onAudioFrame: nil,
            onFrameCallbackEvent: callbackConfig.onFrameCallbackEvent,
            resetPipeline: resetPipeline
        )
    }

    private typealias VideoCallback = (@Sendable (inout VideoFrameContext) -> VideoFrameResult)?
    private typealias EventCallback = (@Sendable (FrameCallbackEvent) -> Void)?

    /// 在 MainActor 上同步执行闭包；若当前已在主线程则直接执行，否则派发到主队列并等待。用于帧回调闭包内调用 MainActor 隔离的增强引擎。
    private nonisolated static func runOnMainActorSync<T: Sendable>(_ body: @MainActor @Sendable @escaping () -> T) -> T {
        if Thread.isMainThread {
            return MainActor.assumeIsolated(body)
        }
        var result: T!
        let semaphore = DispatchSemaphore(value: 0)
        DispatchQueue.main.async {
            result = MainActor.assumeIsolated(body)
            semaphore.signal()
        }
        semaphore.wait()
        return result
    }

    private func makeFrameCallbackConfiguration()
        -> (
            policy: FrameCallbackPolicy, onVideoFrame: VideoCallback,
            onFrameCallbackEvent: EventCallback
        )
    {
        var policy = FrameCallbackPolicy()

        #if !os(tvOS)
        let enhancementModel = PlayerEnhancementModel.shared
        let strategy: VideoEnhancementStrategy
        #if DEBUG
        strategy = enhancementModel.videoEnhancementStrategy
        #else
        switch enhancementModel.videoEnhancementStrategy {
        case .systemML, .opticalFlow:
            strategy = .off
        default:
            strategy = enhancementModel.videoEnhancementStrategy
        }
        #endif

        cinemoreLog(
            level: .debug,
            "VideoEnhance makeFrameCallbackConfiguration strategy=\(strategy.rawValue) systemMLSupported=\(enhancementModel.systemMLEnhancementSupported) systemMLFIEnabled=\(enhancementModel.systemMLFrameInterpolationEnabled) systemMLSREnabled=\(enhancementModel.systemMLSuperResolutionEnabled) systemMLSRScale=\(enhancementModel.systemMLSuperResolutionScale) systemMLScaleBy=\(enhancementModel.systemMLScaleBy) systemMLFramesAdded=\(enhancementModel.systemMLInterpolatedFrames) systemMLCurrentVideoInRange=\(enhancementModel.systemMLCurrentVideoInRange)"
        )

        switch strategy {
        case .off:
            logFrameCallbackConfigurationOnce("Video enhancement disabled")
            Anime4KHostEngine.shared.reset()
            #if !targetEnvironment(simulator)
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                SystemVideoEnhancementAdapter.shared.endSession()
            }
            #endif
            OpticalFlowFrameInterpolationAdapter.shared.endSession()
            return (policy, nil, nil)

        case .anime4k:
            #if !targetEnvironment(simulator)
            if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                SystemVideoEnhancementAdapter.shared.endSession()
            }
            #endif
            OpticalFlowFrameInterpolationAdapter.shared.endSession()

            let anime4kEnabled = enhancementModel.anime4kEnabled
            let preset = enhancementModel.anime4kPreset
            let abCompareEnabled = enhancementModel.anime4kABCompare
            let resolution = enhancementModel.anime4kOutputResolution
            guard anime4kEnabled else {
                logFrameCallbackConfigurationOnce("Anime4K frame callback disabled")
                Anime4KHostEngine.shared.reset()
                return (policy, nil, nil)
            }

            policy.enabled = true
            policy.mode = .asyncSingle
            logFrameCallbackConfigurationOnce(
                "Anime4K frame callback enabled mode=\(policy.mode) preset=\(preset) outputResolution=\(resolution.rawValue) abCompare=\(abCompareEnabled)"
            )

            let engine = Anime4KHostEngine.shared
            let maxW = resolution.maxWidth
            let maxH = resolution.maxHeight
            let onVideoFrame: VideoCallback = { context in
                let ts = context.timestamp
                let dur = context.duration
                let tbn = context.timebaseNum
                let tbd = context.timebaseDen
                let f = context.fps
                let buf = context.pixelBuffer
                let gen = context.generation
                return Self.runOnMainActorSync {
                    let effectivePreset = engine.resolveEffectivePreset(
                        requested: preset,
                        timestamp: ts,
                        frameDuration: dur,
                        timebaseNum: tbn,
                        timebaseDen: tbd,
                        fps: f
                    )
                    guard
                        let enhanced = engine.enhance(
                            pixelBuffer: buf,
                            timestamp: ts,
                            generation: gen,
                            preset: effectivePreset,
                            abCompareEnabled: abCompareEnabled,
                            maxOutputWidth: maxW,
                            maxOutputHeight: maxH
                        )
                    else {
                        return .passthrough
                    }
                    return .replace(pixelBuffer: enhanced)
                }
            }
            let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
            return (policy, onVideoFrame, onEvent)

        case .systemML:
            #if DEBUG
            #if targetEnvironment(simulator)
            logFrameCallbackConfigurationOnce("System VT unavailable on simulator")
            return (policy, nil, nil)
            #else
            guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
                logFrameCallbackConfigurationOnce("System VT unavailable on this OS")
                return (policy, nil, nil)
            }
            guard enhancementModel.systemMLEnhancementSupported else {
                logFrameCallbackConfigurationOnce("System VT not supported on device")
                return (policy, nil, nil)
            }
            guard enhancementModel.systemMLCurrentVideoInRange else {
                logFrameCallbackConfigurationOnce("System VT current video resolution out of supported range")
                return (policy, nil, nil)
            }
            OpticalFlowFrameInterpolationAdapter.shared.endSession()

            let adapter = SystemVideoEnhancementAdapter.shared
            let frameInterpolationEnabled =
                enhancementModel.systemMLFrameInterpolationEnabled
                    && enhancementModel.systemMLCurrentVideoSupportsFrameInterpolation
            let superResolutionEnabled =
                enhancementModel.systemMLSuperResolutionEnabled
                    && enhancementModel.systemMLCurrentVideoSupportsSuperResolution
            guard frameInterpolationEnabled || superResolutionEnabled else {
                logFrameCallbackConfigurationOnce("System VT disabled: no active VT feature")
                return (policy, nil, nil)
            }

            let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
            if frameInterpolationEnabled {
                policy.enabled = true
                policy.preset = .aggressive
                policy.mode = .temporal
                let scalar = max(1, min(2, enhancementModel.systemMLScaleBy))
                policy.temporalSegmentIncludesAnchor = (scalar == 2)
                let numFrames = max(1, min(3, enhancementModel.systemMLInterpolatedFrames))
                logFrameCallbackConfigurationOnce(
                    "System VT frame interpolation enabled mode=temporal scalar=\(scalar) numFrames=\(numFrames)"
                )

                let onVideoFrame: VideoCallback = { context in
                    let prev = context.previousFrame
                    let curr = context
                    return Self.runOnMainActorSync {
                        adapter.processTemporalFrames(
                            previous: prev,
                            current: curr,
                            scalar: scalar,
                            numFrames: numFrames
                        )
                    }
                }
                return (policy, onVideoFrame, onEvent)
            }

            policy.enabled = true
            policy.mode = .asyncSingle
            policy.preset = .aggressive
            let scale = enhancementModel.systemMLSuperResolutionScale
            let abCompareEnabled = enhancementModel.systemMLABCompare
            logFrameCallbackConfigurationOnce(
                "System VT super resolution enabled mode=asyncSingle scale=\(scale) abCompare=\(abCompareEnabled)"
            )
            let onVideoFrame: VideoCallback = { context in
                let ctx = context
                return Self.runOnMainActorSync {
                    guard
                        let enhanced = adapter.processSingleFrame(
                            context: ctx,
                            scale: scale,
                            abCompareEnabled: abCompareEnabled
                        )
                    else {
                        return .passthrough
                    }
                    return .replace(pixelBuffer: enhanced)
                }
            }
            return (policy, onVideoFrame, onEvent)
            #endif
            #else
            return (policy, nil, nil)
            #endif

        case .opticalFlow:
            #if DEBUG
            guard enhancementModel.opticalFlowSectionVisible else {
                logFrameCallbackConfigurationOnce(
                    "Optical flow not available: video not 1080p or below"
                )
                return (policy, nil, nil)
            }
            policy.enabled = true
            policy.mode = .temporal
            policy.temporalSegmentIncludesAnchor = false
            logFrameCallbackConfigurationOnce("Optical flow frame callback enabled mode=temporal")
            let adapter = OpticalFlowFrameInterpolationAdapter.shared
            let onVideoFrame: VideoCallback = { context in
                let prev = context.previousFrame
                let curr = context
                return Self.runOnMainActorSync {
                    adapter.processTemporal(previous: prev, current: curr)
                }
            }
            let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
            return (policy, onVideoFrame, onEvent)
            #else
            return (policy, nil, nil)
            #endif
        }
        #else
        return (policy, nil, nil)
        #endif
    }

    #if !os(tvOS)
    private func makeFrameCallbackEventLogger(tag: String) -> EventCallback {
        { event in
            switch event {
            case let .callbackTimeout(kind, elapsedMs):
                Task { @MainActor in
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback timeout kind=\(kind.rawValue) elapsed=\(String(format: "%.2f", elapsedMs))ms"
                    )
                }
            case let .callbackInvalidResult(kind, message):
                Task { @MainActor in
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback invalid result kind=\(kind.rawValue) message=\(message)"
                    )
                }
            case let .callbackError(kind, message):
                Task { @MainActor in
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback error kind=\(kind.rawValue) message=\(message)"
                    )
                }
            case let .bypassStarted(kind):
                Task { @MainActor in
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback bypass started kind=\(kind.rawValue)"
                    )
                }
            case let .bypassEnded(kind):
                Task { @MainActor in
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback bypass ended kind=\(kind.rawValue)"
                    )
                }
            @unknown default:
                Task { @MainActor in
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback unknown event=\(event)"
                    )
                }
            }
        }
    }

    private func logFrameCallbackConfigurationOnce(_ message: String) {
        guard lastFrameCallbackConfigLog != message else {
            return
        }
        lastFrameCallbackConfigLog = message
        Task { @MainActor in
            cinemoreLog(level: .debug, message)
        }
    }
    #endif
}
