//
//  PlayerEnhancementModel.swift
//  Cinemore
//
//  Created by lf on 2024/12/10.
//

import SwiftUI

#if canImport(Metal)
    import Anime4KMetal
    import CoreVideo
    import Metal
    #if canImport(RifeMetal) && !os(tvOS)
        import RifeMetal
    #endif
    #if canImport(MetalFX)
        @preconcurrency import MetalFX
    #endif
    #if !targetEnvironment(simulator)
        @preconcurrency import VideoToolbox
    #endif

    /// 视频增强策略：关闭 / Anime4K / 系统 VT / MetalFX 补帧 / MetalFX 超分。
    nonisolated enum VideoEnhancementStrategy: String, CaseIterable, Identifiable {
        case off
        case anime4k
        case systemML
        // 保留旧持久化值，已有光流设置自动使用新的 MetalFX 后端。
        case metalFXInterpolation = "opticalFlow"
        case rife
        case metalFX
        case fsr
        case artCNN

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .off: String(localized: "关闭")
            case .anime4k: "Anime4K"
            case .systemML: String(localized: "VT 超分")
            case .metalFXInterpolation: String(localized: "MetalFX 补帧")
            case .rife: String(localized: "RIFE 补帧")
            case .metalFX: String(localized: "MetalFX 超分")
            case .fsr: String(localized: "FSR 超分")
            case .artCNN: String(localized: "ArtCNN 超分")
            }
        }
    }

    nonisolated enum RifeTierPreference: String, CaseIterable, Identifiable {
        case auto
        case hq
        case balanced
        case fast

        var id: String {
            rawValue
        }

        var displayName: String {
            switch self {
            case .auto: String(localized: "自动")
            case .hq: "HQ"
            case .balanced: "Balanced"
            case .fast: "Fast"
            }
        }
    }

    /// Anime4K 输出分辨率：2K 或 4K，默认 2K。
    nonisolated enum Anime4KOutputResolution: String, CaseIterable, Identifiable {
        case resolution2K = "2K"
        case resolution4K = "4K"

        var id: String {
            rawValue
        }

        var displayName: String {
            rawValue
        }

        /// 最大宽度（保持比例时边界）
        var maxWidth: Int {
            switch self {
            case .resolution2K: 2560
            case .resolution4K: 3840
            }
        }

        /// 最大高度（保持比例时边界）
        var maxHeight: Int {
            switch self {
            case .resolution2K: 1440
            case .resolution4K: 2160
            }
        }
    }

    /// MetalFX 输出分辨率：2K 或 4K，按目标边界等比放大。
    nonisolated enum MetalFXOutputResolution: String, CaseIterable, Identifiable {
        case resolution2K = "2K"
        case resolution4K = "4K"

        var id: String {
            rawValue
        }

        var displayName: String {
            rawValue
        }

        var maxWidth: Int {
            switch self {
            case .resolution2K: 2560
            case .resolution4K: 3840
            }
        }

        var maxHeight: Int {
            switch self {
            case .resolution2K: 1440
            case .resolution4K: 2160
            }
        }
    }
#endif

import CinePlayerSDK
import Combine

@MainActor
final class PlayerEnhancementModel: ObservableObject {
    static let shared = PlayerEnhancementModel()
    var onRuntimeConfigChanged: ((Bool) -> Void)?
    var onDolbyVisionFELChanged: (() -> Void)?
    private var runtimeScheduler = DeferredMainActorCommandScheduler()
    private var cancellables = Set<AnyCancellable>()
    private var suppressRuntimeCallback = true

    private init() {
        if let value = UserDefaults.standard.object(forKey: "dolbyVisionFELDecode") as? Bool {
            dolbyVisionFELDecode = value
        }
        suppressRuntimeCallback = false
        let changes: [AnyPublisher<Void, Never>] = [
            $videoEnhancementStrategy.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $anime4kEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $anime4kPreset.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $anime4kOutputResolution.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $anime4kABCompare.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $fsrOutputResolution.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $fsrSharpness.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $fsrABCompare.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $artCNNABCompare.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $systemMLSuperResolutionEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $systemMLSuperResolutionScale.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $systemMLFrameInterpolationEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $systemMLInterpolatedFrames.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $systemMLQualityInterpolation.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $systemMLABCompare.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $metalFXSuperResolutionEnabled.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $metalFXOutputResolution.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $metalFXABCompare.dropFirst().map { _ in () }.eraseToAnyPublisher(),
            $rifeTierPreference.dropFirst().map { _ in () }.eraseToAnyPublisher(),
        ]
        Publishers.MergeMany(changes).sink { [weak self] in
            guard let self, !suppressRuntimeCallback else { return }
            // 合并同一次控件操作产生的互斥设置，只重建最终选中的方案。
            runtimeScheduler.schedule { [weak self] in
                self?.onRuntimeConfigChanged?(true)
            }
        }.store(in: &cancellables)
        $dolbyVisionFELDecode.dropFirst().sink { [weak self] _ in
            self?.onDolbyVisionFELChanged?()
        }.store(in: &cancellables)
    }

