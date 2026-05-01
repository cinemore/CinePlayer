#if !os(tvOS) && os(macOS)
import CinePlayerSDK
import CoreMedia
import CoreVideo
import Foundation
import Metal
import RifeMetal
@preconcurrency import VideoToolbox

/// RIFE frame interpolation adapter. Mirrors OpticalFlowFrameInterpolationAdapter's
/// shape (singleton, serial queue, pools, autorelease per frame) but delegates the
/// actual interpolation to RifeMetal's RifeInterpolator.
nonisolated final class RifeFrameInterpolationAdapter: @unchecked Sendable {
    static let shared = RifeFrameInterpolationAdapter()

    private let queue = DispatchQueue(
        label: "cn.com.cinemore.rife.adapter",
        qos: .userInitiated
    )

    // RIFE state — rebuilt when (width, height, tier) changes.
    private var interpolator: RifeInterpolator?
    private var interpolatorKey: (Int, Int, RifeQualityTier)?

    // Per-resolution pixel buffer pools.
    private var outputPool: CVPixelBufferPool?
    private var outputPoolKey: (Int, Int)?
    private var bgraConversionPool: CVPixelBufferPool?
    private var bgraConversionPoolKey: (Int, Int)?
    private var pixelTransferSession: VTPixelTransferSession?

    // Adaptive tier downgrade. Caller passes a preferred tier from static
    // resolution-based logic; if measured inference time consistently exceeds
    // the source-fps budget, we downgrade (hq → balanced → fast). Never
    // upgrades — avoids tier-flapping (each switch costs a ~200ms graph rebuild).
    private var effectiveTier: RifeQualityTier?
    private var lastDims: (Int, Int)?
    private var perfSamplesMs: [Double] = []
    private var framesSinceLastSwitch: Int = 0
    private var adaptiveDowngradeEnabled: Bool = true
    private static let perfWindowSize = 30
    private static let switchCooldownFrames = 60
    private static let downgradeBudgetRatio = 0.9 // p90 > 0.9 × budget triggers downgrade

    /// Enable / disable runtime auto-downgrade. Disabled when the user picks an
    /// explicit tier — their choice is honored even if the device can't keep up.
    /// Disabling clears any prior auto-downgrade state so the next frame takes
    /// the caller-provided tier.
    nonisolated func setAdaptiveDowngradeEnabled(_ enabled: Bool) {
        queue.sync {
            adaptiveDowngradeEnabled = enabled
            if !enabled {
                effectiveTier = nil
                perfSamplesMs.removeAll(keepingCapacity: true)
                framesSinceLastSwitch = 0
            }
        }
    }

    /// Called on the queue when the adapter auto-switches tiers. Consumer
    /// (VideoPlayerModel) wires this up to update `PlayerEnhancementModel.currentRifeTier`
    /// for the UI footer.
    var onTierChanged: (@Sendable (RifeQualityTier) -> Void)?

    /// 结束会话并释放资源。
    nonisolated func endSession() {
        queue.sync {
            interpolator = nil
            interpolatorKey = nil
            outputPool = nil
            outputPoolKey = nil
            bgraConversionPool = nil
            bgraConversionPoolKey = nil
            if let session = pixelTransferSession {
                VTPixelTransferSessionInvalidate(session)
            }
            pixelTransferSession = nil
            effectiveTier = nil
            lastDims = nil
            perfSamplesMs.removeAll(keepingCapacity: true)
            framesSinceLastSwitch = 0
        }
    }

    /// Pre-build the RifeInterpolator and graph for the given dims/tier on a background
    /// thread, so the first frame doesn't pay the build cost.
    nonisolated func warmup(dimensions: CMVideoDimensions, tier: RifeQualityTier) async {
        await Task.detached(priority: .userInitiated) { [weak self] in
            self?.queue.sync {
                _ = self?.ensureInterpolatorOnQueue(
                    width: Int(dimensions.width),
                    height: Int(dimensions.height),
                    tier: tier
                )
            }
        }.value
    }

    nonisolated func processTemporal(
        previous: PreviousVideoFrameSnapshot?,
        current: VideoFrameContext,
        tier: RifeQualityTier
    ) -> VideoFrameResult {
        queue.sync {
            guard let previous, current.timestamp > previous.timestamp else {
                return .passthrough
            }
            return processTemporalOnQueue(previous: previous, current: current, tier: tier)
        }
    }

    private func processTemporalOnQueue(
        previous: PreviousVideoFrameSnapshot,
        current: VideoFrameContext,
        tier: RifeQualityTier
    ) -> VideoFrameResult {
        // autoreleasepool 强制 drain VT/CV 临时 IOSurface,避免 per-client 16384 配额上限。
        autoreleasepool {
            let totalStart = DispatchTime.now().uptimeNanoseconds
            let prevTs = previous.timestamp
            let currTs = current.timestamp
            let segmentDur = currTs - prevTs

            // 整数 timebase 1 tick/帧无法切两半,降级为 anchor 段。
            guard segmentDur >= 2 else {
                return .replaceMany([
                    GeneratedVideoFrame(pixelBuffer: current.pixelBuffer,
                                         timestamp: prevTs,
                                         duration: segmentDur)
                ])
            }

            let width = CVPixelBufferGetWidth(current.pixelBuffer)
            let height = CVPixelBufferGetHeight(current.pixelBuffer)
            guard width > 0, height > 0 else { return .passthrough }

            // Reset adaptive state on dimension change (different perf characteristics).
            let dims = (width, height)
            if lastDims.map({ $0 != dims }) ?? true {
                effectiveTier = tier
                perfSamplesMs.removeAll(keepingCapacity: true)
                framesSinceLastSwitch = 0
                lastDims = dims
            }
            let activeTier = effectiveTier ?? tier

            guard let interp = ensureInterpolatorOnQueue(width: width, height: height, tier: activeTier) else {
                return .passthrough
            }

            guard let prevBGRA = pixelBufferAsBGRAOnQueue(previous.pixelBuffer, width: width, height: height),
                  let currBGRA = pixelBufferAsBGRAOnQueue(current.pixelBuffer,  width: width, height: height) else {
                cinemoreLog(level: .debug, "[VFI-RIFE] pixelBufferAsBGRA failed")
                return .passthrough
            }

            guard let outBuffer = ensureOutputPool(width: width, height: height) else {
                cinemoreLog(level: .debug, "[VFI-RIFE] ensureOutputPool failed")
                return .passthrough
            }
            current.pixelBuffer.copyPropagatedAttachments(to: outBuffer)

            do {
                try interp.interpolate(previous: prevBGRA, current: currBGRA, output: outBuffer)
            } catch {
                cinemoreLog(level: .debug, "[VFI-RIFE] interpolate failed: \(error)")
                return .passthrough
            }

            // 两段 duration 严格相加 == segmentDur,否则时间轴错位。
            let firstDuration = segmentDur / 2
            let secondDuration = segmentDur - firstDuration
            let midTs = prevTs + firstDuration
            let generated: [GeneratedVideoFrame] = [
                GeneratedVideoFrame(pixelBuffer: outBuffer, timestamp: prevTs, duration: firstDuration),
                GeneratedVideoFrame(pixelBuffer: current.pixelBuffer, timestamp: midTs, duration: secondDuration),
            ]
            let totalMs = Double(DispatchTime.now().uptimeNanoseconds - totalStart) / 1_000_000
            cinemoreLog(
                level: .debug,
                "[VFI-RIFE] diag total=\(String(format: "%.1f", totalMs))ms tier=\(activeTier.rawValue) \(width)x\(height)"
            )

            adaptTierIfNeededOnQueue(elapsedMs: totalMs, fps: current.fps, currentTier: activeTier)
            return .replaceMany(generated)
        }
    }

    /// Single-direction adaptive tier control: downgrade hq → balanced → fast when
    /// measured p90 inference time exceeds the source-fps budget. Never upgrades —
    /// each tier change costs a ~200 ms graph rebuild stall, so flapping must be
    /// avoided. Once at fast, no further action.
    private func adaptTierIfNeededOnQueue(elapsedMs: Double, fps: Float, currentTier: RifeQualityTier) {
        guard adaptiveDowngradeEnabled else { return }
        framesSinceLastSwitch += 1
        perfSamplesMs.append(elapsedMs)
        if perfSamplesMs.count > Self.perfWindowSize {
            perfSamplesMs.removeFirst()
        }

        guard let next = currentTier.downgraded() else { return }
        guard perfSamplesMs.count >= Self.perfWindowSize,
              framesSinceLastSwitch >= Self.switchCooldownFrames,
              fps > 0.5 else { return }

        let budgetMs = 1000.0 / Double(fps)
        let sorted = perfSamplesMs.sorted()
        let p90 = sorted[Int(Double(sorted.count) * 0.9)]
        guard p90 > budgetMs * Self.downgradeBudgetRatio else { return }

        cinemoreLog(
            level: .warning,
            "[VFI-RIFE] auto-downgrade \(currentTier.rawValue) → \(next.rawValue) (p90=\(String(format: "%.1f", p90))ms budget=\(String(format: "%.1f", budgetMs))ms fps=\(fps))"
        )
        effectiveTier = next
        framesSinceLastSwitch = 0
        perfSamplesMs.removeAll(keepingCapacity: true)
        // Force RifeInterpolator rebuild on next frame with the new tier.
        interpolator = nil
        interpolatorKey = nil
        let cb = onTierChanged
        cb?(next)
    }

    // MARK: - Private (queue-confined)

    private func ensureInterpolatorOnQueue(
        width: Int,
        height: Int,
        tier: RifeQualityTier
    ) -> RifeInterpolator? {
        let key = (width, height, tier)
        if let existing = interpolator,
           let existingKey = interpolatorKey,
           existingKey == key {
            return existing
        }
        guard let modelURL = Bundle.main.url(forResource: "rife-v4.6", withExtension: "rmw") else {
            cinemoreLog(level: .debug, "[VFI-RIFE] rife-v4.6.rmw not found in bundle")
            return nil
        }
        do {
            let interp = try RifeInterpolator(
                configuration: .init(modelURL: modelURL, qualityTier: tier))
            interpolator = interp
            interpolatorKey = key
            return interp
        } catch {
            cinemoreLog(level: .debug, "[VFI-RIFE] RifeInterpolator init failed: \(error)")
            return nil
        }
    }

    private func ensureOutputPool(width: Int, height: Int) -> CVPixelBuffer? {
        let key = (width, height)
        if let existing = outputPoolKey, existing == key, let pool = outputPool {
            var buf: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess,
                  let buf else { return nil }
            return buf
        }
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        var pool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool) == kCVReturnSuccess,
              let pool else { return nil }
        outputPool = pool
        outputPoolKey = key
        var buf: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess,
              let buf else { return nil }
        return buf
    }

    private func ensureBGRAConversionBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        let key = (width, height)
        if let existing = bgraConversionPoolKey, existing == key, let pool = bgraConversionPool {
            var buf: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess,
                  let buf else { return nil }
            return buf
        }
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
        ]
        var pool: CVPixelBufferPool?
        guard CVPixelBufferPoolCreate(kCFAllocatorDefault, nil, attrs as CFDictionary, &pool) == kCVReturnSuccess,
              let pool else { return nil }
        bgraConversionPool = pool
        bgraConversionPoolKey = key
        var buf: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess,
              let buf else { return nil }
        return buf
    }

    private func pixelBufferAsBGRAOnQueue(_ buffer: CVPixelBuffer,
                                            width: Int,
                                            height: Int) -> CVPixelBuffer? {
        if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA {
            return buffer
        }
        guard let outRef = ensureBGRAConversionBuffer(width: width, height: height) else {
            return nil
        }
        if let existing = pixelTransferSession {
            guard VTPixelTransferSessionTransferImage(existing, from: buffer, to: outRef) == noErr else {
                return nil
            }
            return outRef
        }
        var newSession: VTPixelTransferSession?
        guard VTPixelTransferSessionCreate(allocator: kCFAllocatorDefault, pixelTransferSessionOut: &newSession) == noErr,
              let newSession else { return nil }
        pixelTransferSession = newSession
        guard VTPixelTransferSessionTransferImage(newSession, from: buffer, to: outRef) == noErr else {
            return nil
        }
        return outRef
    }
}

