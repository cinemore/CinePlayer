import CoreVideo

extension CVPixelBuffer {
    func copy() -> CVPixelBuffer? {
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
