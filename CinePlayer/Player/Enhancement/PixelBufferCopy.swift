import CoreVideo
import Foundation

extension CVPixelBufferPool {
    nonisolated static func create(
        width: Int32,
        height: Int32,
        bytesPerRowAlignment: Int32,
        pixelFormatType: OSType,
        minimumBufferCount: Int? = nil
    ) -> CVPixelBufferPool? {
        let attrs: NSMutableDictionary = [
            kCVPixelBufferPixelFormatTypeKey: pixelFormatType,
            kCVPixelBufferWidthKey: width,
            kCVPixelBufferHeightKey: height,
            kCVPixelBufferBytesPerRowAlignmentKey: bytesPerRowAlignment.aligned(to: 64),
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferIOSurfacePropertiesKey: NSDictionary(),
        ]
        let poolOptions: NSDictionary? = minimumBufferCount.map {
            [kCVPixelBufferPoolMinimumBufferCountKey: $0] as NSDictionary
        }
        var pool: CVPixelBufferPool?
        CVPixelBufferPoolCreate(
            kCFAllocatorDefault,
            poolOptions,
            attrs,
            &pool
        )
        return pool
    }
}

private extension Int32 {
    nonisolated func aligned(to alignment: Int32) -> Int32 {
        guard alignment > 0 else {
            return self
        }
        return ((self + alignment - 1) / alignment) * alignment
    }
}

extension CVPixelBuffer {
    nonisolated func copy() -> CVPixelBuffer? {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
        let pixelFormat = CVPixelBufferGetPixelFormatType(self)
        let planar = CVPixelBufferIsPlanar(self)

        var output: CVPixelBuffer?
        var attrs = (CVPixelBufferCopyCreationAttributes(self) as? [String: Any]) ?? [:]
        attrs[kCVPixelBufferWidthKey as String] = width
        attrs[kCVPixelBufferHeightKey as String] = height
        attrs[kCVPixelBufferPixelFormatTypeKey as String] = pixelFormat

        guard CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            attrs as CFDictionary,
            &output
        ) == kCVReturnSuccess,
        let copied = output
        else {
            return nil
        }

        CVPixelBufferLockBaseAddress(self, .readOnly)
        CVPixelBufferLockBaseAddress(copied, [])
        defer {
            CVPixelBufferUnlockBaseAddress(copied, [])
            CVPixelBufferUnlockBaseAddress(self, .readOnly)
        }

        if planar {
            let planeCount = CVPixelBufferGetPlaneCount(self)
            for plane in 0..<planeCount {
                guard let src = CVPixelBufferGetBaseAddressOfPlane(self, plane),
                      let dst = CVPixelBufferGetBaseAddressOfPlane(copied, plane)
                else {
                    return nil
                }
                let planeHeight = CVPixelBufferGetHeightOfPlane(self, plane)
                let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(self, plane)
                memcpy(dst, src, planeHeight * bytesPerRow)
            }
            return copied
        }

        guard let src = CVPixelBufferGetBaseAddress(self),
              let dst = CVPixelBufferGetBaseAddress(copied)
        else {
            return nil
        }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(self)
        memcpy(dst, src, height * bytesPerRow)
        return copied
    }
}

extension CVBuffer {
    nonisolated func copyPropagatedAttachments(to target: CVBuffer) {
        if let attachments = CVBufferCopyAttachments(self, .shouldPropagate) {
            CVBufferSetAttachments(target, attachments, .shouldPropagate)
        }
    }
}
