import CinePlayerSDK
#if !targetEnvironment(simulator)
    import CoreImage
    import CoreMedia
    import CoreVideo
    import Foundation
    import Metal
    @preconcurrency import VideoToolbox

    nonisolated struct LLFITimingDiagnostics: Equatable {
        var totalMs: Double
        var segmentMs: Double
        var headroomMs: Double
        var queueWaitMs: Double
        var sessionMs: Double
        var sourceTransferMs: Double
        var prepareMs: Double
        var vtCollectMs: Double
        var vtWaitMs: Double
        var collectorCopyMs: Double
        var buildMs: Double
        var width: Int
        var height: Int
        var scalar: Int
        var numFrames: Int
        var format: OSType
        var previousSourceReuseHit: Bool
        var collectedCount: Int
        var generatedCount: Int
        var outcome: String
    }

    private nonisolated func llfiElapsedMs(from startNanos: UInt64, to endNanos: UInt64) -> Double {
        Double(endNanos - startNanos) / 1_000_000
    }

    private nonisolated func llfiMsString(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    nonisolated func formatLLFITimingDiagnostics(_ diagnostics: LLFITimingDiagnostics) -> String {
        let previousSourceState = diagnostics.previousSourceReuseHit ? "reuse" : "miss"
        return
            "[VFI-LLFI] diag total=\(llfiMsString(diagnostics.totalMs))ms segment=\(llfiMsString(diagnostics.segmentMs)) headroom=\(llfiMsString(diagnostics.headroomMs)) \(diagnostics.width)x\(diagnostics.height) scalar=\(diagnostics.scalar) num=\(diagnostics.numFrames) queue=\(llfiMsString(diagnostics.queueWaitMs)) session=\(llfiMsString(diagnostics.sessionMs)) source=\(llfiMsString(diagnostics.sourceTransferMs)) prepare=\(llfiMsString(diagnostics.prepareMs)) vt=\(llfiMsString(diagnostics.vtCollectMs)) vtWait=\(llfiMsString(diagnostics.vtWaitMs)) copy=\(llfiMsString(diagnostics.collectorCopyMs)) build=\(llfiMsString(diagnostics.buildMs)) fmt=\(diagnostics.format) prevSrc=\(previousSourceState) collected=\(diagnostics.collectedCount) generated=\(diagnostics.generatedCount) outcome=\(diagnostics.outcome)"
    }

    /// 系统 ML 视频增强适配层：封装低延迟超分（LLSRS）与低延迟插帧（LLFI），在帧回调线程同步调用。
    /// 所有访问经内部 queue 序列化，标记为 @unchecked Sendable 以在 @Sendable 闭包中安全持有。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    final nonisolated class SystemVideoEnhancementAdapter: @unchecked Sendable {
        static let shared = SystemVideoEnhancementAdapter()

        private let queue = DispatchQueue(
            label: "cn.com.cinemore.systemml.adapter", qos: .userInitiated
        )
        private var temporalRecv = 0
        private var temporalHit = 0
        private var temporalPassthrough = 0

        private func vfiLog(level: CinemoreLogLevel, _ message: String) {
            cinemoreLog(level: level, "[VFI-ML] \(message)")
        }

        // 现有诊断日志按字段接收统计值，保持调用点与日志字段一一对应。
        // swiftlint:disable:next function_parameter_count
        private func vfiTemporalStatsLogMaybe(
            seq: Int,
            scalar: Int,
            numFrames: Int,
            prevTs: Int64,
            currTs: Int64,
            size: String,
            fmt: OSType,
            lastCollected: Int,
            lastGenerated: Int,
            reason: String
        ) {
            guard seq <= 5 || seq % 120 == 0 else {
                return
            }
            vfiLog(
                level: .debug,
                "stats seq=\(seq) recv=\(temporalRecv) hit=\(temporalHit) pass=\(temporalPassthrough) scalar=\(scalar) numFrames=\(numFrames) window=\(prevTs)->\(currTs) size=\(size) fmt=\(fmt) collected=\(lastCollected) generated=\(lastGenerated) reason=\(reason)"
            )
        }

        // MARK: - LLSRS（单帧超分）

        private var frameProcessor: VTFrameProcessor?
        private var configuration: VTLowLatencySuperResolutionScalerConfiguration?
        private var pixelBufferPool: CVPixelBufferPool?
        /// 与 VT 要求的 source 格式一致的 buffer 池，用于 VTPixelTransferSession 转换后喂给 LLSRS。
        private var sourcePixelBufferPool: CVPixelBufferPool?
        private var pixelTransferSession: VTPixelTransferSession?
        private var inputDimensions: CMVideoDimensions?
        private var scaleFactor: Float = 2.0
        private let abConversionCache = BGRAConversionCache()
        private nonisolated struct ABResources {
            let commands: any MTLCommandQueue
            let cache: CVMetalTextureCache
            let compare: SuperResolutionABCompare
        }

        private var abResources: ABResources?

        /// 仅由 adapter 串行队列调用；保留原转换顺序，复用 A/B 两种尺寸的资源。
        typealias BGRAConversionCache = VideoEnhancementBGRAConversionCache

        // MARK: - LLFI（时域插帧，replaceMany）

        private var llfiProcessor: VTFrameProcessor?
        private var llfiConfiguration: VTLowLatencyFrameInterpolationConfiguration?
        private var llfiPixelBufferPool: CVPixelBufferPool?
        /// 拷贝 VT 插帧输出用池，按 yield 顺序收集后用于输出，避免用 destination 顺序导致画面时序错乱（旧画面被后播、来回抖动）。
        private var llfiCopyPixelBufferPool: CVPixelBufferPool?
        private var llfiCopyTransferSession: VTPixelTransferSession?
        private var llfiSourcePixelBufferPool: CVPixelBufferPool?
        private var llfiPixelTransferSession: VTPixelTransferSession?
        private var cachedLLFICurrentSourceOriginal: CVPixelBuffer?
        private var cachedLLFICurrentSourceTransferred: CVPixelBuffer?
        private var llfiInputDimensions: CMVideoDimensions?
        private var llfiScalar: Int = 1
        private var llfiNumFrames: Int = 1

        /// 结束会话并释放资源。
        func endSession() {
            queue.sync {
                resetSuperResolutionSessionOnQueue()
                resetLLFISessionOnQueue()
            }
        }

        /// Center 首帧前预热：在 user-initiated 后台线程提前完成 LLFI session/pools/processor 构建。
        /// 必须传入真实视频自然尺寸；scalar/numFrames 与 processTemporalFrames 调用一致，避免首帧因 session 重建造成额外延迟。
        @discardableResult
        func warmup(dimensions: CMVideoDimensions, scalar: Int, numFrames: Int) async -> Bool {
            await Task.detached(priority: .userInitiated) { [weak self] in
                self?.queue.sync {
                    let effective = scalar == 2 ? 1 : min(3, max(1, numFrames))
                    return self?.ensureLLFISessionIfNeeded(
                        dimensions: dimensions,
                        scalar: scalar,
                        numFrames: effective
                    ) != nil
                }
            }.value ?? false
        }

        /// 单帧超分处理。仅应从非主线程调用（例如 asyncVideoQueue）。
        /// - Parameter abCompareEnabled: 为 true 时返回左原图、右超分的拼接 buffer，与 Anime4K A/B 对比一致。
        func processSingleFrame(
            context: VideoFrameContext,
            scale: Double,
            abCompareEnabled: Bool = false
        ) -> CVPixelBuffer? {
            queue.sync {
                scaleSingleFrameOnQueue(
                    context: context, scale: scale, abCompareEnabled: abCompareEnabled
                )
            }
        }

        /// 单帧超分内部实现，必须在 adapter 的 queue 内调用（供 processSingleFrame 与 processTemporalFrames scalar==2 使用）。
        private func scaleSingleFrameOnQueue(
            context: VideoFrameContext,
            scale: Double,
            abCompareEnabled: Bool = false
        ) -> CVPixelBuffer? {
            // 当前 VT 超分配置只提供 8-bit 缓冲；HDR 不允许经量化后继续输出。
            let sourceTransfer = CVBufferCopyAttachment(context.pixelBuffer, kCVImageBufferTransferFunctionKey, nil) as? String
            guard sourceTransfer != kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String,
                  sourceTransfer != kCVImageBufferTransferFunction_ITU_R_2100_HLG as String
            else {
                return nil
            }
            let pool = ensureSessionIfNeeded(pixelBuffer: context.pixelBuffer, scale: scale)
            let pts = CMTime(
                value: context.timestamp * Int64(context.timebaseNum),
                timescale: context.timebaseDen
            )
            if let pool,
               let srcBuffer = sourceBufferForVT(context.pixelBuffer),
               let srcFrame = VTFrameProcessorFrame(
                   buffer: srcBuffer,
                   presentationTimeStamp: pts
               )
            {
                var dstBufferOptional: CVPixelBuffer?
                if CVPixelBufferPoolCreatePixelBuffer(nil, pool, &dstBufferOptional)
                    == kCVReturnSuccess,
                   let dstBuffer = dstBufferOptional,
                   let dstFrame = VTFrameProcessorFrame(
                       buffer: dstBuffer,
                       presentationTimeStamp: pts
                   ),
                   let config = configuration
                {
                    let parameters = VTLowLatencySuperResolutionScalerParameters(
                        sourceFrame: srcFrame,
                        destinationFrame: dstFrame
                    )
                    if let enhanced = syncProcess(
                        parameters: parameters, destinationBuffer: dstBuffer, config: config
                    ) {
                        return composeSuperResolutionOutput(
                            original: context.pixelBuffer,
                            enhanced: enhanced,
                            abCompareEnabled: abCompareEnabled
                        )
                    }
                }
            }

            // HDR 失败时交回原帧，避免后备缩放走 8-bit / sRGB 路径损失精度。
            let transfer = CVBufferCopyAttachment(context.pixelBuffer, kCVImageBufferTransferFunctionKey, nil) as? String
            if transfer == kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String
                || transfer == kCVImageBufferTransferFunction_ITU_R_2100_HLG as String
            {
                return nil
            }
            // 超分开启后不回退原始帧：ML 失败时至少输出放大后的帧（VT transfer -> CI Lanczos）。
            if let fallbackUpscaled = fallbackUpscaledBuffer(
                original: context.pixelBuffer,
                scale: scale,
                preferredPool: pool
            ) {
                cinemoreLog(level: .debug, "SystemML 超分失败：已回退为非 ML 放大帧")
                return composeSuperResolutionOutput(
                    original: context.pixelBuffer,
                    enhanced: fallbackUpscaled,
                    abCompareEnabled: abCompareEnabled
                )
            }
            cinemoreLog(level: .debug, "SystemML 超分失败：放大 fallback 也失败")
            return nil
        }

        /// 时域插帧：根据 prev/curr 生成 [prevTs, currTs) 内的插值帧，供 temporal 模式 replaceMany 使用。
        /// previous 由 Center 填充；为 nil 直接 passthrough（Center 走兜底保形）。
        func processTemporalFrames(
            previous: PreviousVideoFrameSnapshot?,
            current: VideoFrameContext,
            scalar: Int,
            numFrames: Int
        ) -> VideoFrameResult {
            let totalStart = DispatchTime.now().uptimeNanoseconds
            let width = CVPixelBufferGetWidth(current.pixelBuffer)
            let height = CVPixelBufferGetHeight(current.pixelBuffer)
            let format = CVPixelBufferGetPixelFormatType(current.pixelBuffer)
            var diagnostics = LLFITimingDiagnostics(
                totalMs: 0,
                segmentMs: 0,
                headroomMs: 0,
                queueWaitMs: 0,
                sessionMs: 0,
                sourceTransferMs: 0,
                prepareMs: 0,
                vtCollectMs: 0,
                vtWaitMs: 0,
                collectorCopyMs: 0,
                buildMs: 0,
                width: width,
                height: height,
                scalar: scalar,
                numFrames: numFrames,
                format: format,
                previousSourceReuseHit: false,
                collectedCount: 0,
                generatedCount: 0,
                outcome: "entry"
            )
            defer {
                diagnostics.totalMs = llfiElapsedMs(
                    from: totalStart,
                    to: DispatchTime.now().uptimeNanoseconds
                )
                diagnostics.headroomMs = diagnostics.segmentMs - diagnostics.totalMs
                cinemoreLog(level: .debug, formatLLFITimingDiagnostics(diagnostics))
            }
            return queue.sync {
                let queueEntered = DispatchTime.now().uptimeNanoseconds
                diagnostics.queueWaitMs = llfiElapsedMs(from: totalStart, to: queueEntered)
                temporalRecv += 1
                let seq = temporalRecv
                guard let previous else {
                    diagnostics.outcome = "noPrevious"
                    return .passthrough
                }
                guard current.timestamp > previous.timestamp else {
                    diagnostics.outcome = "nonMonotonic"
                    vfiLog(
                        level: .info,
                        "temporal passthrough nonMonotonic prev=\(previous.timestamp) curr=\(current.timestamp) diff=\(current.timestamp - previous.timestamp) seq=\(seq)"
                    )
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: previous.timestamp,
                        currTs: current.timestamp,
                        size: "\(width)x\(height)",
                        fmt: format,
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "nonMonotonic"
                    )
                    return .passthrough
                }
                let prevTs = previous.timestamp
                let currTs = current.timestamp
                let segmentDuration = currTs - prevTs
                diagnostics.segmentMs =
                    Double(segmentDuration) * Double(previous.timebaseNum) * 1000
                        / Double(previous.timebaseDen)
                guard segmentDuration > 0 else {
                    diagnostics.outcome = "badDuration"
                    vfiLog(level: .debug, "temporal passthrough: segmentDuration<=0")
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: format,
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "badDuration"
                    )
                    return .passthrough
                }

                let dims = CMVideoDimensions(width: Int32(width), height: Int32(height))
                let sessionStart = DispatchTime.now().uptimeNanoseconds
                guard
                    let pool = ensureLLFISessionIfNeeded(
                        dimensions: dims, scalar: scalar, numFrames: numFrames
                    )
                else {
                    diagnostics.sessionMs = llfiElapsedMs(
                        from: sessionStart,
                        to: DispatchTime.now().uptimeNanoseconds
                    )
                    diagnostics.outcome = "ensureSessionNil"
                    vfiLog(level: .debug, "temporal failed: ensureLLFISession returned nil")
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "ensureSessionNil"
                    )
                    return .passthrough
                }
                diagnostics.sessionMs = llfiElapsedMs(
                    from: sessionStart,
                    to: DispatchTime.now().uptimeNanoseconds
                )

                // Use the previous frame timebase for the whole window to keep VT PTS math consistent with CinePlayer timeline.
                let firstPTS = CMTime(
                    value: prevTs * Int64(previous.timebaseNum), timescale: previous.timebaseDen
                )
                let lastPTS = CMTime(
                    value: currTs * Int64(previous.timebaseNum), timescale: previous.timebaseDen
                )
                let sourceTransferStart = DispatchTime.now().uptimeNanoseconds
                let prevBuffer: CVPixelBuffer?
                if let cachedOriginal = cachedLLFICurrentSourceOriginal,
                   cachedOriginal === previous.pixelBuffer
                {
                    diagnostics.previousSourceReuseHit = true
                    prevBuffer = cachedLLFICurrentSourceTransferred
                } else {
                    diagnostics.previousSourceReuseHit = false
                    prevBuffer = sourceBufferForLLFI(previous.pixelBuffer)
                }
                guard let prevBuffer,
                      let currBuffer = sourceBufferForLLFI(current.pixelBuffer),
                      let srcFrame = VTFrameProcessorFrame(
                          buffer: prevBuffer, presentationTimeStamp: firstPTS
                      ),
                      let nextFrame = VTFrameProcessorFrame(
                          buffer: currBuffer, presentationTimeStamp: lastPTS
                      )
                else {
                    diagnostics.sourceTransferMs = llfiElapsedMs(
                        from: sourceTransferStart,
                        to: DispatchTime.now().uptimeNanoseconds
                    )
                    diagnostics.outcome = "vtFrameNil"
                    vfiLog(
                        level: .debug,
                        "temporal failed: sourceBufferForLLFI or VTFrame creation failed"
                    )
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "vtFrameNil"
                    )
                    return .passthrough
                }
                diagnostics.sourceTransferMs = llfiElapsedMs(
                    from: sourceTransferStart,
                    to: DispatchTime.now().uptimeNanoseconds
                )
                cachedLLFICurrentSourceOriginal = current.pixelBuffer
                cachedLLFICurrentSourceTransferred = currBuffer

                // 与 ensureLLFISessionIfNeeded 一致：scalar==2 时用 1，否则按用户 1–3 帧。
                let effectiveNumFrames = scalar == 2 ? 1 : min(3, max(1, numFrames))
                let intervals = interpolationIntervals(numFrames: effectiveNumFrames)
                let prepareStart = DispatchTime.now().uptimeNanoseconds
                guard
                    let (destinationFrames, destinationBuffers) = createLLFIDestinationFrames(
                        firstPTS: firstPTS,
                        lastPTS: lastPTS,
                        pool: pool,
                        scalar: scalar,
                        intervals: intervals
                    )
                else {
                    diagnostics.prepareMs = llfiElapsedMs(
                        from: prepareStart,
                        to: DispatchTime.now().uptimeNanoseconds
                    )
                    diagnostics.outcome = "destinationFramesNil"
                    return .passthrough
                }

                let intervalArray = intervals.map { Float($0) }
                guard
                    let parameters = VTLowLatencyFrameInterpolationParameters(
                        sourceFrame: nextFrame,
                        previousFrame: srcFrame,
                        interpolationPhase: intervalArray,
                        destinationFrames: destinationFrames
                    )
                else {
                    vfiLog(
                        level: .debug,
                        "temporal failed: VTLowLatencyFrameInterpolationParameters == nil"
                    )
                    temporalPassthrough += 1
                    diagnostics.prepareMs = llfiElapsedMs(
                        from: prepareStart,
                        to: DispatchTime.now().uptimeNanoseconds
                    )
                    diagnostics.outcome = "paramsNil"
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "paramsNil"
                    )
                    return .passthrough
                }
                diagnostics.prepareMs = llfiElapsedMs(
                    from: prepareStart,
                    to: DispatchTime.now().uptimeNanoseconds
                )

                guard let processor = llfiProcessor else {
                    diagnostics.outcome = "processorNil"
                    return .passthrough
                }
                guard let copyPool = llfiCopyPixelBufferPool,
                      let copySession = llfiCopyTransferSession
                else {
                    diagnostics.outcome = "copyPoolNil"
                    vfiLog(level: .debug, "temporal failed: copy pool/session nil")
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "copyPoolNil"
                    )
                    return .passthrough
                }

                let holder = LLFICollectorHolder(
                    processor: processor,
                    parameters: parameters,
                    destinationBuffers: scalar == 1 ? destinationBuffers : [],
                    copyPool: copyPool,
                    copyTransferSession: copySession
                )
                let vtCollectStart = DispatchTime.now().uptimeNanoseconds
                holder.runCollect()

                let waitResult = holder.semaphore.wait(timeout: .now() + .seconds(2))
                let framesToUse = holder.frames
                let collectError = holder.error
                diagnostics.vtCollectMs = llfiElapsedMs(
                    from: vtCollectStart,
                    to: DispatchTime.now().uptimeNanoseconds
                )
                diagnostics.collectorCopyMs = Double(holder.copyElapsedNanos) / 1_000_000
                diagnostics.vtWaitMs = max(
                    0,
                    diagnostics.vtCollectMs - diagnostics.collectorCopyMs
                )
                diagnostics.collectedCount = framesToUse.count

                // "Processor is not initialized" 意味着后台 warmup 未完成;
                // 原先做 30ms sleep + 2s retry 会在冷启动/切换瞬间把 asyncVideoQueue 灌爆,
                // 产生看得见的"画面卡住很久"。直接 passthrough,下一段在 warmup 就绪后会自然成功。
                if let err = collectError, err.localizedDescription.contains("not initialized") {
                    vfiLog(level: .debug, "temporal processor not initialized; skip segment, warmup will resolve")
                }

                if waitResult == .timedOut {
                    holder.cancel()
                    resetLLFISessionOnQueue()
                    diagnostics.outcome = "timeout"
                    vfiLog(level: .debug, "temporal failed: VT process timeout (2s)")
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: framesToUse.count,
                        lastGenerated: 0,
                        reason: "timeout"
                    )
                    return .passthrough
                }
                if let collectError {
                    diagnostics.outcome = "vtError"
                    vfiLog(
                        level: .debug,
                        "temporal failed: VT process error: \(collectError.localizedDescription)"
                    )
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: framesToUse.count,
                        lastGenerated: 0,
                        reason: "vtError"
                    )
                    return .passthrough
                }

                // 按 VT yield 顺序使用收集到的帧（持有调用方目标或已拷贝），保证播放顺序与时间轴一致，避免「旧画面被后播」的来回抖动。
                let expectedCollected = scalar == 2 ? 1 + effectiveNumFrames : effectiveNumFrames
                if framesToUse.count != expectedCollected {
                    vfiLog(
                        level: .debug,
                        "temporal collected=\(framesToUse.count) 期望=\(expectedCollected) scalar=\(scalar) numFrames=\(numFrames) effectiveNumFrames=\(effectiveNumFrames)"
                    )
                }
                let buildStart = DispatchTime.now().uptimeNanoseconds
                let generated = buildGeneratedFramesFromLLFIOutput(
                    collectedBuffersInOrder: framesToUse.map(\.0),
                    previousPixelBuffer: previous.pixelBuffer,
                    scalar: scalar,
                    prevTs: prevTs,
                    currTs: currTs
                )
                diagnostics.buildMs = llfiElapsedMs(
                    from: buildStart,
                    to: DispatchTime.now().uptimeNanoseconds
                )
                diagnostics.generatedCount = generated.count
                guard !generated.isEmpty else {
                    diagnostics.outcome = "buildEmpty"
                    vfiLog(level: .debug, "temporal failed: buildGeneratedFrames is empty")
                    temporalPassthrough += 1
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(width)x\(height)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: framesToUse.count,
                        lastGenerated: 0,
                        reason: "buildEmpty"
                    )
                    return .passthrough
                }
                temporalHit += 1
                diagnostics.outcome = "hit"
                vfiTemporalStatsLogMaybe(
                    seq: seq,
                    scalar: scalar,
                    numFrames: numFrames,
                    prevTs: prevTs,
                    currTs: currTs,
                    size: "\(width)x\(height)",
                    fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                    lastCollected: framesToUse.count,
                    lastGenerated: generated.count,
                    reason: "hit"
                )
                return .replaceMany(generated)
            }
        }

        // MARK: - Private

        private func ensureSessionIfNeeded(pixelBuffer: CVPixelBuffer, scale: Double)
            -> CVPixelBufferPool?
        {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            let dims = CMVideoDimensions(width: Int32(width), height: Int32(height))

            let minDim = VTLowLatencySuperResolutionScalerConfiguration.minimumDimensions
            let maxDim = VTLowLatencySuperResolutionScalerConfiguration.maximumDimensions
            guard let minDim, let maxDim,
                  dims.width >= minDim.width, dims.height >= minDim.height,
                  dims.width <= maxDim.width, dims.height <= maxDim.height
            else {
                cinemoreLog(
                    level: .debug,
                    "SystemML ensureSession 失败：尺寸 \(dims.width)x\(dims.height) 不在 VT 支持范围（min=\(minDim?.width ?? 0)x\(minDim?.height ?? 0) max=\(maxDim?.width ?? 0)x\(maxDim?.height ?? 0)）"
                )
                return nil
            }

            let supported = VTLowLatencySuperResolutionScalerConfiguration.supportedScaleFactors(
                frameWidth: Int(dims.width),
                frameHeight: Int(dims.height)
            )
            let effectiveScale: Double
            if supported.contains(where: { abs(Double($0) - scale) < 0.001 }) {
                effectiveScale = scale
            } else if let nearest = supported.min(by: {
                abs(Double($0) - scale) < abs(Double($1) - scale)
            }) {
                effectiveScale = Double(nearest)
                cinemoreLog(
                    level: .debug,
                    "SystemML scale=\(scale) 不在支持列表 \(supported)，使用最近倍率 \(effectiveScale)"
                )
            } else {
                cinemoreLog(level: .debug, "SystemML ensureSession 失败：当前分辨率无支持倍率 \(supported)")
                return nil
            }

            if let existingDims = inputDimensions,
               existingDims.width == dims.width,
               existingDims.height == dims.height,
               abs(Double(scaleFactor) - effectiveScale) < 0.001,
               let pool = pixelBufferPool
            {
                return pool
            }

            // 尺寸或倍率变化：先释放旧会话再创建新会话，避免 VT 资源泄漏
            frameProcessor?.endSession()
            frameProcessor = nil
            configuration = nil
            pixelBufferPool = nil
            if let session = pixelTransferSession {
                VTPixelTransferSessionInvalidate(session)
            }
            pixelTransferSession = nil
            sourcePixelBufferPool = nil
            inputDimensions = nil

            let config = VTLowLatencySuperResolutionScalerConfiguration(
                frameWidth: Int(dims.width),
                frameHeight: Int(dims.height),
                scaleFactor: Float(effectiveScale)
            )

            var pool: CVPixelBufferPool?
            let status = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                config.destinationPixelBufferAttributes as CFDictionary,
                &pool
            )
            guard status == kCVReturnSuccess, let pool else {
                cinemoreLog(
                    level: .debug, "SystemML ensureSession 失败：CVPixelBufferPoolCreate 返回 \(status)"
                )
                return nil
            }

            let processor = frameProcessor ?? VTFrameProcessor()
            do {
                try processor.startSession(configuration: config)
            } catch {
                cinemoreLog(level: .debug, "SystemML ensureSession 失败：startSession 抛出 \(error)")
                return nil
            }

            // 按 Apple demo：用 config.sourcePixelBufferAttributes 建 source 池，经 VTPixelTransferSession 转成 VT 期望格式再喂给 process
            var sourceAttrs = config.sourcePixelBufferAttributes as [String: Any]
            sourceAttrs[kCVPixelBufferWidthKey as String] = width
            sourceAttrs[kCVPixelBufferHeightKey as String] = height
            var sourcePool: CVPixelBufferPool?
            let sourcePoolStatus = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                sourceAttrs as CFDictionary,
                &sourcePool
            )
            guard sourcePoolStatus == kCVReturnSuccess, let sourcePool else {
                cinemoreLog(
                    level: .debug,
                    "SystemML ensureSession 失败：source CVPixelBufferPoolCreate 返回 \(sourcePoolStatus)"
                )
                processor.endSession()
                return nil
            }
            var transferSession: VTPixelTransferSession?
            guard
                VTPixelTransferSessionCreate(
                    allocator: kCFAllocatorDefault, pixelTransferSessionOut: &transferSession
                )
                == noErr,
                let transferSession
            else {
                cinemoreLog(
                    level: .debug, "SystemML ensureSession 失败：VTPixelTransferSessionCreate 失败"
                )
                processor.endSession()
                return nil
            }

            cinemoreLog(
                level: .debug,
                "SystemML ensureSession 成功：\(dims.width)x\(dims.height) scale=\(scale)"
            )
            frameProcessor = processor
            configuration = config
            pixelBufferPool = pool
            sourcePixelBufferPool = sourcePool
            pixelTransferSession = transferSession
            inputDimensions = dims
            scaleFactor = Float(effectiveScale)
            return pool
        }

        /// 将回调传入的 pixelBuffer 转为 VT LLSRS 要求的 source 格式（与 demo 的 VerifyBufferAttributes + sourcePixelBufferAttributes 一致）。
        private func sourceBufferForVT(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
            guard let pool = sourcePixelBufferPool,
                  let session = pixelTransferSession
            else {
                return nil
            }
            var outBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuffer) == kCVReturnSuccess,
                  let outBuffer,
                  VTPixelTransferSessionTransferImage(session, from: pixelBuffer, to: outBuffer)
                  == noErr
            else {
                return nil
            }
            return outBuffer
        }

        // MARK: - LLFI 私有

        private func ensureLLFISessionIfNeeded(
            dimensions: CMVideoDimensions, scalar: Int, numFrames: Int
        ) -> CVPixelBufferPool? {
            let width = Int(dimensions.width)
            let height = Int(dimensions.height)
            // scalar==2 时系统 spatialScaleFactor 路径可能仅支持 1 帧插值，故此处仍用 1；scalar==1 时按用户设置的 1–3 帧。
            let effectiveNumFrames = scalar == 2 ? 1 : min(3, max(1, numFrames))

            guard VTLowLatencyFrameInterpolationConfiguration.isSupported else {
                return nil
            }
            // LLFI 没有像超分那样的公开 min/max 分辨率门槛；
            // 这里只做能力检查，具体配置能否创建交给 VTLowLatencyFrameInterpolationConfiguration 自身判断。

            if let existing = llfiInputDimensions,
               existing.width == dimensions.width,
               existing.height == dimensions.height,
               llfiScalar == scalar,
               llfiNumFrames == effectiveNumFrames,
               let pool = llfiPixelBufferPool,
               llfiCopyPixelBufferPool != nil,
               llfiCopyTransferSession != nil
            {
                return pool
            }

            llfiProcessor?.endSession()
            llfiProcessor = nil
            llfiConfiguration = nil
            llfiPixelBufferPool = nil
            clearCachedLLFICurrentSourceOnQueue()
            if let session = llfiCopyTransferSession {
                VTPixelTransferSessionInvalidate(session)
            }
            llfiCopyTransferSession = nil
            llfiCopyPixelBufferPool = nil
            if let session = llfiPixelTransferSession {
                VTPixelTransferSessionInvalidate(session)
            }
            llfiPixelTransferSession = nil
            llfiSourcePixelBufferPool = nil
            llfiInputDimensions = nil

            let config: VTLowLatencyFrameInterpolationConfiguration? =
                switch scalar {
                case 1:
                    VTLowLatencyFrameInterpolationConfiguration(
                        frameWidth: width,
                        frameHeight: height,
                        numberOfInterpolatedFrames: effectiveNumFrames
                    )
                default:
                    VTLowLatencyFrameInterpolationConfiguration(
                        frameWidth: width,
                        frameHeight: height,
                        spatialScaleFactor: scalar
                    )
                }
            guard let config else {
                cinemoreLog(level: .debug, "SystemML LLFI ensureSession 失败：配置创建为 nil")
                return nil
            }

            var pool: CVPixelBufferPool?
            let status = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                config.destinationPixelBufferAttributes as CFDictionary,
                &pool
            )
            guard status == kCVReturnSuccess, let pool else {
                cinemoreLog(
                    level: .debug,
                    "SystemML LLFI ensureSession 失败：CVPixelBufferPoolCreate 返回 \(status)"
                )
                return nil
            }

            let processor = VTFrameProcessor()
            do {
                try processor.startSession(configuration: config)
            } catch {
                cinemoreLog(level: .debug, "SystemML LLFI ensureSession 失败：startSession 抛出 \(error)")
                return nil
            }

            var sourceAttrs = config.sourcePixelBufferAttributes as [String: Any]
            sourceAttrs[kCVPixelBufferWidthKey as String] = width
            sourceAttrs[kCVPixelBufferHeightKey as String] = height
            var sourcePool: CVPixelBufferPool?
            let sourcePoolStatus = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                sourceAttrs as CFDictionary,
                &sourcePool
            )
            guard sourcePoolStatus == kCVReturnSuccess, let sourcePool else {
                processor.endSession()
                return nil
            }
            var transferSession: VTPixelTransferSession?
            guard
                VTPixelTransferSessionCreate(
                    allocator: kCFAllocatorDefault, pixelTransferSessionOut: &transferSession
                )
                == noErr,
                let transferSession
            else {
                processor.endSession()
                return nil
            }

            // 按 VT yield 顺序收集输出并拷贝，保证播放顺序与时间轴一致，避免用 destination 顺序导致「旧画面被后播」的来回抖动。
            var copyPool: CVPixelBufferPool?
            let copyPoolStatus = CVPixelBufferPoolCreate(
                kCFAllocatorDefault,
                nil,
                config.destinationPixelBufferAttributes as CFDictionary,
                &copyPool
            )
            guard copyPoolStatus == kCVReturnSuccess, let copyPool else {
                processor.endSession()
                return nil
            }
            var copyTransferSession: VTPixelTransferSession?
            guard
                VTPixelTransferSessionCreate(
                    allocator: kCFAllocatorDefault, pixelTransferSessionOut: &copyTransferSession
                ) == noErr,
                let copyTransferSession
            else {
                processor.endSession()
                return nil
            }

            llfiProcessor = processor
            llfiConfiguration = config
            llfiPixelBufferPool = pool
            llfiCopyPixelBufferPool = copyPool
            llfiCopyTransferSession = copyTransferSession
            llfiSourcePixelBufferPool = sourcePool
            llfiPixelTransferSession = transferSession
            llfiInputDimensions = dimensions
            llfiScalar = scalar
            llfiNumFrames = effectiveNumFrames
            return pool
        }

        private func sourceBufferForLLFI(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
            guard let pool = llfiSourcePixelBufferPool,
                  let session = llfiPixelTransferSession
            else {
                return nil
            }
            var outBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuffer) == kCVReturnSuccess,
                  let outBuffer,
                  VTPixelTransferSessionTransferImage(session, from: pixelBuffer, to: outBuffer)
                  == noErr
            else {
                return nil
            }
            return outBuffer
        }

        /// 与官方 demo 一致：1.0/(numFrames+1) 为步长，stride dropLast。
        private func interpolationIntervals(numFrames: Int) -> [Double] {
            let step = 1.0 / (Double(numFrames) + 1)
            return Array(stride(from: step, through: 1.0, by: step)).dropLast()
        }

        /// 与 demo framesBetween 一致，返回 (frames, buffers) 同一顺序；process 完成后用 buffers 构建输出（VT 就地写入）。
        private func createLLFIDestinationFrames(
            firstPTS: CMTime,
            lastPTS: CMTime,
            pool: CVPixelBufferPool,
            scalar: Int,
            intervals: [Double]
        ) -> ([VTFrameProcessorFrame], [CVPixelBuffer])? {
            let ptsScale = lastPTS.timescale
            let firstSeconds = CMTimeGetSeconds(firstPTS)
            let lastSeconds = CMTimeGetSeconds(lastPTS)
            let ptsRange = lastSeconds - firstSeconds

            var frames: [VTFrameProcessorFrame] = []
            var buffers: [CVPixelBuffer] = []
            if scalar == 2 {
                var buf: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buf) == kCVReturnSuccess,
                      let buffer = buf,
                      let frame = VTFrameProcessorFrame(
                          buffer: buffer, presentationTimeStamp: firstPTS
                      )
                else {
                    return nil
                }
                frames.append(frame)
                buffers.append(buffer)
            }
            for interval in intervals {
                let ptsValue = ptsRange * interval + firstSeconds
                let pts = CMTime(seconds: ptsValue, preferredTimescale: ptsScale)
                var buf: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buf) == kCVReturnSuccess,
                      let buffer = buf,
                      let frame = VTFrameProcessorFrame(buffer: buffer, presentationTimeStamp: pts)
                else {
                    return nil
                }
                frames.append(frame)
                buffers.append(buffer)
            }
            return (frames, buffers)
        }

        /// 使用按 VT yield 顺序收集的 buffers 填满 [prevTs, currTs)，保证播放顺序与时间轴一致。
        /// - scalar==1: [raw prev] + collectedBuffersInOrder（与 demo 先 send(source) 再逐帧 send process 一致）。
        /// - scalar==2: 仅 collectedBuffersInOrder，首帧为缩放后的 prev（与 demo 一致）。
        private func buildGeneratedFramesFromLLFIOutput(
            collectedBuffersInOrder: [CVPixelBuffer],
            previousPixelBuffer: CVPixelBuffer,
            scalar: Int,
            prevTs: Int64,
            currTs: Int64
        ) -> [GeneratedVideoFrame] {
            guard !collectedBuffersInOrder.isEmpty else {
                return []
            }
            var buffers: [CVPixelBuffer] = []
            if scalar == 1 {
                buffers.append(previousPixelBuffer)
                buffers.append(contentsOf: collectedBuffersInOrder)
            } else {
                buffers.append(contentsOf: collectedBuffersInOrder)
            }
            return buildGeneratedFramesFromLLFIOutputEven(
                buffers: buffers, prevTs: prevTs, currTs: currTs
            )
        }

        /// 均分 [prevTs, currTs) 的 fallback，保证首帧=prevTs、末帧结束=currTs。
        private func buildGeneratedFramesFromLLFIOutputEven(
            buffers: [CVPixelBuffer],
            prevTs: Int64,
            currTs: Int64
        ) -> [GeneratedVideoFrame] {
            guard !buffers.isEmpty else {
                return []
            }
            let segmentDuration = currTs - prevTs
            let count = buffers.count
            // 每帧 duration 必须 ≥ 1（Center.buildTemporalFramesFromGenerated 的硬约束）。
            // 若 segmentDuration < count，返回空让调用方降级 passthrough，Center 走 fallback 保形。
            guard segmentDuration >= Int64(count) else {
                return []
            }
            let durPerFrame = segmentDuration / Int64(count)
            let remainder = segmentDuration % Int64(count)
            var result: [GeneratedVideoFrame] = []
            var runningTs = prevTs
            for (idx, buffer) in buffers.enumerated() {
                let dur = durPerFrame + (Int64(idx) < remainder ? 1 : 0)
                result.append(
                    GeneratedVideoFrame(pixelBuffer: buffer, timestamp: runningTs, duration: dur)
                )
                runningTs += dur
            }
            return result
        }

        /// CIImage 仅支持部分格式（如 BGRA），y420 等需先转为 BGRA。
        private func pixelBufferAsBGRA(_ buffer: CVPixelBuffer, width: Int, height: Int)
            -> CVPixelBuffer?
        {
            abConversionCache.convert(buffer, width: width, height: height)
        }

        private func ensureABResources() -> ABResources? {
            if let abResources {
                return abResources
            }
            guard let device = MTLCreateSystemDefaultDevice(), let commands = device.makeCommandQueue(),
                  let compare = try? SuperResolutionABCompare(device: device)
            else {
                return nil
            }
            var cache: CVMetalTextureCache?
            guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess,
                  let cache
            else {
                return nil
            }
            let resources = ABResources(commands: commands, cache: cache, compare: compare)
            abResources = resources
            return resources
        }

        /// 由adapter的串行队列调用；原地合成保留增强输出的所有权和色彩信息。
        func composeSuperResolutionOutput(
            original: CVPixelBuffer,
            enhanced: CVPixelBuffer,
            abCompareEnabled: Bool
        ) -> CVPixelBuffer {
            guard abCompareEnabled else {
                VideoFrameAttachments.copyDisplayGeometry(from: original, to: enhanced)
                return enhanced
            }
            let origW = CVPixelBufferGetWidth(original)
            let origH = CVPixelBufferGetHeight(original)
            let enhW = CVPixelBufferGetWidth(enhanced)
            let enhH = CVPixelBufferGetHeight(enhanced)
            guard let origBGRA = pixelBufferAsBGRA(original, width: origW, height: origH),
                  let enhBGRA = pixelBufferAsBGRA(enhanced, width: enhW, height: enhH),
                  let resources = ensureABResources()
            else {
                VideoFrameAttachments.copyDisplayGeometry(from: original, to: enhanced)
                return enhanced
            }
            do {
                try resources.compare.applyToOwnedOutput(original: origBGRA, output: enhBGRA,
                                                         commands: resources.commands, cache: resources.cache)
                VideoFrameAttachments.copyDisplayGeometry(from: original, to: enhBGRA)
                return enhBGRA
            } catch {
                // 合成可能已经写入部分输出，失败时交还未修改的原帧。
                cinemoreLog(level: .debug, "SystemML A/B合成失败，返回原帧")
                return original
            }
        }

        /// 非 ML 放大兜底：优先 VT transfer，失败再走 CI Lanczos，避免超分开启时回退原始帧。
        private func fallbackUpscaledBuffer(
            original: CVPixelBuffer,
            scale: Double,
            preferredPool: CVPixelBufferPool?
        ) -> CVPixelBuffer? {
            let requestedScale = max(1.0, scale)
            if let preferredPool {
                var outBuffer: CVPixelBuffer?
                if CVPixelBufferPoolCreatePixelBuffer(nil, preferredPool, &outBuffer) == kCVReturnSuccess,
                   let outBuffer
                {
                    if let attachments = CVBufferCopyAttachments(original, .shouldPropagate) {
                        CVBufferSetAttachments(outBuffer, attachments, .shouldPropagate)
                    }
                    if transferImageViaNewSession(from: original, to: outBuffer) {
                        return outBuffer
                    }
                }
            }

            let sourceWidth = CVPixelBufferGetWidth(original)
            let sourceHeight = CVPixelBufferGetHeight(original)
            let targetWidth = max(1, Int((Double(sourceWidth) * requestedScale).rounded()))
            let targetHeight = max(1, Int((Double(sourceHeight) * requestedScale).rounded()))
            let sourceFormat = CVPixelBufferGetPixelFormatType(original)

            var attrs = (CVPixelBufferCopyCreationAttributes(original) as? [String: Any]) ?? [:]
            attrs[kCVPixelBufferWidthKey as String] = targetWidth
            attrs[kCVPixelBufferHeightKey as String] = targetHeight
            attrs[kCVPixelBufferPixelFormatTypeKey as String] = Int(sourceFormat)
            if attrs[kCVPixelBufferIOSurfacePropertiesKey as String] == nil {
                attrs[kCVPixelBufferIOSurfacePropertiesKey as String] = [:]
            }

            var outBuffer: CVPixelBuffer?
            guard CVPixelBufferCreate(
                      kCFAllocatorDefault,
                      targetWidth,
                      targetHeight,
                      sourceFormat,
                      attrs as CFDictionary,
                      &outBuffer
                  ) == kCVReturnSuccess,
                  let outBuffer
            else {
                return fallbackUpscaledBufferViaCI(
                    original: original,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight
                )
            }
            if let attachments = CVBufferCopyAttachments(original, .shouldPropagate) {
                CVBufferSetAttachments(outBuffer, attachments, .shouldPropagate)
            }
            if transferImageViaNewSession(from: original, to: outBuffer) {
                return outBuffer
            }
            return fallbackUpscaledBufferViaCI(
                original: original,
                targetWidth: targetWidth,
                targetHeight: targetHeight
            )
        }

        private func transferImageViaNewSession(from source: CVPixelBuffer, to destination: CVPixelBuffer) -> Bool {
            var session: VTPixelTransferSession?
            guard VTPixelTransferSessionCreate(
                      allocator: kCFAllocatorDefault,
                      pixelTransferSessionOut: &session
                  ) == noErr,
                  let session
            else {
                return false
            }
            defer { VTPixelTransferSessionInvalidate(session) }
            return VTPixelTransferSessionTransferImage(session, from: source, to: destination) == noErr
        }

        private func fallbackUpscaledBufferViaCI(
            original: CVPixelBuffer,
            targetWidth: Int,
            targetHeight: Int
        ) -> CVPixelBuffer? {
            let sourceWidth = CVPixelBufferGetWidth(original)
            let sourceHeight = CVPixelBufferGetHeight(original)
            guard sourceWidth > 0, sourceHeight > 0 else {
                return nil
            }

            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: targetWidth,
                kCVPixelBufferHeightKey as String: targetHeight,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            var outBuffer: CVPixelBuffer?
            guard CVPixelBufferCreate(
                      kCFAllocatorDefault,
                      targetWidth,
                      targetHeight,
                      kCVPixelFormatType_32BGRA,
                      attrs as CFDictionary,
                      &outBuffer
                  ) == kCVReturnSuccess,
                  let outBuffer
            else {
                return nil
            }

            let scaleX = CGFloat(targetWidth) / CGFloat(sourceWidth)
            let scaleY = CGFloat(targetHeight) / CGFloat(sourceHeight)
            let src = CIImage(cvPixelBuffer: original)
            let scaled = src.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])
            ciContext.render(scaled, to: outBuffer)
            return outBuffer
        }

        private func syncProcess(
            parameters: VTLowLatencySuperResolutionScalerParameters,
            destinationBuffer: CVPixelBuffer,
            config _: VTLowLatencySuperResolutionScalerConfiguration
        ) -> CVPixelBuffer? {
            guard let processor = frameProcessor else {
                return nil
            }

            final nonisolated class ResultBox: @unchecked Sendable {
                private let lock = NSLock()
                private var result: CVPixelBuffer?
                private var error: Error?

                func setResult(_ buffer: CVPixelBuffer) {
                    lock.lock()
                    result = buffer
                    lock.unlock()
                }

                func setError(_ error: Error) {
                    lock.lock()
                    self.error = error
                    lock.unlock()
                }

                func snapshot() -> (CVPixelBuffer?, Error?) {
                    lock.lock()
                    defer { lock.unlock() }
                    return (result, error)
                }
            }

            // 将 process 所需参数打包为 Sendable，供 Task 闭包捕获，避免「sending 闭包」对多个 non-Sendable 捕获的 data race 警告。
            final nonisolated class SyncProcessContext: @unchecked Sendable {
                let processor: VTFrameProcessor
                let parameters: VTLowLatencySuperResolutionScalerParameters
                let destinationBuffer: CVPixelBuffer
                init(
                    processor: VTFrameProcessor,
                    parameters: VTLowLatencySuperResolutionScalerParameters,
                    destinationBuffer: CVPixelBuffer
                ) {
                    self.processor = processor
                    self.parameters = parameters
                    self.destinationBuffer = destinationBuffer
                }
            }

            let box = ResultBox()
            let semaphore = DispatchSemaphore(value: 0)
            let ctx = SyncProcessContext(
                processor: processor, parameters: parameters, destinationBuffer: destinationBuffer
            )

            let task = Task { [box, ctx] in
                do {
                    try await ctx.processor.process(parameters: ctx.parameters)
                    box.setResult(ctx.destinationBuffer)
                } catch {
                    box.setError(error)
                }
                semaphore.signal()
            }

            let waitResult = semaphore.wait(timeout: .now() + .seconds(2))
            if waitResult == .timedOut {
                task.cancel()
                resetSuperResolutionSessionOnQueue()
                cinemoreLog(level: .debug, "SystemML syncProcess 超时（2s），VT process 未在时限内完成")
                return nil
            }
            let (result, thrown) = box.snapshot()
            if let thrown {
                if let nsErr = thrown as NSError?, nsErr.domain == "VTFrameProcessorErrorDomain" {
                    // -19730: processWithSourceFrame failed（未公开含义，常见于输入格式/设备或系统不支持实际超分时）
                    let hint =
                        (nsErr.code == -19730) ? " 可能为设备/格式不支持 LLSRS 实际处理，已走非 ML 放大 fallback" : ""
                    cinemoreLog(
                        level: .debug,
                        "SystemML syncProcess VT process 抛出错误: \(thrown.localizedDescription) | domain=\(nsErr.domain) code=\(nsErr.code)\(hint)"
                    )
                } else if let nsErr = thrown as NSError? {
                    cinemoreLog(
                        level: .debug,
                        "SystemML syncProcess VT process 抛出错误: \(thrown.localizedDescription) | domain=\(nsErr.domain) code=\(nsErr.code)"
                    )
                } else {
                    cinemoreLog(
                        level: .debug,
                        "SystemML syncProcess VT process 抛出错误: \(thrown.localizedDescription)"
                    )
                }
                return nil
            }
            return result
        }

        private func resetSuperResolutionSessionOnQueue() {
            abConversionCache.reset()
            abResources = nil
            frameProcessor?.endSession()
            frameProcessor = nil
            configuration = nil
            pixelBufferPool = nil
            if let session = pixelTransferSession {
                VTPixelTransferSessionInvalidate(session)
            }
            pixelTransferSession = nil
            sourcePixelBufferPool = nil
            inputDimensions = nil
        }

        private func resetLLFISessionOnQueue() {
            llfiProcessor?.endSession()
            llfiProcessor = nil
            llfiConfiguration = nil
            llfiPixelBufferPool = nil
            clearCachedLLFICurrentSourceOnQueue()
            if let session = llfiCopyTransferSession {
                VTPixelTransferSessionInvalidate(session)
            }
            llfiCopyTransferSession = nil
            llfiCopyPixelBufferPool = nil
            if let session = llfiPixelTransferSession {
                VTPixelTransferSessionInvalidate(session)
            }
            llfiPixelTransferSession = nil
            llfiSourcePixelBufferPool = nil
            llfiInputDimensions = nil
        }

        private func clearCachedLLFICurrentSourceOnQueue() {
            cachedLLFICurrentSourceOriginal = nil
            cachedLLFICurrentSourceTransferred = nil
        }
    }

    nonisolated struct VTInterpolationDowngradeTracker {
        private var consecutiveTimeouts = 0
        mutating func record(_ outcome: TemporalReorderBuffer.DeadlineOutcome, numFrames: Int) -> Bool {
            guard numFrames > 1 else {
                consecutiveTimeouts = 0; return false
            }
            switch outcome {
            case .timedOut: consecutiveTimeouts += 1
            case .completed: consecutiveTimeouts = 0
            case .notAttempted,
                 .busy: break
            }
            if consecutiveTimeouts >= 3 {
                consecutiveTimeouts = 0; return true
            }
            return false
        }
    }

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    private final nonisolated class SystemVideoEnhancementTemporalProcessor: VideoFrameProcessor,
        @unchecked Sendable
    {
        private let adapter: SystemVideoEnhancementAdapter
        private let scalar: Int
        private var numFrames: Int
        private var downgradeTracker = VTInterpolationDowngradeTracker()
        private let onDowngrade: @Sendable () -> Void
        private let buffer = TemporalReorderBuffer()

        init(
            adapter: SystemVideoEnhancementAdapter,
            scalar: Int,
            numFrames: Int,
            onDowngrade: @escaping @Sendable () -> Void
        ) {
            self.adapter = adapter
            self.scalar = scalar
            self.numFrames = numFrames
            self.onDowngrade = onDowngrade
        }

        // scalar 当前被 VideoPlayerModel 硬编码为 1，走 .standard 预算。
        // 若以后恢复 scalar=2（Apple LLFI 能同时做 spatial upscale + temporal 插帧），
        // 把 hint 改回 `scalar >= 2 ? .heavy : .standard` 即可。

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            // 仅在无法用播放时钟推算期限时采用此兜底：VT 1080p 实测约 22ms，
            // 半帧预算会误丢原本能实时完成的结果；正常时钟路径不受此 40ms 上限限制。
            let result = buffer.acceptWithDeadline(ctx, fallbackBudgetFraction: 0.9, fallbackMaximumWait: 0.040) { [
                adapter,
                scalar,
                numFrames
            ] previous, current in
                adapter.processTemporalFrames(
                    previous: previous,
                    current: current,
                    scalar: scalar,
                    numFrames: numFrames
                )
            }
            // 忙时跳过不算新超时；连续三次实际计算超时才降到一帧。
            if downgradeTracker.record(buffer.lastDeadlineOutcome, numFrames: numFrames) {
                numFrames = 1
                onDowngrade()
            }
            return result
        }

        func onInvalidate(newGeneration _: Int64) {
            buffer.onInvalidate()
            downgradeTracker = VTInterpolationDowngradeTracker()
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

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    extension SystemVideoEnhancementAdapter {
        nonisolated func makeTemporalProcessor(
            scalar: Int,
            numFrames: Int,
            onDowngrade: @escaping @Sendable () -> Void = {}
        ) -> any VideoFrameProcessor {
            SystemVideoEnhancementTemporalProcessor(
                adapter: self,
                scalar: scalar,
                numFrames: numFrames,
                onDowngrade: onDowngrade
            )
        }
    }

    /// 按 VT process(parameters) 的 yield 顺序收集输出，匹配调用方目标时直接持有，否则逐帧拷贝。
    /// 保证播放顺序与时间轴一致，避免「旧画面被后播」的来回抖动。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    private final nonisolated class LLFICollectorHolder: @unchecked Sendable {
        let processor: VTFrameProcessor
        let parameters: VTLowLatencyFrameInterpolationParameters
        let destinationBuffers: [CVPixelBuffer]
        let copyPool: CVPixelBufferPool
        let copyTransferSession: VTPixelTransferSession
        var frames: [(CVPixelBuffer, CMTime)] = []
        var error: Error?
        var copyElapsedNanos: UInt64 = 0
        let semaphore = DispatchSemaphore(value: 0)
        private var task: Task<Void, Never>?

        init(
            processor: VTFrameProcessor,
            parameters: VTLowLatencyFrameInterpolationParameters,
            destinationBuffers: [CVPixelBuffer],
            copyPool: CVPixelBufferPool,
            copyTransferSession: VTPixelTransferSession
        ) {
            self.processor = processor
            self.parameters = parameters
            self.destinationBuffers = destinationBuffers
            self.copyPool = copyPool
            self.copyTransferSession = copyTransferSession
        }

        func runCollect() {
            task = Task {
                do {
                    for try await readOnlyFrame in processor.process(parameters: parameters) {
                        let pts = readOnlyFrame.timeStamp
                        readOnlyFrame.frame.withUnsafeBuffer { source in
                            // 只持有调用方已拥有、且与 yield 对象相同的目标；借用对象本身不逃逸。
                            if let owned = destinationBuffers.first(where: { $0 === source }) {
                                frames.append((owned, pts))
                                return
                            }
                            // 系统返回其他对象时保留原拷贝路径，输出顺序始终跟随 yield。
                            let copyStart = DispatchTime.now().uptimeNanoseconds
                            var copyBuffer: CVPixelBuffer?
                            guard CVPixelBufferPoolCreatePixelBuffer(nil, copyPool, &copyBuffer)
                                == kCVReturnSuccess,
                                let copyBuffer,
                                VTPixelTransferSessionTransferImage(
                                    copyTransferSession, from: source, to: copyBuffer
                                ) == noErr
                            else {
                                return
                            }
                            copyElapsedNanos +=
                                DispatchTime.now().uptimeNanoseconds - copyStart
                            frames.append((copyBuffer, pts))
                        }
                    }
                } catch {
                    self.error = error
                }
                semaphore.signal()
                task = nil
            }
        }

        func cancel() {
            task?.cancel()
            task = nil
        }
    }

    /// asyncSingle 路径 processor 包装：把 `SystemVideoEnhancementAdapter.processSingleFrame` 适配到
    /// VideoFrameProcessor。并发安全（adapter 内部的 queue.sync 串行化所有 VT 调用）。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    final nonisolated class SystemVideoEnhancementSuperResolutionProcessor: VideoFrameProcessor, @unchecked Sendable {
        private let adapter: SystemVideoEnhancementAdapter
        private let scale: Double
        private let abCompareEnabled: Bool

        init(adapter: SystemVideoEnhancementAdapter, scale: Double, abCompareEnabled: Bool) {
            self.adapter = adapter
            self.scale = scale
            self.abCompareEnabled = abCompareEnabled
        }

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            guard let enhanced = adapter.processSingleFrame(
                context: ctx, scale: scale, abCompareEnabled: abCompareEnabled
            ) else {
                return .passthrough
            }
            return .replace(pixelBuffer: enhanced)
        }

        func onInvalidate(newGeneration _: Int64) {}
        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {
            adapter.endSession()
        }
    }

