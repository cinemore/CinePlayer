import CinePlayerSDK
#if canImport(Metal)
    import CoreVideo
    import Foundation
    import Metal
    @preconcurrency import VideoToolbox
    import Vision
    #if canImport(MetalFX)
        @preconcurrency import MetalFX
    #endif

    /// 仅替换时域回调中的补帧算法；重排、时间轴及显示层继续由既有组件负责。
    final nonisolated class MetalFXFrameInterpolationAdapter: @unchecked Sendable {
        static let shared = MetalFXFrameInterpolationAdapter()
        private let queue = DispatchQueue(label: "cn.com.cinemore.metalfx.interpolation", qos: .userInitiated)
        private var backend: (any MetalFXInterpolationBackend)?
        private var lastProcessedTimestamp: Int64?
        /// 1080p 实测四分之一光流更快；较小输入保留二分之一，避免 Vision 小图开销回退。
        static func flowDivisor(width: Int, height: Int) -> Int {
            width * height > 1280 * 720 ? 4 : 2
        }

        static func isSupported() -> Bool {
            #if canImport(MetalFX) && !os(visionOS) && !targetEnvironment(simulator)
                if #available(macOS 26.0, iOS 26.0, tvOS 27.1, *), let device = MTLCreateSystemDefaultDevice() {
                    return MTLFXFrameInterpolatorDescriptor.supportsDevice(device)
                }
            #endif
            return false
        }

        func endSession() {
            queue.sync { backend = nil }
        }

        @discardableResult
        func warmup(dimensions: CMVideoDimensions) async -> Bool {
            await Task.detached(priority: .userInitiated) { [weak self] in
                self?.queue.sync {
                    self?.prepare(width: Int(dimensions.width), height: Int(dimensions.height))
                    return self?.backend?.prime() == true
                }
            }.value ?? false
        }

        private func prepare(width: Int, height: Int) {
            guard PlayerEnhancementModel.isVideoResolutionInMetalFXInterpolationRange(width: width, height: height) else {
                backend = nil
                return
            }
            if backend?.width == width, backend?.height == height {
                return
            }
            backend = nil
            #if canImport(MetalFX) && !os(visionOS) && !targetEnvironment(simulator)
                if #available(macOS 26.0, iOS 26.0, tvOS 27.1, *) {
                    backend = MetalFXInterpolationEngine(width: width, height: height,
                                                         flowDivisor: Self.flowDivisor(width: width, height: height))
                }
            #endif
        }

        func processTemporal(previous: PreviousVideoFrameSnapshot?, current: VideoFrameContext) -> VideoFrameResult {
            queue.sync {
                autoreleasepool {
                    if lastProcessedTimestamp != previous?.timestamp {
                        backend?.reset()
                    }
                    lastProcessedTimestamp = current.timestamp
                    guard let previous, previous.generation == current.generation,
                          current.timestamp > previous.timestamp,
                          previous.timebaseNum == current.timebaseNum,
                          previous.timebaseDen == current.timebaseDen,
                          current.timebaseNum > 0, current.timebaseDen > 0
                    else {
                        backend?.reset()
                        return .passthrough
                    }
                    let (duration, overflow) = current.timestamp.subtractingReportingOverflow(previous.timestamp)
                    guard !overflow, duration >= 2 else {
                        backend?.reset()
                        return .passthrough
                    }
                    let seconds = Double(duration) * Double(current.timebaseNum) / Double(current.timebaseDen)
                    // 长间隔不建立跨 seek / 丢帧历史，仍按原始帧时间戳输出。
                    guard seconds > 0, seconds <= 0.2 else {
                        backend?.reset()
                        return .passthrough
                    }
                    let width = CVPixelBufferGetWidth(current.pixelBuffer)
                    let height = CVPixelBufferGetHeight(current.pixelBuffer)
                    let transfer = CVBufferCopyAttachment(current.pixelBuffer, kCVImageBufferTransferFunctionKey, nil) as? String
                    guard transfer != (kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String),
                          transfer != (kCVImageBufferTransferFunction_ITU_R_2100_HLG as String),
                          CVPixelBufferGetWidth(previous.pixelBuffer) == width,
                          CVPixelBufferGetHeight(previous.pixelBuffer) == height
                    else {
                        backend?.reset()
                        return .passthrough
                    }
                    prepare(width: width, height: height)
                    guard let output = backend?.interpolate(previous: previous, current: current, seconds: seconds) else {
                        return .passthrough
                    }
                    // 保持现有 temporal 段契约；两段时长严格覆盖 [previous, current)。
                    // 原图锚定段首，MetalFX 中点图锚定半段；current 留给下一段或 drain。
                    let firstDuration = duration / 2
                    return .replaceMany([
                        GeneratedVideoFrame(pixelBuffer: previous.pixelBuffer, timestamp: previous.timestamp, duration: firstDuration),
                        GeneratedVideoFrame(
                            pixelBuffer: output,
                            timestamp: previous.timestamp + firstDuration,
                            duration: duration - firstDuration
                        ),
                    ])
                }
            }
        }

        func makeTemporalProcessor() -> any VideoFrameProcessor {
            MetalFXInterpolationProcessor(adapter: self)
        }
    }

    private nonisolated protocol MetalFXInterpolationBackend: AnyObject {
        var width: Int { get }
        var height: Int { get }
        func reset()
        func prime() -> Bool
        func interpolate(previous: PreviousVideoFrameSnapshot, current: VideoFrameContext, seconds: Double) -> CVPixelBuffer?
    }

    private final nonisolated class MetalFXInterpolationProcessor: VideoFrameProcessor, @unchecked Sendable {
        private let adapter: MetalFXFrameInterpolationAdapter
        private let buffer = TemporalReorderBuffer()

        init(adapter: MetalFXFrameInterpolationAdapter) {
            self.adapter = adapter
        }

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            buffer.acceptWithDeadline(ctx) { [adapter] previous, current in
                adapter.processTemporal(previous: previous, current: current)
            }
        }

        func onInvalidate(newGeneration _: Int64) {
            buffer.onInvalidate()
            adapter.endSession()
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

    #if canImport(MetalFX) && !os(visionOS) && !targetEnvironment(simulator)
        @available(macOS 26.0, iOS 26.0, tvOS 27.1, *)
        private final nonisolated class MetalFXInterpolationEngine: MetalFXInterpolationBackend {
            let width: Int
            let height: Int
            private let commandQueue: MTLCommandQueue
            private let cache: CVMetalTextureCache
            private let interpolator: MTLFXFrameInterpolator
            private let motion: MTLTexture
            private let depth: MTLTexture
            private let output: MTLTexture
            private let expand: MTLComputePipelineState
            private let fullPool: CVPixelBufferPool
            private let smallPool: CVPixelBufferPool
            private let transfer: VTPixelTransferSession
            private let smallTransfer: VTPixelTransferSession
            private var lastBGRA: CVPixelBuffer?
            private var lastSmall: CVPixelBuffer?
            private var lastTimestamp: Int64?
            private var generation: Int64?
            private var timebaseNum: Int32?
            private var timebaseDen: Int32?
            private var encodedPairs = 0
            private let cutSamplingStep: Int

            init?(width: Int, height: Int, flowDivisor: Int) {
                guard let device = MTLCreateSystemDefaultDevice(),
                      MTLFXFrameInterpolatorDescriptor.supportsDevice(device),
                      let queue = device.makeCommandQueue(),
                      let function = device.makeDefaultLibrary()?.makeFunction(name: "metalFXExpandMotion"),
                      let pipeline = try? device.makeComputePipelineState(function: function),
                      let fullPool = Self.pool(width: width, height: height),
                      let smallPool = Self.pool(width: max(1, width / flowDivisor), height: max(1, height / flowDivisor))
                else {
                    return nil
                }
                let descriptor = MTLFXFrameInterpolatorDescriptor()
                descriptor.inputWidth = width; descriptor.inputHeight = height
                descriptor.outputWidth = width; descriptor.outputHeight = height
                descriptor.colorTextureFormat = .bgra8Unorm; descriptor.outputTextureFormat = .bgra8Unorm
                descriptor.motionTextureFormat = .rg32Float; descriptor.depthTextureFormat = .r32Float
                guard let fx = descriptor.makeFrameInterpolator(device: device) else {
                    return nil
                }
                func texture(_ format: MTLPixelFormat, _ usage: MTLTextureUsage, _ storage: MTLStorageMode) -> MTLTexture? {
                    let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
                    d.storageMode = storage; d.usage = usage.union([.shaderRead, .shaderWrite])
                    return device.makeTexture(descriptor: d)
                }
                guard let motion = texture(.rg32Float, fx.motionTextureUsage, .private),
                      let depth = texture(.r32Float, fx.depthTextureUsage, .shared),
                      let output = texture(.bgra8Unorm, fx.outputTextureUsage, .private)
                else {
                    return nil
                }
                var cache: CVMetalTextureCache?
                var transfer: VTPixelTransferSession?
                guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess, let cache,
                      VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &transfer) == noErr, let transfer
                else {
                    return nil
                }
                // 全尺寸颜色转换与光流小图缩放分别复用会话，避免逐帧交替切换格式和尺寸。
                // 两条路径仍使用默认的 VT 转换规则，并保留完整 BGRA 快照以隔离解码缓冲复用。
                var smallTransfer: VTPixelTransferSession?
                guard VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &smallTransfer) == noErr,
                      let smallTransfer
                else {
                    VTPixelTransferSessionInvalidate(transfer)
                    return nil
                }
                self.width = width; self.height = height
                // 低分辨率输入也保留足够的直方图样本，避免稀疏采样把运动误判为切镜。
                cutSamplingStep = max(1, min(16 / flowDivisor,
                                             min((width / flowDivisor + 63) / 64, (height / flowDivisor + 35) / 36)))
                commandQueue = queue; self.cache = cache; self.transfer = transfer
                self.smallTransfer = smallTransfer
                interpolator = fx; self.motion = motion; self.depth = depth; self.output = output
                expand = pipeline; self.fullPool = fullPool; self.smallPool = smallPool
                // 普通视频没有几何深度；固定深度仅是已验证的 SDR 实验近似。
                let values = [Float](repeating: 0.5, count: width * height)
                values.withUnsafeBytes { depth.replace(
                    region: MTLRegionMake2D(0, 0, width, height),
                    mipmapLevel: 0,
                    withBytes: $0.baseAddress!,
                    bytesPerRow: width * 4
                ) }
                fx.depthTexture = depth; fx.motionTexture = motion; fx.outputTexture = output
                fx.motionVectorScaleX = 1; fx.motionVectorScaleY = 1
                fx.nearPlane = 0.1; fx.farPlane = 100; fx.fieldOfView = 60
                fx.aspectRatio = Float(width) / Float(height)
            }

            deinit {
                VTPixelTransferSessionInvalidate(transfer)
                VTPixelTransferSessionInvalidate(smallTransfer)
            }

            func prime() -> Bool {
                // 把 Vision 首次调用和 MetalFX 首次编码留在后台；黑帧及其结果不进入播放时间轴。
                guard let frame = try? EnhancementStartupProcessor.warmupFrame(
                    CMVideoDimensions(width: Int32(width), height: Int32(height))
                ) else {
                    return false
                }
                defer { reset() }
                var ready = false
                for index in 0 ..< 4 {
                    let previous = PreviousVideoFrameSnapshot(pixelBuffer: frame.pixelBuffer,
                                                              timestamp: Int64(index * 100), duration: 100, timebaseNum: 1, timebaseDen: 2400,
                                                              fps: 24, generation: -1)
                    let current = VideoFrameContext(pixelBuffer: frame.pixelBuffer,
                                                    timestamp: Int64((index + 1) * 100), duration: 100, timebaseNum: 1, timebaseDen: 2400,
                                                    fps: 24, generation: -1)
                    ready = interpolate(previous: previous, current: current, seconds: 1.0 / 24) != nil
                }
                return ready
            }

            func reset() {
                lastTimestamp = nil; generation = nil; encodedPairs = 0
                timebaseNum = nil; timebaseDen = nil
                lastBGRA = nil; lastSmall = nil
                interpolator.prevColorTexture = nil; interpolator.colorTexture = nil
            }

            func interpolate(previous: PreviousVideoFrameSnapshot, current: VideoFrameContext, seconds: Double) -> CVPixelBuffer? {
                let continuous = lastTimestamp == previous.timestamp && generation == current.generation
                    && timebaseNum == current.timebaseNum && timebaseDen == current.timebaseDen
                if !continuous {
                    reset()
                }
                var completed = false
                defer {
                    if !completed {
                        reset()
                    }
                    CVMetalTextureCacheFlush(cache, 0)
                }
                // 转换缓冲池也承担稳定快照，避免外部解码器复用 IOSurface 污染 MetalFX 历史。
                guard let first = lastBGRA ?? converted(previous.pixelBuffer, pool: fullPool, using: transfer),
                      let second = converted(current.pixelBuffer, pool: fullPool, using: transfer),
                      let smallFirst = lastSmall ?? converted(first, pool: smallPool, using: smallTransfer),
                      let smallSecond = converted(second, pool: smallPool, using: smallTransfer)
                else {
                    return nil
                }
                if Self.isSceneCut(smallFirst, smallSecond, step: cutSamplingStep) {
                    return nil
                }
                let request = VNGenerateOpticalFlowRequest(targetedCVPixelBuffer: smallFirst, orientation: .up)
                request.revision = VNGenerateOpticalFlowRequestRevision1
                request.computationAccuracy = .medium
                request.outputPixelFormat = kCVPixelFormatType_TwoComponent32Float
                do { try VNImageRequestHandler(cvPixelBuffer: smallSecond, options: [:]).perform([request]) }
                catch { return nil }
                guard let flow = request.results?.first?.pixelBuffer,
                      let destination = Self.allocate(fullPool),
                      let a = texture(first, format: .bgra8Unorm),
                      let b = texture(second, format: .bgra8Unorm),
                      let f = texture(flow, format: .rg32Float),
                      let dest = texture(destination, format: .bgra8Unorm),
                      let at = CVMetalTextureGetTexture(a), let bt = CVMetalTextureGetTexture(b),
                      let ft = CVMetalTextureGetTexture(f), let dt = CVMetalTextureGetTexture(dest),
                      let command = commandQueue.makeCommandBuffer(),
                      let encoder = command.makeComputeCommandEncoder()
                else {
                    return nil
                }
                encoder.setComputePipelineState(expand)
                encoder.setTexture(ft, index: 0); encoder.setTexture(motion, index: 1)
                let tw = expand.threadExecutionWidth
                let th = min(16, max(1, expand.maxTotalThreadsPerThreadgroup / tw))
                encoder.dispatchThreads(
                    MTLSize(width: width, height: height, depth: 1),
                    threadsPerThreadgroup: MTLSize(width: tw, height: th, depth: 1)
                )
                encoder.endEncoding()
                interpolator.prevColorTexture = at; interpolator.colorTexture = bt
                interpolator.deltaTime = Float(seconds)
                interpolator.shouldResetHistory = !continuous
                interpolator.encode(commandBuffer: command)
                guard let blit = command.makeBlitCommandEncoder() else {
                    return nil
                }
                blit.copy(from: output, to: dt); blit.endEncoding()
                command.commit()
                // CVMetalTexture 包装对象必须保留至 GPU 完成，不能只持有其 MTLTexture。
                withExtendedLifetime((a, b, f, dest)) { command.waitUntilCompleted() }
                guard command.status == .completed else {
                    return nil
                }
                lastBGRA = second; lastSmall = smallSecond
                lastTimestamp = current.timestamp; generation = current.generation
                timebaseNum = current.timebaseNum; timebaseDen = current.timebaseDen
                encodedPairs += 1; completed = true
                // 首次/重置后的前三对仅建立历史，不把复制当前帧当作有效插帧输出。
                guard encodedPairs > 3 else {
                    return nil
                }
                VideoFrameAttachments.copy(from: second, to: destination)
                VideoFrameAttachments.copyDisplayGeometry(from: current.pixelBuffer, to: destination)
                return destination
            }

            private static func pool(width: Int, height: Int) -> CVPixelBufferPool? {
                var result: CVPixelBufferPool?
                let attrs: [String: Any] = [
                    kCVPixelBufferWidthKey as String: width, kCVPixelBufferHeightKey as String: height,
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                    kCVPixelBufferMetalCompatibilityKey as String: true,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                ]
                guard CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &result) == kCVReturnSuccess else {
                    return nil
                }
                return result
            }

            private static func allocate(_ pool: CVPixelBufferPool) -> CVPixelBuffer? {
                var buffer: CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess else {
                    return nil
                }
                return buffer
            }

            private func converted(_ source: CVPixelBuffer, pool: CVPixelBufferPool, using session: VTPixelTransferSession) -> CVPixelBuffer? {
                guard let result = Self.allocate(pool),
                      VTPixelTransferSessionTransferImage(session, from: source, to: result) == noErr
                else {
                    return nil
                }
                return result
            }

            private func texture(_ buffer: CVPixelBuffer, format: MTLPixelFormat) -> CVMetalTexture? {
                var texture: CVMetalTexture?
                guard CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, format,
                                                                CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &texture) ==
                    kCVReturnSuccess
                else {
                    return nil
                }
                return texture
            }

            /// 保守地拒绝跨镜头生成；只检查输入，不猜测中间镜头或修改时间戳。
            private static func isSceneCut(_ a: CVPixelBuffer, _ b: CVPixelBuffer, step: Int) -> Bool {
                CVPixelBufferLockBaseAddress(a, .readOnly); CVPixelBufferLockBaseAddress(b, .readOnly)
                defer { CVPixelBufferUnlockBaseAddress(a, .readOnly); CVPixelBufferUnlockBaseAddress(b, .readOnly) }
                guard let pa = CVPixelBufferGetBaseAddress(a), let pb = CVPixelBufferGetBaseAddress(b) else {
                    return true
                }
                var ha = [Int](repeating: 0, count: 32), hb = ha
                var difference = 0.0, samples = 0
                for y in stride(from: 0, to: CVPixelBufferGetHeight(a), by: step) {
                    let ra = (pa + y * CVPixelBufferGetBytesPerRow(a)).assumingMemoryBound(to: UInt8.self)
                    let rb = (pb + y * CVPixelBufferGetBytesPerRow(b)).assumingMemoryBound(to: UInt8.self)
                    for x in stride(from: 0, to: CVPixelBufferGetWidth(a), by: step) {
                        let i = x * 4
                        let va = (Int(ra[i]) + Int(ra[i + 1]) + Int(ra[i + 2])) / 3
                        let vb = (Int(rb[i]) + Int(rb[i + 1]) + Int(rb[i + 2])) / 3
                        ha[min(31, va / 8)] += 1; hb[min(31, vb / 8)] += 1
                        for c in 0 ..< 3 {
                            difference += abs(Double(ra[i + c]) - Double(rb[i + c]))
                        }
                        samples += 1
                    }
                }
                let distance = Double(zip(ha, hb).reduce(0) { $0 + abs($1.0 - $1.1) }) / Double(samples * 2)
                return difference / Double(samples * 3) > 25 && distance > 0.2
            }
        }
    #endif
#endif