    private static var defaultFELDecode: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    #if canImport(Metal)
        /// 是否解码并合成 P7 FEL 增强层；
        /// macOS默认开启，其他默认关闭，跨播放会话持久化。
        @Published var dolbyVisionFELDecode: Bool = PlayerEnhancementModel.defaultFELDecode {
            didSet {
                UserDefaults.standard.set(dolbyVisionFELDecode, forKey: "dolbyVisionFELDecode")
            }
        }

        /// 当前视频是否为 Dolby Vision Profile 7 FEL 视频。
        @Published var dolbyVisionP7SectionVisible: Bool = false

        func applyDolbyVisionFELPreference(to options: CinePlayerConfig) {
            options.dolbyVisionFELDecode = dolbyVisionFELDecode
        }

        /// 当前视频像素数量是否在 Anime4K 适配范围内（由播放器 ready 时根据轨道实际分辨率计算）；仅当为 true 时显示 Anime4K 设置并允许开启。
        @Published var anime4kSectionVisible: Bool = false
        /// 当前设备、系统及 SDR 视频是否支持 MetalFX 补帧；采用总像素预算及源帧率限制。
        @Published var metalFXInterpolationSectionVisible: Bool = false
        /// 当前视频是否允许显示 MetalFX 超分入口；由播放器 ready 时根据设备支持与轨道分辨率共同计算。
        @Published var metalFXSectionVisible: Bool = false
        @Published var rifeSectionVisible: Bool = false
        /// 每次播放新视频默认自动；手动档位仅保留到当前播放会话结束。
        @Published var rifeTierPreference: RifeTierPreference = .auto

        /// Anime4K 单帧超分开关（默认关闭；仅当 anime4kSectionVisible 时生效）。
        @Published var anime4kEnabled: Bool = false
        /// Anime4K 预设档位（不持久化，每次进入播放均为默认 Mode A Fast）。
        @Published var anime4kPreset: Anime4KPreset = .modeAFast
        /// Anime4K 输出分辨率（不持久化，每次进入播放均为默认 2K）。
        @Published var anime4kOutputResolution: Anime4KOutputResolution = .resolution2K
        /// Anime4K A/B 分屏对比（左原图右超分）。
        @Published var anime4kABCompare: Bool = false

        @Published var fsrOutputResolution: FSROutputResolution = .ultraHD
        @Published var fsrSharpness: FSRSharpness = .medium
        /// 仅当前播放会话使用，分屏方向与既有超分一致。
        @Published var fsrABCompare = false
        @Published var artCNNABCompare = false

        var spatialSuperResolutionCurrentVideoSupported: Bool {
            guard !enhancementCurrentVideoIsHDR, !enhancementCurrentVideoHasDolbyVisionConfig,
                  let width = systemMLCurrentVideoWidth, let height = systemMLCurrentVideoHeight,
                  let fps = enhancementCurrentVideoFrameRate
            else {
                return false
            }
            return SpatialSuperResolutionProcessor.isSupported()
                && SpatialSuperResolutionProcessor.canProcess(width: width, height: height, fps: fps)
        }

        var fsrSupportedOutputResolutions: [FSROutputResolution] {
            guard let width = systemMLCurrentVideoWidth, let height = systemMLCurrentVideoHeight else {
                return FSROutputResolution.allCases
            }
            return FSROutputResolution.allCases.filter { $0.enlarges(width: width, height: height) }
        }

        /// 当前播放器的准备状态，不持久化；请求标识用于拒绝旧预热任务的 UI 更新。
        @Published private(set) var enhancementPreparingStrategy: VideoEnhancementStrategy?
        @Published private(set) var enhancementStartupFailed = false
        private var enhancementStartupRequest = UUID()

        func cancelEnhancementStartup() {
            enhancementStartupRequest = UUID()
            enhancementPreparingStrategy = nil
            enhancementStartupFailed = false
        }

        func beginEnhancementStartup() -> UUID {
            enhancementStartupRequest = UUID()
            enhancementPreparingStrategy = videoEnhancementStrategy
            enhancementStartupFailed = false
            return enhancementStartupRequest
        }

        func updateEnhancementStartup(request: UUID, state: EnhancementStartupProcessor.State) {
            guard request == enhancementStartupRequest else {
                return
            }
            switch state {
            case .preparing:
                enhancementPreparingStrategy = videoEnhancementStrategy
                enhancementStartupFailed = false
            case .ready:
                enhancementPreparingStrategy = nil
                enhancementStartupFailed = false
            case .failed:
                enhancementPreparingStrategy = nil
                enhancementStartupFailed = true
            }
        }

