import Anime4KMetal
import CinePlayerSDK
import Combine
import Foundation
import SwiftUI
import CoreVideo
import CoreMedia
import QuartzCore
#if canImport(RifeMetal) && !os(tvOS)
import RifeMetal
#endif

@MainActor
final class VideoPlayerModel: ObservableObject {
    let translationRuntime = SubtitleTranslationRuntime()
    let translationRouter: SubtitleTranslationRouter

    @Published var playerCoordinator = CinePlayer.Coordinator()
    @Published var config: CinePlayerConfig = .init()

    @Published var isPlaybackInfoPinned = false
    private var enhancementConfigurationID = UUID()
    private var frameCallbackConfigurationResetScheduler = DeferredMainActorCommandScheduler()
    private var translationSettings = PlayerControlConfig.default
    private(set) var sourceURL: URL?

    #if canImport(Metal)
        private var lastFrameCallbackConfigLog: String?
    #endif

    init() {
        translationRouter = SubtitleTranslationRouter(runtime: translationRuntime)

        #if canImport(Metal)
            PlayerEnhancementModel.shared.onDolbyVisionFELChanged = { [weak self] in
                Task { @MainActor [weak self] in self?.applyDolbyVisionFELPreferenceToActivePlayer() }
            }
            PlayerEnhancementModel.shared.onRuntimeConfigChanged = { [weak self] resetPipeline in
                Task { @MainActor [weak self] in
                    self?.applyFrameCallbackConfigurationToActivePlayer(
                        resetPipeline: resetPipeline)
                }
            }
        #endif
    }

    func open(url: URL, startTime: TimeInterval = 0, controlConfig: PlayerControlConfig) {
        translationSettings = controlConfig
        sourceURL = url
        let newConfig = CinePlayerConfig()

        PlayerEnhancementModel.shared.resetVideoEnhancementForNewVideoSession()

        newConfig.url = url
        newConfig.startTime = max(0, startTime)
        newConfig.autoPlay = true
        configureSubtitleTranslate(for: newConfig, mode: controlConfig.subtitleTranslateMode)
        configureDolbyVisionFEL(for: newConfig)
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
        isPlaybackInfoPinned = false
        enhancementConfigurationID = UUID()
        frameCallbackConfigurationResetScheduler.cancel()
        #if canImport(Metal)
        PlayerEnhancementModel.shared.cancelEnhancementStartup()
        #endif
        playerCoordinator.shutdown()
        sourceURL = nil
        translationRuntime.desiredApplePair = nil
        Task { [translationRouter] in await translationRouter.applySettings(mode: .off) }
        #if canImport(Metal)
        PlayerEnhancementModel.shared.resetVideoEnhancementForNewVideoSession()
        #endif
        config = .init()
    }

    func applySubtitleTranslationSettings(_ settings: PlayerControlConfig) async {
        translationSettings = settings
        config.subtitleTranslateMode = settings.subtitleTranslateMode
        await translationRouter.applySettings(mode: settings.subtitleTranslateMode)
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
        options.subtitleTranslate = { [weak self] text, from in
            let settings = await MainActor.run { self?.translationSettings ?? .default }
            return try await router.processSubtitle(
                text: text, from: from,
                targetLanguage: settings.resolvedSubtitleTranslationTargetLanguage,
                translationOnTop: settings.subtitleTranslationOnTop
            )
        }
        Task { [translationRouter] in
            await translationRouter.applySettings(mode: mode)
        }
    }

