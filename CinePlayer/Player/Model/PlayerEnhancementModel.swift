import Foundation
import SwiftUI
import Combine

#if !os(tvOS)
#if !targetEnvironment(simulator)
@preconcurrency import VideoToolbox
#endif

enum VideoEnhancementStrategy: String, CaseIterable, Identifiable {
    case off
    case anime4k
    case systemML
    case opticalFlow

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off: "关闭"
        case .anime4k: "Anime4K"
        case .systemML: "系统 VT"
        case .opticalFlow: "光流补帧"
        }
    }
}

enum Anime4KPreset: String, CaseIterable, Identifiable {
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

enum Anime4KOutputResolution: String, CaseIterable, Identifiable {
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
        systemMLScaleBy = max(1, min(2, Self.loadInt(
            forKey: StorageKey.systemMLScaleBy,
            defaultValue: Self.loadBool(
                forKey: StorageKey.systemMLSuperResolutionEnabled,
                defaultValue: true
            ) ? 2 : 1
        )))
        systemMLABCompare = Self.loadBool(
            forKey: StorageKey.systemMLABCompare,
            defaultValue: false
        )
        suppressRuntimeCallback = false
    }

    @Published var anime4kSectionVisible: Bool = false
    @Published var opticalFlowSectionVisible: Bool = false
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

    @Published var systemMLScaleBy: Int = 1 {
        didSet {
            let clamped = max(1, min(2, systemMLScaleBy))
            if clamped != systemMLScaleBy {
                systemMLScaleBy = clamped
                return
            }
            UserDefaults.standard.set(systemMLScaleBy, forKey: StorageKey.systemMLScaleBy)
            notifyRuntimeConfigChanged(resetPipeline: false)
        }
    }

    @Published var systemMLABCompare: Bool = false {
        didSet {
            UserDefaults.standard.set(systemMLABCompare, forKey: StorageKey.systemMLABCompare)
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

    func updateAvailabilityForCurrentVideo(width: Int?, height: Int?) {
        guard let width, let height, width > 0, height > 0 else {
            anime4kSectionVisible = false
            opticalFlowSectionVisible = false
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
        anime4kSectionVisible = false
        systemMLCurrentVideoInRange = false
        opticalFlowSectionVisible = false
        systemMLCurrentVideoWidth = nil
        systemMLCurrentVideoHeight = nil

        anime4kABCompare = false
        anime4kPreset = .modeAFast
        anime4kOutputResolution = .resolution2K

        systemMLABCompare = false
        systemMLInterpolatedFrames = 1

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
        return isVideoResolutionInVTSuperResolutionRange(width: width, height: height)
        #endif
    }

    static var systemMLSupportedScaleFactors: [Double] {
        systemMLSupportedScaleFactors(forWidth: nil, height: nil)
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
        static let systemMLScaleBy = "systemMLScaleBy"
        static let systemMLABCompare = "systemMLABCompare"
    }

    private static func loadVideoEnhancementStrategy() -> VideoEnhancementStrategy {
        let raw = UserDefaults.standard.string(forKey: StorageKey.videoEnhancementStrategy)
        return VideoEnhancementStrategy(rawValue: raw ?? VideoEnhancementStrategy.off.rawValue) ?? .off
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
            .off
        case .systemML where !systemMLEnhancementSupported:
            .off
        case .systemML where !systemMLCurrentVideoInRange:
            .off
        case .opticalFlow where !opticalFlowSectionVisible:
            .off
        default:
            strategy
        }
    }

    private func applyMutualExclusion(for strategy: VideoEnhancementStrategy) {
        switch strategy {
        case .anime4k:
            systemMLSuperResolutionEnabled = false
            systemMLFrameInterpolationEnabled = false
            anime4kEnabled = true
        case .systemML:
            anime4kEnabled = false
            if !systemMLSuperResolutionEnabled, !systemMLFrameInterpolationEnabled {
                if systemMLCurrentVideoSupportsFrameInterpolation {
                    systemMLFrameInterpolationEnabled = true
                } else if systemMLCurrentVideoSupportsSuperResolution {
                    systemMLSuperResolutionEnabled = true
                }
            }
        case .opticalFlow:
            anime4kEnabled = false
            systemMLSuperResolutionEnabled = false
            systemMLFrameInterpolationEnabled = false
        case .off:
            anime4kEnabled = false
            systemMLSuperResolutionEnabled = false
            systemMLFrameInterpolationEnabled = false
        }
    }
}
#endif
