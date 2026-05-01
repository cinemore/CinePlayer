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

            guard let interp = ensureInterpolatorOnQueue(width: width, height: height, tier: tier) else {
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
                "[VFI-RIFE] diag total=\(String(format: "%.1f", totalMs))ms tier=\(tier.rawValue) \(width)x\(height)"
            )
            return .replaceMany(generated)
        }
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

#endif