    func refreshEnhancementCapabilities(resetSelection: Bool = false) {
        let playSettingModel = PlayerEnhancementModel.shared
        // 系统 VT：根据当前视频实际分辨率（轨道 naturalSize）判断是否支持 VT 插帧/超分；Anime4K：根据适配的像素数量判断是否显示。
        if let track = playerCoordinator.controller?.videoTrack {
            let size = track.naturalSize
            let w = Int(size.width)
            let h = Int(size.height)
            playSettingModel.enhancementCurrentVideoFrameRate = track.nominalFrameRate
            playSettingModel.enhancementCurrentVideoIsHDR = track.dynamicRange.isHDR
            playSettingModel.enhancementCurrentVideoHasDolbyVisionConfig =
                track.dolbyVisionConfig != nil
            playSettingModel.anime4kSectionVisible =
                !track.dynamicRange.isHDR
                    && PlayerEnhancementModel.isVideoPixelCountInAnime4KRange(
                        width: w, height: h
                    )
            playSettingModel.setSystemMLCurrentVideoDimensions(
                width: w, height: h
            )
            playSettingModel.systemMLCurrentVideoInRange =
                PlayerEnhancementModel.isVideoResolutionInSystemMLRange(
                    width: w,
                    height: h
                )
            playSettingModel.metalFXSectionVisible =
                playSettingModel.metalFXSuperResolutionSupported
                    && !track.dynamicRange.isHDR
                    && PlayerEnhancementModel.isVideoResolutionInMetalFXRange(
                        width: w,
                        height: h
                    )
            playSettingModel.clampMetalFXOutputResolutionToCurrentVideoIfNeeded()
            playSettingModel.metalFXInterpolationSectionVisible =
                MetalFXFrameInterpolationAdapter.isSupported()
                    && playSettingModel.currentVideoSupportsInterpolationFrameRate
                    && !track.dynamicRange.isHDR
                    && PlayerEnhancementModel.isVideoResolutionInMetalFXInterpolationRange(
                        width: w,
                        height: h
                    )
            #if canImport(RifeMetal) && !os(tvOS)
                playSettingModel.rifeSectionVisible =
                    playSettingModel.currentVideoSupportsInterpolationFrameRate
                        && !track.dynamicRange.isHDR
                        && PlayerEnhancementModel.isVideoResolutionInRifeRange(
                            width: w,
                            height: h
                        )
            #else
                playSettingModel.rifeSectionVisible = false
            #endif
            playSettingModel.dolbyVisionP7SectionVisible =
                track.dolbyVisionConfig?.isLayeredProfile7 == true
        } else {
            playSettingModel.anime4kSectionVisible = false
            playSettingModel.enhancementCurrentVideoFrameRate = nil
            playSettingModel.enhancementCurrentVideoIsHDR = false
            playSettingModel.enhancementCurrentVideoHasDolbyVisionConfig = false
            playSettingModel.setSystemMLCurrentVideoDimensions(
                width: nil, height: nil
            )
            playSettingModel.systemMLCurrentVideoInRange = false
            playSettingModel.metalFXSectionVisible = false
            playSettingModel.metalFXInterpolationSectionVisible = false
            playSettingModel.rifeSectionVisible = false
            playSettingModel.dolbyVisionP7SectionVisible = false
        }
        if resetSelection {
            // 只有初始化播放才清空选择；切轨保留仍然适用的增强方式。
            playSettingModel.videoEnhancementStrategy = .off
        } else {
            playSettingModel.reconcileEnhancementForCurrentVideo()
        }
    }

    func refreshEnhancementForSelectedVideoTrack() {
        guard playerCoordinator.videoTrack != nil else {
            return
        }
        let hadEnhancement = PlayerEnhancementModel.shared.videoEnhancementStrategy != .off
        refreshEnhancementCapabilities()
        if hadEnhancement {
            // 即使策略未变化，新轨道的尺寸和帧率也需要重新配置现有处理器。
            scheduleFrameCallbackConfigurationResetForActivePlayer()
        }
    }

    func configureFrameCallback(for options: CinePlayerConfig) {
        let callbackConfig = makeFrameCallbackConfiguration()
        options.frameCallbackPolicy = callbackConfig.policy
        options.onAudioFrame = nil
        options.onFrameCallbackEvent = callbackConfig.onFrameCallbackEvent
    }

    #if canImport(Metal)
        func configureDolbyVisionFEL(for options: CinePlayerConfig) {
            PlayerEnhancementModel.shared.applyDolbyVisionFELPreference(to: options)
        }

        /// 热更新 P7 FEL 偏好；当前视频为 P7 时仅重建视频解码器并精确回到当前进度。
        func applyDolbyVisionFELPreferenceToActivePlayer() {
            let options = config
            let enabled = PlayerEnhancementModel.shared.dolbyVisionFELDecode
            guard let controller = playerCoordinator.controller else {
                guard options.dolbyVisionFELDecode != enabled else {
                    return
                }
                options.dolbyVisionFELDecode = enabled
                return
            }
            controller.refreshDolbyVisionFELDecoderAfterPreferenceChange(
                enabled: enabled
            ) { success in
                cinemoreLog(
                    level: .debug,
                    "DolbyVisionP7 preference refresh completed success=\(success) enabled=\(enabled)"
                )
            }
        }
    #endif