        /// 视频增强策略；各平台按设备和当前视频能力开放选项。
        @Published var videoEnhancementStrategy: VideoEnhancementStrategy = .off {
            didSet {
                if oldValue != videoEnhancementStrategy {
                    cancelEnhancementStartup()
                }
                let clamped = clampStrategyToAvailability(videoEnhancementStrategy)
                if clamped != videoEnhancementStrategy {
                    videoEnhancementStrategy = clamped
                    return
                }
                applyMutualExclusion(for: videoEnhancementStrategy)
            }
        }

        /// 当前处理方式的状态名称，区分 VT 超分与补帧。
        var videoEnhancementDisplayName: String {
            guard videoEnhancementStrategy == .systemML else {
                return videoEnhancementStrategy.displayName
            }
            return systemMLFrameInterpolationEnabled
                ? String(localized: "VT 补帧") : String(localized: "VT 超分")
        }

        /// 系统 VT 超分开关（仅当 strategy == .systemML 时生效）。
        @Published var systemMLSuperResolutionEnabled: Bool = true {
            didSet {
                if systemMLSuperResolutionEnabled, !systemMLSuperResolutionSupported {
                    systemMLSuperResolutionEnabled = false
                    return
                }
                if systemMLSuperResolutionEnabled, systemMLFrameInterpolationEnabled {
                    systemMLFrameInterpolationEnabled = false
                }
            }
        }

        /// 系统 ML 超分倍率（仅允许系统接口 supportedScaleFactors 中的固定值）。
        @Published var systemMLSuperResolutionScale: Double = 2.0 {
            didSet {
                let supported = Self.systemMLSupportedScaleFactors(forWidth: systemMLCurrentVideoWidth, height: systemMLCurrentVideoHeight)
                if !supported.contains(where: { abs($0 - systemMLSuperResolutionScale) < 0.001 }), let nearest = supported.min(by: {
                    abs($0 - systemMLSuperResolutionScale) < abs($1 - systemMLSuperResolutionScale)
                }) {
                    systemMLSuperResolutionScale = nearest
                }
            }
        }

        /// 系统 VT 插帧开关（仅当 strategy == .systemML 时生效）。
        @Published var systemMLFrameInterpolationEnabled: Bool = false {
            didSet {
                if systemMLFrameInterpolationEnabled, !systemMLFrameInterpolationSupported {
                    systemMLFrameInterpolationEnabled = false
                    return
                }
                if systemMLFrameInterpolationEnabled, systemMLSuperResolutionEnabled {
                    systemMLSuperResolutionEnabled = false
                }
            }
        }

        /// 默认使用低延迟速度档；质量档使用独立的 VT 帧率转换处理器。
        @Published var systemMLQualityInterpolation = false {
            didSet {
                if systemMLInterpolatedFrames > systemMLMaximumInterpolatedFrames {
                    systemMLInterpolatedFrames = 1
                }
            }
        }

        /// 质量档只开放已验证的帧率组合；这不是实时性能保证。
        var systemMLMaximumInterpolatedFrames: Int {
            guard systemMLQualityInterpolation else {
                return 3
            }
            guard let fps = enhancementCurrentVideoFrameRate, fps.isFinite, fps > 0, fps <= 25 else {
                return 1
            }
            return 3
        }

