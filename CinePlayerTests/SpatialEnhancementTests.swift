import CinePlayerSDK
import CoreMedia
import CoreVideo
import Foundation
import Metal
import Testing
@testable import CinePlayer

#if os(macOS)
@Suite(.serialized, .timeLimit(.minutes(1)))
@MainActor
struct SpatialEnhancementTests {
    @Test(arguments: [false, true])
    func realGPUOutputAndBackpressure(artCNN: Bool) throws {
        let input = try EnhancementStartupProcessor.warmupFrame(CMVideoDimensions(width: 32, height: 18))
        CVBufferSetAttachment(input.pixelBuffer, kCVImageBufferColorPrimariesKey,
                              kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(input.pixelBuffer, kCVImageBufferTransferFunctionKey,
                              kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        let processor = try SpatialSuperResolutionProcessor(
            method: artCNN ? .artCNN : .fsr(resolution: .fullHD, sharpness: .medium),
            dimensions: CMVideoDimensions(width: 32, height: 18)
        )
        defer { processor.onDrain() }
        try processor.prepare()
        var outputs: [CVPixelBuffer] = []
        for _ in 0..<3 {
            #expect(processor.reserveOutputForNextFrame())
            guard case let .replace(output) = processor.onFrame(input) else {
                Issue.record("Prepared GPU processor must produce an enhanced frame")
                return
            }
            #expect(output !== input.pixelBuffer)
            #expect(CVPixelBufferGetWidth(output) == (artCNN ? 64 : 1920))
            #expect(CVPixelBufferGetHeight(output) == (artCNN ? 36 : 1080))
            #expect(CVPixelBufferGetPixelFormatType(output) == kCVPixelFormatType_32BGRA)
            outputs.append(output)
        }
        #expect(!processor.reserveOutputForNextFrame())
        outputs.removeAll()
        #expect(processor.reserveOutputForNextFrame())
    }

    @Test func hdrFrameCannotEnterSDRProcessor() throws {
        let input = try EnhancementStartupProcessor.warmupFrame(CMVideoDimensions(width: 32, height: 18))
        CVBufferSetAttachment(input.pixelBuffer, kCVImageBufferTransferFunctionKey,
                              kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ, .shouldPropagate)
        let processor = try SpatialSuperResolutionProcessor(
            method: .fsr(resolution: .fullHD, sharpness: .off),
            dimensions: CMVideoDimensions(width: 32, height: 18)
        )
        defer { processor.onDrain() }
        guard case .passthrough = processor.onFrame(input) else {
            Issue.record("HDR input must keep its original frame")
            return
        }
    }
}
#endif
