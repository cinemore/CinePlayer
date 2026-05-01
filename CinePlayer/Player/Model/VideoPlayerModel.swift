import CinePlayerSDK
import Combine
import Foundation
import SwiftUI
#if os(macOS)
import RifeMetal
#endif

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
                    self?.applyFrameCallbackConfigurationToActivePlayer(
                        resetPipeline: resetPipeline)
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

        // SDK 是 imperative 模型：CinePlayer.updateView 不监听 config 变化，
        // 已有 controller 时必须显式调 replace 才能切源并触发 .ready 状态流。
        // 首次播放（controller 为 nil）由 SwiftUI 的 makeView 创建 controller。
        if let controller = playerCoordinator.controller {
            newConfig.subtitleStyle = config.subtitleStyle
            controller.replace(config: newConfig)
        }
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
            MetalFXSuperResolutionAdapter.shared.endSession()
            OpticalFlowFrameInterpolationAdapter.shared.endSession()
            #if os(macOS)
                RifeFrameInterpolationAdapter.shared.endSession()
            #endif
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

    private func configureSubtitleTranslate(
        for options: CinePlayerConfig, mode: SubtitleTranslateMode
    ) {
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
        config.onAudioFrame = nil
        config.onFrameCallbackEvent = callbackConfig.onFrameCallbackEvent

        controller.setFrameCallbackConfiguration(
            policy: callbackConfig.policy,
            onAudioFrame: nil,
            onFrameCallbackEvent: callbackConfig.onFrameCallbackEvent,
            resetPipeline: resetPipeline
        )
    }

    private typealias EventCallback = (@Sendable (FrameCallbackEvent) -> Void)?

    private func makeFrameCallbackConfiguration()
        -> (
            policy: FrameCallbackPolicy,
            onFrameCallbackEvent: EventCallback
        )
    {
        var policy = FrameCallbackPolicy()

        #if !os(tvOS)
            let enhancementModel = PlayerEnhancementModel.shared
            let strategy: VideoEnhancementStrategy
            strategy = enhancementModel.videoEnhancementStrategy

            cinemoreLog(
                level: .debug,
                "VideoEnhance makeFrameCallbackConfiguration strategy=\(strategy.rawValue) systemMLSupported=\(enhancementModel.systemMLEnhancementSupported) systemMLFIEnabled=\(enhancementModel.systemMLFrameInterpolationEnabled) systemMLSREnabled=\(enhancementModel.systemMLSuperResolutionEnabled) systemMLSRScale=\(enhancementModel.systemMLSuperResolutionScale) systemMLFramesAdded=\(enhancementModel.systemMLInterpolatedFrames) systemMLCurrentVideoInRange=\(enhancementModel.systemMLCurrentVideoInRange)"
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
                MetalFXSuperResolutionAdapter.shared.endSession()
                OpticalFlowFrameInterpolationAdapter.shared.endSession()
                #if os(macOS)
                    RifeFrameInterpolationAdapter.shared.endSession()
                #endif
                return (policy, nil)

            case .anime4k:
                #if !targetEnvironment(simulator)
                    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                        SystemVideoEnhancementAdapter.shared.endSession()
                    }
                #endif
                MetalFXSuperResolutionAdapter.shared.endSession()
                OpticalFlowFrameInterpolationAdapter.shared.endSession()
                #if os(macOS)
                    RifeFrameInterpolationAdapter.shared.endSession()
                #endif

                let anime4kEnabled = enhancementModel.anime4kEnabled
                let preset = enhancementModel.anime4kPreset
                let abCompareEnabled = enhancementModel.anime4kABCompare
                let resolution = enhancementModel.anime4kOutputResolution
                guard anime4kEnabled else {
                    logFrameCallbackConfigurationOnce("Anime4K frame callback disabled")
                    Anime4KHostEngine.shared.reset()
                    return (policy, nil)
                }

                let engine = Anime4KHostEngine.shared
                let maxOutputWidth = resolution.maxWidth
                let maxOutputHeight = resolution.maxHeight
                policy = FrameCallbackPolicy(
                    enabled: true,
                    mode: .asyncSingle(
                        .init(
                            processorFactory: {
                                Anime4KSingleFrameProcessor(
                                    engine: engine,
                                    preset: preset,
                                    abCompareEnabled: abCompareEnabled,
                                    maxOutputWidth: maxOutputWidth,
                                    maxOutputHeight: maxOutputHeight
                                )
                            }
                        )
                    )
                )
                logFrameCallbackConfigurationOnce(
                    "Anime4K frame callback enabled mode=\(policy.mode.kind.rawValue) preset=\(preset) outputResolution=\(resolution.rawValue) abCompare=\(abCompareEnabled)"
                )
                let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
                return (policy, onEvent)

            case .systemML:
                #if targetEnvironment(simulator)
                    logFrameCallbackConfigurationOnce("System VT unavailable on simulator")
                    return (policy, nil)
                #else
                    guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
                        logFrameCallbackConfigurationOnce("System VT unavailable on this OS")
                        return (policy, nil)
                    }
                    guard enhancementModel.systemMLEnhancementSupported else {
                        logFrameCallbackConfigurationOnce("System VT not supported on device")
                        return (policy, nil)
                    }
                    guard enhancementModel.systemMLCurrentVideoInRange else {
                        logFrameCallbackConfigurationOnce(
                            "System VT current video resolution out of supported range")
                        return (policy, nil)
                    }
                    MetalFXSuperResolutionAdapter.shared.endSession()
                    OpticalFlowFrameInterpolationAdapter.shared.endSession()
                    #if os(macOS)
                        RifeFrameInterpolationAdapter.shared.endSession()
                    #endif

                    let adapter = SystemVideoEnhancementAdapter.shared
                    let frameInterpolationEnabled =
                        enhancementModel.systemMLFrameInterpolationEnabled
                        && enhancementModel.systemMLCurrentVideoSupportsFrameInterpolation
                    let superResolutionEnabled =
                        enhancementModel.systemMLSuperResolutionEnabled
                        && enhancementModel.systemMLCurrentVideoSupportsSuperResolution
                    guard frameInterpolationEnabled || superResolutionEnabled else {
                        logFrameCallbackConfigurationOnce(
                            "System VT disabled: no active VT feature")
                        return (policy, nil)
                    }

                    let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
                    if frameInterpolationEnabled {
                        let scalar = 1
                        let numFrames = max(
                            1, min(3, enhancementModel.systemMLInterpolatedFrames))
                        logFrameCallbackConfigurationOnce(
                            "System VT frame interpolation enabled mode=temporal scalar=\(scalar) numFrames=\(numFrames)"
                        )
                        policy = FrameCallbackPolicy(
                            enabled: true,
                            mode: .temporal(
                                .init(
                                    processorFactory: {
                                        adapter.makeTemporalProcessor(
                                            scalar: scalar,
                                            numFrames: numFrames
                                        )
                                    },
                                    warmup: { dims in
                                        await adapter.warmup(
                                            dimensions: dims,
                                            scalar: scalar,
                                            numFrames: numFrames
                                        )
                                    }
                                )
                            )
                        )
                        return (policy, onEvent)
                    }

                    let scale = enhancementModel.systemMLSuperResolutionScale
                    let abCompareEnabled = enhancementModel.systemMLABCompare
                    logFrameCallbackConfigurationOnce(
                        "System VT super resolution enabled mode=asyncSingle scale=\(scale) abCompare=\(abCompareEnabled)"
                    )
                    policy = FrameCallbackPolicy(
                        enabled: true,
                        mode: .asyncSingle(
                            .init(
                                processorFactory: {
                                    SystemVideoEnhancementSuperResolutionProcessor(
                                        adapter: adapter,
                                        scale: scale,
                                        abCompareEnabled: abCompareEnabled
                                    )
                                },
                                preset: .aggressive
                            )
                        )
                    )
                    return (policy, onEvent)
                #endif

            case .opticalFlow:
                MetalFXSuperResolutionAdapter.shared.endSession()
                #if os(macOS)
                    RifeFrameInterpolationAdapter.shared.endSession()
                #endif
                guard enhancementModel.opticalFlowSectionVisible else {
                    logFrameCallbackConfigurationOnce(
                        "Optical flow not available: video not 1080p or below"
                    )
                    return (policy, nil)
                }
                logFrameCallbackConfigurationOnce(
                    "Optical flow frame callback enabled mode=temporal")
                let adapter = OpticalFlowFrameInterpolationAdapter.shared
                policy = FrameCallbackPolicy(
                    enabled: true,
                    mode: .temporal(
                        .init(
                            processorFactory: {
                                adapter.makeTemporalProcessor()
                            },
                            warmup: { dims in
                                await adapter.warmup(dimensions: dims)
                            }
                        )
                    )
                )
                let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
                return (policy, onEvent)

            case .rife:
                #if os(macOS)
                    Anime4KHostEngine.shared.reset()
                    #if !targetEnvironment(simulator)
                        if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                            SystemVideoEnhancementAdapter.shared.endSession()
                        }
                    #endif
                    MetalFXSuperResolutionAdapter.shared.endSession()
                    OpticalFlowFrameInterpolationAdapter.shared.endSession()

                    guard enhancementModel.rifeSectionVisible else {
                        logFrameCallbackConfigurationOnce(
                            "RIFE not available: video out of supported range")
                        return (policy, nil)
                    }

                    let adapter = RifeFrameInterpolationAdapter.shared
                    let tier = enhancementModel.resolvedRifeTier
                    let adaptive = enhancementModel.rifeAdaptiveEnabled
                    enhancementModel.currentRifeTier = tier
                    adapter.setAdaptiveDowngradeEnabled(adaptive)
                    adapter.onTierChanged = { newTier in
                        Task { @MainActor in
                            PlayerEnhancementModel.shared.currentRifeTier = newTier
                        }
                    }
                    logFrameCallbackConfigurationOnce(
                        "RIFE frame callback enabled mode=temporal tier=\(tier.rawValue) adaptive=\(adaptive)")
                    policy = FrameCallbackPolicy(
                        enabled: true,
                        mode: .temporal(
                            .init(
                                processorFactory: { adapter.makeTemporalProcessor(tier: tier) },
                                warmup: { dims in await adapter.warmup(dimensions: dims, tier: tier) }
                            )
                        )
                    )
                    let onEvent = makeFrameCallbackEventLogger(tag: "VFI-RIFE")
                    return (policy, onEvent)
                #else
                    return (policy, nil)
                #endif

            case .metalFX:
                Anime4KHostEngine.shared.reset()
                #if !targetEnvironment(simulator)
                    if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                        SystemVideoEnhancementAdapter.shared.endSession()
                    }
                #endif
                OpticalFlowFrameInterpolationAdapter.shared.endSession()
                #if os(macOS)
                    RifeFrameInterpolationAdapter.shared.endSession()
                #endif
                guard enhancementModel.metalFXSectionVisible else {
                    logFrameCallbackConfigurationOnce(
                        "MetalFX super resolution unavailable for current video"
                    )
                    return (policy, nil)
                }
                guard enhancementModel.metalFXSuperResolutionSupported else {
                    logFrameCallbackConfigurationOnce("MetalFX super resolution unsupported on device")
                    return (policy, nil)
                }
                guard enhancementModel.metalFXSuperResolutionEnabled else {
                    logFrameCallbackConfigurationOnce("MetalFX super resolution disabled")
                    return (policy, nil)
                }

                let outputResolution = enhancementModel.metalFXOutputResolution
                let abCompareEnabled = enhancementModel.metalFXABCompare
                let adapter = MetalFXSuperResolutionAdapter.shared
                policy = FrameCallbackPolicy(
                    enabled: true,
                    mode: .asyncSingle(
                        .init(
                            processorFactory: {
                                MetalFXSuperResolutionProcessor(
                                    adapter: adapter,
                                    targetOutputResolution: outputResolution,
                                    abCompareEnabled: abCompareEnabled
                                )
                            },
                            preset: .aggressive
                        )
                    )
                )
                logFrameCallbackConfigurationOnce(
                    "MetalFX super resolution enabled mode=asyncSingle output=\(outputResolution.rawValue) abCompare=\(abCompareEnabled)"
                )
                let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
                return (policy, onEvent)
            }
        #else
            return (policy, nil)
        #endif
    }

    #if !os(tvOS)
        private func makeFrameCallbackEventLogger(tag: String) -> EventCallback {
            { event in
                switch event {
                case let .callbackTimeout(kind, elapsedMs):
                    cinemoreLog(
                        level: .warning,
                        "[\(tag)] Frame callback timeout kind=\(kind.rawValue) elapsed=\(String(format: "%.2f", elapsedMs))ms"
                    )
                case let .callbackInvalidResult(kind, message):
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback invalid result kind=\(kind.rawValue) message=\(message)"
                    )
                case let .callbackError(kind, message):
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback error kind=\(kind.rawValue) message=\(message)"
                    )
                case let .bypassStarted(kind):
                    cinemoreLog(
                        level: .warning,
                        "[\(tag)] Frame callback bypass started kind=\(kind.rawValue)"
                    )
                case let .bypassEnded(kind):
                    cinemoreLog(
                        level: .warning,
                        "[\(tag)] Frame callback bypass ended kind=\(kind.rawValue)"
                    )
                case let .warmupReady(kind, elapsedMs):
                    cinemoreLog(
                        level: .debug,
                        "[\(tag)] Frame callback warmup ready kind=\(kind.rawValue) elapsed=\(String(format: "%.2f", elapsedMs))ms"
                    )
                @unknown default:
                    cinemoreLog(level: .debug, "[\(tag)] Frame callback unknown event")
                }
            }
        }

        private func logFrameCallbackConfigurationOnce(_ message: String) {
            guard lastFrameCallbackConfigLog != message else {
                return
            }
            lastFrameCallbackConfigLog = message
            cinemoreLog(level: .debug, message)
        }
    #endif
}