        var systemMLQualityAvailable: Bool {
            #if !os(tvOS) && !os(visionOS) && !targetEnvironment(simulator)
                if #available(iOS 26.0, macOS 26.0, *) {
                    return !enhancementCurrentVideoIsHDR && VTFrameRateConversionConfiguration.isSupported
                }
            #endif
            return false
        }

        /// 每对源帧之间插入的帧数，质量档按源帧率收敛可选范围。
        @Published var systemMLInterpolatedFrames: Int = 1 {
            didSet {
                let clamped = max(1, min(systemMLMaximumInterpolatedFrames, systemMLInterpolatedFrames))
                if clamped != systemMLInterpolatedFrames {
                    systemMLInterpolatedFrames = clamped
                    return
                }
            }
        }

        /// 系统 ML A/B 对比（左原图，右超分），仅当 strategy == .systemML 时生效。
        @Published var systemMLABCompare: Bool = false

        /// MetalFX 超分开关（仅当 strategy == .metalFX 时生效）。
        @Published var metalFXSuperResolutionEnabled: Bool = false {
            didSet {
                if metalFXSuperResolutionEnabled, !metalFXSuperResolutionSupported {
                    metalFXSuperResolutionEnabled = false
                    return
                }
            }
        }

        /// MetalFX 目标输出尺寸。按当前视频宽高比等比放大到目标边界内。
        @Published var metalFXOutputResolution: MetalFXOutputResolution = .resolution2K {
            didSet {
                let supported = metalFXSupportedOutputResolutionsForCurrentVideo
                if !supported.isEmpty, !supported.contains(metalFXOutputResolution), let fallback = supported.first {
                    metalFXOutputResolution = fallback
                }
            }
        }

        /// MetalFX A/B 对比（左原图，右超分）。
        @Published var metalFXABCompare: Bool = false

        /// 当前设备是否支持系统 VT 插帧能力。
        var systemMLFrameInterpolationSupported: Bool {
            #if targetEnvironment(simulator)
                return false
            #else
                if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                    return VTLowLatencyFrameInterpolationConfiguration.isSupported
                }
                return false
            #endif
        }

        /// 当前设备是否支持系统 VT 超分能力。
        var systemMLSuperResolutionSupported: Bool {
            #if targetEnvironment(simulator)
                return false
            #else
                if #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) {
                    return VTLowLatencySuperResolutionScalerConfiguration.isSupported
                }
                return false
            #endif
        }

        /// 当前设备是否支持系统 VT 任一增强能力（插帧或超分）。
        var systemMLEnhancementSupported: Bool {
            systemMLFrameInterpolationSupported || systemMLSuperResolutionSupported
        }

        /// 当前设备是否支持 MetalFX 空间超分。
        var metalFXSuperResolutionSupported: Bool {
            #if canImport(MetalFX)
                guard #available(iOS 16.0, macOS 13.0, tvOS 27.1, *), let device = MTLCreateSystemDefaultDevice() else {
                    return false
                }
                return MTLFXSpatialScalerDescriptor.supportsDevice(device)
            #else
                return false
            #endif
        }

        /// 当前视频实际分辨率是否在系统 VT 可用范围（插帧或超分任一可用）。
        @Published var systemMLCurrentVideoInRange: Bool = false

        /// 当前视频实际宽高（ready 时由播放器设置，用于按当前分辨率查询系统支持的倍率）。
        @Published var systemMLCurrentVideoWidth: Int?
        @Published var systemMLCurrentVideoHeight: Int?
        @Published var enhancementCurrentVideoFrameRate: Float? {
            didSet {
                if systemMLInterpolatedFrames > systemMLMaximumInterpolatedFrames {
                    systemMLInterpolatedFrames = 1
                }
            }
        }

        @Published var enhancementCurrentVideoIsHDR = false
        /// 轨道只要存在 Dolby Vision 配置，就不开放增强；不按 Profile 或 P7 解码开关放行。
        /// 与 HDR 分开记录，普通 HDR10/HLG 仍按各增强方案的条件判断。
        @Published var enhancementCurrentVideoHasDolbyVisionConfig = false

        var currentVideoSupportsInterpolationFrameRate: Bool {
            guard let fps = enhancementCurrentVideoFrameRate else {
                return false
            }
            return Self.isVideoFrameRateInInterpolationRange(fps)
        }

        nonisolated static func isVideoFrameRateInInterpolationRange(_ fps: Float) -> Bool {
            fps.isFinite && fps > 0 && fps <= 30
        }

        /// 当前视频是否可用系统 VT 插帧。
        var systemMLCurrentVideoSupportsFrameInterpolation: Bool {
            guard !enhancementCurrentVideoHasDolbyVisionConfig else {
                return false
            }
            if systemMLQualityInterpolation, !systemMLQualityAvailable {
                return false
            }
            guard currentVideoSupportsInterpolationFrameRate,
                  let width = systemMLCurrentVideoWidth,
                  let height = systemMLCurrentVideoHeight
            else {
                return false
            }
            return Self.isVideoResolutionInVTFrameInterpolationRange(width: width, height: height)
        }

        /// 当前视频是否可用系统 VT 超分。
        var systemMLCurrentVideoSupportsSuperResolution: Bool {
            guard !enhancementCurrentVideoHasDolbyVisionConfig, !enhancementCurrentVideoIsHDR,
                  let width = systemMLCurrentVideoWidth,
                  let height = systemMLCurrentVideoHeight
            else {
                return false
            }
            return Self.isVideoResolutionInVTSuperResolutionRange(width: width, height: height)
        }

        /// 用于 Picker 的超分倍率列表：有当前视频尺寸时用该分辨率下系统支持倍率，否则用 min/max 交集。
        var systemMLSupportedScaleFactorsForPicker: [Double] {
            Self.systemMLSupportedScaleFactors(forWidth: systemMLCurrentVideoWidth, height: systemMLCurrentVideoHeight)
        }

        /// 切轨后只保留当前轨道仍支持的增强，不自动切换到另一种 VT 功能。
        func reconcileEnhancementForCurrentVideo() {
            let supported: Bool
            switch videoEnhancementStrategy {
            case .off: return
            case .fsr,
                 .artCNN:
                supported = spatialSuperResolutionCurrentVideoSupported
                if videoEnhancementStrategy == .fsr, !fsrSupportedOutputResolutions.contains(fsrOutputResolution) {
                    fsrOutputResolution = .ultraHD
                }
            case .anime4k:
                supported = anime4kSectionVisible && !enhancementCurrentVideoHasDolbyVisionConfig
            case .systemML:
                supported = systemMLFrameInterpolationEnabled
                    ? systemMLCurrentVideoSupportsFrameInterpolation
                    : systemMLSuperResolutionEnabled && systemMLCurrentVideoSupportsSuperResolution
            case .metalFX:
                supported = metalFXSectionVisible && !enhancementCurrentVideoHasDolbyVisionConfig
            case .metalFXInterpolation:
                supported = metalFXInterpolationSectionVisible && !enhancementCurrentVideoHasDolbyVisionConfig
            case .rife:
                supported = rifeSectionVisible && !enhancementCurrentVideoHasDolbyVisionConfig
            }
            if !supported {
                videoEnhancementStrategy = .off
            }
        }

        /// 更新当前视频尺寸，并据此将超分倍率限制到该分辨率下系统支持列表。
        func setSystemMLCurrentVideoDimensions(width: Int?, height: Int?) {
            systemMLCurrentVideoWidth = width
            systemMLCurrentVideoHeight = height
            let supported = Self.systemMLSupportedScaleFactors(forWidth: width, height: height)
            if !supported.contains(where: { abs($0 - systemMLSuperResolutionScale) < 0.001 }),
               let nearest = supported.min(by: { abs($0 - systemMLSuperResolutionScale) < abs($1 - systemMLSuperResolutionScale) })
            {
                systemMLSuperResolutionScale = nearest
            }
        }

        /// 按当前轨道和选项预估输出格式；不代表实际处理或显示帧率。
        func enhancementOutputFormat(
            for strategy: VideoEnhancementStrategy,
            frameInterpolation: Bool = false
        ) -> (width: Int, height: Int, frameRate: Double?)? {
            guard let width = systemMLCurrentVideoWidth, let height = systemMLCurrentVideoHeight,
                  width > 0, height > 0, width <= Int(Int32.max), height <= Int(Int32.max)
            else {
                return nil
            }
            var output = (width: width, height: height)
            var frameRateMultiplier = 1
            switch strategy {
            case .off:
                // P7 FEL 合成保持原片尺寸和帧率。
                break
            case .fsr:
                guard spatialSuperResolutionCurrentVideoSupported else {
                    return nil
                }
                output = fsrOutputResolution.outputSize(width: width, height: height)
            case .artCNN:
                guard spatialSuperResolutionCurrentVideoSupported else {
                    return nil
                }
                output = (width * 2, height * 2)
            case .anime4k:
                // 与 Anime4KHostEngine 的目标边界及向上取偶数规则一致。
                output = Self.enhancementOutputSize(
                    width: width, height: height,
                    maxWidth: anime4kOutputResolution.maxWidth,
                    maxHeight: anime4kOutputResolution.maxHeight,
                    evenDimensions: true
                )
            case .metalFX:
                output = Self.enhancementOutputSize(
                    width: width, height: height,
                    maxWidth: metalFXOutputResolution.maxWidth,
                    maxHeight: metalFXOutputResolution.maxHeight,
                    evenDimensions: false
                )
            case .systemML where frameInterpolation:
                frameRateMultiplier = systemMLInterpolatedFrames + 1
            case .systemML:
                #if !targetEnvironment(simulator)
                    guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *),
                          let scale = systemMLSupportedScaleFactorsForPicker.min(by: {
                              abs($0 - systemMLSuperResolutionScale) < abs($1 - systemMLSuperResolutionScale)
                          })
                    else {
                        return nil
                    }
                    // 使用 VT 配置给出的实际缓冲尺寸，避免猜测非整数倍率的取整方式。
                    let attributes = VTLowLatencySuperResolutionScalerConfiguration(
                        frameWidth: width, frameHeight: height, scaleFactor: Float(scale)
                    ).destinationPixelBufferAttributes
                    guard let outputWidth = attributes[kCVPixelBufferWidthKey as String] as? Int,
                          let outputHeight = attributes[kCVPixelBufferHeightKey as String] as? Int,
                          outputWidth > 0, outputHeight > 0
                    else {
                        return nil
                    }
                    output = (outputWidth, outputHeight)
                #else
                    return nil
                #endif
            case .rife,
                 .metalFXInterpolation:
                frameRateMultiplier = 2
            }
            let frameRate = enhancementCurrentVideoFrameRate.flatMap { fps -> Double? in
                guard fps.isFinite, fps > 0 else {
                    return nil
                }
                return Double(fps) * Double(frameRateMultiplier)
            }
            return (output.width, output.height, frameRate)
        }

        private static func enhancementOutputSize(
            width: Int, height: Int, maxWidth: Int, maxHeight: Int, evenDimensions: Bool
        ) -> (width: Int, height: Int) {
            let scale = min(Double(maxWidth) / Double(width), Double(maxHeight) / Double(height))
            guard scale > 1 else {
                return (width, height)
            }
            let rounding: FloatingPointRoundingRule = evenDimensions ? .toNearestOrAwayFromZero : .down
            let outputWidth = max(width, Int((Double(width) * scale).rounded(rounding)))
            let outputHeight = max(height, Int((Double(height) * scale).rounded(rounding)))
            return (
                outputWidth + (evenDimensions ? outputWidth % 2 : 0),
                outputHeight + (evenDimensions ? outputHeight % 2 : 0)
            )
        }

        /// 每次开始播放新视频时调用：视频增强按“每个视频独立”重置为默认关闭，避免上一部视频的设置泄漏到下一部。
        func resetVideoEnhancementForNewVideoSession() {
            runtimeScheduler.cancel()
            suppressRuntimeCallback = true
            defer { suppressRuntimeCallback = false }
            cancelEnhancementStartup()
            dolbyVisionP7SectionVisible = false
            // Reset availability gates first.
            anime4kSectionVisible = false
            systemMLCurrentVideoInRange = false
            metalFXInterpolationSectionVisible = false
            metalFXSectionVisible = false
            rifeSectionVisible = false
            #if canImport(RifeMetal) && !os(tvOS)
                currentRifeTier = nil
            #endif
            rifeTierPreference = .auto
            systemMLCurrentVideoWidth = nil
            systemMLCurrentVideoHeight = nil
            enhancementCurrentVideoFrameRate = nil
            enhancementCurrentVideoIsHDR = false
            enhancementCurrentVideoHasDolbyVisionConfig = false

            // Reset toggles to defaults (per-session, default off).
            anime4kABCompare = false
            anime4kPreset = .modeAFast
            anime4kOutputResolution = .resolution2K

            systemMLABCompare = false
            systemMLInterpolatedFrames = 1
            systemMLQualityInterpolation = false
            systemMLSuperResolutionScale = 2.0
            metalFXOutputResolution = .resolution2K
            metalFXABCompare = false

            fsrOutputResolution = .ultraHD
            fsrSharpness = .medium
            fsrABCompare = false
            artCNNABCompare = false

            // Strategy setter will also apply mutual exclusion and disable SystemML/Anime4K toggles.
            videoEnhancementStrategy = .off
        }

        /// Anime4K 允许的输入像素数量上限（1080p），仅当当前视频像素数不超过此值时才显示并允许开启 Anime4K。
        static let anime4KMaxInputPixels: Int = 1920 * 1080

        /// 判断当前视频的像素数量是否在 Anime4K 适配范围内（不超过 1080p 像素数即可适配超分）。
        static func isVideoPixelCountInAnime4KRange(width: Int, height: Int) -> Bool {
            guard width > 0, height > 0 else {
                return false
            }
            let pixels = width * height
            return pixels <= anime4KMaxInputPixels
        }

        /// MetalFX 补帧已验证 4K 实时处理，取消 1080p 总像素门槛；保留单边限制，避免极端尺寸输入。
        nonisolated static func isVideoResolutionInMetalFXInterpolationRange(width: Int, height: Int) -> Bool {
            guard width > 0, height > 0 else {
                return false
            }
            return width <= 4096 && height <= 4096
        }

        static func isVideoResolutionInRifeRange(width: Int, height: Int) -> Bool {
            isVideoResolutionBelow4KInterpolationLimit(width: width, height: height)
        }

        /// 4K 实测 VT 速度档初始化失败，质量档及 RIFE Fast 也无法持续补齐，暂不开放 UHD 及以上像素量。
        /// 这是当前产品准入门槛，不代表系统 API 的硬性尺寸上限；低于门槛也不保证所有设备均可实时处理。
        nonisolated static func isVideoResolutionBelow4KInterpolationLimit(width: Int, height: Int) -> Bool {
            guard width > 0, height > 0 else {
                return false
            }
            // 使用除法比较，避免异常轨道尺寸相乘溢出。
            return width <= (3840 * 2160 - 1) / height
        }

        /// 判断当前视频是否允许开启 MetalFX 超分。
        /// 当前先只要求视频分辨率有效；真正的设备能力由 `metalFXSuperResolutionSupported` 控制。
        static func isVideoResolutionInMetalFXRange(width: Int, height: Int) -> Bool {
            guard width > 0, height > 0 else {
                return false
            }
            return !metalFXSupportedOutputResolutions(forWidth: width, height: height).isEmpty
        }

        /// 判断给定分辨率是否可用系统 VT（插帧或超分任一可用）。
        static func isVideoResolutionInSystemMLRange(width: Int, height: Int) -> Bool {
            isVideoResolutionInVTFrameInterpolationRange(width: width, height: height)
                || isVideoResolutionInVTSuperResolutionRange(width: width, height: height)
        }

        /// 判断给定分辨率是否在 VT 超分支持范围内（min/max 由系统接口给出）。
        static func isVideoResolutionInVTSuperResolutionRange(width: Int, height: Int) -> Bool {
            #if targetEnvironment(simulator)
                return false
            #else
                guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *),
                      let minDim = VTLowLatencySuperResolutionScalerConfiguration.minimumDimensions,
                      let maxDim = VTLowLatencySuperResolutionScalerConfiguration.maximumDimensions,
                      VTLowLatencySuperResolutionScalerConfiguration.isSupported,
                      width >= Int(minDim.width), height >= Int(minDim.height),
                      width <= Int(maxDim.width), height <= Int(maxDim.height)
                else {
                    return false
                }
                return !systemMLSupportedScaleFactors(forWidth: width, height: height).isEmpty
            #endif
        }

        /// 判断给定分辨率是否允许开启 VT 补帧，速度和质量档共用产品像素门槛。
        /// VT 没有像超分那样的公开 min/max 分辨率限制，配置创建仍由 VT 自身判断。
        static func isVideoResolutionInVTFrameInterpolationRange(width: Int, height: Int) -> Bool {
            #if targetEnvironment(simulator)
                return false
            #else
                guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *), VTLowLatencyFrameInterpolationConfiguration.isSupported else {
                    return false
                }
                return isVideoResolutionBelow4KInterpolationLimit(width: width, height: height)
            #endif
        }

        /// 根据系统支持的分辨率范围（min/max dimensions）计算超分倍率：在最小与最大分辨率下都支持的倍率取交集，保证任意在范围内的视频均可选。
        static var systemMLSupportedScaleFactors: [Double] {
            systemMLSupportedScaleFactors(forWidth: nil, height: nil)
        }

        static func metalFXResolvedOutputSize(
            width: Int,
            height: Int,
            targetResolution: MetalFXOutputResolution
        ) -> (width: Int, height: Int) {
            guard width > 0, height > 0 else {
                return (0, 0)
            }
            let ratio = min(
                Double(targetResolution.maxWidth) / Double(width),
                Double(targetResolution.maxHeight) / Double(height)
            )
            guard ratio > 1.0 else {
                return (width, height)
            }
            return (
                width: Int((Double(width) * ratio).rounded(.down)),
                height: Int((Double(height) * ratio).rounded(.down))
            )
        }

        static func metalFXSupportedOutputResolutions(
            forWidth width: Int?,
            height: Int?
        ) -> [MetalFXOutputResolution] {
            guard let width, let height, width > 0, height > 0 else {
                return MetalFXOutputResolution.allCases
            }
            return MetalFXOutputResolution.allCases.filter { resolution in
                let output = metalFXResolvedOutputSize(
                    width: width,
                    height: height,
                    targetResolution: resolution
                )
                return output.width > width || output.height > height
            }
        }

        var metalFXSupportedOutputResolutionsForCurrentVideo: [MetalFXOutputResolution] {
            Self.metalFXSupportedOutputResolutions(
                forWidth: systemMLCurrentVideoWidth,
                height: systemMLCurrentVideoHeight
            )
        }

        func clampMetalFXOutputResolutionToCurrentVideoIfNeeded() {
            let supported = metalFXSupportedOutputResolutionsForCurrentVideo
            guard !supported.isEmpty else {
                return
            }
            if !supported.contains(metalFXOutputResolution) {
                metalFXOutputResolution = supported.first ?? .resolution2K
            }
        }

        /// 按当前或指定分辨率返回系统支持的超分倍率。有 width/height 时用该分辨率下 VT 支持倍率；否则用 min/max 交集作为 fallback。
        static func systemMLSupportedScaleFactors(forWidth width: Int?, height: Int?) -> [Double] {
            #if targetEnvironment(simulator)
                return []
            #else
                guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *), VTLowLatencySuperResolutionScalerConfiguration.isSupported else {
                    return []
                }
                if let w = width, let h = height {
                    guard w > 0, h > 0 else {
                        return []
                    }
                    let supported = VTLowLatencySuperResolutionScalerConfiguration.supportedScaleFactors(
                        frameWidth: w,
                        frameHeight: h
                    )
                    return supported.sorted().map { Double($0) }
                }
                guard let minDim = VTLowLatencySuperResolutionScalerConfiguration.minimumDimensions,
                      let maxDim = VTLowLatencySuperResolutionScalerConfiguration.maximumDimensions
                else {
                    return []
                }
                let atMin = Set(
                    VTLowLatencySuperResolutionScalerConfiguration.supportedScaleFactors(
                        frameWidth: Int(minDim.width),
                        frameHeight: Int(minDim.height)
                    )
                )
                let atMax = Set(
                    VTLowLatencySuperResolutionScalerConfiguration.supportedScaleFactors(
                        frameWidth: Int(maxDim.width),
                        frameHeight: Int(maxDim.height)
                    )
                )
                let intersection = atMin.intersection(atMax).sorted()
                return intersection.map { Double($0) }
            #endif
        }

        #if canImport(RifeMetal) && !os(tvOS)
            var rifeAutoTier: RifeQualityTier {
                guard let width = systemMLCurrentVideoWidth,
                      let height = systemMLCurrentVideoHeight
                else {
                    return .balanced
                }
                let pixels = width * height
                if pixels <= 1280 * 720 {
                    return .hq
                } else if pixels <= 2560 * 1440 {
                    return .balanced
                } else {
                    return .fast
                }
            }

            @Published var currentRifeTier: RifeQualityTier?

            var resolvedRifeTier: RifeQualityTier {
                switch rifeTierPreference {
                case .auto: rifeAutoTier
                case .hq: .hq
                case .balanced: .balanced
                case .fast: .fast
                }
            }

            var rifeAdaptiveEnabled: Bool {
                rifeTierPreference == .auto
            }

            var rifeAutoTierDisplayName: String {
                let tier = currentRifeTier ?? resolvedRifeTier
                switch tier {
                case .hq: return "HQ"
                case .balanced: return "Balanced"
                case .fast: return "Fast"
                }
            }
        #endif
    #endif
}

