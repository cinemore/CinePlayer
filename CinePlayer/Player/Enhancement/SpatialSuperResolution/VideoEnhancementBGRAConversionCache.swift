import CinePlayerSDK
import CoreVideo
import VideoToolbox

/// 由适配器的串行队列／锁保护，复用转换session及最多两种尺寸的缓冲池。
final nonisolated class VideoEnhancementBGRAConversionCache {
    private struct Size: Hashable { let width: Int; let height: Int }
    private var pools: [Size: CVPixelBufferPool] = [:]
    private var session: VTPixelTransferSession?

    func reset() {
        pools.removeAll()
        if let session {
            VTPixelTransferSessionInvalidate(session)
        }
        session = nil
    }

    deinit {
        if let session {
            VTPixelTransferSessionInvalidate(session)
        }
    }

    func convert(_ source: CVPixelBuffer, width: Int, height: Int) -> CVPixelBuffer? {
        if CVPixelBufferGetPixelFormatType(source) == kCVPixelFormatType_32BGRA {
            return source
        }
        let size = Size(width: width, height: height)
        if pools[size] == nil {
            var pool: CVPixelBufferPool?
            let attrs: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            guard CVPixelBufferPoolCreate(nil, nil, attrs as CFDictionary, &pool) == kCVReturnSuccess,
                  let pool
            else {
                return nil
            }
            if pools.count >= 2 {
                pools.removeAll()
            }
            pools[size] = pool
        }
        if session == nil {
            guard VTPixelTransferSessionCreate(allocator: nil, pixelTransferSessionOut: &session) == noErr else {
                return nil
            }
        }
        guard let pool = pools[size], let session else {
            return nil
        }
        var output: CVPixelBuffer?
        guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &output) == kCVReturnSuccess, let output else {
            return nil
        }
        CVBufferRemoveAllAttachments(output)
        guard VTPixelTransferSessionTransferImage(session, from: source, to: output) == noErr else {
            return nil
        }
        return output
    }
}
