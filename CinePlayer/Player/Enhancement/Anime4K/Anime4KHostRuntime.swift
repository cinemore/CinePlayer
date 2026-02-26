import CoreVideo
import Foundation
import Metal
import QuartzCore
import VideoToolbox
import CinePlayerSDK

#if !os(tvOS)
    fileprivate extension Anime4KPreset {
        var callbackPreset: FrameCallbackPreset {
            .aggressive
        }

        var shaderProgram: Anime4KShaderProgram {
            Anime4KShaderCatalog.program(for: self)
        }
    }

    private enum Anime4KShaderCatalog {
        private static func stageFiles(for preset: Anime4KPreset) -> [String] {
            // Official Anime4K 链：Fast = 低档 M/S（iOS + 低端 Mac），HQ = 高档 VL/M（仅 macOS）。
            switch preset {
            case .modeAFast:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_M.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
                ]
            case .modeBFast:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_Soft_M.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
                ]
            case .modeCFast:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_M.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
                ]
            case .modeAAFast:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_M.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                    "Restore/Anime4K_Restore_CNN_S.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
                ]
            case .modeBBFast:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_Soft_M.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Restore/Anime4K_Restore_CNN_Soft_S.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
                ]
            case .modeCAFast:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_M.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Restore/Anime4K_Restore_CNN_S.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_S.glsl",
                ]
            case .modeAHQ:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_VL.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                ]
            case .modeBHQ:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_Soft_VL.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                ]
            case .modeCHQ:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                ]
            case .modeAAHQ:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_VL.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
                    "Restore/Anime4K_Restore_CNN_M.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                ]
            case .modeBBHQ:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Restore/Anime4K_Restore_CNN_Soft_VL.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_VL.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Restore/Anime4K_Restore_CNN_Soft_M.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                ]
            case .modeCAHQ:
                [
                    "Restore/Anime4K_Clamp_Highlights.glsl",
                    "Upscale+Denoise/Anime4K_Upscale_Denoise_CNN_x2_VL.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x2.glsl",
                    "Upscale/Anime4K_AutoDownscalePre_x4.glsl",
                    "Restore/Anime4K_Restore_CNN_M.glsl",
                    "Upscale/Anime4K_Upscale_CNN_x2_M.glsl",
                ]
            }
        }

        static func program(for preset: Anime4KPreset) -> Anime4KShaderProgram {
            let files = stageFiles(for: preset)
            var stages: [Anime4KShaderStage] = []
            stages.reserveCapacity(files.count)

            for relative in files {
                guard let source = loadSource(relativePath: relative, preset: preset) else {
                    #if DEBUG
                        cinemoreLog(
                            level: .error,
                            "Anime4K shader program unavailable, bypass preset=\(preset)"
                        )
                    #endif
                    return Anime4KShaderProgram(
                        name: "\(modeName(for: preset)) (missing)", stages: []
                    )
                }
                stages.append(Anime4KShaderStage(name: relative, glsl: source))
            }

            return Anime4KShaderProgram(
                name: modeName(for: preset),
                stages: stages,
                stageFiles: files
            )
        }

        private static func loadSource(relativePath: String, preset: Anime4KPreset) -> String? {
            var lastError: String?
            for url in candidateURLs(relativePath: relativePath) {
                do {
                    return try String(contentsOf: url, encoding: .utf8)
                } catch {
                    lastError = error.localizedDescription
                }
            }

            let searchPaths = candidateURLs(relativePath: relativePath).map(\.path).joined(
                separator: ", "
            )
            #if DEBUG
                cinemoreLog(
                    level: .error,
                    "Anime4K shader file missing, fallback preset=\(preset) relative=\(relativePath) searched=[\(searchPaths)] lastError=\(lastError ?? "none")"
                )
            #endif
            return nil
        }

        private static func candidateURLs(relativePath: String) -> [URL] {
            let baseName = URL(fileURLWithPath: relativePath).lastPathComponent
            guard let flatFileURL = Bundle.main.url(forResource: baseName, withExtension: nil)
            else {
                return []
            }
            return [flatFileURL]
        }

        private static func modeName(for preset: Anime4KPreset) -> String {
            switch preset {
            case .modeAFast: "Anime4K Mode A (Fast)"
            case .modeBFast: "Anime4K Mode B (Fast)"
            case .modeCFast: "Anime4K Mode C (Fast)"
            case .modeAAFast: "Anime4K Mode A+A (Fast)"
            case .modeBBFast: "Anime4K Mode B+B (Fast)"
            case .modeCAFast: "Anime4K Mode C+A (Fast)"
            case .modeAHQ: "Anime4K Mode A (HQ)"
            case .modeBHQ: "Anime4K Mode B (HQ)"
            case .modeCHQ: "Anime4K Mode C (HQ)"
            case .modeAAHQ: "Anime4K Mode A+A (HQ)"
            case .modeBBHQ: "Anime4K Mode B+B (HQ)"
            case .modeCAHQ: "Anime4K Mode C+A (HQ)"
            }
        }
    }

    struct Anime4KHostEngineDebugSnapshot: Sendable {
        var receivedFrames: Int
        var enhancedFrames: Int
        var bypassFrames: Int
        var directTransferFrames: Int
        var compileCount: Int
        var resetCount: Int
        var p95ProcessMs: Double
        var lastEnabledShaderCount: Int
        var lastError: String?
    }

    struct Anime4KShaderStage: Sendable {
        let name: String
        let glsl: String
    }

    struct Anime4KShaderProgram: Sendable {
        let name: String
        let stages: [Anime4KShaderStage]
        let stageFiles: [String]

        init(name: String, glsl: String, stageFiles: [String] = []) {
            self.name = name
            let resolvedStageFiles = stageFiles.isEmpty ? [name] : stageFiles
            stages = [Anime4KShaderStage(name: resolvedStageFiles[0], glsl: glsl)]
            self.stageFiles = resolvedStageFiles
        }

        init(name: String, stages: [Anime4KShaderStage], stageFiles: [String] = []) {
            self.name = name
            self.stages = stages
            if stageFiles.isEmpty {
                self.stageFiles = stages.map(\.name)
            } else {
                self.stageFiles = stageFiles
            }
        }
    }

    /// 用于在 @Sendable 闭包中延长 CVPixelBuffer 生命周期的持有者（仅保留引用，不在闭包内访问 buffer）。
    private final class PixelBufferLifetimeHolder: @unchecked Sendable {
        let buffer: CVPixelBuffer
        init(_ buffer: CVPixelBuffer) {
            self.buffer = buffer
        }
    }

    /// 用于在 @Sendable 闭包中向 intermediate pool 回传 texture，避免直接捕获 non-Sendable MTLTexture。
    private final class TextureReturnHolder: @unchecked Sendable {
        let texture: MTLTexture
        let width: Int
        let height: Int
        init(texture: MTLTexture, width: Int, height: Int) {
            self.texture = texture
            self.width = width
            self.height = height
        }
    }

    final class Anime4KHostEngine: @unchecked Sendable {
        static let shared = Anime4KHostEngine()

        /// A/B 对比中线红线的半宽（像素）。
        /// 仅按输出图像宽度线性缩放，保证不同分辨率下按固定比例变化。
        static func abCompareRedLineHalfWidth(outputWidth: Int) -> Int {
            guard outputWidth > 0 else {
                return 1
            }
            return max(1, (2 * outputWidth) / 2560)
        }

        /// x420 FourCC (0x78343230)，与 420v 相同 bi-planar 4:2:0 布局，VideoToolbox 等可能输出此格式。
        private static let biPlanar420X420: OSType = 0x7834_3230

        private struct PipelineKey: Hashable {
            let preset: Anime4KPreset
            let width: Int
            let height: Int
        }

        private struct Anime4KPipeline {
            let programName: String
            let stageFiles: [String]
            let stages: [Anime4KProcessor]
        }

        private enum BypassReason: String {
            case processingLockBusy = "processing_lock_busy"
            case missingMetalContext = "missing_metal_context"
            case missingConverterLibrary = "missing_converter_library"
            case invalidDimensions = "invalid_dimensions"
            case outputPoolCreateFailed = "output_pool_create_failed"
            case outputTextureCreateFailed = "output_texture_create_failed"
            case commandBufferCreateFailed = "command_buffer_create_failed"
            case inputTextureCreateFailed = "input_texture_create_failed"
            case processorUnavailable = "processor_unavailable"
            case processorEncodeFailed = "processor_encode_failed"
            case commandBufferFailed = "command_buffer_failed"
            case unsupportedPixelFormat = "unsupported_pixel_format"
        }

        private struct RuntimeStats {
            var receivedFrames = 0
            var enhancedFrames = 0
            var bypassFrames = 0
            var directTransferFrames = 0
            var compileCount = 0
            var resetCount = 0
            var timingsMs: [Double] = []
            var lastLogFrame = 0
            var bypassByReason: [String: Int] = [:]
            var lastEnabledShaderCount = 0
            var lastError: String?

            mutating func recordTiming(_ value: Double) {
                timingsMs.append(value)
                if timingsMs.count > 300 {
                    timingsMs.removeFirst(timingsMs.count - 300)
                }
            }

            mutating func recordBypass(reason: String) {
                bypassByReason[reason, default: 0] += 1
            }

            func p95() -> Double {
                guard !timingsMs.isEmpty else {
                    return 0
                }
                let sorted = timingsMs.sorted()
                let index = min(sorted.count - 1, Int(Double(sorted.count - 1) * 0.95))
                return sorted[index]
            }

            func bypassSummary(limit: Int = 3) -> String {
                guard !bypassByReason.isEmpty else {
                    return "none"
                }
                let parts =
                    bypassByReason
                        .sorted { lhs, rhs in
                            if lhs.value == rhs.value {
                                return lhs.key < rhs.key
                            }
                            return lhs.value > rhs.value
                        }
                        .prefix(limit)
                        .map { "\($0.key)=\($0.value)" }
                return parts.joined(separator: ",")
            }
        }

        private struct OutputPoolKey: Hashable {
            let width: Int
            let height: Int
        }

        private let stateLock = NSLock()
        private let processingLock = NSLock()
        private let commandQueue: MTLCommandQueue?
        private let device: MTLDevice?

        private var textureCache: CVMetalTextureCache?
        private var converterLibrary: MTLLibrary?
        private var yuvConverterPSO: MTLComputePipelineState?
        private var yuvPlanarConverterPSO: MTLComputePipelineState?
        private var yuvP010ConverterPSO: MTLComputePipelineState?
        private var bgraConverterPSO: MTLComputePipelineState?
        private var abComparePSO: MTLComputePipelineState?
        private var directTransferPSO: MTLComputePipelineState?
        private var centerResizePSO: MTLComputePipelineState?

        private var pipelines: [PipelineKey: Anime4KPipeline] = [:]
        private var loggedPipelineKeys: Set<PipelineKey> = []
        private var outputPoolKey: OutputPoolKey?
        private var outputPool: CVPixelBufferPool?
        private let intermediatePoolLock = NSLock()
        private var intermediateTexturePool: [String: [MTLTexture]] = [:]
        private var vtTransferSession: VTPixelTransferSession?
        private var bgraPoolKey: (Int, Int)?
        private var bgraPool: CVPixelBufferPool?
        private var stats = RuntimeStats()
        private var lastGeneration: Int64 = -1
        #if DEBUG
            private var shaderCatalogOverride: [Anime4KPreset: Anime4KShaderProgram]?
        #endif

        init() {
            let localDevice = MTLCreateSystemDefaultDevice()
            device = localDevice
            commandQueue = localDevice?.makeCommandQueue(maxCommandBufferCount: 2)
            if let localDevice {
                var createdCache: CVMetalTextureCache?
                if CVMetalTextureCacheCreate(
                    kCFAllocatorDefault,
                    nil,
                    localDevice,
                    nil,
                    &createdCache
                ) == kCVReturnSuccess {
                    textureCache = createdCache
                }
            }
            compileConverterPipelinesIfNeeded()
        }

        #if DEBUG
            func debugSnapshot() -> Anime4KHostEngineDebugSnapshot {
                stateLock.lock()
                defer { stateLock.unlock() }
                return Anime4KHostEngineDebugSnapshot(
                    receivedFrames: stats.receivedFrames,
                    enhancedFrames: stats.enhancedFrames,
                    bypassFrames: stats.bypassFrames,
                    directTransferFrames: stats.directTransferFrames,
                    compileCount: stats.compileCount,
                    resetCount: stats.resetCount,
                    p95ProcessMs: stats.p95(),
                    lastEnabledShaderCount: stats.lastEnabledShaderCount,
                    lastError: stats.lastError
                )
            }

            func setShaderCatalogOverrideForTesting(
                _ override: [Anime4KPreset: Anime4KShaderProgram]?
            ) {
                stateLock.lock()
                shaderCatalogOverride = override
                stateLock.unlock()
            }
        #endif

        /// 与 Anime4K A/B 对比同一套 Metal kernel（左原图、右增强、中线红线），供 System ML 等复用。要求 original/enhanced 均为 BGRA。
        func makeABComparePixelBuffer(original: CVPixelBuffer, enhanced: CVPixelBuffer) -> CVPixelBuffer? {
            compileConverterPipelinesIfNeeded()
            guard let _ = device, let cache = textureCache, let pso = abComparePSO, let queue = commandQueue else {
                return nil
            }
            let origW = CVPixelBufferGetWidth(original)
            let origH = CVPixelBufferGetHeight(original)
            let enhW = CVPixelBufferGetWidth(enhanced)
            let enhH = CVPixelBufferGetHeight(enhanced)
            guard origW > 0, origH > 0, enhW > 0, enhH > 0 else {
                return nil
            }
            guard CVPixelBufferGetPixelFormatType(original) == kCVPixelFormatType_32BGRA,
                  CVPixelBufferGetPixelFormatType(enhanced) == kCVPixelFormatType_32BGRA
            else {
                return nil
            }
            var origRef: CVMetalTexture?
            guard CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, cache, original, nil, .bgra8Unorm, origW, origH, 0, &origRef
            ) == kCVReturnSuccess, let origRef, let originalTexture = CVMetalTextureGetTexture(origRef) else {
                return nil
            }
            var enhRef: CVMetalTexture?
            guard CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault, cache, enhanced, nil, .bgra8Unorm, enhW, enhH, 0, &enhRef
            ) == kCVReturnSuccess, let enhRef, let enhancedTexture = CVMetalTextureGetTexture(enhRef) else {
                return nil
            }
            // 与 Anime4K A/B 一致：输出尺寸 = 增强尺寸，左半=原图、右半=增强、中线红线
            guard let outputBuffer = makeOutputPixelBuffer(width: enhW, height: enhH) else {
                return nil
            }
            guard let outputTexture = makeBGRAOutputTexture(
                pixelBuffer: outputBuffer, textureCache: cache, width: enhW, height: enhH
            ) else {
                return nil
            }
            guard let commandBuffer = queue.makeCommandBuffer() else {
                return nil
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }
            encoder.setComputePipelineState(pso)
            encoder.setTexture(originalTexture, index: 0)
            encoder.setTexture(enhancedTexture, index: 1)
            encoder.setTexture(outputTexture, index: 2)
            var lineHalfWidth = UInt32(Self.abCompareRedLineHalfWidth(outputWidth: enhW))
            encoder.setBytes(&lineHalfWidth, length: MemoryLayout<UInt32>.size, index: 0)
            dispatch2D(encoder: encoder, width: enhW, height: enhH, pipeline: pso)
            encoder.endEncoding()
            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else {
                return nil
            }
            return outputBuffer
        }

        func reset() {
            stateLock.lock()
            pipelines.removeAll()
            loggedPipelineKeys.removeAll()
            outputPool = nil
            outputPoolKey = nil
            lastGeneration = -1
            #if DEBUG
                stats.resetCount += 1
                let resetCount = stats.resetCount
            #endif
            stateLock.unlock()

            intermediatePoolLock.lock()
            intermediateTexturePool.removeAll()
            intermediatePoolLock.unlock()

            if let textureCache {
                CVMetalTextureCacheFlush(textureCache, 0)
            }
            #if DEBUG
                cinemoreLog(level: .debug, "Anime4K engine reset count=\(resetCount)")
            #endif
        }

        func enhance(
            pixelBuffer: CVPixelBuffer,
            timestamp: Int64,
            generation: Int64,
            preset: Anime4KPreset,
            abCompareEnabled: Bool = false,
            maxOutputWidth: Int = 2560,
            maxOutputHeight: Int = 1440
        ) -> CVPixelBuffer? {
            stateLock.lock()
            #if DEBUG
                stats.receivedFrames += 1
                stats.lastError = nil
            #endif
            if generation != lastGeneration {
                pipelines.removeAll()
                loggedPipelineKeys.removeAll()
                outputPool = nil
                outputPoolKey = nil
                lastGeneration = generation
                #if DEBUG
                    stats.resetCount += 1
                #endif
            }
            stateLock.unlock()

            guard processingLock.try() else {
                markBypass(reason: .processingLockBusy, timestamp: timestamp)
                return nil
            }
            defer { processingLock.unlock() }

            #if DEBUG
                let start = CACurrentMediaTime()
                defer {
                    let elapsed = (CACurrentMediaTime() - start) * 1000
                    recordTiming(elapsedMs: elapsed, timestamp: timestamp)
                }
            #endif

            guard let device, let commandQueue, let textureCache else {
                markBypass(reason: .missingMetalContext, timestamp: timestamp)
                return nil
            }
            guard let converterLibrary else {
                markBypass(reason: .missingConverterLibrary, timestamp: timestamp)
                return nil
            }

            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            guard width > 0, height > 0 else {
                markBypass(reason: .invalidDimensions, timestamp: timestamp)
                return nil
            }
            let outputSize = resolvedOutputSize(
                inputWidth: width,
                inputHeight: height,
                maxOutputWidth: maxOutputWidth,
                maxOutputHeight: maxOutputHeight
            )

            guard
                let outputBuffer = makeOutputPixelBuffer(
                    width: outputSize.width, height: outputSize.height
                )
            else {
                markBypass(reason: .outputPoolCreateFailed, timestamp: timestamp)
                return nil
            }
            CVBufferPropagateAttachments(pixelBuffer, outputBuffer)

            guard
                let outputTexture = makeBGRAOutputTexture(
                    pixelBuffer: outputBuffer,
                    textureCache: textureCache,
                    width: outputSize.width,
                    height: outputSize.height
                )
            else {
                markBypass(reason: .outputTextureCreateFailed, timestamp: timestamp)
                return nil
            }

            guard let commandBuffer = commandQueue.makeCommandBuffer() else {
                markBypass(reason: .commandBufferCreateFailed, timestamp: timestamp)
                return nil
            }

            var inputFailureReason: BypassReason?
            guard
                let inputTexture = makeInputTexture(
                    pixelBuffer: pixelBuffer,
                    textureCache: textureCache,
                    converterLibrary: converterLibrary,
                    commandBuffer: commandBuffer,
                    width: width,
                    height: height,
                    failureReason: &inputFailureReason
                )
            else {
                markBypass(
                    reason: inputFailureReason ?? .inputTextureCreateFailed, timestamp: timestamp
                )
                return nil
            }

            guard
                let pipeline = pipelineFor(
                    key: PipelineKey(preset: preset, width: width, height: height),
                    preset: preset,
                    device: device
                )
            else {
                markBypass(reason: .processorUnavailable, timestamp: timestamp)
                return nil
            }

            let useOutputSizeCap = maxOutputWidth > 0 && maxOutputHeight > 0
            do {
                let compileOutput = compileOutputSize(
                    inputWidth: width,
                    inputHeight: height,
                    outputWidth: outputSize.width,
                    outputHeight: outputSize.height,
                    preset: preset,
                    useOutputSizeCap: useOutputSizeCap
                )
                var enhancedTexture = inputTexture
                var totalEnabledShaderCount = 0
                for stage in pipeline.stages {
                    try stage.compileIfNeeded(
                        device: device,
                        videoInW: width,
                        videoInH: height,
                        textureInW: enhancedTexture.width,
                        textureInH: enhancedTexture.height,
                        displayOutW: compileOutput.width,
                        displayOutH: compileOutput.height
                    )
                    totalEnabledShaderCount += stage.enabledShaderCount
                    enhancedTexture = try stage.encodeIntermediate(
                        device,
                        cmdBuf: commandBuffer,
                        input: enhancedTexture
                    )
                }
                #if DEBUG
                    stateLock.lock()
                    stats.lastEnabledShaderCount = totalEnabledShaderCount
                    stateLock.unlock()
                #endif
                logPipelineActivationIfNeeded(
                    key: PipelineKey(preset: preset, width: width, height: height),
                    inputWidth: width,
                    inputHeight: height,
                    compileWidth: compileOutput.width,
                    compileHeight: compileOutput.height,
                    enabledShaderCount: totalEnabledShaderCount,
                    programName: pipeline.programName
                )

                let composeTargetTexture = outputTexture

                if abCompareEnabled {
                    if !encodeABCompareSplit(
                        commandBuffer: commandBuffer,
                        originalTexture: inputTexture,
                        enhancedTexture: enhancedTexture,
                        outputTexture: composeTargetTexture
                    ) {
                        #if DEBUG
                            cinemoreLog(
                                level: .error,
                                "Anime4K A/B split compose failed, fallback to enhanced output"
                            )
                        #endif
                        if !encodeBestCompose(
                            commandBuffer: commandBuffer,
                            inputTexture: enhancedTexture,
                            outputTexture: composeTargetTexture
                        ) {
                            setLastError("A/B split compose and fallback both failed")
                            markBypass(reason: .processorEncodeFailed, timestamp: timestamp)
                            return nil
                        }
                    }
                } else if !encodeBestCompose(
                    commandBuffer: commandBuffer,
                    inputTexture: enhancedTexture,
                    outputTexture: composeTargetTexture
                ) {
                    setLastError("final center resize failed")
                    markBypass(reason: .processorEncodeFailed, timestamp: timestamp)
                    return nil
                }
            } catch {
                #if DEBUG
                    cinemoreLog(
                        level: .error, "Anime4K encode failed: \(error.localizedDescription)"
                    )
                #endif
                setLastError("encode failed: \(error.localizedDescription)")
                markBypass(reason: .processorEncodeFailed, timestamp: timestamp)
                return nil
            }

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else {
                let errorText =
                    commandBuffer.error?.localizedDescription
                        ?? "status=\(commandBuffer.status.rawValue)"
                setLastError("command buffer failed: \(errorText)")
                #if DEBUG
                    cinemoreLog(
                        level: .error,
                        "Anime4K command buffer failed ts=\(timestamp): \(errorText)"
                    )
                #endif
                markBypass(reason: .processorEncodeFailed, timestamp: timestamp)
                return nil
            }

            markEnhanced(
                timestamp: timestamp,
                width: width,
                height: height,
                pixelFormat: CVPixelBufferGetPixelFormatType(pixelBuffer),
                abCompareEnabled: abCompareEnabled,
                outputWidth: outputSize.width,
                outputHeight: outputSize.height
            )
            return outputBuffer
        }

        func resolveEffectivePreset(
            requested: Anime4KPreset,
            timestamp: Int64,
            frameDuration: Int64,
            timebaseNum: Int32,
            timebaseDen: Int32,
            fps: Float
        ) -> Anime4KPreset {
            _ = timestamp
            _ = frameDuration
            _ = timebaseNum
            _ = timebaseDen
            _ = fps
            return requested
        }

        private func recordTiming(elapsedMs: Double, timestamp: Int64) {
            #if DEBUG
                stateLock.lock()
                stats.recordTiming(elapsedMs)
                let shouldLog =
                    stats.receivedFrames <= 3 || stats.receivedFrames - stats.lastLogFrame >= 30
                if shouldLog {
                    stats.lastLogFrame = stats.receivedFrames
                }
                let snapshot = stats
                stateLock.unlock()

                guard shouldLog else {
                    return
                }
                let hitRate =
                    Double(snapshot.enhancedFrames) / Double(max(1, snapshot.receivedFrames))
                let hitRateText = String(format: "%.3f", hitRate)
                let p95Text = String(format: "%.2f", snapshot.p95())
                cinemoreLog(
                    level: .debug,
                    "Anime4K stats ts=\(timestamp) recv=\(snapshot.receivedFrames) hit=\(snapshot.enhancedFrames) bypass=\(snapshot.bypassFrames) compile=\(snapshot.compileCount) hitRate=\(hitRateText) p95=\(p95Text)ms bypassTop=\(snapshot.bypassSummary())"
                )
            #endif
        }

        private func compileConverterPipelinesIfNeeded() {
            guard let device else {
                return
            }
            guard converterLibrary == nil else {
                return
            }
            do {
                let library: MTLLibrary
                if let bundled = try? device.makeDefaultLibrary(bundle: .main) {
                    library = bundled
                } else if let fallback = device.makeDefaultLibrary() {
                    library = fallback
                } else {
                    #if DEBUG
                        cinemoreLog(
                            level: .error, "Anime4K kernel library missing: default.metallib"
                        )
                    #endif
                    return
                }
                guard let yuvFunction = library.makeFunction(name: "YUV420BiPlanarToRGBA"),
                      let yuvPlanarFunction = library.makeFunction(name: "YUV420PlanarToRGBA"),
                      let yuvP010Function = library.makeFunction(name: "YUV420P010BiPlanarToRGBA"),
                      let bgraFunction = library.makeFunction(name: "BGRA8ToRGBA"),
                      let abCompareFunction = library.makeFunction(name: "ABCompareSplit"),
                      let directTransferFunction = library.makeFunction(name: "DirectTransfer"),
                      let centerResizeFunction = library.makeFunction(name: "CenterResize")
                else {
                    #if DEBUG
                        cinemoreLog(
                            level: .error, "Anime4K converter function missing in metal library"
                        )
                    #endif
                    return
                }
                converterLibrary = library
                yuvConverterPSO = try device.makeComputePipelineState(
                    function: yuvFunction
                )
                yuvPlanarConverterPSO = try device.makeComputePipelineState(
                    function: yuvPlanarFunction
                )
                yuvP010ConverterPSO = try device.makeComputePipelineState(
                    function: yuvP010Function
                )
                bgraConverterPSO = try device.makeComputePipelineState(
                    function: bgraFunction
                )
                abComparePSO = try device.makeComputePipelineState(
                    function: abCompareFunction
                )
                directTransferPSO = try device.makeComputePipelineState(
                    function: directTransferFunction
                )
                centerResizePSO = try device.makeComputePipelineState(
                    function: centerResizeFunction
                )
            } catch {
                #if DEBUG
                    cinemoreLog(
                        level: .error,
                        "Anime4K converter compile failed: \(error.localizedDescription)"
                    )
                #endif
            }
        }

        private func pipelineFor(
            key: PipelineKey,
            preset: Anime4KPreset,
            device: MTLDevice
        ) -> Anime4KPipeline? {
            #if DEBUG
                stateLock.lock()
                let shaderProgram = shaderCatalogOverride?[preset] ?? preset.shaderProgram
                stateLock.unlock()
            #else
                let shaderProgram = preset.shaderProgram
            #endif

            stateLock.lock()
            if let existing = pipelines[key] {
                stateLock.unlock()
                return existing
            }
            stateLock.unlock()

            guard let centerResizePSO else {
                return nil
            }

            do {
                let stages = shaderProgram.stages
                guard !stages.isEmpty else {
                    #if DEBUG
                        cinemoreLog(
                            level: .error,
                            "Anime4K shader program has no stages: \(shaderProgram.name)"
                        )
                    #endif
                    setLastError("shader program has no stages")
                    return nil
                }

                var processors: [Anime4KProcessor] = []
                processors.reserveCapacity(stages.count)
                for stage in stages {
                    let processor = try Anime4KProcessor(
                        name: stage.name,
                        glsl: stage.glsl,
                        centerResizePSO: centerResizePSO,
                        device: device
                    )
                    processors.append(processor)
                }

                let pipeline = Anime4KPipeline(
                    programName: shaderProgram.name,
                    stageFiles: shaderProgram.stageFiles,
                    stages: processors
                )
                stateLock.lock()
                pipelines[key] = pipeline
                #if DEBUG
                    stats.compileCount += 1
                #endif
                stateLock.unlock()
                #if DEBUG
                    if !pipeline.stageFiles.isEmpty {
                        cinemoreLog(
                            level: .debug,
                            "Anime4K shader chain preset=\(preset) program=\(shaderProgram.name) stages=\(pipeline.stageFiles.joined(separator: " -> "))"
                        )
                    }
                #endif
                return pipeline
            } catch {
                #if DEBUG
                    cinemoreLog(
                        level: .error,
                        "Anime4K shader compile failed: \(error.localizedDescription)"
                    )
                #endif
                setLastError("shader compile failed: \(error.localizedDescription)")
                return nil
            }
        }

        private func markEnhanced(
            timestamp: Int64,
            width: Int,
            height: Int,
            pixelFormat: OSType,
            abCompareEnabled: Bool,
            outputWidth: Int,
            outputHeight: Int
        ) {
            #if DEBUG
                var shouldLog = false
                var enhancedCount = 0
                stateLock.lock()
                stats.enhancedFrames += 1
                enhancedCount = stats.enhancedFrames
                shouldLog = enhancedCount <= 3 || enhancedCount % 120 == 0
                stateLock.unlock()

                guard shouldLog else {
                    return
                }
                cinemoreLog(
                    level: .debug,
                    "Anime4K enhanced frame ts=\(timestamp) input=\(width)x\(height) output=\(outputWidth)x\(outputHeight) fmt=\(formatFourCC(pixelFormat)) mode=\(abCompareEnabled ? "ab_compare" : "normal") totalEnhanced=\(enhancedCount)"
                )
            #endif
        }

        private func markBypass(reason: BypassReason, timestamp: Int64) {
            #if DEBUG
                var bypassCount = 0
                var shouldLog = false
                stateLock.lock()
                stats.bypassFrames += 1
                stats.recordBypass(reason: reason.rawValue)
                bypassCount = stats.bypassFrames
                shouldLog = bypassCount <= 5 || bypassCount % 30 == 0
                stateLock.unlock()

                guard shouldLog else {
                    return
                }
                cinemoreLog(
                    level: .debug,
                    "Anime4K bypass ts=\(timestamp) reason=\(reason.rawValue) totalBypass=\(bypassCount)"
                )
            #endif
        }

        private func setLastError(_ message: String) {
            #if DEBUG
                stateLock.lock()
                stats.lastError = message
                stateLock.unlock()
            #endif
        }

        private func compileOutputSize(
            inputWidth: Int,
            inputHeight: Int,
            outputWidth: Int,
            outputHeight: Int,
            preset: Anime4KPreset,
            useOutputSizeCap: Bool
        ) -> (width: Int, height: Int) {
            _ = preset
            let scale: Float = 1.50
            let baseOutW = max(inputWidth, Int((Float(inputWidth) * scale).rounded(.up)))
            let baseOutH = max(inputHeight, Int((Float(inputHeight) * scale).rounded(.up)))
            let outW = useOutputSizeCap ? max(baseOutW, outputWidth) : baseOutW
            let outH = useOutputSizeCap ? max(baseOutH, outputHeight) : baseOutH
            return (outW, outH)
        }

        private func resolvedOutputSize(
            inputWidth: Int,
            inputHeight: Int,
            maxOutputWidth: Int,
            maxOutputHeight: Int
        ) -> (width: Int, height: Int) {
            guard maxOutputWidth > 0, maxOutputHeight > 0 else {
                return (inputWidth, inputHeight)
            }
            guard inputWidth > 0, inputHeight > 0 else {
                return (inputWidth, inputHeight)
            }

            let widthScale = Double(maxOutputWidth) / Double(inputWidth)
            let heightScale = Double(maxOutputHeight) / Double(inputHeight)
            let scale = min(widthScale, heightScale)
            guard scale > 1.0 else {
                return (inputWidth, inputHeight)
            }

            let scaledWidth = max(inputWidth, Int((Double(inputWidth) * scale).rounded()))
            let scaledHeight = max(inputHeight, Int((Double(inputHeight) * scale).rounded()))
            return (
                width: makeEven(scaledWidth),
                height: makeEven(scaledHeight)
            )
        }

        private func makeEven(_ value: Int) -> Int {
            guard value > 0 else {
                return value
            }
            return value % 2 == 0 ? value : value + 1
        }

        private func logPipelineActivationIfNeeded(
            key: PipelineKey,
            inputWidth: Int,
            inputHeight: Int,
            compileWidth: Int,
            compileHeight: Int,
            enabledShaderCount: Int,
            programName: String
        ) {
            #if DEBUG
                var shouldLog = false
                stateLock.lock()
                if !loggedPipelineKeys.contains(key) {
                    loggedPipelineKeys.insert(key)
                    shouldLog = true
                }
                stateLock.unlock()

                guard shouldLog else {
                    return
                }
                cinemoreLog(
                    level: .debug,
                    "Anime4K pipeline preset=\(key.preset) program=\(programName) input=\(inputWidth)x\(inputHeight) compileOutput=\(compileWidth)x\(compileHeight) enabledShaders=\(enabledShaderCount)"
                )
            #endif
        }

        private func encodeCenterResize(
            commandBuffer: MTLCommandBuffer,
            inputTexture: MTLTexture,
            outputTexture: MTLTexture
        ) -> Bool {
            guard let centerResizePSO else {
                return false
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return false
            }
            encoder.setComputePipelineState(centerResizePSO)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(outputTexture, index: 1)
            dispatch2D(
                encoder: encoder, width: outputTexture.width, height: outputTexture.height,
                pipeline: centerResizePSO
            )
            encoder.endEncoding()
            return true
        }

        private func encodeBestCompose(
            commandBuffer: MTLCommandBuffer,
            inputTexture: MTLTexture,
            outputTexture: MTLTexture
        ) -> Bool {
            if inputTexture.width == outputTexture.width,
               inputTexture.height == outputTexture.height,
               encodeDirectTransfer(
                   commandBuffer: commandBuffer,
                   inputTexture: inputTexture,
                   outputTexture: outputTexture
               )
            {
                #if DEBUG
                    stateLock.lock()
                    stats.directTransferFrames += 1
                    stateLock.unlock()
                #endif
                return true
            }
            return encodeCenterResize(
                commandBuffer: commandBuffer,
                inputTexture: inputTexture,
                outputTexture: outputTexture
            )
        }

        private func encodeDirectTransfer(
            commandBuffer: MTLCommandBuffer,
            inputTexture: MTLTexture,
            outputTexture: MTLTexture
        ) -> Bool {
            guard let directTransferPSO else {
                return false
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return false
            }
            encoder.setComputePipelineState(directTransferPSO)
            encoder.setTexture(inputTexture, index: 0)
            encoder.setTexture(outputTexture, index: 1)
            dispatch2D(
                encoder: encoder, width: outputTexture.width, height: outputTexture.height,
                pipeline: directTransferPSO
            )
            encoder.endEncoding()
            return true
        }

        private func encodeABCompareSplit(
            commandBuffer: MTLCommandBuffer,
            originalTexture: MTLTexture,
            enhancedTexture: MTLTexture,
            outputTexture: MTLTexture
        ) -> Bool {
            guard let abComparePSO else {
                return false
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return false
            }
            encoder.setComputePipelineState(abComparePSO)
            encoder.setTexture(originalTexture, index: 0)
            encoder.setTexture(enhancedTexture, index: 1)
            encoder.setTexture(outputTexture, index: 2)
            var lineHalfWidth = UInt32(Self.abCompareRedLineHalfWidth(outputWidth: outputTexture.width))
            encoder.setBytes(&lineHalfWidth, length: MemoryLayout<UInt32>.size, index: 0)
            dispatch2D(
                encoder: encoder, width: outputTexture.width, height: outputTexture.height,
                pipeline: abComparePSO
            )
            encoder.endEncoding()
            return true
        }

        private func makeOutputPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
            let key = OutputPoolKey(width: width, height: height)
            if outputPoolKey != key || outputPool == nil {
                let poolOptions: [String: Any] = [
                    kCVPixelBufferPoolMinimumBufferCountKey as String: 2
                ]
                let attrs: [String: Any] = [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                    kCVPixelBufferWidthKey as String: width,
                    kCVPixelBufferHeightKey as String: height,
                    kCVPixelBufferMetalCompatibilityKey as String: true,
                    kCVPixelBufferIOSurfacePropertiesKey as String: [:],
                    kCVPixelBufferCGImageCompatibilityKey as String: true,
                    kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
                ]
                var pool: CVPixelBufferPool?
                CVPixelBufferPoolCreate(
                    kCFAllocatorDefault, poolOptions as CFDictionary, attrs as CFDictionary, &pool
                )
                outputPool = pool
                outputPoolKey = key
            }
            guard let outputPool else {
                return nil
            }
            var pixelBuffer: CVPixelBuffer?
            let result = CVPixelBufferPoolCreatePixelBuffer(
                kCFAllocatorDefault, outputPool, &pixelBuffer
            )
            guard result == kCVReturnSuccess else {
                return nil
            }
            return pixelBuffer
        }

        private func makeInputTexture(
            pixelBuffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            converterLibrary _: MTLLibrary,
            commandBuffer: MTLCommandBuffer,
            width: Int,
            height: Int,
            failureReason: inout BypassReason?
        ) -> MTLTexture? {
            let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
            switch pixelFormat {
            case kCVPixelFormatType_32BGRA:
                return makeBGRAInputTexture(
                    pixelBuffer: pixelBuffer,
                    textureCache: textureCache,
                    width: width,
                    height: height,
                    commandBuffer: commandBuffer
                )
            case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
                 kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
                if let bgraBuffer = makeBGRAPixelBufferViaVT(from: pixelBuffer, width: width, height: height) {
                    let holder = PixelBufferLifetimeHolder(bgraBuffer)
                    commandBuffer.addCompletedHandler { _ in _ = holder }
                    return makeBGRAInputTexture(
                        pixelBuffer: bgraBuffer,
                        textureCache: textureCache,
                        width: width,
                        height: height,
                        commandBuffer: commandBuffer
                    )
                }
                return makeYUVInputTexture(
                    pixelBuffer: pixelBuffer,
                    textureCache: textureCache,
                    width: width,
                    height: height,
                    commandBuffer: commandBuffer,
                    isVideoRange: pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                )
            case Self.biPlanar420X420:
                // x420 可能为 8-bit(420v) 或 10-bit(P010)，VT 对 yuv420p10le 常输出 x420。用 Y 平面 bytesPerRow 区分
                let planeCount = CVPixelBufferGetPlaneCount(pixelBuffer)
                if planeCount >= 3 {
                    return makeYUVPlanarInputTexture(
                        pixelBuffer: pixelBuffer,
                        textureCache: textureCache,
                        width: width,
                        height: height,
                        commandBuffer: commandBuffer,
                        isVideoRange: true
                    )
                }
                if planeCount >= 2 {
                    let yBytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
                    // P010 Y 为 2 字节/像素，420v 为 1 字节/像素
                    if yBytesPerRow >= width * 2 {
                        return makeP010InputTexture(
                            pixelBuffer: pixelBuffer,
                            textureCache: textureCache,
                            width: width,
                            height: height,
                            commandBuffer: commandBuffer,
                            isVideoRange: true
                        )
                    }
                    return makeYUVInputTexture(
                        pixelBuffer: pixelBuffer,
                        textureCache: textureCache,
                        width: width,
                        height: height,
                        commandBuffer: commandBuffer,
                        isVideoRange: true
                    )
                }
                failureReason = .unsupportedPixelFormat
                return nil
            case kCVPixelFormatType_420YpCbCr8Planar,
                 kCVPixelFormatType_420YpCbCr8PlanarFullRange:
                return makeYUVPlanarInputTexture(
                    pixelBuffer: pixelBuffer,
                    textureCache: textureCache,
                    width: width,
                    height: height,
                    commandBuffer: commandBuffer,
                    isVideoRange: pixelFormat == kCVPixelFormatType_420YpCbCr8Planar
                )
            case kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange,
                 kCVPixelFormatType_420YpCbCr10BiPlanarFullRange:
                return makeP010InputTexture(
                    pixelBuffer: pixelBuffer,
                    textureCache: textureCache,
                    width: width,
                    height: height,
                    commandBuffer: commandBuffer,
                    isVideoRange: pixelFormat == kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange
                )
            default:
                failureReason = .unsupportedPixelFormat
                #if DEBUG
                    cinemoreLog(
                        level: .debug,
                        "Anime4K bypass unsupported pixel format: \(pixelFormat) (\(formatFourCC(pixelFormat)))"
                    )
                #endif
                return nil
            }
        }

        private func makeBGRAInputTexture(
            pixelBuffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            width: Int,
            height: Int,
            commandBuffer: MTLCommandBuffer
        ) -> MTLTexture? {
            var srcRef: CVMetalTexture?
            let srcStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .bgra8Unorm,
                width,
                height,
                0,
                &srcRef
            )
            guard srcStatus == kCVReturnSuccess, let srcRef,
                  let src = CVMetalTextureGetTexture(srcRef)
            else {
                return nil
            }
            guard let bgraConverterPSO else {
                return nil
            }
            guard let dst = makeIntermediateTexture(width: width, height: height, commandBuffer: commandBuffer) else {
                return nil
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }
            encoder.setComputePipelineState(bgraConverterPSO)
            encoder.setTexture(src, index: 0)
            encoder.setTexture(dst, index: 1)
            dispatch2D(encoder: encoder, width: width, height: height, pipeline: bgraConverterPSO)
            encoder.endEncoding()
            return dst
        }

        private func makeYUVInputTexture(
            pixelBuffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            width: Int,
            height: Int,
            commandBuffer: MTLCommandBuffer,
            isVideoRange: Bool
        ) -> MTLTexture? {
            guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
                return nil
            }
            var yRef: CVMetalTexture?
            var uvRef: CVMetalTexture?
            let yStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .r8Unorm,
                width,
                height,
                0,
                &yRef
            )
            let uvStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .rg8Unorm,
                width / 2,
                height / 2,
                1,
                &uvRef
            )
            guard yStatus == kCVReturnSuccess,
                  uvStatus == kCVReturnSuccess,
                  let yRef,
                  let uvRef,
                  let yTex = CVMetalTextureGetTexture(yRef),
                  let uvTex = CVMetalTextureGetTexture(uvRef)
            else {
                return nil
            }

            guard let yuvConverterPSO else {
                return nil
            }
            guard let dst = makeIntermediateTexture(width: width, height: height, commandBuffer: commandBuffer) else {
                return nil
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }

            var params = YUVConversionParams(isVideoRange: isVideoRange ? 1 : 0)
            encoder.setComputePipelineState(yuvConverterPSO)
            encoder.setTexture(yTex, index: 0)
            encoder.setTexture(uvTex, index: 1)
            encoder.setTexture(dst, index: 2)
            encoder.setBytes(
                &params,
                length: MemoryLayout<YUVConversionParams>.stride,
                index: 0
            )
            dispatch2D(encoder: encoder, width: width, height: height, pipeline: yuvConverterPSO)
            encoder.endEncoding()
            return dst
        }

        /// P010 10-bit bi-planar Y+UV → RGBA，供 Anime4K 管线使用
        private func makeP010InputTexture(
            pixelBuffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            width: Int,
            height: Int,
            commandBuffer: MTLCommandBuffer,
            isVideoRange: Bool
        ) -> MTLTexture? {
            guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 2 else {
                return nil
            }
            var yRef: CVMetalTexture?
            var uvRef: CVMetalTexture?
            let yStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .r16Unorm,
                width,
                height,
                0,
                &yRef
            )
            let uvStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .rg16Unorm,
                width / 2,
                height / 2,
                1,
                &uvRef
            )
            guard yStatus == kCVReturnSuccess,
                  uvStatus == kCVReturnSuccess,
                  let yRef,
                  let uvRef,
                  let yTex = CVMetalTextureGetTexture(yRef),
                  let uvTex = CVMetalTextureGetTexture(uvRef)
            else {
                return nil
            }
            guard let pso = yuvP010ConverterPSO else {
                return nil
            }
            guard let dst = makeIntermediateTexture(width: width, height: height, commandBuffer: commandBuffer) else {
                return nil
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }
            var params = YUVConversionParams(isVideoRange: isVideoRange ? 1 : 0)
            encoder.setComputePipelineState(pso)
            encoder.setTexture(yTex, index: 0)
            encoder.setTexture(uvTex, index: 1)
            encoder.setTexture(dst, index: 2)
            encoder.setBytes(
                &params,
                length: MemoryLayout<YUVConversionParams>.stride,
                index: 0
            )
            dispatch2D(encoder: encoder, width: width, height: height, pipeline: pso)
            encoder.endEncoding()
            return dst
        }

        private func makeYUVPlanarInputTexture(
            pixelBuffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            width: Int,
            height: Int,
            commandBuffer: MTLCommandBuffer,
            isVideoRange: Bool
        ) -> MTLTexture? {
            guard CVPixelBufferGetPlaneCount(pixelBuffer) >= 3 else {
                return nil
            }
            let chromaWidth = width / 2
            let chromaHeight = height / 2

            var yRef: CVMetalTexture?
            var uRef: CVMetalTexture?
            var vRef: CVMetalTexture?
            let yStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .r8Unorm,
                width,
                height,
                0,
                &yRef
            )
            let uStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .r8Unorm,
                chromaWidth,
                chromaHeight,
                1,
                &uRef
            )
            let vStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .r8Unorm,
                chromaWidth,
                chromaHeight,
                2,
                &vRef
            )

            guard yStatus == kCVReturnSuccess,
                  uStatus == kCVReturnSuccess,
                  vStatus == kCVReturnSuccess,
                  let yRef,
                  let uRef,
                  let vRef,
                  let yTex = CVMetalTextureGetTexture(yRef),
                  let uTex = CVMetalTextureGetTexture(uRef),
                  let vTex = CVMetalTextureGetTexture(vRef)
            else {
                return nil
            }

            guard let yuvPlanarConverterPSO else {
                return nil
            }
            guard let dst = makeIntermediateTexture(width: width, height: height, commandBuffer: commandBuffer) else {
                return nil
            }
            guard let encoder = commandBuffer.makeComputeCommandEncoder() else {
                return nil
            }

            var params = YUVConversionParams(isVideoRange: isVideoRange ? 1 : 0)
            encoder.setComputePipelineState(yuvPlanarConverterPSO)
            encoder.setTexture(yTex, index: 0)
            encoder.setTexture(uTex, index: 1)
            encoder.setTexture(vTex, index: 2)
            encoder.setTexture(dst, index: 3)
            encoder.setBytes(
                &params,
                length: MemoryLayout<YUVConversionParams>.stride,
                index: 0
            )
            dispatch2D(
                encoder: encoder, width: width, height: height, pipeline: yuvPlanarConverterPSO
            )
            encoder.endEncoding()
            return dst
        }

        /// 从池中取或新建；传入 commandBuffer 时在本帧 GPU 完成后自动归还池，减少每帧分配。
        private func makeIntermediateTexture(
            width: Int,
            height: Int,
            commandBuffer: MTLCommandBuffer? = nil
        ) -> MTLTexture? {
            let key = "\(width)x\(height)"
            intermediatePoolLock.lock()
            var texture: MTLTexture?
            if var list = intermediateTexturePool[key], !list.isEmpty {
                texture = list.removeLast()
                intermediateTexturePool[key] = list.isEmpty ? nil : list
            }
            intermediatePoolLock.unlock()

            if texture == nil, let device {
                let desc = MTLTextureDescriptor()
                desc.width = width
                desc.height = height
                desc.pixelFormat = .rgba16Float
                desc.usage = [.shaderRead, .shaderWrite]
                desc.storageMode = .private
                texture = device.makeTexture(descriptor: desc)
            }

            if let texture, let commandBuffer {
                let holder = TextureReturnHolder(texture: texture, width: width, height: height)
                commandBuffer.addCompletedHandler { [weak self, holder] _ in
                    Task { @MainActor in
                        self?.returnToIntermediatePool(texture: holder.texture, width: holder.width, height: holder.height)
                    }
                }
            }
            return texture
        }

        private func returnToIntermediatePool(texture: MTLTexture, width: Int, height: Int) {
            let key = "\(width)x\(height)"
            intermediatePoolLock.lock()
            var list = intermediateTexturePool[key] ?? []
            if list.count < 2 {
                list.append(texture)
                intermediateTexturePool[key] = list
            }
            intermediatePoolLock.unlock()
        }

        /// 8-bit YUV → BGRA 走 VideoToolbox 硬件转换，失败时返回 nil 由调用方回退 Metal 路径。
        private func makeBGRAPixelBufferViaVT(from source: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
            guard let pool = ensureBGRAPool(width: width, height: height),
                  let session = ensureVTPixelTransferSession()
            else {
                return nil
            }
            var outBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &outBuffer) == kCVReturnSuccess,
                  let out = outBuffer
            else {
                return nil
            }
            CVBufferPropagateAttachments(source, out)
            guard VTPixelTransferSessionTransferImage(session, from: source, to: out) == noErr else {
                return nil
            }
            return out
        }

        private func ensureVTPixelTransferSession() -> VTPixelTransferSession? {
            if let vtTransferSession {
                return vtTransferSession
            }
            var session: VTPixelTransferSession?
            guard VTPixelTransferSessionCreate(allocator: kCFAllocatorDefault, pixelTransferSessionOut: &session) == noErr,
                  let session
            else {
                return nil
            }
            vtTransferSession = session
            return session
        }

        private func ensureBGRAPool(width: Int, height: Int) -> CVPixelBufferPool? {
            let key = (width, height)
            if let existingKey = bgraPoolKey, existingKey == key, let bgraPool {
                return bgraPool
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
            bgraPoolKey = key
            bgraPool = pool
            return pool
        }

        private func makeBGRAOutputTexture(
            pixelBuffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            width: Int,
            height: Int
        ) -> MTLTexture? {
            var outRef: CVMetalTexture?
            let outStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                .bgra8Unorm,
                width,
                height,
                0,
                &outRef
            )
            guard outStatus == kCVReturnSuccess, let outRef else {
                return nil
            }
            return CVMetalTextureGetTexture(outRef)
        }

        /// 2D 友好的 threadgroup 尺寸，在不超过 pipeline 限制下优先 16×16 或 32×8 形状以提升占用率。
        fileprivate static func threadgroupSize2D(for pipeline: MTLComputePipelineState) -> (width: Int, height: Int) {
            let tw = pipeline.threadExecutionWidth
            let maxTotal = pipeline.maxTotalThreadsPerThreadgroup
            let h = min(16, max(1, maxTotal / tw))
            return (tw, h)
        }

        private func dispatch2D(
            encoder: MTLComputeCommandEncoder,
            width: Int,
            height: Int,
            pipeline: MTLComputePipelineState
        ) {
            let (threadWidth, threadHeight) = Self.threadgroupSize2D(for: pipeline)
            let threadsPerThreadgroup = MTLSize(width: threadWidth, height: threadHeight, depth: 1)
            let threadgroupsPerGrid = MTLSize(
                width: (width + threadWidth - 1) / threadWidth,
                height: (height + threadHeight - 1) / threadHeight,
                depth: 1
            )
            encoder.dispatchThreadgroups(
                threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup
            )
        }

        private func formatFourCC(_ value: OSType) -> String {
            let bytes = [
                UInt8((value >> 24) & 0xFF),
                UInt8((value >> 16) & 0xFF),
                UInt8((value >> 8) & 0xFF),
                UInt8(value & 0xFF),
            ]
            for byte in bytes where byte < 32 || byte > 126 {
                return String(format: "0x%08X", value)
            }
            return String(bytes: bytes, encoding: .ascii) ?? String(format: "0x%08X", value)
        }
    }

    private struct YUVConversionParams {
        var isVideoRange: UInt32
    }

    private final class Anime4KProcessor {
        let name: String
        let shaders: [MPVShader]
        let libraries: [MTLLibrary]
        let centerResizePSO: MTLComputePipelineState

        var enabledShaders: [MPVShader] = []
        var pipelineStates: [MTLComputePipelineState] = []
        var textureMap: [String: MTLTexture] = [:]
        var sizeMap: [String: (Float, Float)] = [:]

        var outputW: Float = 0
        var outputH: Float = 0
        var textureInW: Float = 0
        var textureInH: Float = 0
        var displayActualW: Float = 0
        var displayActualH: Float = 0
        private var compiledSignature: String = ""
        /// 按 mag/min filter 缓存 sampler，避免每帧每 stage 重复创建（仅 linear / nearest 两种）。
        private var samplerCache: [String: MTLSamplerState] = [:]

        var enabledShaderCount: Int {
            enabledShaders.count
        }

        init(
            name: String,
            glsl: String,
            centerResizePSO: MTLComputePipelineState,
            device: MTLDevice
        ) throws {
            self.name = name
            shaders = try MPVShader.parse(glsl)
            libraries = try shaders.map { shader in
                try device.makeLibrary(source: shader.metalCode, options: nil)
            }
            self.centerResizePSO = centerResizePSO
        }

        func compileIfNeeded(
            device: MTLDevice,
            videoInW: Int,
            videoInH: Int,
            textureInW: Int,
            textureInH: Int,
            displayOutW: Int,
            displayOutH: Int
        ) throws {
            let signature =
                "\(videoInW)x\(videoInH)-\(textureInW)x\(textureInH)-\(displayOutW)x\(displayOutH)"
            if compiledSignature == signature {
                return
            }
            compiledSignature = signature

            enabledShaders.removeAll()
            pipelineStates.removeAll()
            textureMap.removeAll()
            sizeMap.removeAll()

            self.textureInW = Float(textureInW)
            self.textureInH = Float(textureInH)
            let displayScale = min(
                Float(displayOutW) / Float(videoInW), Float(displayOutH) / Float(videoInH)
            )
            displayActualW = round(displayScale * Float(videoInW))
            displayActualH = round(displayScale * Float(videoInH))
            outputW = self.textureInW
            outputH = self.textureInH
            sizeMap["MAIN"] = (Float(textureInW), Float(textureInH))
            sizeMap["NATIVE"] = (Float(videoInW), Float(videoInH))
            sizeMap["OUTPUT"] = (displayActualW, displayActualH)

            for (index, shader) in shaders.enumerated() {
                if let when = shader.when, evaluateWhen(when) == false {
                    continue
                }
                enabledShaders.append(shader)
                outputW = self.textureInW
                outputH = self.textureInH
                if let hooked = shader.hook {
                    sizeMap["HOOKED"] = sizeMap[hooked]
                }
                if let widthMultiplier = shader.width {
                    outputW = (sizeMap[widthMultiplier.0]?.0 ?? outputW) * widthMultiplier.1
                }
                if let heightMultiplier = shader.height {
                    outputH = (sizeMap[heightMultiplier.0]?.1 ?? outputH) * heightMultiplier.1
                }
                if let save = shader.save, save != "MAIN" {
                    sizeMap[save] = (outputW, outputH)
                }
                let library = libraries[index]
                guard let function = library.makeFunction(name: shader.functionName) else {
                    throw Anime4KError.encoderFail("missing function \(shader.functionName)")
                }
                try pipelineStates.append(device.makeComputePipelineState(function: function))
            }
        }

        func encode(
            _ device: MTLDevice,
            cmdBuf: MTLCommandBuffer,
            input: MTLTexture,
            output: MTLTexture
        ) throws {
            let outTex = try encode(device, cmdBuf: cmdBuf, input: input)
            guard let encoder = cmdBuf.makeComputeCommandEncoder() else {
                throw Anime4KError.encoderCreationFail("CenterResize")
            }
            encoder.setComputePipelineState(centerResizePSO)
            encoder.setTexture(outTex, index: 0)
            encoder.setTexture(output, index: 1)
            let (w, h) = Anime4KHostEngine.threadgroupSize2D(for: centerResizePSO)
            let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
            let threadgroupsPerGrid = MTLSize(
                width: (output.width + w - 1) / w,
                height: (output.height + h - 1) / h,
                depth: output.arrayLength
            )
            encoder.dispatchThreadgroups(
                threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup
            )
            encoder.endEncoding()
        }

        func encodeIntermediate(
            _ device: MTLDevice,
            cmdBuf: MTLCommandBuffer,
            input: MTLTexture
        ) throws -> MTLTexture {
            try encode(device, cmdBuf: cmdBuf, input: input)
        }

        private func encode(_ device: MTLDevice, cmdBuf: MTLCommandBuffer, input: MTLTexture) throws
            -> MTLTexture
        {
            guard !enabledShaders.isEmpty else {
                return input
            }
            textureMap["MAIN"] = input
            textureMap["NATIVE"] = input

            let outputDesc = MTLTextureDescriptor()
            outputDesc.width = Int(outputW)
            outputDesc.height = Int(outputH)
            outputDesc.pixelFormat = .rgba16Float
            outputDesc.usage = [.shaderRead, .shaderWrite]
            outputDesc.storageMode = .private
            textureMap["output"] = device.makeTexture(descriptor: outputDesc)

            // 单 encoder 跑完所有 stage，减少 encoder 创建/提交开销
            guard let encoder = cmdBuf.makeComputeCommandEncoder() else {
                throw Anime4KError.encoderCreationFail("Anime4K pipeline")
            }
            defer { encoder.endEncoding() }

            for (index, shader) in enabledShaders.enumerated() {
                var outputW = textureInW
                var outputH = textureInH
                if let hooked = shader.hook {
                    sizeMap["HOOKED"] = sizeMap[hooked]
                }
                if let widthMultiplier = shader.width {
                    outputW = (sizeMap[widthMultiplier.0]?.0 ?? outputW) * widthMultiplier.1
                }
                if let heightMultiplier = shader.height {
                    outputH = (sizeMap[heightMultiplier.0]?.1 ?? outputH) * heightMultiplier.1
                }

                let pipelineState = pipelineStates[index]
                encoder.setComputePipelineState(pipelineState)

                let useNearest = outputW >= textureInW
                let samplerKey = useNearest ? "nearest" : "linear"
                if let sampler = samplerCache[samplerKey] {
                    encoder.setSamplerState(sampler, index: 0)
                } else {
                    let descriptor = MTLSamplerDescriptor()
                    descriptor.magFilter = useNearest ? .nearest : .linear
                    descriptor.minFilter = useNearest ? .nearest : .linear
                    descriptor.sAddressMode = .clampToEdge
                    descriptor.tAddressMode = .clampToEdge
                    if let sampler = device.makeSamplerState(descriptor: descriptor) {
                        samplerCache[samplerKey] = sampler
                        encoder.setSamplerState(sampler, index: 0)
                    }
                }

                for textureIndex in 0 ..< shader.inputTextureNames.count {
                    var textureName = shader.inputTextureNames[textureIndex]
                    if textureName == "HOOKED", let hook = shader.hook {
                        textureName = hook
                    }
                    if textureMap[textureName] == nil {
                        if textureName == shader.save {
                            let desc = MTLTextureDescriptor()
                            desc.width = Int(outputW)
                            desc.height = Int(outputH)
                            desc.pixelFormat = .rgba16Float
                            desc.usage = [.shaderRead, .shaderWrite]
                            desc.storageMode = .private
                            textureMap[textureName] = device.makeTexture(descriptor: desc)
                        } else {
                            throw Anime4KError.encoderFail("texture \(textureName) is missing")
                        }
                    }
                    encoder.setTexture(textureMap[textureName], index: textureIndex)
                }

                if shader.binds.contains(shader.outputTextureName)
                    || textureMap[shader.outputTextureName] == nil
                {
                    let desc = MTLTextureDescriptor()
                    desc.width = Int(outputW)
                    desc.height = Int(outputH)
                    desc.pixelFormat = .rgba16Float
                    desc.usage = [.shaderRead, .shaderWrite]
                    desc.storageMode = .private
                    textureMap[shader.outputTextureName] = device.makeTexture(descriptor: desc)
                }
                guard let outputTex = textureMap[shader.outputTextureName] else {
                    throw Anime4KError.encoderFail("failed to allocate output texture")
                }
                encoder.setTexture(outputTex, index: shader.inputTextureNames.count)

                let (w, h) = Anime4KHostEngine.threadgroupSize2D(for: pipelineState)
                let threadsPerThreadgroup = MTLSizeMake(w, h, 1)
                let threadgroupsPerGrid = MTLSize(
                    width: (outputTex.width + w - 1) / w,
                    height: (outputTex.height + h - 1) / h,
                    depth: outputTex.arrayLength
                )
                encoder.dispatchThreadgroups(
                    threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup
                )
            }

            guard let output = textureMap["output"] else {
                throw Anime4KError.encoderFail("missing output texture")
            }
            return output
        }

        private func evaluateWhen(_ when: String) -> Bool {
            let splits = when.split(separator: " ").compactMap { token -> Substring? in
                if token == "WHEN" || token.isEmpty {
                    return nil
                }
                return token
            }
            var stack: [Float] = []
            for token in splits {
                let tSplits = token.split(separator: ".")
                if tSplits.count == 2 {
                    let key = String(tSplits[0])
                    if tSplits[1] == "w" {
                        stack.append(sizeMap[key]?.0 ?? 0)
                        continue
                    }
                    if tSplits[1] == "h" {
                        stack.append(sizeMap[key]?.1 ?? 0)
                        continue
                    }
                }
                if ["+", "-", "*", "/", "<", ">"].contains(token) {
                    guard stack.count >= 2 else {
                        return false
                    }
                    let rhs = stack.removeLast()
                    let lhs = stack.removeLast()
                    switch token {
                    case "+":
                        stack.append(lhs + rhs)
                    case "-":
                        stack.append(lhs - rhs)
                    case "*":
                        stack.append(lhs * rhs)
                    case "/":
                        stack.append(rhs == 0 ? 0 : lhs / rhs)
                    case "<":
                        stack.append(lhs < rhs ? 1 : 0)
                    case ">":
                        stack.append(lhs > rhs ? 1 : 0)
                    default:
                        break
                    }
                    continue
                }
                if let value = Float(token) {
                    stack.append(value)
                }
            }
            guard stack.count == 1 else {
                return false
            }
            return stack[0] != 0
        }
    }

    private enum Anime4KError: Error, LocalizedError {
        case encoderCreationFail(String)
        case encoderFail(String)

        var errorDescription: String? {
            switch self {
            case let .encoderCreationFail(msg):
                "Cannot create encoder for \(msg)"
            case let .encoderFail(msg):
                "Failed to encode: \(msg)"
            }
        }
    }

    private struct MPVShader {
        var name: String
        var hook: String?
        var binds: [String]
        var save: String?
        var components: Int?
        var width: (String, Float)?
        var height: (String, Float)?
        var when: String?
        var sigma: Double?
        var code: [String]

        var functionName: String {
            var fn = name
            fn.removeAll { ".-()".contains($0) }
            return fn
        }

        var inputTextureNames: [String] {
            var names = binds
            if hook == "MAIN", !binds.contains("MAIN") {
                names.append("MAIN")
            }
            return names
        }

        var outputTextureName: String {
            if let save, save != "MAIN" {
                return save
            }
            return "output"
        }

        var metalCode: String {
            var header = """
            #include <metal_stdlib>
            using namespace metal;

            using vec2 = float2;
            using vec3 = float3;
            using vec4 = float4;
            using ivec2 = int2;
            using mat4 = float4x4;

            """

            for bind in binds {
                header += """
                #define \(bind)_pos mtlPos
                #define \(bind)_size float2(\(bind).get_width(), \(bind).get_height())
                #define \(bind)_pt (vec2(1, 1) / \(bind)_size)
                #define \(bind)_tex(pos) \(bind).sample(textureSampler, pos)
                #define \(bind)_texOff(off) \(bind)_tex(\(bind)_pos + \(bind)_pt * vec2(off))

                """
            }
            // MAIN 已在 for bind in binds 中定义时不再重复，避免 -Wmacro-redefined
            if hook == "MAIN", !binds.contains("MAIN") {
                header += """
                #define MAIN_pos mtlPos
                #define MAIN_pt (vec2(1, 1) / vec2(MAIN.get_width(), MAIN.get_height()))
                #define MAIN_size vec2(MAIN.get_width(), MAIN.get_height())
                #define MAIN_tex(pos) MAIN.sample(textureSampler, pos)
                #define MAIN_texOff(off) MAIN_tex(MAIN_pos + MAIN_pt * vec2(off))

                """
            }

            var extraArgs = "float2 mtlPos, sampler textureSampler, "
            var extraCallArgs = "mtlPos, textureSampler, "
            var entryArgs = ""
            for i in 0 ..< binds.count {
                extraArgs += "texture2d<float, access::sample> \(binds[i]), "
                extraCallArgs += "\(binds[i]), "
                entryArgs += "texture2d<float, access::sample> \(binds[i]) [[texture(\(i))]], "
            }
            var textureIdx = binds.count
            if hook == "MAIN", !binds.contains("MAIN") {
                extraArgs += "texture2d<float, access::sample> MAIN, "
                extraCallArgs += "MAIN, "
                entryArgs += "texture2d<float, access::sample> MAIN [[texture(\(textureIdx))]], "
                textureIdx += 1
            }
            entryArgs += "texture2d<float, access::write> output [[texture(\(textureIdx))]], "
            entryArgs += "uint2 gid [[thread_position_in_grid]], "
            entryArgs += "sampler textureSampler [[sampler(0)]]"

            var functions: [String] = []
            var currentFunc: String? = nil
            var body = ""

            for line in code {
                if currentFunc == nil {
                    let matches = MPVShader.matches(
                        for: "(\\w*\\s+)(\\w+)\\((.*)\\)(\\s+\\{)", in: line
                    )
                    if matches.count == 5 {
                        let returnType = matches[1]
                        let functionName = matches[2]
                        let args = matches[3]
                        let suffix = matches[4]
                        currentFunc = functionName
                        functions.append(functionName)
                        var extra = extraArgs
                        if args.isEmpty {
                            extra.removeLast(2)
                        }
                        body += returnType + functionName + "(" + extra + args + ")" + suffix + "\n"
                        continue
                    }
                } else if line == "}" {
                    currentFunc = nil
                }

                var newLine = line
                for function in functions {
                    newLine = newLine.replacingOccurrences(
                        of: function + "(", with: function + "(" + extraCallArgs
                    )
                    newLine = newLine.replacingOccurrences(of: ", )", with: ")")
                }
                body += newLine + "\n"
            }

            var hookCallArgs = extraCallArgs
            hookCallArgs.removeLast(2)
            body += """
            kernel void \(functionName)(\(entryArgs)) {
                float2 mtlPos = float2(gid) / (float2(output.get_width(), output.get_height()) - float2(1, 1));
                output.write(hook(\(hookCallArgs)), gid);
            }

            """
            return header + body
        }

        init(_ name: String) {
            self.name = name
            binds = []
            code = []
        }

        static func parse(_ glsl: String) throws -> [MPVShader] {
            var shaders: [MPVShader] = []
            var current: MPVShader?

            let glslLines = glsl.split(separator: "\n").map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            for line in glslLines {
                if line.isEmpty {
                    continue
                }
                if line.starts(with: "//") {
                    if !line.starts(with: "//!") {
                        continue
                    }
                    var info = line
                    info.removeFirst(3)
                    let split = info.split(separator: " ").map { String($0) }
                    switch split[0] {
                    case "DESC":
                        if let current {
                            shaders.append(current)
                        }
                        current = MPVShader(split[1])
                    case "HOOK":
                        current?.hook = split[1] == "PREKERNEL" ? "MAIN" : split[1]
                    case "BIND":
                        current?.binds.append(split[1])
                    case "SAVE":
                        current?.save = split[1]
                    case "WIDTH":
                        if split.count == 4 {
                            let base = String(split[1].split(separator: ".")[0])
                            if split[3] == "*" {
                                current?.width = (base, Float(split[2]) ?? 1)
                            } else if split[3] == "/" {
                                current?.width = (base, 1.0 / (Float(split[2]) ?? 1))
                            }
                        } else if split.count == 2 {
                            current?.width = (String(split[1].split(separator: ".")[0]), 1)
                        }
                    case "HEIGHT":
                        if split.count == 4 {
                            let base = String(split[1].split(separator: ".")[0])
                            if split[3] == "*" {
                                current?.height = (base, Float(split[2]) ?? 1)
                            } else if split[3] == "/" {
                                current?.height = (base, 1.0 / (Float(split[2]) ?? 1))
                            }
                        } else if split.count == 2 {
                            current?.height = (String(split[1].split(separator: ".")[0]), 1)
                        }
                    case "COMPONENTS":
                        current?.components = Int(split[1])
                    case "WHEN":
                        current?.when = info
                    default:
                        throw GLSLError.parseFail(String(line))
                    }
                    continue
                }

                if line.contains("#define SPATIAL_SIGMA") {
                    let matches = matches(for: "#define SPATIAL_SIGMA (\\d+).*", in: String(line))
                    if matches.count == 2, let value = Double(matches[1]) {
                        current?.sigma = value
                    }
                }
                if line.contains("#define KERNELSIZE int(max(int(SPATIAL_SIGMA), 1) * 2 + 1)"),
                   let sigma = current?.sigma
                {
                    current?.code.append("#define KERNELSIZE \(Int(max(Int(sigma), 1) * 2 + 1))")
                    continue
                }
                current?.code.append(String(line))
            }

            if let current {
                shaders.append(current)
            }
            return shaders
        }

        private static func matches(for regex: String, in text: String) -> [String] {
            do {
                let regex = try NSRegularExpression(pattern: regex)
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                return matches.flatMap { match in
                    (0 ..< match.numberOfRanges).map { index in
                        let bounds = match.range(at: index)
                        guard let range = Range(bounds, in: text) else {
                            return ""
                        }
                        return String(text[range])
                    }
                }
            } catch {
                return []
            }
        }
    }

    private enum GLSLError: Error, LocalizedError {
        case parseFail(String)

        var errorDescription: String? {
            switch self {
            case let .parseFail(line):
                "GLSL parse failed: \(line)"
            }
        }
    }

#endif