#else
    import CoreMedia
    import CoreVideo
    import Foundation

    /// 模拟器不提供 VTLowLatency* 类型，保留同名适配器空实现用于通过编译。
    /// 真机/正式运行时由非 simulator 分支提供完整 System ML 能力。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    final nonisolated class SystemVideoEnhancementAdapter: @unchecked Sendable {
        static let shared = SystemVideoEnhancementAdapter()

        func endSession() {}

        func processSingleFrame(
            context _: VideoFrameContext,
            scale _: Double,
            abCompareEnabled _: Bool = false
        ) -> CVPixelBuffer? {
            nil
        }

        func processTemporalFrames(
            previous _: PreviousVideoFrameSnapshot?,
            current _: VideoFrameContext,
            scalar _: Int,
            numFrames _: Int,
            onDowngrade _: @escaping @Sendable () -> Void = {}
        ) -> VideoFrameResult {
            .passthrough
        }

        @discardableResult
        func warmup(dimensions _: CMVideoDimensions, scalar _: Int, numFrames _: Int) async -> Bool {
            false
        }

        func makeTemporalProcessor(
            scalar _: Int,
            numFrames _: Int,
            onDowngrade _: @escaping @Sendable () -> Void = {}
        ) -> any VideoFrameProcessor {
            SystemVideoEnhancementTemporalProcessor()
        }
    }

    /// 模拟器侧 stub，行为与真机一致 —— processSingleFrame 永远 nil，processor 会一律 .passthrough。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    final nonisolated class SystemVideoEnhancementSuperResolutionProcessor: VideoFrameProcessor, @unchecked Sendable {
        init(adapter _: SystemVideoEnhancementAdapter, scale _: Double, abCompareEnabled _: Bool) {}
        func onFrame(_: VideoFrameContext) -> VideoFrameResult {
            .passthrough
        }

        func onInvalidate(newGeneration _: Int64) {}
        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {}
    }

    /// 模拟器侧 temporal stub，与单帧 stub 行为一致 —— 一律 .passthrough。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    private final nonisolated class SystemVideoEnhancementTemporalProcessor: VideoFrameProcessor, @unchecked Sendable {
        func onFrame(_: VideoFrameContext) -> VideoFrameResult {
            .passthrough
        }

        func onInvalidate(newGeneration _: Int64) {}
        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {}
    }
#endif
