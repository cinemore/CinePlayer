import Foundation
import SwiftUI
import Combine

#if !os(tvOS)
import Metal
#if os(macOS)
import RifeMetal
#endif
#if canImport(MetalFX)
@preconcurrency import MetalFX
#endif
#if !targetEnvironment(simulator)
@preconcurrency import VideoToolbox
#endif

nonisolated enum VideoEnhancementStrategy: String, CaseIterable, Identifiable {
    case off
    case anime4k
    case systemML
    case opticalFlow
    case rife
    case metalFX

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "关闭"
        case .anime4k: "Anime4K"
        case .systemML: "系统 VT"
        case .opticalFlow: "光流补帧"
        case .rife: "RIFE 补帧"
        case .metalFX: "MetalFX 超分"
        }
    }
}

nonisolated enum Anime4KPreset: String, CaseIterable, Identifiable {
    case modeAFast
    case modeBFast
    case modeCFast
    case modeAAFast
    case modeBBFast
    case modeCAFast
    case modeAHQ
    case modeBHQ
    case modeCHQ
    case modeAAHQ
    case modeBBHQ
    case modeCAHQ

    var id: String { rawValue }

    static var availablePresets: [Anime4KPreset] {
        #if os(iOS)
        return [.modeAFast, .modeBFast, .modeCFast, .modeAAFast, .modeBBFast, .modeCAFast]
        #else
        return Anime4KPreset.allCases
        #endif
    }

    var displayName: String {
        switch self {
        case .modeAFast: "Mode A (Fast)"
        case .modeBFast: "Mode B (Fast)"
        case .modeCFast: "Mode C (Fast)"
        case .modeAAFast: "Mode A+A (Fast)"
        case .modeBBFast: "Mode B+B (Fast)"
        case .modeCAFast: "Mode C+A (Fast)"
        case .modeAHQ: "Mode A (HQ)"
        case .modeBHQ: "Mode B (HQ)"
        case .modeCHQ: "Mode C (HQ)"
        case .modeAAHQ: "Mode A+A (HQ)"
        case .modeBBHQ: "Mode B+B (HQ)"
        case .modeCAHQ: "Mode C+A (HQ)"
        }
    }
}