nonisolated private final class RifeTemporalProcessor: VideoFrameProcessor, @unchecked Sendable {
    private let adapter: RifeFrameInterpolationAdapter
    private let tier: RifeQualityTier
    private let buffer = TemporalReorderBuffer()

    init(adapter: RifeFrameInterpolationAdapter, tier: RifeQualityTier) {
        self.adapter = adapter
        self.tier = tier
    }

    func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
        buffer.accept(ctx) { previous, current in
            adapter.processTemporal(previous: previous, current: current, tier: tier)
        }
    }

    func onInvalidate(newGeneration _: Int64) {
        buffer.onInvalidate()
    }

    func drainPendingFrames() -> [GeneratedVideoFrame] {
        buffer.drainPendingFrames()
    }

    func onDrain() {
        buffer.onDrain()
        adapter.endSession()
    }

    var hasPendingFrames: Bool {
        buffer.hasPendingFrames
    }
}

extension RifeFrameInterpolationAdapter {
    nonisolated func makeTemporalProcessor(tier: RifeQualityTier) -> any VideoFrameProcessor {
        RifeTemporalProcessor(adapter: self, tier: tier)
    }
}

private extension RifeQualityTier {
    nonisolated func downgraded() -> RifeQualityTier? {
        switch self {
        case .hq: return .balanced
        case .balanced: return .fast
        case .fast: return nil
        }
    }
}

#endif
