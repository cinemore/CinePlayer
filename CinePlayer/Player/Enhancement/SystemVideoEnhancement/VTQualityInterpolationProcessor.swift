import CinePlayerSDK
#if !os(tvOS) && !os(visionOS) && !targetEnvironment(simulator)
    import CoreMedia
    import CoreVideo
    import Foundation
    @preconcurrency import VideoToolbox

    /// 质量补帧使用原生半浮点输入输出；处理实例随预热工厂创建，不向 CinePlayer 暴露算法状态。
    @available(iOS 26.0, macOS 26.0, *)
    final nonisolated class VTQualityInterpolationProcessor: VideoFrameProcessor, @unchecked Sendable {
        private let buffer = TemporalReorderBuffer()
        private let engine: Engine
        private let count: Int

        init(dimensions: CMVideoDimensions, count: Int) throws {
            self.count = max(1, min(3, count))
            engine = try Engine(dimensions: dimensions)
            // 工厂在后台执行，预热不阻塞原帧播放。
            let frame = try EnhancementStartupProcessor.warmupFrame(dimensions)
            for index in 0 ..< 4 {
                let a = PreviousVideoFrameSnapshot(
                    pixelBuffer: frame.pixelBuffer,
                    timestamp: Int64(index * 100),
                    duration: 100,
                    timebaseNum: 1,
                    timebaseDen: 2400,
                    fps: 24,
                    generation: -1
                )
                let b = VideoFrameContext(
                    pixelBuffer: frame.pixelBuffer,
                    timestamp: Int64((index + 1) * 100),
                    duration: 100,
                    timebaseNum: 1,
                    timebaseDen: 2400,
                    fps: 24,
                    generation: -1
                )
                _ = try engine.process(a, b, count: self.count)
            }
        }

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            buffer.acceptWithDeadline(ctx, fallbackBudgetFraction: 0.9, fallbackMaximumWait: 0.040) { [engine, count] a, b in
                (try? engine.process(a, b, count: count)) ?? .passthrough
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
        }

        var hasPendingFrames: Bool {
            buffer.hasPendingFrames
        }

        /// 重排器串行提交计算；迟到任务持有 engine，资源只在最后一个任务释放后销毁。
        private final class Engine: @unchecked Sendable {
            let processor = VTFrameProcessor()
            let sourcePool: CVPixelBufferPool
            let destinationPool: CVPixelBufferPool
            let transfer: VTPixelTransferSession
            let dimensions: CMVideoDimensions
            var cached: CVPixelBuffer?
            var cachedSource: CVPixelBuffer?
            var cachedGeneration: Int64?
            var cachedTimestamp: Int64?

            init(dimensions: CMVideoDimensions) throws {
                self.dimensions = dimensions
                guard let config = VTFrameRateConversionConfiguration(
                    frameWidth: Int(dimensions.width),
                    frameHeight: Int(dimensions.height),
                    usePrecomputedFlow: false,
                    qualityPrioritization: .normal,
                    revision: .revision1
                ) else {
                    throw EnhancementStartupProcessor.StartupError.unavailable
                }
                sourcePool = try Self.pool(config.sourcePixelBufferAttributes)
                destinationPool = try Self.pool(config.destinationPixelBufferAttributes)
                var session: VTPixelTransferSession?
                guard VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &session) == noErr,
                      let session
                else {
                    throw EnhancementStartupProcessor.StartupError.unavailable
                }
                transfer = session
                try processor.startSession(configuration: config)
            }

            deinit { processor.endSession(); VTPixelTransferSessionInvalidate(transfer) }

            static func pool(_ attributes: [String: Any]) throws -> CVPixelBufferPool {
                var attributes = attributes
                if let formats = attributes[kCVPixelBufferPixelFormatTypeKey as String] as? [NSNumber],
                   let first = formats.first
                {
                    attributes[kCVPixelBufferPixelFormatTypeKey as String] = first
                }
                var result: CVPixelBufferPool?
                guard CVPixelBufferPoolCreate(nil, nil, attributes as CFDictionary, &result) == kCVReturnSuccess,
                      let result
                else {
                    throw EnhancementStartupProcessor.StartupError.unavailable
                }
                return result
            }

            func allocate(_ pool: CVPixelBufferPool) throws -> CVPixelBuffer {
                var result: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &result) == kCVReturnSuccess,
                      let result
                else {
                    throw EnhancementStartupProcessor.StartupError.unavailable
                }
                return result
            }

            func convert(_ input: CVPixelBuffer) throws -> CVPixelBuffer {
                let result = try allocate(sourcePool)
                CVBufferRemoveAllAttachments(result)
                guard VTPixelTransferSessionTransferImage(transfer, from: input, to: result) == noErr
                else {
                    throw EnhancementStartupProcessor.StartupError.unavailable
                }
                return result
            }

            func process(_ a: PreviousVideoFrameSnapshot, _ b: VideoFrameContext, count: Int) throws -> VideoFrameResult {
                guard a.generation == b.generation, a.timebaseNum == b.timebaseNum, a.timebaseDen == b.timebaseDen,
                      b.timebaseNum > 0, b.timebaseDen > 0, b.timestamp > a.timestamp,
                      CVPixelBufferGetWidth(b.pixelBuffer) == Int(dimensions.width),
                      CVPixelBufferGetHeight(b.pixelBuffer) == Int(dimensions.height)
                else {
                    return .passthrough
                }
                let first: CVPixelBuffer
                // 只按真正提交过的请求判断连续性；忙时跳过与结果超时丢弃不是一回事。
                // 跳过请求后必须清理 VT 内部历史，否则新输入可能与旧缓存混用。
                let continuous = cachedGeneration == a.generation && cachedTimestamp == a.timestamp && cachedSource === a.pixelBuffer && cached != nil
                if continuous, let cached {
                    first = cached
                } else {
                    first = try convert(a.pixelBuffer)
                }
                let next = try convert(b.pixelBuffer)
                func time(_ timestamp: Int64) -> CMTime {
                    CMTimeMultiply(CMTime(value: timestamp, timescale: b.timebaseDen), multiplier: b.timebaseNum)
                }
                let start = time(a.timestamp), end = time(b.timestamp)
                guard start.isNumeric, end.isNumeric else {
                    return .passthrough
                }
                guard let source = VTFrameProcessorFrame(buffer: first, presentationTimeStamp: start), let target = VTFrameProcessorFrame(
                    buffer: next,
                    presentationTimeStamp: end
                ) else {
                    return .passthrough
                }
                let span = b.timestamp.subtractingReportingOverflow(a.timestamp)
                guard !span.overflow, span.partialValue >= Int64(count + 1) else {
                    return .passthrough
                }
                let delta = span.partialValue / Int64(count + 1)
                let outputs = try (0 ..< count).map { _ in try allocate(destinationPool) }
                let frames = outputs.enumerated().compactMap { index, output in VTFrameProcessorFrame(
                    buffer: output,
                    presentationTimeStamp: time(a.timestamp + Int64(index + 1) * delta)
                ) }
                guard frames.count == count, let params = VTFrameRateConversionParameters(
                    sourceFrame: source,
                    nextFrame: target,
                    opticalFlow: nil,
                    interpolationPhase: (1 ... count).map { Float($0) / Float(count + 1) },
                    submissionMode: continuous ? .sequential : .random,
                    destinationFrames: frames
                ) else {
                    return .passthrough
                }
                let done = DispatchSemaphore(value: 0)
                final class Status: @unchecked Sendable { var error: Error? }
                let status = Status()
                processor.process(parameters: params) { _, error in status.error = error; done.signal() }
                done.wait()
                if let error = status.error {
                    cachedGeneration = nil
                    throw error
                }
                cached = next; cachedSource = b.pixelBuffer; cachedGeneration = b.generation; cachedTimestamp = b.timestamp
                // VT 不继承显示附件。RGB 输出只复制色彩与几何附件，不能带入 YCbCr 矩阵。
                for output in outputs {
                    CVBufferRemoveAllAttachments(output)
                    for key in [
                        kCVImageBufferColorPrimariesKey,
                        kCVImageBufferTransferFunctionKey,
                        kCVImageBufferGammaLevelKey,
                        kCVImageBufferCGColorSpaceKey,
                        kCVImageBufferCleanApertureKey,
                        kCVImageBufferPixelAspectRatioKey
                    ] {
                        if let value = CVBufferCopyAttachment(a.pixelBuffer, key, nil) {
                            CVBufferSetAttachment(output, key, value, .shouldPropagate)
                        }
                    }
                }
                var result = [GeneratedVideoFrame(pixelBuffer: a.pixelBuffer, timestamp: a.timestamp, duration: delta)]
                result += outputs.enumerated().map { index, output in
                    let timestamp = a.timestamp + Int64(index + 1) * delta
                    return GeneratedVideoFrame(
                        pixelBuffer: output,
                        timestamp: timestamp,
                        duration: index == count - 1 ? b.timestamp - timestamp : delta
                    )
                }
                return .replaceMany(result)
            }
        }
    }
#endif