nonisolated enum Anime4KOutputResolution: String, CaseIterable, Identifiable {
    case resolution2K = "2K"
    case resolution4K = "4K"

    var id: String { rawValue }

    var displayName: String { rawValue }

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

nonisolated enum MetalFXOutputResolution: String, CaseIterable, Identifiable {
    case resolution2K = "2K"
    case resolution4K = "4K"

    var id: String { rawValue }

    var displayName: String { rawValue }

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

@MainActor
final class PlayerEnhancementModel: ObservableObject {
    static let shared = PlayerEnhancementModel()

    var onRuntimeConfigChanged: ((Bool) -> Void)?
    private var suppressRuntimeCallback = true

    private init() {
        videoEnhancementStrategy = Self.loadVideoEnhancementStrategy()
        systemMLSuperResolutionEnabled = Self.loadBool(
            forKey: StorageKey.systemMLSuperResolutionEnabled,
            defaultValue: true
        )
        let storedScale = Self.loadDouble(
            forKey: StorageKey.systemMLSuperResolutionScale,
            defaultValue: 2.0
        )
        systemMLSuperResolutionScale = Self.systemMLSupportedScaleFactors.min(by: {
            abs($0 - storedScale) < abs($1 - storedScale)
        }) ?? 2.0
        systemMLFrameInterpolationEnabled = Self.loadBool(
            forKey: StorageKey.systemMLFrameInterpolationEnabled,
            defaultValue: false
        )
        systemMLInterpolatedFrames = max(1, min(3, Self.loadInt(
            forKey: StorageKey.systemMLInterpolatedFrames,
            defaultValue: 1
        )))
        systemMLABCompare = Self.loadBool(
            forKey: StorageKey.systemMLABCompare,
            defaultValue: false
        )
        metalFXSuperResolutionEnabled = Self.loadBool(
            forKey: StorageKey.metalFXSuperResolutionEnabled,
            defaultValue: false
        )
        metalFXOutputResolution = Self.loadMetalFXOutputResolution()
        metalFXABCompare = Self.loadBool(
            forKey: StorageKey.metalFXABCompare,
            defaultValue: false
        )
        suppressRuntimeCallback = false
    }

    @Published var anime4kSectionVisible: Bool = false
    @Published var opticalFlowSectionVisible: Bool = false
    @Published var metalFXSectionVisible: Bool = false
    @Published var rifeSectionVisible: Bool = false
    @Published var anime4kEnabled: Bool = false {
        didSet { notifyRuntimeConfigChanged(resetPipeline: false) }
    }
    @Published var anime4kPreset: Anime4KPreset = .modeAFast {
        didSet { notifyRuntimeConfigChanged(resetPipeline: false) }
    }
    @Published var anime4kOutputResolution: Anime4KOutputResolution = .resolution2K {
        didSet { notifyRuntimeConfigChanged(resetPipeline: true) }
    }
    @Published var anime4kABCompare: Bool = false {
        didSet { notifyRuntimeConfigChanged(resetPipeline: false) }
    }

    @Published var videoEnhancementStrategy: VideoEnhancementStrategy = .off {
        didSet {
            let clamped = clampStrategyToAvailability(videoEnhancementStrategy)
            if clamped != videoEnhancementStrategy {
                videoEnhancementStrategy = clamped
                return
            }
            UserDefaults.standard.set(
                videoEnhancementStrategy.rawValue,
                forKey: StorageKey.videoEnhancementStrategy
            )
            applyMutualExclusion(for: videoEnhancementStrategy)
            notifyRuntimeConfigChanged(resetPipeline: true)
        }
    }

    @Published var systemMLSuperResolutionEnabled: Bool = true {
        didSet {
            if systemMLSuperResolutionEnabled, !systemMLSuperResolutionSupported {
                systemMLSuperResolutionEnabled = false
                return
            }
            if systemMLSuperResolutionEnabled, systemMLFrameInterpolationEnabled {
                systemMLFrameInterpolationEnabled = false
            }
            UserDefaults.standard.set(
                systemMLSuperResolutionEnabled,
                forKey: StorageKey.systemMLSuperResolutionEnabled
            )
            notifyRuntimeConfigChanged(resetPipeline: false)
        }
    }

    @Published var systemMLSuperResolutionScale: Double = 2.0 {
        didSet {
            let supported = Self.systemMLSupportedScaleFactors(
                forWidth: systemMLCurrentVideoWidth,
                height: systemMLCurrentVideoHeight
            )
            if supported.contains(where: { abs($0 - systemMLSuperResolutionScale) < 0.001 }) {
                UserDefaults.standard.set(
                    systemMLSuperResolutionScale,
                    forKey: StorageKey.systemMLSuperResolutionScale
                )
                notifyRuntimeConfigChanged(resetPipeline: false)
            } else if let nearest = supported.min(by: {
                abs($0 - systemMLSuperResolutionScale) < abs($1 - systemMLSuperResolutionScale)
            }) {
                systemMLSuperResolutionScale = nearest
            }
        }
    }

    @Published var systemMLFrameInterpolationEnabled: Bool = false {
        didSet {
            if systemMLFrameInterpolationEnabled, !systemMLFrameInterpolationSupported {
                systemMLFrameInterpolationEnabled = false
                return
            }
            if systemMLFrameInterpolationEnabled, systemMLSuperResolutionEnabled {
                systemMLSuperResolutionEnabled = false
            }
            UserDefaults.standard.set(
                systemMLFrameInterpolationEnabled,
                forKey: StorageKey.systemMLFrameInterpolationEnabled
            )
            notifyRuntimeConfigChanged(resetPipeline: false)
        }
    }

    @Published var systemMLInterpolatedFrames: Int = 1 {
        didSet {
            let clamped = max(1, min(3, systemMLInterpolatedFrames))
            if clamped != systemMLInterpolatedFrames {
                systemMLInterpolatedFrames = clamped
                return
            }
            UserDefaults.standard.set(
                systemMLInterpolatedFrames,
                forKey: StorageKey.systemMLInterpolatedFrames
            )
            notifyRuntimeConfigChanged(resetPipeline: false)
        }
    }

    @Published var systemMLABCompare: Bool = false {
        didSet {
            UserDefaults.standard.set(systemMLABCompare, forKey: StorageKey.systemMLABCompare)
            notifyRuntimeConfigChanged(resetPipeline: false)
        }
    }

    @Published var metalFXSuperResolutionEnabled: Bool = false {
        didSet {
            if metalFXSuperResolutionEnabled, !metalFXSuperResolutionSupported {
                metalFXSuperResolutionEnabled = false
                return
            }
            UserDefaults.standard.set(
                metalFXSuperResolutionEnabled,
                forKey: StorageKey.metalFXSuperResolutionEnabled
            )
            notifyRuntimeConfigChanged(resetPipeline: false)
        }
    }

    @Published var metalFXOutputResolution: MetalFXOutputResolution = .resolution2K {
        didSet {
            let supported = metalFXSupportedOutputResolutionsForCurrentVideo
            if supported.isEmpty || supported.contains(metalFXOutputResolution) {
                UserDefaults.standard.set(
                    metalFXOutputResolution.rawValue,
                    forKey: StorageKey.metalFXOutputResolution
                )
                notifyRuntimeConfigChanged(resetPipeline: true)
            } else if let fallback = supported.first {
                metalFXOutputResolution = fallback
            }
        }
    }

    @Published var metalFXABCompare: Bool = false {
        didSet {
            UserDefaults.standard.set(metalFXABCompare, forKey: StorageKey.metalFXABCompare)
            notifyRuntimeConfigChanged(resetPipeline: false)
        }
    }

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

    var systemMLEnhancementSupported: Bool {
        systemMLFrameInterpolationSupported || systemMLSuperResolutionSupported
    }

    var metalFXSuperResolutionSupported: Bool {
        #if canImport(MetalFX)
        guard #available(iOS 16.0, macOS 13.0, *) else {
            return false
        }
        guard let device = MTLCreateSystemDefaultDevice() else {
            return false
        }
        return MTLFXSpatialScalerDescriptor.supportsDevice(device)
        #else
        return false
        #endif
    }

    @Published var systemMLCurrentVideoInRange: Bool = false
    @Published var systemMLCurrentVideoWidth: Int?
    @Published var systemMLCurrentVideoHeight: Int?

    var systemMLCurrentVideoSupportsFrameInterpolation: Bool {
        guard let width = systemMLCurrentVideoWidth,
              let height = systemMLCurrentVideoHeight
        else {
            return false
        }
        return Self.isVideoResolutionInVTFrameInterpolationRange(width: width, height: height)
    }

    var systemMLCurrentVideoSupportsSuperResolution: Bool {
        guard let width = systemMLCurrentVideoWidth,
              let height = systemMLCurrentVideoHeight
        else {
            return false
        }
        return Self.isVideoResolutionInVTSuperResolutionRange(width: width, height: height)
    }

    var systemMLSupportedScaleFactorsForPicker: [Double] {
        Self.systemMLSupportedScaleFactors(
            forWidth: systemMLCurrentVideoWidth,
            height: systemMLCurrentVideoHeight
        )
    }

    var metalFXSupportedOutputResolutionsForCurrentVideo: [MetalFXOutputResolution] {
        Self.metalFXSupportedOutputResolutions(
            forWidth: systemMLCurrentVideoWidth,
            height: systemMLCurrentVideoHeight
        )
    }

    func updateAvailabilityForCurrentVideo(width: Int?, height: Int?, isHDR: Bool = false) {
        guard let width, let height, width > 0, height > 0 else {
            anime4kSectionVisible = false
            opticalFlowSectionVisible = false
            metalFXSectionVisible = false
            rifeSectionVisible = false
            systemMLCurrentVideoInRange = false
            setSystemMLCurrentVideoDimensions(width: nil, height: nil)
            if videoEnhancementStrategy != .off {
                videoEnhancementStrategy = .off
            }
            return
        }

        anime4kSectionVisible = Self.isVideoPixelCountInAnime4KRange(width: width, height: height)
        opticalFlowSectionVisible = Self.isVideoResolutionInOpticalFlowRange(width: width, height: height)
        systemMLCurrentVideoInRange = Self.isVideoResolutionInSystemMLRange(width: width, height: height)
        setSystemMLCurrentVideoDimensions(width: width, height: height)
        metalFXSectionVisible =
            metalFXSuperResolutionSupported
            && Self.isVideoResolutionInMetalFXRange(width: width, height: height)
        // RIFE pipeline is BGRA8 end-to-end; HDR sources would be tonemapped to SDR
        // and lose their dynamic range. Block the toggle entirely on HDR videos
        // rather than silently downgrading.
        rifeSectionVisible = !isHDR && Self.isVideoResolutionInRifeRange(width: width, height: height)
        clampMetalFXOutputResolutionToCurrentVideoIfNeeded()

        let clamped = clampStrategyToAvailability(videoEnhancementStrategy)
        if clamped != videoEnhancementStrategy {
            videoEnhancementStrategy = clamped
        }
    }

    func setSystemMLCurrentVideoDimensions(width: Int?, height: Int?) {
        systemMLCurrentVideoWidth = width
        systemMLCurrentVideoHeight = height
        let supported = Self.systemMLSupportedScaleFactors(forWidth: width, height: height)
        if !supported.contains(where: { abs($0 - systemMLSuperResolutionScale) < 0.001 }),
           let nearest = supported.min(by: {
               abs($0 - systemMLSuperResolutionScale) < abs($1 - systemMLSuperResolutionScale)
           })
        {
            systemMLSuperResolutionScale = nearest
        }
    }

    func resetVideoEnhancementForNewVideoSession() {
        let previousSuppressState = suppressRuntimeCallback
        suppressRuntimeCallback = true
        defer { suppressRuntimeCallback = previousSuppressState }

        anime4kSectionVisible = false
        systemMLCurrentVideoInRange = false
        opticalFlowSectionVisible = false
        metalFXSectionVisible = false
        rifeSectionVisible = false
        currentRifeTier = nil
        systemMLCurrentVideoWidth = nil
        systemMLCurrentVideoHeight = nil

        anime4kABCompare = false
        anime4kPreset = .modeAFast
        anime4kOutputResolution = .resolution2K

        systemMLABCompare = false
        systemMLInterpolatedFrames = 1
        metalFXOutputResolution = .resolution2K
        metalFXABCompare = false

        videoEnhancementStrategy = .off
    }

    static let anime4KMaxInputPixels: Int = 1920 * 1080

    static func isVideoPixelCountInAnime4KRange(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else {
            return false
        }
        return width * height < anime4KMaxInputPixels
    }

    static func isVideoResolutionInOpticalFlowRange(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else {
            return false
        }
        return width <= 1920 && height <= 1080
    }

    static func isVideoResolutionInRifeRange(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else { return false }
        return width * height <= 3840 * 2160
    }

    static func isVideoResolutionInMetalFXRange(width: Int, height: Int) -> Bool {
        guard width > 0, height > 0 else {
            return false
        }
        return !metalFXSupportedOutputResolutions(forWidth: width, height: height).isEmpty
    }

    static func isVideoResolutionInSystemMLRange(width: Int, height: Int) -> Bool {
        isVideoResolutionInVTFrameInterpolationRange(width: width, height: height)
            || isVideoResolutionInVTSuperResolutionRange(width: width, height: height)
    }

    static func isVideoResolutionInVTSuperResolutionRange(width: Int, height: Int) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
            return false
        }
        guard let minDim = VTLowLatencySuperResolutionScalerConfiguration.minimumDimensions,
              let maxDim = VTLowLatencySuperResolutionScalerConfiguration.maximumDimensions
        else {
            return false
        }
        let w = Int32(width)
        let h = Int32(height)
        return w >= minDim.width && h >= minDim.height && w <= maxDim.width && h <= maxDim.height
        #endif
    }

    static func isVideoResolutionInVTFrameInterpolationRange(width: Int, height: Int) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
            return false
        }
        guard VTLowLatencyFrameInterpolationConfiguration.isSupported else {
            return false
        }
        return width > 0 && height > 0
        #endif
    }

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

    func clampMetalFXOutputResolutionToCurrentVideoIfNeeded() {
        let supported = metalFXSupportedOutputResolutionsForCurrentVideo
        guard !supported.isEmpty else {
            return
        }
        if !supported.contains(metalFXOutputResolution) {
            metalFXOutputResolution = supported.first ?? .resolution2K
        }
    }

    static func systemMLSupportedScaleFactors(forWidth width: Int?, height: Int?) -> [Double] {
        #if targetEnvironment(simulator)
        return [2.0]
        #else
        guard #available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *) else {
            return [2.0]
        }
        if let w = width, let h = height, w > 0, h > 0 {
            let supported = VTLowLatencySuperResolutionScalerConfiguration.supportedScaleFactors(
                frameWidth: w,
                frameHeight: h
            )
            return supported.isEmpty ? [2.0] : supported.sorted().map { Double($0) }
        }
        guard let minDim = VTLowLatencySuperResolutionScalerConfiguration.minimumDimensions,
              let maxDim = VTLowLatencySuperResolutionScalerConfiguration.maximumDimensions
        else {
            return [2.0]
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
        if intersection.isEmpty {
            return atMin.isEmpty ? [2.0] : atMin.sorted().map { Double($0) }
        }
        return intersection.map { Double($0) }
        #endif
    }

    private func notifyRuntimeConfigChanged(resetPipeline: Bool) {
        guard !suppressRuntimeCallback else {
            return
        }
        onRuntimeConfigChanged?(resetPipeline)
    }

    private enum StorageKey {
        static let videoEnhancementStrategy = "videoEnhancementStrategy"
        static let systemMLSuperResolutionEnabled = "systemMLSuperResolutionEnabled"
        static let systemMLSuperResolutionScale = "systemMLSuperResolutionScale"
        static let systemMLFrameInterpolationEnabled = "systemMLFrameInterpolationEnabled"
        static let systemMLInterpolatedFrames = "systemMLInterpolatedFrames"
        static let systemMLABCompare = "systemMLABCompare"
        static let metalFXSuperResolutionEnabled = "metalFXSuperResolutionEnabled"
        static let metalFXOutputResolution = "metalFXOutputResolution"
        static let metalFXABCompare = "metalFXABCompare"
    }

    private static func loadVideoEnhancementStrategy() -> VideoEnhancementStrategy {
        let raw = UserDefaults.standard.string(forKey: StorageKey.videoEnhancementStrategy)
        let loaded =
            VideoEnhancementStrategy(rawValue: raw ?? VideoEnhancementStrategy.off.rawValue) ?? .off
        return loaded
    }

    private static func loadBool(forKey key: String, defaultValue: Bool) -> Bool {
        if let stored = UserDefaults.standard.object(forKey: key) as? Bool {
            return stored
        }
        return defaultValue
    }

    private static func loadDouble(forKey key: String, defaultValue: Double) -> Double {
        if let stored = UserDefaults.standard.object(forKey: key) as? Double {
            return stored
        }
        return defaultValue
    }

    private static func loadInt(forKey key: String, defaultValue: Int) -> Int {
        if let stored = UserDefaults.standard.object(forKey: key) as? Int {
            return stored
        }
        return defaultValue
    }

    private func clampStrategyToAvailability(_ strategy: VideoEnhancementStrategy) -> VideoEnhancementStrategy {
        switch strategy {
        case .anime4k where !anime4kSectionVisible:
            return .off
        case .systemML where !systemMLEnhancementSupported:
            return .off
        case .systemML where !systemMLCurrentVideoInRange:
            return .off
        case .opticalFlow where !opticalFlowSectionVisible:
            return .off
        case .rife where !rifeSectionVisible:
            return .off
        case .metalFX where !metalFXSectionVisible:
            return .off
        default:
            return strategy
        }
    }

    private func applyMutualExclusion(for strategy: VideoEnhancementStrategy) {
        switch strategy {
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
        case .opticalFlow:
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

    private static func loadMetalFXOutputResolution() -> MetalFXOutputResolution {
        let raw = UserDefaults.standard.string(forKey: StorageKey.metalFXOutputResolution)
        return MetalFXOutputResolution(
            rawValue: raw ?? MetalFXOutputResolution.resolution2K.rawValue
        ) ?? .resolution2K
    }

    #if os(macOS)
    /// Initial tier picked from current video resolution. The adapter may downgrade
    /// at runtime if measured inference time exceeds the source-fps budget; the
    /// active tier is reflected in `currentRifeTier` (published by the adapter
    /// callback).
    var rifeAutoTier: RifeQualityTier {
        guard let w = systemMLCurrentVideoWidth,
              let h = systemMLCurrentVideoHeight else {
            return .balanced
        }
        let pixels = w * h
        // Conservative initial picks calibrated for 30 fps real-time on M-series
        // Mac. The adapter's runtime downgrade catches devices/content where these
        // are still too aggressive (e.g., M1 base, 60 fps source).
        if pixels <= 1280 * 720 { return .hq }
        else if pixels <= 2560 * 1440 { return .balanced }
        else { return .fast }
    }

    /// Tier currently in use by the adapter. Mirrors `rifeAutoTier` until the
    /// adapter auto-downgrades on perf overshoot. `nil` until the first frame is
    /// processed (footer falls back to the static `rifeAutoTier`).
    @Published var currentRifeTier: RifeQualityTier?

    var rifeAutoTierDisplayName: String {
        let tier = currentRifeTier ?? rifeAutoTier
        switch tier {
        case .hq: return "HQ"
        case .balanced: return "Balanced"
        case .fast: return "Fast"
        }
    }
    #endif
}
#endif
