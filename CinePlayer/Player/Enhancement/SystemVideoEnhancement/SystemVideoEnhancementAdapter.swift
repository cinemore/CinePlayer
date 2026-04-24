#if !os(tvOS) && !targetEnvironment(simulator)
    import CoreImage
    import CoreMedia
    import CoreVideo
    import Foundation
    import CinePlayerSDK
    @preconcurrency import VideoToolbox

    /// 系统 ML 视频增强适配层：封装低延迟超分（LLSRS）与低延迟插帧（LLFI），在帧回调线程同步调用。
    /// 所有访问经内部 queue 序列化，标记为 @unchecked Sendable 以在 @Sendable 闭包中安全持有。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    nonisolated final class SystemVideoEnhancementAdapter: @unchecked Sendable {
        static let shared = SystemVideoEnhancementAdapter()

        private let queue = DispatchQueue(
            label: "com.cinemore.systemml.adapter", qos: .userInitiated
        )
        private var temporalRecv = 0
        private var temporalHit = 0
        private var temporalPassthrough = 0

        private func vfiLog(level: CinemoreLogLevel, _ message: String) {
            cinemoreLog(level: level, "[VFI-ML] \(message)")
        }

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

        // MARK: - LLFI（时域插帧，replaceMany）

        private var llfiProcessor: VTFrameProcessor?
        private var llfiConfiguration: VTLowLatencyFrameInterpolationConfiguration?
        private var llfiPixelBufferPool: CVPixelBufferPool?
        /// 拷贝 VT 插帧输出用池，按 yield 顺序收集后用于输出，避免用 destination 顺序导致画面时序错乱（旧画面被后播、来回抖动）。
        private var llfiCopyPixelBufferPool: CVPixelBufferPool?
        private var llfiCopyTransferSession: VTPixelTransferSession?
        private var llfiSourcePixelBufferPool: CVPixelBufferPool?
        private var llfiPixelTransferSession: VTPixelTransferSession?
        private var llfiInputDimensions: CMVideoDimensions?
        private var llfiScalar: Int = 1
        private var llfiNumFrames: Int = 1
        /// 播放器不再传上一帧时，由适配器自行缓存；无缓存时先拷贝当前帧再回传，下一帧即可用缓存做 previous。
        private var cachedPreviousForTemporal: (snapshot: PreviousVideoFrameSnapshot, generation: Int64)?

        /// 结束会话并释放资源。
        nonisolated func endSession() {
            queue.sync {
                clearTemporalPreviousCache()
                resetSuperResolutionSessionOnQueue()
                resetLLFISessionOnQueue()
            }
        }

        /// Warm up the LLFI session before the first temporal frame arrives.
        nonisolated func warmup(dimensions: CMVideoDimensions, scalar: Int, numFrames: Int) async {
            await Task.detached(priority: .userInitiated) { [weak self] in
                self?.queue.sync {
                    let effective = scalar == 2 ? 1 : min(3, max(1, numFrames))
                    _ = self?.ensureLLFISessionIfNeeded(
                        dimensions: dimensions,
                        scalar: scalar,
                        numFrames: effective
                    )
                }
            }.value
        }

        /// 单帧超分处理。仅应从非主线程调用（例如 asyncVideoQueue）。
        /// - Parameter abCompareEnabled: 为 true 时返回左原图、右超分的拼接 buffer，与 Anime4K A/B 对比一致。
        nonisolated func processSingleFrame(
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
        /// previous 为 nil 时使用内部缓存；无缓存或 generation 变更时拷贝当前帧并 passthrough，下一帧即有缓存可插帧。
        nonisolated func processTemporalFrames(
            previous: PreviousVideoFrameSnapshot?,
            current: VideoFrameContext,
            scalar: Int,
            numFrames: Int
        ) -> VideoFrameResult {
            queue.sync {
                temporalRecv += 1
                let seq = temporalRecv
                var shouldAdvanceCache = true
                let effectivePrevious: PreviousVideoFrameSnapshot?
                if let prev = previous {
                    effectivePrevious = prev
                } else if let cached = cachedPreviousForTemporal, cached.generation == current.generation {
                    effectivePrevious = cached.snapshot
                } else {
                    // 无缓存或 seek 后 generation 变化：拷贝当前帧作为下一段的 previous，本次 passthrough。
                    guard advanceTemporalPreviousCache(current: current) else {
                        vfiLog(level: .debug, "temporal cache copy failed, passthrough")
                        return .passthrough
                    }
                    shouldAdvanceCache = false
                    return .passthrough
                }
                guard let previous = effectivePrevious else {
                    return .passthrough
                }
                defer {
                    if shouldAdvanceCache, !advanceTemporalPreviousCache(current: current) {
                        vfiLog(level: .debug, "temporal advance cache failed, cleared")
                    }
                }
                guard current.timestamp > previous.timestamp else {
                    vfiLog(level: .debug, "temporal passthrough: current.ts <= previous.ts")
                    temporalPassthrough += 1
                    let w = CVPixelBufferGetWidth(current.pixelBuffer)
                    let h = CVPixelBufferGetHeight(current.pixelBuffer)
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: previous.timestamp,
                        currTs: current.timestamp,
                        size: "\(w)x\(h)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "nonMonotonic"
                    )
                    return .passthrough
                }
                let prevTs = previous.timestamp
                let currTs = current.timestamp
                let segmentDuration = currTs - prevTs
                guard segmentDuration > 0 else {
                    vfiLog(level: .debug, "temporal passthrough: segmentDuration<=0")
                    temporalPassthrough += 1
                    let w = CVPixelBufferGetWidth(current.pixelBuffer)
                    let h = CVPixelBufferGetHeight(current.pixelBuffer)
                    vfiTemporalStatsLogMaybe(
                        seq: seq,
                        scalar: scalar,
                        numFrames: numFrames,
                        prevTs: prevTs,
                        currTs: currTs,
                        size: "\(w)x\(h)",
                        fmt: CVPixelBufferGetPixelFormatType(current.pixelBuffer),
                        lastCollected: 0,
                        lastGenerated: 0,
                        reason: "badDuration"
                    )
                    return .passthrough
                }

                let width = CVPixelBufferGetWidth(current.pixelBuffer)
                let height = CVPixelBufferGetHeight(current.pixelBuffer)
                let dims = CMVideoDimensions(width: Int32(width), height: Int32(height))
                guard
                    let pool = ensureLLFISessionIfNeeded(
                        dimensions: dims, scalar: scalar, numFrames: numFrames
                    )
                else {
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

                // Use the previous frame timebase for the whole window to keep VT PTS math consistent with CinePlayer timeline.
                let firstPTS = CMTime(
                    value: prevTs * Int64(previous.timebaseNum), timescale: previous.timebaseDen
                )
                let lastPTS = CMTime(
                    value: currTs * Int64(previous.timebaseNum), timescale: previous.timebaseDen
                )
                guard let prevBuffer = sourceBufferForLLFI(previous.pixelBuffer),
                      let currBuffer = sourceBufferForLLFI(current.pixelBuffer),
                      let srcFrame = VTFrameProcessorFrame(
                          buffer: prevBuffer, presentationTimeStamp: firstPTS
                      ),
                      let nextFrame = VTFrameProcessorFrame(
                          buffer: currBuffer, presentationTimeStamp: lastPTS
                      )
                else {
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

                // 与 ensureLLFISessionIfNeeded 一致：scalar==2 时用 1，否则按用户 1–3 帧。
                let effectiveNumFrames = scalar == 2 ? 1 : min(3, max(1, numFrames))
                let intervals = interpolationIntervals(numFrames: effectiveNumFrames)
                guard
                    let (destinationFrames, _) = createLLFIDestinationFrames(
                        firstPTS: firstPTS,
                        lastPTS: lastPTS,
                        pool: pool,
                        scalar: scalar,
                        intervals: intervals
                    )
                else {
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

                guard let processor = llfiProcessor else {
                    return .passthrough
                }
                guard let copyPool = llfiCopyPixelBufferPool,
                      let copySession = llfiCopyTransferSession
                else {
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
                    copyPool: copyPool,
                    copyTransferSession: copySession
                )
                holder.runCollect()

                var waitResult = holder.semaphore.wait(timeout: .now() + .seconds(2))
                var framesToUse = holder.frames
                var collectError = holder.error
                var retryHolder: LLFICollectorHolder?

                if let err = collectError, err.localizedDescription.contains("not initialized") {
                    vfiLog(level: .debug, "temporal processor not initialized; wait and retry once")
                    usleep(30000)
                    let holder2 = LLFICollectorHolder(
                        processor: processor,
                        parameters: parameters,
                        copyPool: copyPool,
                        copyTransferSession: copySession
                    )
                    retryHolder = holder2
                    holder2.runCollect()
                    waitResult = holder2.semaphore.wait(timeout: .now() + .seconds(2))
                    framesToUse = holder2.frames
                    collectError = holder2.error
                }

                if waitResult == .timedOut {
                    holder.cancel()
                    retryHolder?.cancel()
                    resetLLFISessionOnQueue()
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

                // 按 VT yield 顺序使用收集到的帧（已拷贝），保证播放顺序与时间轴一致，避免「旧画面被后播」的来回抖动。
                let expectedCollected = scalar == 2 ? 1 + effectiveNumFrames : effectiveNumFrames
                if framesToUse.count != expectedCollected {
                    vfiLog(
                        level: .debug,
                        "temporal collected=\(framesToUse.count) 期望=\(expectedCollected) scalar=\(scalar) numFrames=\(numFrames) effectiveNumFrames=\(effectiveNumFrames)"
                    )
                }
                let generated = buildGeneratedFramesFromLLFIOutput(
                    collectedBuffersInOrder: framesToUse.map(\.0),
                    previousPixelBuffer: previous.pixelBuffer,
                    scalar: scalar,
                    prevTs: prevTs,
                    currTs: currTs
                )
                guard !generated.isEmpty else {
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
                  let outBuffer
            else {
                return nil
            }
            guard
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
            // LLFI does not expose the same public min/max dimension gates as super resolution.
            // Match cinemore: only check device capability here and let VT decide whether a
            // concrete frameWidth/frameHeight configuration can be created.

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
                  let outBuffer
            else {
                return nil
            }
            guard
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
            if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA {
                return buffer
            }
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            var outRef: CVPixelBuffer?
            guard
                CVPixelBufferCreate(
                    kCFAllocatorDefault, width, height,
                    kCVPixelFormatType_32BGRA, attrs as CFDictionary, &outRef
                ) == kCVReturnSuccess, let outRef
            else {
                return nil
            }
            var session: VTPixelTransferSession?
            guard
                VTPixelTransferSessionCreate(
                    allocator: kCFAllocatorDefault, pixelTransferSessionOut: &session
                ) == noErr,
                let session
            else {
                return nil
            }
            defer { VTPixelTransferSessionInvalidate(session) }
            guard VTPixelTransferSessionTransferImage(session, from: buffer, to: outRef) == noErr
            else {
                return nil
            }
            return outRef
        }

        /// 左原图、右超分拼接（CI 回退）。输出尺寸与 Anime4K 一致：(enhW, enhH)，左半/右半各占一半宽，避免窗口尺寸跳动。
        private func makeABCompareBuffer(original: CVPixelBuffer, enhanced: CVPixelBuffer)
            -> CVPixelBuffer?
        {
            let w = CVPixelBufferGetWidth(enhanced)
            let h = CVPixelBufferGetHeight(enhanced)
            let origW = CVPixelBufferGetWidth(original)
            let origH = CVPixelBufferGetHeight(original)
            let enhW = CVPixelBufferGetWidth(enhanced)
            let enhH = CVPixelBufferGetHeight(enhanced)
            let splitX = w / 2
            guard let origBGRA = pixelBufferAsBGRA(original, width: origW, height: origH),
                  let enhBGRA = pixelBufferAsBGRA(enhanced, width: enhW, height: enhH)
            else {
                return nil
            }
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: w,
                kCVPixelBufferHeightKey as String: h,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            var outBuffer: CVPixelBuffer?
            guard
                CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    w,
                    h,
                    kCVPixelFormatType_32BGRA,
                    attrs as CFDictionary,
                    &outBuffer
                ) == kCVReturnSuccess,
                let out = outBuffer
            else {
                return nil
            }
            guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
                return nil
            }
            let ciContext = CIContext(options: [.useSoftwareRenderer: false])
            let origImg = CIImage(cvPixelBuffer: origBGRA)
            let enhImg = CIImage(cvPixelBuffer: enhBGRA)

            // 与 Anime4K ABCompareSplit kernel 一致：整帧缩放后按中线取左/右，不裁原图半边再拼接。
            let origScaled = origImg.transformed(
                by: CGAffineTransform(
                    scaleX: CGFloat(w) / CGFloat(max(1, origW)),
                    y: CGFloat(h) / CGFloat(max(1, origH))
                )
            )
            let enhScaled = enhImg.transformed(
                by: CGAffineTransform(
                    scaleX: CGFloat(w) / CGFloat(max(1, enhW)),
                    y: CGFloat(h) / CGFloat(max(1, enhH))
                )
            )

            let leftRect = CGRect(x: 0, y: 0, width: splitX, height: h)
            let rightRect = CGRect(x: splitX, y: 0, width: w - splitX, height: h)
            ciContext.render(origScaled, to: out, bounds: leftRect, colorSpace: colorSpace)
            ciContext.render(enhScaled, to: out, bounds: rightRect, colorSpace: colorSpace)

            // 中线红线与 Anime4K 一致（同半宽公式）。
            let lineHalfWidth = Anime4KHostEngine.abCompareRedLineHalfWidth(outputWidth: w)
            let lineMinX = max(0, splitX - lineHalfWidth)
            let lineMaxX = min(w - 1, splitX + lineHalfWidth)
            if lineMinX <= lineMaxX {
                let redColor = CIColor(red: 1, green: 0.15, blue: 0.15, alpha: 1)
                let lineRect = CGRect(x: lineMinX, y: 0, width: lineMaxX - lineMinX + 1, height: h)
                let redImage = CIImage(color: redColor).cropped(to: lineRect)
                ciContext.render(redImage, to: out, bounds: lineRect, colorSpace: colorSpace)
            }
            return out
        }

        private func composeSuperResolutionOutput(
            original: CVPixelBuffer,
            enhanced: CVPixelBuffer,
            abCompareEnabled: Bool
        ) -> CVPixelBuffer {
            guard abCompareEnabled else {
                return enhanced
            }
            let origW = CVPixelBufferGetWidth(original)
            let origH = CVPixelBufferGetHeight(original)
            let enhW = CVPixelBufferGetWidth(enhanced)
            let enhH = CVPixelBufferGetHeight(enhanced)
            if let origBGRA = pixelBufferAsBGRA(original, width: origW, height: origH),
               let enhBGRA = pixelBufferAsBGRA(enhanced, width: enhW, height: enhH),
               let ab = Anime4KHostEngine.shared.makeABComparePixelBuffer(
                   original: origBGRA,
                   enhanced: enhBGRA
               )
            {
                return ab
            }
            if let ab = makeABCompareBuffer(original: original, enhanced: enhanced) {
                return ab
            }
            cinemoreLog(level: .debug, "SystemML makeABCompare 失败，返回单路超分")
            return enhanced
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

            final class ResultBox: @unchecked Sendable {
                private let lock = NSLock()
                nonisolated(unsafe) private var result: CVPixelBuffer?
                nonisolated(unsafe) private var error: Error?

                nonisolated func setResult(_ buffer: CVPixelBuffer) {
                    lock.lock()
                    result = buffer
                    lock.unlock()
                }

                nonisolated func setError(_ error: Error) {
                    lock.lock()
                    self.error = error
                    lock.unlock()
                }

                nonisolated func snapshot() -> (CVPixelBuffer?, Error?) {
                    lock.lock()
                    defer { lock.unlock() }
                    return (result, error)
                }
            }

            // 将 process 所需参数打包为 Sendable，供 Task 闭包捕获，避免「sending 闭包」对多个 non-Sendable 捕获的 data race 警告。
            final class SyncProcessContext: @unchecked Sendable {
                nonisolated(unsafe) let processor: VTFrameProcessor
                nonisolated(unsafe) let parameters: VTLowLatencySuperResolutionScalerParameters
                nonisolated(unsafe) let destinationBuffer: CVPixelBuffer
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

            ctx.processor.process(parameters: ctx.parameters) { _, error in
                if let error {
                    box.setError(error)
                } else {
                    box.setResult(ctx.destinationBuffer)
                }
                semaphore.signal()
            }

            let waitResult = semaphore.wait(timeout: .now() + .seconds(2))
            if waitResult == .timedOut {
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

        private func clearTemporalPreviousCache() {
            cachedPreviousForTemporal = nil
        }

        private func advanceTemporalPreviousCache(current: VideoFrameContext) -> Bool {
            clearTemporalPreviousCache()
            guard let copied = current.pixelBuffer.copy() else {
                return false
            }
            let nextSnapshot = PreviousVideoFrameSnapshot(
                pixelBuffer: copied,
                timestamp: current.timestamp,
                duration: current.duration,
                timebaseNum: current.timebaseNum,
                timebaseDen: current.timebaseDen,
                fps: current.fps,
                generation: current.generation
            )
            cachedPreviousForTemporal = (nextSnapshot, current.generation)
            return true
        }

        private func resetSuperResolutionSessionOnQueue() {
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
    }

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    nonisolated private final class SystemVideoEnhancementTemporalProcessor: VideoFrameProcessor,
        @unchecked Sendable
    {
        private let adapter: SystemVideoEnhancementAdapter
        private let scalar: Int
        private let numFrames: Int
        private let buffer = TemporalReorderBuffer()

        init(
            adapter: SystemVideoEnhancementAdapter,
            scalar: Int,
            numFrames: Int
        ) {
            self.adapter = adapter
            self.scalar = scalar
            self.numFrames = numFrames
        }

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            buffer.accept(ctx) { previous, current in
                adapter.processTemporalFrames(
                    previous: previous,
                    current: current,
                    scalar: scalar,
                    numFrames: numFrames
                )
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

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    extension SystemVideoEnhancementAdapter {
        nonisolated func makeTemporalProcessor(
            scalar: Int,
            numFrames: Int
        ) -> any VideoFrameProcessor {
            SystemVideoEnhancementTemporalProcessor(
                adapter: self,
                scalar: scalar,
                numFrames: numFrames
            )
        }
    }

    /// 按 VT process(parameters) 的 yield 顺序收集输出并逐帧拷贝，保证播放顺序与时间轴一致，避免「旧画面被后播」的来回抖动。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    nonisolated private final class LLFICollectorHolder: @unchecked Sendable {
        let processor: VTFrameProcessor
        let parameters: VTLowLatencyFrameInterpolationParameters
        let copyPool: CVPixelBufferPool
        let copyTransferSession: VTPixelTransferSession
        var frames: [(CVPixelBuffer, CMTime)] = []
        var error: Error?
        let semaphore = DispatchSemaphore(value: 0)
        private var task: Task<Void, Never>?

        init(
            processor: VTFrameProcessor,
            parameters: VTLowLatencyFrameInterpolationParameters,
            copyPool: CVPixelBufferPool,
            copyTransferSession: VTPixelTransferSession
        ) {
            self.processor = processor
            self.parameters = parameters
            self.copyPool = copyPool
            self.copyTransferSession = copyTransferSession
        }

        func runCollect() {
            task = Task {
                do {
                    for try await readOnlyFrame in processor.process(parameters: parameters) {
                        let pts = readOnlyFrame.timeStamp
                        readOnlyFrame.frame.withUnsafeBuffer { source in
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

    /// asyncSingle processor wrapper for System VT super resolution.
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    nonisolated final class SystemVideoEnhancementSuperResolutionProcessor: VideoFrameProcessor,
        @unchecked Sendable
    {
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
                context: ctx,
                scale: scale,
                abCompareEnabled: abCompareEnabled
            ) else {
                return .passthrough
            }
            return .replace(pixelBuffer: enhanced)
        }

        func onInvalidate(newGeneration _: Int64) {}

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {}
    }

#elseif !os(tvOS)
    import CoreMedia
    import CoreVideo
    import Foundation
    import CinePlayerSDK

    /// 模拟器不提供 VTLowLatency* 类型，保留同名适配器空实现用于通过编译。
    /// 真机/正式运行时由非 simulator 分支提供完整 System ML 能力。
    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    nonisolated final class SystemVideoEnhancementAdapter: @unchecked Sendable {
        static let shared = SystemVideoEnhancementAdapter()

        nonisolated func endSession() {}

        nonisolated func processSingleFrame(
            context _: VideoFrameContext,
            scale _: Double,
            abCompareEnabled _: Bool = false
        ) -> CVPixelBuffer? {
            nil
        }

        nonisolated func processTemporalFrames(
            previous _: PreviousVideoFrameSnapshot?,
            current _: VideoFrameContext,
            scalar _: Int,
            numFrames _: Int
        ) -> VideoFrameResult {
            .passthrough
        }

        nonisolated func warmup(dimensions _: CMVideoDimensions, scalar _: Int, numFrames _: Int) async {}

        nonisolated func makeTemporalProcessor(
            scalar _: Int,
            numFrames _: Int
        ) -> any VideoFrameProcessor {
            SystemVideoEnhancementTemporalProcessor()
        }
    }

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    nonisolated private final class SystemVideoEnhancementTemporalProcessor: VideoFrameProcessor,
        @unchecked Sendable
    {
        func onFrame(_: VideoFrameContext) -> VideoFrameResult {
            .passthrough
        }

        func onInvalidate(newGeneration _: Int64) {}

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {}
    }

    @available(iOS 26.0, macOS 26.0, tvOS 26.0, visionOS 26.0, *)
    nonisolated final class SystemVideoEnhancementSuperResolutionProcessor: VideoFrameProcessor,
        @unchecked Sendable
    {
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
#endif