#if canImport(Metal)
    private extension PlayerEnhancementModel {
        func clampStrategyToAvailability(_ strategy: VideoEnhancementStrategy) -> VideoEnhancementStrategy {
            switch strategy {
            case .fsr,
                 .artCNN:
                spatialSuperResolutionCurrentVideoSupported ? strategy : .off
            case .anime4k where !anime4kSectionVisible:
                .off
            case .systemML where !systemMLEnhancementSupported:
                .off
            case .systemML where !systemMLCurrentVideoInRange:
                .off
            case .metalFXInterpolation where !metalFXInterpolationSectionVisible:
                .off
            case .rife where !rifeSectionVisible:
                .off
            case .metalFX where !metalFXSectionVisible:
                .off
            default:
                strategy
            }
        }

        func applyMutualExclusion(for strategy: VideoEnhancementStrategy) {
            switch strategy {
            case .fsr,
                 .artCNN:
                anime4kEnabled = false
                metalFXSuperResolutionEnabled = false
                systemMLSuperResolutionEnabled = false
                systemMLFrameInterpolationEnabled = false
            case .anime4k:
                metalFXSuperResolutionEnabled = false
                systemMLSuperResolutionEnabled = false
                systemMLFrameInterpolationEnabled = false
                anime4kEnabled = true
            case .systemML:
                anime4kEnabled = false
                metalFXSuperResolutionEnabled = false
                if !systemMLSuperResolutionEnabled, !systemMLFrameInterpolationEnabled {
                    if systemMLCurrentVideoSupportsFrameInterpolation {
                        systemMLFrameInterpolationEnabled = true
                    } else if systemMLCurrentVideoSupportsSuperResolution {
                        systemMLSuperResolutionEnabled = true
                    }
                }
            case .metalFXInterpolation:
                anime4kEnabled = false
                metalFXSuperResolutionEnabled = false
                systemMLSuperResolutionEnabled = false
                systemMLFrameInterpolationEnabled = false
            case .rife:
                anime4kEnabled = false
                metalFXSuperResolutionEnabled = false
                systemMLSuperResolutionEnabled = false
                systemMLFrameInterpolationEnabled = false
            case .metalFX:
                anime4kEnabled = false
                systemMLSuperResolutionEnabled = false
                systemMLFrameInterpolationEnabled = false
                metalFXSuperResolutionEnabled = true
            case .off:
                anime4kEnabled = false
                metalFXSuperResolutionEnabled = false
                systemMLSuperResolutionEnabled = false
                systemMLFrameInterpolationEnabled = false
            }
        }
    }
#endif