    /// 在播放过程中热更新帧回调配置（仅更新宿主配置，不触碰播放器核心逻辑）。
    func applyFrameCallbackConfigurationToActivePlayer(resetPipeline: Bool) {
        guard let controller = playerCoordinator.controller, sourceURL != nil else {
            return
        }
        cinemoreLog(
            level: .debug,
            "VideoEnhance applyFrameCallbackConfigurationToActivePlayer resetPipeline=\(resetPipeline)"
        )
        let options = config
        let callbackConfig = makeFrameCallbackConfiguration()
        options.frameCallbackPolicy = callbackConfig.policy
        options.onAudioFrame = nil
        options.onFrameCallbackEvent = callbackConfig.onFrameCallbackEvent
        // Phase 4: mode 切换不再 reseek。Center 的 bumpGenerationAndClear + processor swap
        // 配合 TemporalReorderBuffer 跨代自愈已经保证干净切换；代价仅 3-4 帧的"暖窗"过渡，
        // 比原先 seek 回当前时间的卡顿好得多。
        controller.setFrameCallbackConfiguration(
            policy: callbackConfig.policy,
            onAudioFrame: nil,
            onFrameCallbackEvent: callbackConfig.onFrameCallbackEvent,
            resetPipeline: resetPipeline
        )
    }

    #if canImport(Metal)
        func scheduleFrameCallbackConfigurationResetForActivePlayer() {
            frameCallbackConfigurationResetScheduler.schedule { [weak self] in
                self?.applyFrameCallbackConfigurationToActivePlayer(resetPipeline: true)
            }
        }
    #endif

    private typealias EventCallback = (@Sendable (FrameCallbackEvent) -> Void)?

