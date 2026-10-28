import CinePlayerSDK
import ArtCNNMetal
import CoreMedia
import CoreVideo
import Foundation
import FSRMetal
import IOSurface
import Metal

/// 一个实例串行处理，使用现有StartupProcessor及Center管理准备、倍速、代次和预算。
final nonisolated class SpatialSuperResolutionProcessor: VideoFrameProcessor, @unchecked Sendable {
    enum Method: Sendable {
        case fsr(resolution: FSROutputResolution, sharpness: FSRSharpness)
        case artCNN
    }

    private let lock = NSLock()
    private let method: Method
    private let dimensions: CMVideoDimensions
    let outputDimensions: CMVideoDimensions
    private let queue: any MTLCommandQueue
    private let pool: SpatialOutputPool
    private let conversion = VideoEnhancementBGRAConversionCache()
    private let fsr: FSREngine?
    private let art: ArtCNNEngine?
    private let abCompare: SuperResolutionABCompare?

    static func isSupported() -> Bool {
        MTLCreateSystemDefaultDevice() != nil
    }

    static func canProcess(width: Int, height: Int, fps: Float) -> Bool {
        width > 0 && height > 0 && width <= 4096 && height <= 4096
            && width <= (1920 * 1080) / height && fps.isFinite && fps > 0 && fps <= 30
    }

    init(method: Method, dimensions: CMVideoDimensions, abCompareEnabled: Bool = false) throws {
        guard Self.canProcess(width: Int(dimensions.width), height: Int(dimensions.height), fps: 30),
              let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue()
        else {
            throw SpatialEnhancementError.unavailable("Spatial enhancement device or dimensions")
        }
        self.method = method; self.dimensions = dimensions; self.queue = queue
        switch method {
        case let .fsr(resolution, _):
            guard resolution.enlarges(width: Int(dimensions.width), height: Int(dimensions.height)) else {
                throw SpatialEnhancementError.unavailable("FSR requires an enlarged output")
            }
            let output = resolution.outputSize(width: Int(dimensions.width), height: Int(dimensions.height))
            outputDimensions = CMVideoDimensions(width: Int32(output.width), height: Int32(output.height))
            fsr = try FSREngine(device: device); art = nil
        case .artCNN:
            outputDimensions = CMVideoDimensions(width: dimensions.width * 2, height: dimensions.height * 2)
            art = try ArtCNNEngine(device: device); fsr = nil
        }
        pool = try SpatialOutputPool(device: device, input: dimensions, output: outputDimensions)
        if abCompareEnabled {
            abCompare = try SuperResolutionABCompare(device: device)
        } else {
            abCompare = nil
        }
    }

    /// 合成帧经过真实YUV转换及GPU路径，每个既有输出槽完整准备一次。
    func prepare() throws {
        try lock.withLock {
            try autoreleasepool {
                let input = try preparationInput()
                var outputs: [CVPixelBuffer] = []
                let count = art == nil ? 1 : pool.capacity
                for _ in 0 ..< count {
                    guard let output = try pool.acquire() else {
                        throw SpatialEnhancementError.unavailable("Preparation output slot")
                    }
                    outputs.append(output)
                }
                if art != nil {
                    let ids = outputs.compactMap { CVPixelBufferGetIOSurface($0).map { IOSurfaceGetID($0.takeUnretainedValue()) } }
                    guard Set(ids).count == pool.capacity, try pool.acquire() == nil else {
                        throw SpatialEnhancementError.unavailable("Preparation output ownership")
                    }
                }
                for output in outputs {
                    try render(input, output: output)
                }
                withExtendedLifetime(outputs) {}
            }
        }
    }

    func reserveOutputForNextFrame() -> Bool {
        guard lock.try() else {
            return false
        }
        defer { lock.unlock() }
        // 分配错误仍交由既有onFrame的失败直通处理；池满则保持原帧待消费。
        return (try? pool.reserveIfAvailable()) ?? true
    }

    func onFrame(_ context: VideoFrameContext) -> VideoFrameResult {
        lock.withLock {
            guard context.timebaseNum > 0, context.timebaseDen > 0, context.duration > 0,
                  Self.canProcess(width: CVPixelBufferGetWidth(context.pixelBuffer),
                                  height: CVPixelBufferGetHeight(context.pixelBuffer), fps: context.fps),
                  CVPixelBufferGetWidth(context.pixelBuffer) == Int(dimensions.width),
                  CVPixelBufferGetHeight(context.pixelBuffer) == Int(dimensions.height)
            else {
                return .passthrough
            }
            do {
                guard let output = try pool.acquire() else {
                    return .passthrough
                }
                try render(context.pixelBuffer, output: output)
                return .replace(pixelBuffer: output)
            } catch { return .passthrough }
        }
    }

    // 空间超分没有跨帧历史，倍速恢复时保留已准备的资源。
    func onInvalidate(newGeneration _: Int64) {}
    func drainPendingFrames() -> [GeneratedVideoFrame] {
        []
    }

    func onDrain() {
        lock.withLock { pool.cancelReservation() }
    }

    private func render(_ source: CVPixelBuffer, output: CVPixelBuffer) throws {
        defer { pool.finishFrame() }
        try pool.prepare(output, source: source)
        guard let bgra = conversion.convert(source, width: Int(dimensions.width), height: Int(dimensions.height)) else {
            throw SpatialEnhancementError.unavailable("BGRA conversion")
        }
        let input = try pool.surface(bgra), destination = try pool.surface(output)
        guard let command = queue.makeCommandBuffer() else {
            throw SpatialEnhancementError.unavailable("Spatial command")
        }
        if let art {
            guard let encoder = command.makeComputeCommandEncoder(dispatchType: .serial) else {
                throw SpatialEnhancementError.unavailable("ArtCNN encoder")
            }
            defer { encoder.endEncoding() }
            let originX = abCompare == nil ? 0 : SuperResolutionABCompare.originalSideWidth(outputWidth: destination.texture.width)
            try art.encode(encoder: encoder, input: input.texture, output: destination.texture,
                           coefficients: Self.coefficients(source), outputOriginX: originX)
            if let abCompare {
                try abCompare.encodeOriginalSide(encoder: encoder, original: input.texture, output: destination.texture)
            }
        } else if let fsr, case let .fsr(_, sharpness) = method {
            try fsr.encode(command: command, input: input.texture, output: destination.texture, sharpness: sharpness.parameter)
        }
        if art == nil, let abCompare {
            guard let encoder = command.makeComputeCommandEncoder() else {
                throw SpatialEnhancementError.unavailable("Spatial A/B encoder")
            }
            defer { encoder.endEncoding() }
            try abCompare.encodeOriginalSide(encoder: encoder, original: input.texture, output: destination.texture)
        }
        command.commit(); command.waitUntilCompleted()
        withExtendedLifetime((bgra, input.reference, destination.reference)) {}
        guard command.status == .completed else {
            throw SpatialEnhancementError.unavailable("Spatial GPU completion")
        }
    }

    static func coefficients(_ source: CVPixelBuffer) throws -> SIMD4<Float> {
        let matrix = CVBufferCopyAttachment(source, kCVImageBufferYCbCrMatrixKey, nil) as? String
        if matrix == kCVImageBufferYCbCrMatrix_ITU_R_601_4 as String {
            return SIMD4(0.299, 0.587, 0.114, 0)
        }
        if matrix == kCVImageBufferYCbCrMatrix_ITU_R_709_2 as String {
            return SIMD4(0.2126, 0.7152, 0.0722, 0)
        }
        if matrix == nil, CVPixelBufferGetPixelFormatType(source) == kCVPixelFormatType_32BGRA,
           CVBufferCopyAttachment(source, kCVImageBufferColorPrimariesKey, nil) as? String == kCVImageBufferColorPrimaries_ITU_R_709_2 as String
        {
            return SIMD4(0.2126, 0.7152, 0.0722, 0)
        }
        throw SpatialEnhancementError.unavailable("Unknown or unsupported ArtCNN matrix")
    }

    private func preparationInput() throws -> CVPixelBuffer {
        var input: CVPixelBuffer?
        let attrs = [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary
        guard CVPixelBufferCreate(nil, Int(dimensions.width), Int(dimensions.height), kCVPixelFormatType_420YpCbCr8Planar,
                                  attrs, &input) == kCVReturnSuccess, let input,
                                                CVPixelBufferLockBaseAddress(input, []) == kCVReturnSuccess
        else {
            throw SpatialEnhancementError.unavailable("Preparation YUV input")
        }
        defer { CVPixelBufferUnlockBaseAddress(input, []) }
        for plane in 0 ..< CVPixelBufferGetPlaneCount(input) {
            guard let address = CVPixelBufferGetBaseAddressOfPlane(input, plane) else {
                throw SpatialEnhancementError.unavailable("YUV plane")
            }
            let count = CVPixelBufferGetBytesPerRowOfPlane(input, plane) * CVPixelBufferGetHeightOfPlane(input, plane)
            address.assumingMemoryBound(to: UInt8.self).initialize(repeating: plane == 0 ? 16 : 128, count: count)
        }
        for (key, value) in [
            (kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2),
            (kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2),
            (kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2)
        ] {
            CVBufferSetAttachment(input, key, value, .shouldPropagate)
        }
        return input
    }
}
