#if !os(tvOS)
    import CoreVideo
    import Foundation
    import Metal
    import CinePlayerSDK
    @preconcurrency import VideoToolbox
    import Vision

    /// 光流补帧适配器：使用 Vision VNGenerateOpticalFlowRequest 计算相邻帧光流，Metal 着色器 warp+blend 生成中间帧，
    /// 供 temporal 帧回调 replaceMany 使用。全分辨率计算，不做缩小或模糊。
    final class OpticalFlowFrameInterpolationAdapter: @unchecked Sendable {
        static let shared = OpticalFlowFrameInterpolationAdapter()

        private let queue = DispatchQueue(label: "com.cinemore.opticalflow.adapter", qos: .userInitiated)
        private var device: MTLDevice?
        private var textureCache: CVMetalTextureCache?
        private var pipelineState: MTLComputePipelineState?
        private var library: MTLLibrary?
        private var commandQueue: MTLCommandQueue?
        private var outputPool: CVPixelBufferPool?
        private var outputPoolKey: (Int, Int)?
        private var pixelTransferSession: VTPixelTransferSession?
        /// 播放器不传上一帧时由适配器缓存；无缓存时拷贝当前帧并 passthrough。
        private var cachedPreviousForTemporal: (snapshot: PreviousVideoFrameSnapshot, generation: Int64)?

        init() {}

        /// 结束会话并释放资源。
        func endSession() {
            queue.sync {
                clearTemporalPreviousCache()
                textureCache = nil
                pipelineState = nil
                library = nil
                commandQueue = nil
                outputPool = nil
                outputPoolKey = nil
                if let session = pixelTransferSession {
                    VTPixelTransferSessionInvalidate(session)
                }
                pixelTransferSession = nil
            }
        }

        /// 时域插帧：根据 prev/curr 生成 [插值帧, 当前帧]，覆盖 [prevTs, currTs)。previous 为 nil 时用内部缓存；无缓存则拷贝当前帧并 passthrough。
        func processTemporal(
            previous: PreviousVideoFrameSnapshot?,
            current: VideoFrameContext
        ) -> VideoFrameResult {
            queue.sync {
                var shouldAdvanceCache = true
                let effectivePrevious: PreviousVideoFrameSnapshot?
                if let prev = previous {
                    effectivePrevious = prev
                } else if let cached = cachedPreviousForTemporal, cached.generation == current.generation {
                    effectivePrevious = cached.snapshot
                } else {
                    guard advanceTemporalPreviousCache(current: current) else {
                        return .passthrough
                    }
                    shouldAdvanceCache = false
                    return .passthrough
                }
                guard let prev = effectivePrevious else {
                    return .passthrough
                }
                defer {
                    if shouldAdvanceCache {
                        _ = advanceTemporalPreviousCache(current: current)
                    }
                }
                return processTemporalOnQueue(previous: prev, current: current)
            }
        }

        private func processTemporalOnQueue(
            previous: PreviousVideoFrameSnapshot,
            current: VideoFrameContext
        ) -> VideoFrameResult {
            let prevTs = previous.timestamp
            let currTs = current.timestamp
            guard currTs > prevTs else {
                return .passthrough
            }
            let width = CVPixelBufferGetWidth(current.pixelBuffer)
            let height = CVPixelBufferGetHeight(current.pixelBuffer)
            guard width > 0, height > 0 else {
                return .passthrough
            }

            guard let dev = device ?? MTLCreateSystemDefaultDevice() else {
                cinemoreLog(level: .debug, "[VFI-OF] Metal device nil")
                return .passthrough
            }
            if device == nil {
                device = dev
            }

            guard let lib = library ?? dev.makeDefaultLibrary() else {
                cinemoreLog(level: .debug, "[VFI-OF] Metal default library nil")
                return .passthrough
            }
            if library == nil {
                library = lib
            }

            guard let pipeline = pipelineState ?? makePipeline(device: dev, library: lib) else {
                return .passthrough
            }
            if pipelineState == nil {
                pipelineState = pipeline
            }

            guard let commandQueue = commandQueue ?? dev.makeCommandQueue() else {
                cinemoreLog(level: .debug, "[VFI-OF] Metal command queue nil")
                return .passthrough
            }
            if self.commandQueue == nil {
                self.commandQueue = commandQueue
            }

            guard let cache = ensureTextureCache(device: dev) else {
                return .passthrough
            }

            guard let firstBGRA = pixelBufferAsBGRA(previous.pixelBuffer, width: width, height: height),
                  let secondBGRA = pixelBufferAsBGRA(current.pixelBuffer, width: width, height: height)
            else {
                cinemoreLog(level: .debug, "[VFI-OF] pixelBufferAsBGRA failed")
                return .passthrough
            }

            guard let flowBuffer = createOpticalFlow(first: firstBGRA, second: secondBGRA) else {
                cinemoreLog(level: .debug, "[VFI-OF] createOpticalFlow failed")
                return .passthrough
            }

            guard let outBuffer = ensureOutputPool(width: width, height: height) else {
                return .passthrough
            }

            guard let cmdBuffer = commandQueue.makeCommandBuffer(),
                  let encoder = cmdBuffer.makeComputeCommandEncoder()
            else {
                return .passthrough
            }

            let firstTex = makeTextureFromPixelBuffer(firstBGRA, textureCache: cache, width: width, height: height, pixelFormat: .bgra8Unorm)
            let secondTex = makeTextureFromPixelBuffer(secondBGRA, textureCache: cache, width: width, height: height, pixelFormat: .bgra8Unorm)
            let flowTex = makeTextureFromFlowBuffer(flowBuffer, textureCache: cache, width: width, height: height)
            let outTex = makeTextureFromPixelBuffer(outBuffer, textureCache: cache, width: width, height: height, pixelFormat: .bgra8Unorm)

            guard let firstTex, let secondTex, let flowTex, let outTex else {
                cinemoreLog(level: .debug, "[VFI-OF] texture create failed")
                return .passthrough
            }

            encoder.setComputePipelineState(pipeline)
            encoder.setTexture(firstTex, index: 0)
            encoder.setTexture(secondTex, index: 1)
            encoder.setTexture(flowTex, index: 2)
            encoder.setTexture(outTex, index: 3)
            var t: Float = 0.5
            encoder.setBytes(&t, length: MemoryLayout<Float>.size, index: 0)
            let tw = pipeline.threadExecutionWidth
            let th = min(16, max(1, pipeline.maxTotalThreadsPerThreadgroup / tw))
            let threadgroups = MTLSize(
                width: (width + tw - 1) / tw,
                height: (height + th - 1) / th,
                depth: 1
            )
            encoder.dispatchThreadgroups(threadgroups, threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1))
            encoder.endEncoding()
            cmdBuffer.commit()
            cmdBuffer.waitUntilCompleted()
            if cmdBuffer.status != .completed {
                cinemoreLog(level: .debug, "[VFI-OF] Metal command buffer status \(cmdBuffer.status.rawValue)")
                return .passthrough
            }

            // 两段 duration 必须严格相加等于 (currTs - prevTs)，否则 buildTemporalFramesFromGenerated 校验失败或时间轴错位导致抖动
            let segmentDur = currTs - prevTs
            let firstDuration = segmentDur / 2
            let secondDuration = segmentDur - firstDuration
            let midTs = prevTs + firstDuration
            let generated: [GeneratedVideoFrame] = [
                GeneratedVideoFrame(pixelBuffer: outBuffer, timestamp: prevTs, duration: firstDuration),
                GeneratedVideoFrame(pixelBuffer: current.pixelBuffer, timestamp: midTs, duration: secondDuration),
            ]
            return .replaceMany(generated)
        }

        // MARK: - Private

        private func makePipeline(device: MTLDevice, library: MTLLibrary) -> MTLComputePipelineState? {
            guard let fn = library.makeFunction(name: "opticalFlowBlend") else {
                cinemoreLog(level: .debug, "[VFI-OF] opticalFlowBlend function not found")
                return nil
            }
            do {
                return try device.makeComputePipelineState(function: fn)
            } catch {
                cinemoreLog(level: .debug, "[VFI-OF] pipeline failed: \(error)")
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
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            ]
            var outRef: CVPixelBuffer?
            guard CVPixelBufferCreate(
                kCFAllocatorDefault, width, height,
                kCVPixelFormatType_32BGRA, attrs as CFDictionary, &outRef
            ) == kCVReturnSuccess, let outRef else {
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

        private func createOpticalFlow(first: CVPixelBuffer, second: CVPixelBuffer) -> CVPixelBuffer? {
            let request = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: second, orientation: .up)
            request.revision = VNGenerateOpticalFlowRequestRevision1
            request.computationAccuracy = .medium
            let handler = VNImageRequestHandler(cvPixelBuffer: first, options: [:])
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

        private func clearTemporalPreviousCache() {
            cachedPreviousForTemporal = nil
        }

        private func advanceTemporalPreviousCache(current: VideoFrameContext) -> Bool {
            clearTemporalPreviousCache()
            guard let copied = current.pixelBuffer.copy() else {
                return false
            }
            let snapshot = PreviousVideoFrameSnapshot(
                pixelBuffer: copied,
                timestamp: current.timestamp,
                duration: current.duration,
                timebaseNum: current.timebaseNum,
                timebaseDen: current.timebaseDen,
                fps: current.fps,
                generation: current.generation
            )
            cachedPreviousForTemporal = (snapshot, current.generation)
            return true
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
#endif
