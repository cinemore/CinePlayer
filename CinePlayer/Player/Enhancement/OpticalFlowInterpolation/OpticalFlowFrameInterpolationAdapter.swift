#if !os(tvOS)
    import CoreMedia
    import CoreVideo
    import Foundation
    import Metal
    import CinePlayerSDK
    @preconcurrency import VideoToolbox
    import Vision

    nonisolated struct OpticalFlowRequestKey: Hashable, Sendable {
        let previousTimestamp: Int64
        let currentTimestamp: Int64
        let generation: Int64
        let width: Int
        let height: Int
    }

    nonisolated struct OpticalFlowPair: @unchecked Sendable {
        let forwardFlow: CVPixelBuffer
        let backwardFlow: CVPixelBuffer
    }

    nonisolated final class OpticalFlowAsyncProvider: @unchecked Sendable {
        private let flowQueue = DispatchQueue(
            label: "cn.com.cinemore.opticalflow.async-provider",
            qos: .userInitiated
        )
        private let lock = NSLock()
        private let cacheLimit: Int
        private let flowRunner: @Sendable (CVPixelBuffer, CVPixelBuffer) -> OpticalFlowPair?
        private var cache: [OpticalFlowRequestKey: OpticalFlowPair] = [:]
        private var order: [OpticalFlowRequestKey] = []
        private var pending: Set<OpticalFlowRequestKey> = []
        private var resetEpoch: Int64 = 0

        init(
            maxCachedPairs: Int = 6,
            flowRunner: @escaping @Sendable (CVPixelBuffer, CVPixelBuffer) -> OpticalFlowPair?
        ) {
            cacheLimit = max(1, maxCachedPairs)
            self.flowRunner = flowRunner
        }

        nonisolated func cachedResult(for key: OpticalFlowRequestKey) -> OpticalFlowPair? {
            lock.lock()
            defer { lock.unlock() }
            return cache[key]
        }

        nonisolated func submitIfNeeded(
            key: OpticalFlowRequestKey,
            previous: CVPixelBuffer,
            current: CVPixelBuffer
        ) {
            lock.lock()
            if cache[key] != nil || pending.contains(key) {
                lock.unlock()
                return
            }
            pending.insert(key)
            let epoch = resetEpoch
            lock.unlock()

            flowQueue.async { [weak self] in
                guard let self else { return }
                let result = autoreleasepool {
                    self.flowRunner(previous, current)
                }
                self.lock.lock()
                defer { self.lock.unlock() }
                self.pending.remove(key)
                guard epoch == self.resetEpoch, let result else {
                    return
                }
                self.cache[key] = result
                self.order.removeAll { $0 == key }
                self.order.append(key)
                while self.order.count > self.cacheLimit {
                    let removed = self.order.removeFirst()
                    self.cache.removeValue(forKey: removed)
                }
            }
        }

        nonisolated func reset() {
            lock.lock()
            resetEpoch &+= 1
            cache.removeAll(keepingCapacity: false)
            order.removeAll(keepingCapacity: false)
            pending.removeAll(keepingCapacity: false)
            lock.unlock()
        }
    }

    /// 光流补帧适配器：计算前后向光流，Metal 着色器分别对 prev/next 做 backward-warp，
    /// 再用颜色 + 光流双重置信度合成中间帧，遮挡/大位移区域回退到时间上更近的一帧，
    /// 避免单向光流 + 交叉淡化导致的鬼影/双影。供 temporal 帧回调 replaceMany 使用。
    nonisolated final class OpticalFlowFrameInterpolationAdapter: @unchecked Sendable {
        static let shared = OpticalFlowFrameInterpolationAdapter()

        private let queue = DispatchQueue(label: "cn.com.cinemore.opticalflow.adapter", qos: .userInitiated)
        private var device: MTLDevice?
        private var textureCache: CVMetalTextureCache?
        private var warpPipelineState: MTLComputePipelineState?
        private var consistencyPipelineState: MTLComputePipelineState?
        private var composePipelineState: MTLComputePipelineState?
        private var library: MTLLibrary?
        private var commandQueue: MTLCommandQueue?
        private var outputPool: CVPixelBufferPool?
        private var outputPoolKey: (Int, Int)?
        private var bgraConversionPool: CVPixelBufferPool?
        private var bgraConversionPoolKey: (Int, Int)?
        private var pixelTransferSession: VTPixelTransferSession?
        private var asyncFlowProvider: OpticalFlowAsyncProvider

        // 中间纹理（compute-only，IOSurface 无关，按分辨率缓存）。
        private var warpedPrevTexture: MTLTexture?
        private var warpedNextTexture: MTLTexture?
        private var consistencyTexture: MTLTexture?
        private var intermediateTextureKey: (Int, Int)?

        /// 前后向残差的 smoothstep 中心（像素单位）。低于 0.5× 完全可信，高于 1.5× 完全不可信。
        private static let flowErrorPivot: Float = 1.5

        init() {
            asyncFlowProvider = OpticalFlowAsyncProvider { _, _ in nil }
            asyncFlowProvider = OpticalFlowAsyncProvider { [weak self] previous, current in
                self?.createOpticalFlowPair(source: previous, target: current)
            }
        }

        /// 结束会话并释放资源。
        nonisolated func endSession() {
            queue.sync {
                textureCache = nil
                warpPipelineState = nil
                consistencyPipelineState = nil
                composePipelineState = nil
                library = nil
                commandQueue = nil
                outputPool = nil
                outputPoolKey = nil
                bgraConversionPool = nil
                bgraConversionPoolKey = nil
                warpedPrevTexture = nil
                warpedNextTexture = nil
                consistencyTexture = nil
                intermediateTextureKey = nil
                if let session = pixelTransferSession {
                    VTPixelTransferSessionInvalidate(session)
                }
                pixelTransferSession = nil
                asyncFlowProvider.reset()
            }
        }

        /// Center 首帧前预热：在 user-initiated 后台线程提前完成 Metal device/library/pipelineState/commandQueue/textureCache 初始化。
        /// `dimensions` 仅作为接口对称参数（OF 流水线本身不依赖；textureCache 不需要尺寸）。
        nonisolated func warmup(dimensions _: CMVideoDimensions) async {
            await Task.detached(priority: .userInitiated) { [weak self] in
                self?.queue.sync {
                    _ = self?.ensureMetalResourcesOnQueue()
                }
            }.value
        }

        /// 时域插帧：根据 prev/curr 生成 [插值帧, 当前帧]，覆盖 [prevTs, currTs)。previous 由 Center 填充；为 nil 直接 passthrough（Center 走兜底保形）。
        nonisolated func processTemporal(
            previous: PreviousVideoFrameSnapshot?,
            current: VideoFrameContext
        ) -> VideoFrameResult {
            queue.sync {
                guard let previous else {
                    return .passthrough
                }
                guard current.timestamp > previous.timestamp else {
                    return .passthrough
                }
                return processTemporalOnQueue(previous: previous, current: current)
            }
        }

        nonisolated func resetPrefetchCache() {
            asyncFlowProvider.reset()
        }

        nonisolated func prefetchFlow(
            previous: PreviousVideoFrameSnapshot,
            currentPixelBuffer: CVPixelBuffer,
            currentTimestamp: Int64,
            generation: Int64
        ) {
            let width = CVPixelBufferGetWidth(currentPixelBuffer)
            let height = CVPixelBufferGetHeight(currentPixelBuffer)
            guard width > 0, height > 0, currentTimestamp > previous.timestamp else {
                return
            }
            let key = OpticalFlowRequestKey(
                previousTimestamp: previous.timestamp,
                currentTimestamp: currentTimestamp,
                generation: generation,
                width: width,
                height: height
            )
            asyncFlowProvider.submitIfNeeded(
                key: key,
                previous: previous.pixelBuffer,
                current: currentPixelBuffer
            )
        }

        private func processTemporalOnQueue(
            previous: PreviousVideoFrameSnapshot,
            current: VideoFrameContext
        ) -> VideoFrameResult {
            // 每帧用 autoreleasepool 包裹:Swift + GCD queue.sync 不会自动 drain Obj-C autorelease pool,
            // Metal/Vision/VTPixelTransfer 产生的临时 IOSurface 引用会累积到 per-client 16384 配额触顶。
            autoreleasepool {
                let totalStart = DispatchTime.now().uptimeNanoseconds
                let prevTs = previous.timestamp
                let currTs = current.timestamp
                guard currTs > prevTs else {
                    return .passthrough
                }

                // 整数 timebase 源(1 tick/帧,例如 720x480 DVD 级)segmentDur=1,无法切两半插帧。
                // 输出单帧 anchor 段覆盖 [prevTs, currTs),时间线连续、降级为 1x fps,不运行 Vision/Metal。
                let segmentDur = currTs - prevTs
                guard segmentDur >= 2 else {
                    let generated: [GeneratedVideoFrame] = [
                        GeneratedVideoFrame(pixelBuffer: current.pixelBuffer, timestamp: prevTs, duration: segmentDur),
                    ]
                    return .replaceMany(generated)
                }

                let width = CVPixelBufferGetWidth(current.pixelBuffer)
                let height = CVPixelBufferGetHeight(current.pixelBuffer)
                guard width > 0, height > 0 else {
                    return .passthrough
                }

                guard let resources = ensureMetalResourcesOnQueue() else {
                    return .passthrough
                }
                let warpPipeline = resources.warpPipeline
                let consistencyPipeline = resources.consistencyPipeline
                let composePipeline = resources.composePipeline
                let commandQueue = resources.commandQueue
                let cache = resources.textureCache

                // 函数退出时强制 flush Metal 纹理缓存:CVMetalTextureCache 内部会按 IOSurface 缓存
                // 纹理对象,不 flush 就会留存本帧用到的输入/flow/输出 IOSurface 引用。
                defer { CVMetalTextureCacheFlush(cache, 0) }

                guard let firstBGRA = pixelBufferAsBGRA(previous.pixelBuffer, width: width, height: height),
                      let secondBGRA = pixelBufferAsBGRA(current.pixelBuffer, width: width, height: height)
                else {
                    cinemoreLog(level: .debug, "[VFI-OF] pixelBufferAsBGRA failed")
                    return .passthrough
                }

                let requestKey = OpticalFlowRequestKey(
                    previousTimestamp: prevTs,
                    currentTimestamp: currTs,
                    generation: current.generation,
                    width: width,
                    height: height
                )
                let visionStart = DispatchTime.now().uptimeNanoseconds
                let flowPair =
                    asyncFlowProvider.cachedResult(for: requestKey)
                    ?? createOpticalFlowPair(source: firstBGRA, target: secondBGRA)
                guard let flowPair else {
                    cinemoreLog(level: .debug, "[VFI-OF] optical flow pair unavailable")
                    return .passthrough
                }
                let visionMs = Double(DispatchTime.now().uptimeNanoseconds - visionStart) / 1_000_000

                guard let outBuffer = ensureOutputPool(width: width, height: height) else {
                    return .passthrough
                }
                current.pixelBuffer.copyPropagatedAttachments(to: outBuffer)

                guard let (warpedPrev, warpedNext, consistency) = ensureIntermediateTextures(width: width, height: height, device: resources.device)
                else {
                    cinemoreLog(level: .debug, "[VFI-OF] intermediate textures alloc failed")
                    return .passthrough
                }

                let firstTex = makeTextureFromPixelBuffer(firstBGRA, textureCache: cache, width: width, height: height, pixelFormat: .bgra8Unorm)
                let secondTex = makeTextureFromPixelBuffer(secondBGRA, textureCache: cache, width: width, height: height, pixelFormat: .bgra8Unorm)
                let forwardFlowTex = makeTextureFromFlowBuffer(flowPair.forwardFlow, textureCache: cache, width: width, height: height)
                let backwardFlowTex = makeTextureFromFlowBuffer(flowPair.backwardFlow, textureCache: cache, width: width, height: height)
                let outTex = makeTextureFromPixelBuffer(outBuffer, textureCache: cache, width: width, height: height, pixelFormat: .bgra8Unorm)

                guard let firstTex, let secondTex, let forwardFlowTex, let backwardFlowTex, let outTex else {
                    cinemoreLog(level: .debug, "[VFI-OF] texture create failed")
                    return .passthrough
                }

                guard let cmdBuffer = commandQueue.makeCommandBuffer(),
                      let encoder = cmdBuffer.makeComputeCommandEncoder()
                else {
                    return .passthrough
                }

                // t=0.5 正中插值；scale 分别为 t 和 (1-t)。
                let t: Float = 0.5
                let prevWarpScale: Float = t
                let nextWarpScale: Float = 1.0 - t

                /// 三个 pipeline 的 threadgroup 尺寸略有差异，按各自的 threadExecutionWidth 取。
                func dispatch(pipeline: MTLComputePipelineState) {
                    let tw = pipeline.threadExecutionWidth
                    let th = min(16, max(1, pipeline.maxTotalThreadsPerThreadgroup / tw))
                    let groups = MTLSize(
                        width: (width + tw - 1) / tw,
                        height: (height + th - 1) / th,
                        depth: 1
                    )
                    encoder.dispatchThreadgroups(groups, threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
                }

                // 1) warp prev: forward flow × t
                encoder.setComputePipelineState(warpPipeline)
                encoder.setTexture(firstTex, index: 0)
                encoder.setTexture(forwardFlowTex, index: 1)
                encoder.setTexture(warpedPrev, index: 2)
                var prevScale = prevWarpScale
                encoder.setBytes(&prevScale, length: MemoryLayout<Float>.size, index: 0)
                dispatch(pipeline: warpPipeline)

                // 2) warp next: backward flow × (1 - t)
                encoder.setTexture(secondTex, index: 0)
                encoder.setTexture(backwardFlowTex, index: 1)
                encoder.setTexture(warpedNext, index: 2)
                var nextScale = nextWarpScale
                encoder.setBytes(&nextScale, length: MemoryLayout<Float>.size, index: 0)
                dispatch(pipeline: warpPipeline)

                // 3) 前后向一致性（与 warp 无依赖，可同 encoder）
                encoder.setComputePipelineState(consistencyPipeline)
                encoder.setTexture(forwardFlowTex, index: 0)
                encoder.setTexture(backwardFlowTex, index: 1)
                encoder.setTexture(consistency, index: 2)
                dispatch(pipeline: consistencyPipeline)

                // compose 读 warpedPrev/warpedNext/consistency，必须等上面三次写入完成。
                encoder.memoryBarrier(scope: .textures)

                // 4) compose：颜色 + 光流双重置信度，低置信度区域退回到未 warp 的
                // prev/next 交叉淡化（对称，不会在 t=0.5 偏向某帧）。
                encoder.setComputePipelineState(composePipeline)
                encoder.setTexture(warpedPrev, index: 0)
                encoder.setTexture(warpedNext, index: 1)
                encoder.setTexture(firstTex, index: 2)
                encoder.setTexture(secondTex, index: 3)
                encoder.setTexture(consistency, index: 4)
                encoder.setTexture(outTex, index: 5)
                var composeT = t
                var pivot = Self.flowErrorPivot
                encoder.setBytes(&composeT, length: MemoryLayout<Float>.size, index: 0)
                encoder.setBytes(&pivot, length: MemoryLayout<Float>.size, index: 1)
                dispatch(pipeline: composePipeline)

                encoder.endEncoding()
                cmdBuffer.commit()
                cmdBuffer.waitUntilCompleted()
                if cmdBuffer.status != .completed {
                    cinemoreLog(level: .debug, "[VFI-OF] Metal command buffer status \(cmdBuffer.status.rawValue)")
                    return .passthrough
                }

                // 两段 duration 必须严格相加等于 (currTs - prevTs),否则 buildTemporalFramesFromGenerated 校验失败或时间轴错位导致抖动。
                // segmentDur >= 2 的前提在函数开头已保证。
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
                    "[VFI-OF] diag total=\(String(format: "%.1f", totalMs))ms vision2x=\(String(format: "%.1f", visionMs))ms metal=\(String(format: "%.1f", totalMs - visionMs))ms \(width)x\(height)"
                )
                return .replaceMany(generated)
            }
        }

        // MARK: - Private

        private struct MetalResources {
            let device: MTLDevice
            let library: MTLLibrary
            let warpPipeline: MTLComputePipelineState
            let consistencyPipeline: MTLComputePipelineState
            let composePipeline: MTLComputePipelineState
            let commandQueue: MTLCommandQueue
            let textureCache: CVMetalTextureCache
        }

        /// 懒加载 Metal device/library/pipeline/commandQueue/textureCache。warmup 与 processTemporalOnQueue 共用。
        private func ensureMetalResourcesOnQueue() -> MetalResources? {
            guard let dev = device ?? MTLCreateSystemDefaultDevice() else {
                cinemoreLog(level: .debug, "[VFI-OF] Metal device nil")
                return nil
            }
            if device == nil {
                device = dev
            }

            guard let lib = library ?? dev.makeDefaultLibrary() else {
                cinemoreLog(level: .debug, "[VFI-OF] Metal default library nil")
                return nil
            }
            if library == nil {
                library = lib
            }

            guard let warpPipe = warpPipelineState ?? makePipeline(device: dev, library: lib, function: "opticalFlowWarp") else {
                return nil
            }
            if warpPipelineState == nil {
                warpPipelineState = warpPipe
            }

            guard let consistencyPipe = consistencyPipelineState ?? makePipeline(device: dev, library: lib, function: "opticalFlowConsistency") else {
                return nil
            }
            if consistencyPipelineState == nil {
                consistencyPipelineState = consistencyPipe
            }

            guard let composePipe = composePipelineState ?? makePipeline(device: dev, library: lib, function: "opticalFlowCompose") else {
                return nil
            }
            if composePipelineState == nil {
                composePipelineState = composePipe
            }

            guard let cmdQueue = commandQueue ?? dev.makeCommandQueue() else {
                cinemoreLog(level: .debug, "[VFI-OF] Metal command queue nil")
                return nil
            }
            if commandQueue == nil {
                commandQueue = cmdQueue
            }

            guard let cache = ensureTextureCache(device: dev) else {
                return nil
            }

            return MetalResources(
                device: dev,
                library: lib,
                warpPipeline: warpPipe,
                consistencyPipeline: consistencyPipe,
                composePipeline: composePipe,
                commandQueue: cmdQueue,
                textureCache: cache
            )
        }

        private func makePipeline(device: MTLDevice, library: MTLLibrary, function: String) -> MTLComputePipelineState? {
            guard let fn = library.makeFunction(name: function) else {
                cinemoreLog(level: .debug, "[VFI-OF] \(function) function not found")
                return nil
            }
            do {
                return try device.makeComputePipelineState(function: fn)
            } catch {
                cinemoreLog(level: .debug, "[VFI-OF] pipeline \(function) failed: \(error)")
                return nil
            }
        }

        private func ensureTextureCache(device: MTLDevice) -> CVMetalTextureCache? {
            if let cache = textureCache {
                return cache
            }
            var cache: CVMetalTextureCache?
            guard CVMetalTextureCacheCreate(
                kCFAllocatorDefault,
                nil,
                device,
                nil,
                &cache
            ) == kCVReturnSuccess, let cache else {
                return nil
            }
            textureCache = cache
            return cache
        }

        /// 按 (width, height) 缓存 warpedPrev/warpedNext（BGRA8Unorm）与 consistency（R16Float），
        /// 全部 storage=.private，shaderRead+shaderWrite，只在 GPU 内部流转，不走 IOSurface。
        private func ensureIntermediateTextures(
            width: Int,
            height: Int,
            device: MTLDevice
        ) -> (MTLTexture, MTLTexture, MTLTexture)? {
            let key = (width, height)
            if let existing = intermediateTextureKey, existing == key,
               let a = warpedPrevTexture, let b = warpedNextTexture, let c = consistencyTexture
            {
                return (a, b, c)
            }

            let bgraDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            bgraDesc.usage = [.shaderRead, .shaderWrite]
            bgraDesc.storageMode = .private

            let consistencyDesc = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .r16Float,
                width: width,
                height: height,
                mipmapped: false
            )
            consistencyDesc.usage = [.shaderRead, .shaderWrite]
            consistencyDesc.storageMode = .private

            guard let a = device.makeTexture(descriptor: bgraDesc),
                  let b = device.makeTexture(descriptor: bgraDesc),
                  let c = device.makeTexture(descriptor: consistencyDesc)
            else {
                return nil
            }
            warpedPrevTexture = a
            warpedNextTexture = b
            consistencyTexture = c
            intermediateTextureKey = key
            return (a, b, c)
        }

        private func ensureOutputPool(width: Int, height: Int) -> CVPixelBuffer? {
            let key = (width, height)
            if let existingKey = outputPoolKey, existingKey == key, let pool = outputPool {
                var buf: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess, let buf else {
                    return nil
                }
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
                  let pool
            else {
                return nil
            }
            outputPool = pool
            outputPoolKey = key
            var buf: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess, let buf else {
                return nil
            }
            return buf
        }

        private func pixelBufferAsBGRA(_ buffer: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
            if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA {
                return buffer
            }
            // 通过 CVPixelBufferPool 回收 BGRA 转换缓冲:原先 CVPixelBufferCreate 每帧分 2 个 IOSurface,
            // 触达 per-client 16384 上限后解码器级联失败。池化后 IOSurface 数量与在飞数量线性相关。
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
                  let newSession
            else {
                return nil
            }
            pixelTransferSession = newSession
            guard VTPixelTransferSessionTransferImage(newSession, from: buffer, to: outRef) == noErr else {
                return nil
            }
            return outRef
        }

        private func ensureBGRAConversionBuffer(width: Int, height: Int) -> CVPixelBuffer? {
            let key = (width, height)
            if let existingKey = bgraConversionPoolKey, existingKey == key, let pool = bgraConversionPool {
                var buf: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess, let buf else {
                    return nil
                }
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
                  let pool
            else {
                return nil
            }
            bgraConversionPool = pool
            bgraConversionPoolKey = key
            var buf: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &buf) == kCVReturnSuccess, let buf else {
                return nil
            }
            return buf
        }

        private func createOpticalFlowPair(
            source: CVPixelBuffer,
            target: CVPixelBuffer
        ) -> OpticalFlowPair? {
            guard let forwardFlow = createOpticalFlow(source: source, target: target) else {
                cinemoreLog(level: .debug, "[VFI-OF] forward flow failed")
                return nil
            }
            guard let backwardFlow = createOpticalFlow(source: target, target: source) else {
                cinemoreLog(level: .debug, "[VFI-OF] backward flow failed")
                return nil
            }
            return OpticalFlowPair(forwardFlow: forwardFlow, backwardFlow: backwardFlow)
        }

        /// 单向光流：source → target 的像素位移场（RG32Float）。
        private func createOpticalFlow(source: CVPixelBuffer, target: CVPixelBuffer) -> CVPixelBuffer? {
            // autoreleasepool 强制 drain Vision 内部临时 IOSurface；
            // 否则 Swift + GCD queue.sync 不会在 block 结束时 drain Obj-C autorelease pool，
            // float 光流 buffer 持续累积会触发 per-client 16384 IOSurface 配额上限。
            autoreleasepool {
                let request = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: target, orientation: .up)
                request.revision = VNGenerateOpticalFlowRequestRevision1
                request.computationAccuracy = .medium
                let handler = VNImageRequestHandler(cvPixelBuffer: source, options: [:])
                do {
                    try handler.perform([request])
                } catch {
                    cinemoreLog(level: .debug, "[VFI-OF] VNGenerateOpticalFlowRequest error: \(error)")
                    return nil
                }
                guard let observation = request.results?.first else {
                    return nil
                }
                return observation.pixelBuffer
            }
        }

        private func makeTextureFromPixelBuffer(
            _ buffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            width: Int,
            height: Int,
            pixelFormat: MTLPixelFormat
        ) -> MTLTexture? {
            var cvTex: CVMetalTexture?
            let err = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                buffer,
                nil,
                pixelFormat,
                width,
                height,
                0,
                &cvTex
            )
            guard err == kCVReturnSuccess, let cvTex else {
                return nil
            }
            return CVMetalTextureGetTexture(cvTex)
        }

        private func makeTextureFromFlowBuffer(
            _ buffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            width: Int,
            height: Int
        ) -> MTLTexture? {
            var cvTex: CVMetalTexture?
            let err = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                buffer,
                nil,
                .rg32Float,
                width,
                height,
                0,
                &cvTex
            )
            guard err == kCVReturnSuccess, let cvTex else {
                return nil
            }
            return CVMetalTextureGetTexture(cvTex)
        }
    }

    nonisolated private final class OpticalFlowTemporalProcessor: VideoFrameProcessor, @unchecked Sendable {
        private let adapter: OpticalFlowFrameInterpolationAdapter
        private let buffer = TemporalReorderBuffer()
        private var lastPrefetchSnapshot: PreviousVideoFrameSnapshot?

        init(adapter: OpticalFlowFrameInterpolationAdapter) {
            self.adapter = adapter
        }

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            prefetchIfPossible(next: ctx)
            lastPrefetchSnapshot = makePrefetchSnapshot(from: ctx)
            return buffer.accept(ctx) { previous, current in
                adapter.processTemporal(previous: previous, current: current)
            }
        }

        func onInvalidate(newGeneration _: Int64) {
            lastPrefetchSnapshot = nil
            buffer.onInvalidate()
            adapter.resetPrefetchCache()
        }

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            buffer.drainPendingFrames()
        }

        func onDrain() {
            lastPrefetchSnapshot = nil
            buffer.onDrain()
            adapter.endSession()
        }

        var hasPendingFrames: Bool {
            buffer.hasPendingFrames
        }

        private func prefetchIfPossible(next ctx: VideoFrameContext) {
            guard let previous = lastPrefetchSnapshot,
                  previous.generation == ctx.generation,
                  ctx.timestamp > previous.timestamp
            else {
                return
            }
            let currentCopy = ctx.pixelBuffer.copy() ?? ctx.pixelBuffer
            adapter.prefetchFlow(
                previous: previous,
                currentPixelBuffer: currentCopy,
                currentTimestamp: ctx.timestamp,
                generation: ctx.generation
            )
        }

        private func makePrefetchSnapshot(from ctx: VideoFrameContext) -> PreviousVideoFrameSnapshot {
            let stablePixelBuffer = ctx.pixelBuffer.copy() ?? ctx.pixelBuffer
            return PreviousVideoFrameSnapshot(
                pixelBuffer: stablePixelBuffer,
                timestamp: ctx.timestamp,
                duration: ctx.duration,
                timebaseNum: ctx.timebaseNum,
                timebaseDen: ctx.timebaseDen,
                fps: ctx.fps,
                generation: ctx.generation
            )
        }
    }

    extension OpticalFlowFrameInterpolationAdapter {
        nonisolated func makeTemporalProcessor() -> any VideoFrameProcessor {
            OpticalFlowTemporalProcessor(adapter: self)
        }
    }
#endif