    private func makeFrameCallbackConfiguration()
        -> (
            policy: FrameCallbackPolicy,
            onFrameCallbackEvent: EventCallback
        )
    {
        var policy = FrameCallbackPolicy()
        enhancementConfigurationID = UUID()
        let configurationID = enhancementConfigurationID
        #if canImport(Metal)
            let playSettings = PlayerEnhancementModel.shared
            let strategy = playSettings.videoEnhancementStrategy
            playSettings.cancelEnhancementStartup()
            // 与面板共用准入门槛；含杜比配置的轨道即便开关残留为开，也不创建增强实例。
            guard !playSettings.enhancementCurrentVideoHasDolbyVisionConfig else {
                logFrameCallbackConfigurationOnce("Video enhancement unavailable: video has Dolby Vision configuration")
                return (policy, nil)
            }
            cinemoreLog(
                level: .debug,
                "VideoEnhance makeFrameCallbackConfiguration strategy=\(strategy.rawValue) systemMLSupported=\(playSettings.systemMLEnhancementSupported) systemMLFIEnabled=\(playSettings.systemMLFrameInterpolationEnabled) systemMLSREnabled=\(playSettings.systemMLSuperResolutionEnabled) systemMLSRScale=\(playSettings.systemMLSuperResolutionScale) systemMLFramesAdded=\(playSettings.systemMLInterpolatedFrames) systemMLCurrentVideoInRange=\(playSettings.systemMLCurrentVideoInRange)"
            )

            switch strategy {
            case .off:
                logFrameCallbackConfigurationOnce("Video enhancement disabled")
                return (policy, nil)

            case .fsr,
                 .artCNN:
                guard playSettings.spatialSuperResolutionCurrentVideoSupported else {
                    return (policy, nil)
                }
                let method: SpatialSuperResolutionProcessor.Method = strategy == .fsr
                    ? .fsr(resolution: playSettings.fsrOutputResolution, sharpness: playSettings.fsrSharpness)
                    : .artCNN
                let abCompareEnabled = strategy == .fsr ? playSettings.fsrABCompare : playSettings.artCNNABCompare
                policy = FrameCallbackPolicy(enabled: true, mode: .asyncSingle(.init(
                    processorFactory: makeEnhancementStartupFactory { dimensions in
                        let processor = try SpatialSuperResolutionProcessor(method: method, dimensions: dimensions,
                                                                            abCompareEnabled: abCompareEnabled)
                        try processor.prepare()
                        return processor
                    }, renderLookahead: 2
                )))
                return (policy, makeFrameCallbackEventLogger(tag: strategy == .fsr ? "FSR" : "ArtCNN"))

            case .anime4k:
                let anime4kEnabled = playSettings.anime4kEnabled
                let preset = playSettings.anime4kPreset
                let abCompareEnabled = playSettings.anime4kABCompare
                let resolution = playSettings.anime4kOutputResolution
                guard anime4kEnabled else {
                    logFrameCallbackConfigurationOnce("Anime4K frame callback disabled")
                    return (policy, nil)
                }

                let maxOutputWidth = resolution.maxWidth
                let maxOutputHeight = resolution.maxHeight
                policy = FrameCallbackPolicy(
                    enabled: true,
                    mode: .asyncSingle(
                        .init(
                            processorFactory: makeEnhancementStartupFactory { dimensions in
                                let engine = try Anime4KHostEngine()
                                let interpolator = Anime4KInterpolator(
                                    configuration: .init(preset: preset, maxOutputWidth: maxOutputWidth,
                                                         maxOutputHeight: maxOutputHeight, abCompareEnabled: abCompareEnabled),
                                    engine: engine
                                )
                                let processor = Anime4KSingleFrameProcessor(interpolator: interpolator,
                                                                            preset: preset, abCompareEnabled: abCompareEnabled,
                                                                            maxOutputWidth: maxOutputWidth, maxOutputHeight: maxOutputHeight)
                                guard case .replace = try processor.onFrame(EnhancementStartupProcessor.warmupFrame(dimensions))
                                else {
                                    throw EnhancementStartupProcessor.StartupError.unavailable
                                }
                                return processor
                            }, renderLookahead: 2
                        )
                    )
                )
                logFrameCallbackConfigurationOnce(
                    "Anime4K frame callback enabled mode=\(policy.mode.kind.rawValue) preset=\(preset) outputResolution=\(resolution.rawValue) abCompare=\(abCompareEnabled)"
                )
                let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
                return (policy, onEvent)

            case .systemML:
                guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
                    cinemoreLog(
                        level: .debug, "[VFI] VideoEnhance System VT 不可用：当前系统版本低于 iOS/macOS 26"
                    )
                    logFrameCallbackConfigurationOnce("System VT unavailable on this OS")
                    return (policy, nil)
                }
                guard playSettings.systemMLEnhancementSupported else {
                    cinemoreLog(
                        level: .debug,
                        "[VFI] VideoEnhance System VT 不可用：设备不支持 VT 插帧/超分"
                    )
                    logFrameCallbackConfigurationOnce("System VT not supported on device")
                    return (policy, nil)
                }
                guard playSettings.systemMLCurrentVideoInRange else {
                    cinemoreLog(
                        level: .debug, "[VFI] VideoEnhance System VT 未启用：当前视频分辨率不支持 VT 插帧/超分"
                    )
                    logFrameCallbackConfigurationOnce(
                        "System VT current video resolution out of supported range"
                    )
                    return (policy, nil)
                }

                let frameInterpolationEnabled =
                    playSettings.systemMLFrameInterpolationEnabled
                        && playSettings.systemMLCurrentVideoSupportsFrameInterpolation
                let superResolutionEnabled =
                    playSettings.systemMLSuperResolutionEnabled
                        && playSettings.systemMLCurrentVideoSupportsSuperResolution

                guard frameInterpolationEnabled || superResolutionEnabled else {
                    logFrameCallbackConfigurationOnce("System VT disabled: no active VT feature")
                    return (policy, nil)
                }

                let onEvent = makeFrameCallbackEventLogger(tag: "VFI")

                if frameInterpolationEnabled {
                    // VT LLFI 空间缩放固定 1：实测 scalar=2 在当前 runtime 路径下无法稳定启动，
                    // 所以不让用户选择。想重启 scalar=2 需要修 adapter + 重新评估 budget。
                    let scalar = 1
                    let quality = playSettings.systemMLQualityInterpolation
                    let numFrames = max(1, min(playSettings.systemMLMaximumInterpolatedFrames, playSettings.systemMLInterpolatedFrames))
                    let effectiveNumFrames = numFrames
                    cinemoreLog(
                        level: .debug,
                        "[VFI] VideoEnhance System VT 插帧已启用 mode=temporal scalar=\(scalar) numFrames=\(numFrames)"
                    )
                    logFrameCallbackConfigurationOnce(
                        "System VT frame interpolation enabled mode=temporal scalar=\(scalar) numFrames=\(numFrames)"
                    )
                    policy = FrameCallbackPolicy(
                        enabled: true,
                        mode: .temporal(
                            .init(
                                processorFactory: makeEnhancementStartupFactory { [weak self] dimensions in
                                    #if !os(tvOS) && !os(visionOS) && !targetEnvironment(simulator)
                                        if quality {
                                            return try VTQualityInterpolationProcessor(dimensions: dimensions, count: numFrames)
                                        }
                                    #endif
                                    let adapter = SystemVideoEnhancementAdapter()
                                    guard await adapter.warmup(dimensions: dimensions, scalar: scalar, numFrames: effectiveNumFrames)
                                    else {
                                        throw EnhancementStartupProcessor.StartupError.unavailable
                                    }
                                    return adapter.makeTemporalProcessor(scalar: scalar, numFrames: numFrames) { [weak self] in
                                        Task { @MainActor [weak self] in
                                            guard let self, self.enhancementConfigurationID == configurationID,
                                                  playSettings.videoEnhancementStrategy == .systemML,
                                                  playSettings.systemMLFrameInterpolationEnabled,
                                                  playSettings.systemMLInterpolatedFrames == numFrames
                                            else {
                                                return
                                            }
                                            playSettings.systemMLInterpolatedFrames = 1
                                        }
                                    }
                                }
                            )
                        )
                    )
                    policy.preferredVideoQueueCapacity = numFrames == 1 ? 8 : 16
                    return (policy, onEvent)
                }

                let scale = playSettings.systemMLSuperResolutionScale
                let abCompareEnabled = playSettings.systemMLABCompare
                policy = FrameCallbackPolicy(
                    enabled: true,
                    mode: .asyncSingle(
                        .init(
                            processorFactory: makeEnhancementStartupFactory { dimensions in
                                let adapter = SystemVideoEnhancementAdapter()
                                let processor = SystemVideoEnhancementSuperResolutionProcessor(
                                    adapter: adapter, scale: scale, abCompareEnabled: abCompareEnabled
                                )
                                guard case .replace = try processor.onFrame(EnhancementStartupProcessor.warmupFrame(dimensions))
                                else {
                                    throw EnhancementStartupProcessor.StartupError.unavailable
                                }
                                return processor
                            },
                            preset: .aggressive
                        )
                    )
                )
                cinemoreLog(
                    level: .debug,
                    "[VFI] VideoEnhance System VT 超分已启用 mode=asyncSingle scale=\(scale) abCompare=\(abCompareEnabled)"
                )
                logFrameCallbackConfigurationOnce(
                    "System VT super resolution enabled mode=asyncSingle scale=\(scale) abCompare=\(abCompareEnabled)"
                )
                return (policy, onEvent)

            case .metalFXInterpolation:
                guard playSettings.metalFXInterpolationSectionVisible,
                      MetalFXFrameInterpolationAdapter.isSupported()
                else {
                    logFrameCallbackConfigurationOnce(
                        "MetalFX interpolation unavailable for the current device, OS or video"
                    )
                    return (policy, nil)
                }
                cinemoreLog(level: .debug, "[VFI] VideoEnhance MetalFX 补帧帧回调已启用 mode=temporal")
                logFrameCallbackConfigurationOnce(
                    "MetalFX interpolation frame callback enabled mode=temporal"
                )
                policy = FrameCallbackPolicy(
                    enabled: true,
                    mode: .temporal(
                        .init(
                            processorFactory: makeEnhancementStartupFactory { dimensions in
                                let adapter = MetalFXFrameInterpolationAdapter()
                                guard await adapter.warmup(dimensions: dimensions)
                                else {
                                    throw EnhancementStartupProcessor.StartupError.unavailable
                                }
                                return adapter.makeTemporalProcessor()
                            }
                        )
                    )
                )
                let onEvent = makeFrameCallbackEventLogger(tag: "VFI")
                policy.preferredVideoQueueCapacity = 8
                return (policy, onEvent)

            case .rife:
                #if canImport(RifeMetal) && !os(tvOS)
                    guard playSettings.rifeSectionVisible else {
                        logFrameCallbackConfigurationOnce(
                            "RIFE not available: video out of supported range"
                        )
                        return (policy, nil)
                    }

                    let tier = playSettings.resolvedRifeTier
                    let adaptive = playSettings.rifeAdaptiveEnabled
                    playSettings.currentRifeTier = tier
                    logFrameCallbackConfigurationOnce(
                        "RIFE frame callback enabled mode=temporal tier=\(tier.rawValue) adaptive=\(adaptive)"
                    )
                    policy = FrameCallbackPolicy(
                        enabled: true,
                        mode: .temporal(
                            .init(
                                processorFactory: makeEnhancementStartupFactory { [weak self] dimensions in
                                    let adapter = RifeFrameInterpolationAdapter()
                                    adapter.setAdaptiveDowngradeEnabled(adaptive)
                                    adapter.onTierChanged = { [weak self] newTier in
                                        Task { @MainActor [weak self] in
                                            // 切换档位后，旧实例的迟到通知不能覆盖新配置。
                                            guard let self, self.enhancementConfigurationID == configurationID,
                                                  playSettings.videoEnhancementStrategy == .rife,
                                                  playSettings.rifeAdaptiveEnabled
                                            else {
                                                return
                                            }
                                            playSettings.currentRifeTier = newTier
                                        }
                                    }
                                    guard await adapter.warmup(dimensions: dimensions, tier: tier)
                                    else {
                                        throw EnhancementStartupProcessor.StartupError.unavailable
                                    }
                                    return adapter.makeTemporalProcessor(tier: tier)
                                }
                            )
                        )
                    )
                    let onEvent = makeFrameCallbackEventLogger(tag: "VFI-RIFE")
                    policy.preferredVideoQueueCapacity = 8
                    return (policy, onEvent)

                #else
                    return (policy, nil)
                #endif

            case .metalFX:
                guard playSettings.metalFXSectionVisible else {
                    logFrameCallbackConfigurationOnce(
                        "MetalFX super resolution unavailable for current video"
                    )
                    return (policy, nil)
                }
                guard playSettings.metalFXSuperResolutionSupported else {
                    logFrameCallbackConfigurationOnce("MetalFX super resolution unsupported on device")
                    return (policy, nil)
                }
                guard playSettings.metalFXSuperResolutionEnabled else {
                    logFrameCallbackConfigurationOnce("MetalFX super resolution disabled")
                    return (policy, nil)
                }
                let outputResolution = playSettings.metalFXOutputResolution
                let abCompareEnabled = playSettings.metalFXABCompare
                policy = FrameCallbackPolicy(
                    enabled: true,
                    mode: .asyncSingle(
                        .init(
                            processorFactory: makeEnhancementStartupFactory { dimensions in
                                let adapter = MetalFXSuperResolutionAdapter()
                                let processor = MetalFXSuperResolutionProcessor(adapter: adapter,
                                                                                targetOutputResolution: outputResolution,
                                                                                abCompareEnabled: abCompareEnabled)
                                guard case .replace = try processor.onFrame(EnhancementStartupProcessor.warmupFrame(dimensions))
                                else {
                                    throw EnhancementStartupProcessor.StartupError.unavailable
                                }
                                return processor
                            },
                            preset: .aggressive,
                            renderLookahead: 2
                        )
                    )
                )
                cinemoreLog(
                    level: .debug,
                    "[VFI] VideoEnhance MetalFX 超分已启用 mode=asyncSingle output=\(outputResolution.rawValue) abCompare=\(abCompareEnabled)"
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

    #if canImport(Metal)
        private func makeEnhancementStartupFactory(
            _ prepare: @escaping EnhancementStartupProcessor.Factory
        ) -> @Sendable () -> any VideoFrameProcessor {
            let settings = PlayerEnhancementModel.shared
            let request = settings.beginEnhancementStartup()
            let dimensions: CMVideoDimensions? =
                if let width = settings.systemMLCurrentVideoWidth, let height = settings.systemMLCurrentVideoHeight,
                let w = Int32(exactly: width), let h = Int32(exactly: height), w > 0, h > 0 {
                    CMVideoDimensions(width: w, height: h)
                } else {
                    nil
                }
            return {
                EnhancementStartupProcessor(dimensions: dimensions, onUpdate: { update in
                    Task { @MainActor in
                        guard update.isCurrent() else {
                            return
                        }
                        settings.updateEnhancementStartup(request: request, state: update.state)
                    }
                }, factory: prepare)
            }
        }

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
                    break
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
