import CinePlayerSDK
import CoreMedia
import CoreVideo
import Foundation
import Metal

final nonisolated class SpatialOutputPool {
    let capacity = 3
    let cache: CVMetalTextureCache
    private let pool: CVPixelBufferPool
    private let input: CMVideoDimensions
    private let output: CMVideoDimensions
    private var reserved: CVPixelBuffer?

    init(device: any MTLDevice, input: CMVideoDimensions, output: CMVideoDimensions) throws {
        self.input = input; self.output = output
        var pool: CVPixelBufferPool?
        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(output.width),
            kCVPixelBufferHeightKey as String: Int(output.height),
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        guard CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool) == kCVReturnSuccess, let pool else {
            throw SpatialEnhancementError.unavailable("Output pool")
        }
        self.pool = pool
        var cache: CVMetalTextureCache?
        guard CVMetalTextureCacheCreate(nil, nil, device, nil, &cache) == kCVReturnSuccess, let cache else {
            throw SpatialEnhancementError.unavailable("Texture cache")
        }
        self.cache = cache
    }

    func acquire() throws -> CVPixelBuffer? {
        if let reserved {
            self.reserved = nil
            return reserved
        }
        return try allocate()
    }

    func reserveIfAvailable() throws -> Bool {
        if reserved == nil {
            reserved = try allocate()
        }
        return reserved != nil
    }

    func cancelReservation() {
        reserved = nil
    }

    private func allocate() throws -> CVPixelBuffer? {
        var result: CVPixelBuffer?
        let attrs = [kCVPixelBufferPoolAllocationThresholdKey as String: capacity] as CFDictionary
        let status = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(nil, pool, attrs, &result)
        if status == kCVReturnWouldExceedAllocationThreshold {
            return nil
        }
        guard status == kCVReturnSuccess, let result else {
            throw SpatialEnhancementError.unavailable("Output slot")
        }
        return result
    }

    func surface(_ buffer: CVPixelBuffer) throws -> (texture: any MTLTexture, reference: CVMetalTexture) {
        var reference: CVMetalTexture?
        guard CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA,
              CVMetalTextureCacheCreateTextureFromImage(nil, cache, buffer, nil, .bgra8Unorm,
                                                        CVPixelBufferGetWidth(buffer), CVPixelBufferGetHeight(buffer), 0, &reference) ==
              kCVReturnSuccess,
              let reference, let texture = CVMetalTextureGetTexture(reference)
        else {
            throw SpatialEnhancementError.unavailable("BGRA Metal mapping")
        }
        return (texture, reference)
    }

    func finishFrame() {
        CVMetalTextureCacheFlush(cache, 0)
    }

    func prepare(_ buffer: CVPixelBuffer, source: CVPixelBuffer) throws {
        guard buffer !== source, CVPixelBufferGetWidth(source) == Int(input.width),
              CVPixelBufferGetHeight(source) == Int(input.height),
              CVPixelBufferGetWidth(buffer) == Int(output.width), CVPixelBufferGetHeight(buffer) == Int(output.height),
              CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA
        else {
            throw SpatialEnhancementError.unavailable("Output dimensions")
        }
        let transfer = CVBufferCopyAttachment(source, kCVImageBufferTransferFunctionKey, nil) as? String
        let hdrKeys = [
            kCVImageBufferMasteringDisplayColorVolumeKey,
            kCVImageBufferContentLightLevelInfoKey,
            "DolbyVisionRPUData" as CFString
        ]
        guard transfer != kCVImageBufferTransferFunction_SMPTE_ST_2084_PQ as String,
              transfer != kCVImageBufferTransferFunction_ITU_R_2100_HLG as String,
              hdrKeys.allSatisfy({ CVBufferCopyAttachment(source, $0, nil) == nil })
        else {
            throw SpatialEnhancementError.unavailable("SDR input required")
        }
        CVBufferRemoveAllAttachments(buffer)
        for key in [
            kCVImageBufferColorPrimariesKey,
            kCVImageBufferTransferFunctionKey,
            kCVImageBufferGammaLevelKey,
            kCVImageBufferCGColorSpaceKey,
            kCVImageBufferPixelAspectRatioKey
        ] {
            if let value = CVBufferCopyAttachment(source, key, nil) {
                CVBufferSetAttachment(buffer, key, value, .shouldPropagate)
            }
        }
        CVBufferSetAttachment(buffer, kCMFormatDescriptionExtension_FullRangeVideo, kCFBooleanTrue, .shouldPropagate)
        CVBufferSetAttachment(buffer, kCVImageBufferFieldCountKey, NSNumber(value: 1), .shouldPropagate)
        if let aperture = CVBufferCopyAttachment(source, kCVImageBufferCleanApertureKey, nil) as? [String: Any] {
            let sx = Double(output.width) / Double(input.width), sy = Double(output.height) / Double(input.height)
            var scaled: [String: Double] = [:]
            for (key, scale) in [
                (kCVImageBufferCleanApertureWidthKey, sx),
                (kCVImageBufferCleanApertureHeightKey, sy),
                (kCVImageBufferCleanApertureHorizontalOffsetKey, sx),
                (kCVImageBufferCleanApertureVerticalOffsetKey, sy)
            ] {
                guard let value = aperture[key as String] as? NSNumber, value.doubleValue.isFinite else {
                    throw SpatialEnhancementError.unavailable("Source aperture")
                }
                scaled[key as String] = value.doubleValue * scale
            }
            guard scaled[kCVImageBufferCleanApertureWidthKey as String]! > 0,
                  scaled[kCVImageBufferCleanApertureHeightKey as String]! > 0
            else {
                throw SpatialEnhancementError.unavailable("Empty aperture")
            }
            CVBufferSetAttachment(buffer, kCVImageBufferCleanApertureKey, scaled as CFDictionary, .shouldPropagate)
            let stored = CVBufferCopyAttachment(buffer, kCVImageBufferCleanApertureKey, nil) as? [String: Any]
            guard scaled.allSatisfy({ key, value in
                guard let actual = stored?[key] as? NSNumber else {
                    return false
                }
                return abs(actual.doubleValue - value) <= 1e-9
            }) else {
                throw SpatialEnhancementError.unavailable("Aperture precision")
            }
        }
    }
}
