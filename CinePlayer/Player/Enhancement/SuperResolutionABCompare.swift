import CinePlayerSDK
import Anime4KMetal
import CoreVideo
import Metal

/// 共用Anime4K的分屏shader；编码入口使用调用方的输出和encoder，不分配合成帧。
final nonisolated class SuperResolutionABCompare {
    private let pipeline: any MTLComputePipelineState

    init(device: any MTLDevice) throws {
        let library = try Anime4KMetalLibrary.makeDefaultLibrary(device: device)
        guard let function = library.makeFunction(name: "ABCompareSplit") else {
            throw SpatialEnhancementError.unavailable("A/B shader")
        }
        pipeline = try device.makeComputePipelineState(function: function)
    }

    /// 原画半侧包含整条中线，增强输出从此列开始，两个区域各写一次。
    static func originalSideWidth(outputWidth: Int) -> Int {
        guard outputWidth > 0 else {
            return 0
        }
        return min(outputWidth, outputWidth / 2 + Anime4KHostEngine.abCompareRedLineHalfWidth(outputWidth: outputWidth) + 1)
    }

    func encodeSplit(
        encoder: any MTLComputeCommandEncoder,
        original: any MTLTexture,
        enhanced: any MTLTexture,
        output: any MTLTexture
    ) throws {
        try encode(encoder: encoder, original: original, enhanced: enhanced, output: output, width: output.width)
    }

    func encodeOriginalSide(
        encoder: any MTLComputeCommandEncoder,
        original: any MTLTexture,
        output: any MTLTexture
    ) throws {
        // 左半侧和红线不会使用增强纹理；绑定原画，避免将输出同时作为采样源。
        try encode(encoder: encoder, original: original, enhanced: original, output: output,
                   width: Self.originalSideWidth(outputWidth: output.width))
    }

    private func encode(
        encoder: any MTLComputeCommandEncoder,
        original: any MTLTexture,
        enhanced: any MTLTexture,
        output: any MTLTexture,
        width: Int
    ) throws {
        guard original !== output, enhanced !== output else {
            throw SpatialEnhancementError.unavailable("A/B input/output alias")
        }
        var lineHalfWidth = UInt32(Anime4KHostEngine.abCompareRedLineHalfWidth(outputWidth: output.width))
        encoder.setComputePipelineState(pipeline)
        encoder.setTexture(original, index: 0)
        encoder.setTexture(enhanced, index: 1)
        encoder.setTexture(output, index: 2)
        encoder.setBytes(&lineHalfWidth, length: MemoryLayout<UInt32>.stride, index: 0)
        encoder.dispatchThreads(MTLSize(width: width, height: output.height, depth: 1),
                                threadsPerThreadgroup: MTLSize(width: 16, height: 8, depth: 1))
    }

    /// VT不公开内部命令缓冲，只在其已有的、尚未交付的BGRA输出上提交一次后处理。
    func applyToOwnedOutput(
        original: CVPixelBuffer,
        output: CVPixelBuffer,
        commands: any MTLCommandQueue,
        cache: CVMetalTextureCache
    ) throws {
        guard original !== output else {
            throw SpatialEnhancementError.unavailable("A/B pixel buffer alias")
        }
        defer { CVMetalTextureCacheFlush(cache, 0) }
        func surface(_ buffer: CVPixelBuffer) throws -> (reference: CVMetalTexture, texture: any MTLTexture) {
            var reference: CVMetalTexture?
            guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
                  CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, .bgra8Unorm,
                                                            CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer),
                                                            0, &reference) == kCVReturnSuccess,
                  let reference, let texture = CVMetalTextureGetTexture(reference)
            else {
                throw SpatialEnhancementError.unavailable("A/B BGRA mapping")
            }
            return (reference, texture)
        }
        let input = try surface(original), destination = try surface(output)
        guard let command = commands.makeCommandBuffer(), let encoder = command.makeComputeCommandEncoder() else {
            throw SpatialEnhancementError.unavailable("A/B command")
        }
        do {
            try encodeOriginalSide(encoder: encoder, original: input.texture, output: destination.texture)
        } catch {
            encoder.endEncoding()
            throw error
        }
        encoder.endEncoding()
        command.commit()
        command.waitUntilCompleted()
        withExtendedLifetime((input.reference, destination.reference, original, output)) {}
        guard command.status == .completed else {
            throw SpatialEnhancementError.unavailable("A/B GPU completion")
        }
    }
}
