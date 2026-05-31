import CinePlayerSDK
import CoreVideo
import Foundation
import Metal
import VideoToolbox
#if canImport(MetalFX)
@preconcurrency import MetalFX
#endif

#if !os(tvOS)
#if canImport(MetalFX)
    nonisolated final class MetalFXSuperResolutionAdapter: @unchecked Sendable {
        static let shared = MetalFXSuperResolutionAdapter()

        private let queue = DispatchQueue(
            label: "cn.com.cinemore.metalfx.super-resolution.adapter",
            qos: .userInitiated
        )
        private var device: MTLDevice?
        private var commandQueue: MTLCommandQueue?
        private var textureCache: CVMetalTextureCache?
        private var scaler: MTLFXSpatialScaler?
        private var scalerInputSize: (width: Int, height: Int)?
        private var scalerOutputSize: (width: Int, height: Int)?
        private var privateOutputTexture: MTLTexture?
        private var privateOutputTextureKey: (width: Int, height: Int)?
        private var bgraPool: CVPixelBufferPool?
        private var bgraPoolKey: (width: Int, height: Int)?
        private var outputPool: CVPixelBufferPool?
        private var outputPoolKey: (width: Int, height: Int)?
        private var transferSession: VTPixelTransferSession?
        private var processedFrames = 0

        nonisolated static func isSupported(
            on device: MTLDevice? = MTLCreateSystemDefaultDevice()
        ) -> Bool {
            guard #available(iOS 16.0, macOS 13.0, *) else {
                return false
            }
            guard let device else {
                return false
            }
            return MTLFXSpatialScalerDescriptor.supportsDevice(device)
        }

        nonisolated func endSession() {
            queue.sync {
                scaler = nil
                scalerInputSize = nil
                scalerOutputSize = nil
                privateOutputTexture = nil
                privateOutputTextureKey = nil
                bgraPool = nil
                bgraPoolKey = nil
                outputPool = nil
                outputPoolKey = nil
                textureCache = nil
                commandQueue = nil
                device = nil
                if let transferSession {
                    VTPixelTransferSessionInvalidate(transferSession)
                }
                transferSession = nil
            }
        }

        nonisolated func processSingleFrame(
            context: VideoFrameContext,
            targetOutputResolution: MetalFXOutputResolution,
            abCompareEnabled: Bool = false
        ) -> CVPixelBuffer? {
            queue.sync {
                processSingleFrameOnQueue(
                    context: context,
                    targetOutputResolution: targetOutputResolution,
                    abCompareEnabled: abCompareEnabled
                )
            }
        }

        private func processSingleFrameOnQueue(
            context: VideoFrameContext,
            targetOutputResolution: MetalFXOutputResolution,
            abCompareEnabled: Bool
        ) -> CVPixelBuffer? {
            guard Self.isSupported(on: device ?? MTLCreateSystemDefaultDevice()) else {
                return nil
            }
            guard let resources = ensureResources() else {
                return nil
            }
            let inputWidth = CVPixelBufferGetWidth(context.pixelBuffer)
            let inputHeight = CVPixelBufferGetHeight(context.pixelBuffer)
            guard inputWidth > 0, inputHeight > 0 else {
                return nil
            }

            let (outputWidth, outputHeight) = resolvedOutputSize(
                width: inputWidth,
                height: inputHeight,
                targetOutputResolution: targetOutputResolution
            )
            guard outputWidth > inputWidth || outputHeight > inputHeight else {
                return nil
            }

            guard let sourceBGRA = pixelBufferAsBGRA(
                context.pixelBuffer,
                width: inputWidth,
                height: inputHeight
            ) else {
                return nil
            }
            guard let sourceTexture = makeTexture(
                from: sourceBGRA,
                textureCache: resources.textureCache,
                pixelFormat: .bgra8Unorm
            ) else {
                return nil
            }
            guard let scaler = ensureScaler(
                device: resources.device,
                inputWidth: inputWidth,
                inputHeight: inputHeight,
                outputWidth: outputWidth,
                outputHeight: outputHeight
            ) else {
                return nil
            }
            guard let outputTexture = ensurePrivateOutputTexture(
                width: outputWidth,
                height: outputHeight,
                device: resources.device
            ) else {
                return nil
            }
            guard let outputPool = ensureOutputPool(width: outputWidth, height: outputHeight)
            else {
                return nil
            }

            var outputBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, outputPool, &outputBuffer)
                == kCVReturnSuccess,
                let outputBuffer
            else {
                return nil
            }

            context.pixelBuffer.copyPropagatedAttachments(to: outputBuffer)
            guard let exportTexture = makeTexture(
                from: outputBuffer,
                textureCache: resources.textureCache,
                pixelFormat: .bgra8Unorm
            ) else {
                return nil
            }

            defer {
                CVMetalTextureCacheFlush(resources.textureCache, 0)
            }

            guard let commandBuffer = resources.commandQueue.makeCommandBuffer() else {
                return nil
            }
            scaler.colorTexture = sourceTexture
            scaler.inputContentWidth = inputWidth
            scaler.inputContentHeight = inputHeight
            scaler.outputTexture = outputTexture
            scaler.encode(commandBuffer: commandBuffer)

            guard let blitEncoder = commandBuffer.makeBlitCommandEncoder() else {
                return nil
            }
            blitEncoder.copy(
                from: outputTexture,
                sourceSlice: 0,
                sourceLevel: 0,
                sourceOrigin: MTLOrigin(x: 0, y: 0, z: 0),
                sourceSize: MTLSize(width: outputWidth, height: outputHeight, depth: 1),
                to: exportTexture,
                destinationSlice: 0,
                destinationLevel: 0,
                destinationOrigin: MTLOrigin(x: 0, y: 0, z: 0)
            )
            blitEncoder.endEncoding()

            commandBuffer.commit()
            commandBuffer.waitUntilCompleted()
            guard commandBuffer.status == .completed else {
                return nil
            }

            processedFrames += 1
            if processedFrames <= 3 || processedFrames % 120 == 0 {
                cinemoreLog(
                    level: .debug,
                    "MetalFX super resolution frame input=\(inputWidth)x\(inputHeight) output=\(outputWidth)x\(outputHeight) target=\(targetOutputResolution.rawValue) abCompare=\(abCompareEnabled)"
                )
            }

            guard abCompareEnabled else {
                return outputBuffer
            }
            if let ab = Anime4KHostBridge.makeABComparePixelBuffer(
                original: sourceBGRA,
                enhanced: outputBuffer
            ) {
                return ab
            }
            return outputBuffer
        }

        nonisolated private struct Resources {
            let device: MTLDevice
            let commandQueue: MTLCommandQueue
            let textureCache: CVMetalTextureCache
        }

        private func ensureResources() -> Resources? {
            if let device, let commandQueue, let textureCache {
                return Resources(
                    device: device,
                    commandQueue: commandQueue,
                    textureCache: textureCache
                )
            }
            guard let newDevice = MTLCreateSystemDefaultDevice(),
                  let newCommandQueue = newDevice.makeCommandQueue()
            else {
                return nil
            }
            var createdCache: CVMetalTextureCache?
            guard CVMetalTextureCacheCreate(
                kCFAllocatorDefault,
                nil,
                newDevice,
                nil,
                &createdCache
            ) == kCVReturnSuccess,
                let createdCache
            else {
                return nil
            }
            device = newDevice
            commandQueue = newCommandQueue
            textureCache = createdCache
            return Resources(
                device: newDevice,
                commandQueue: newCommandQueue,
                textureCache: createdCache
            )
        }

        private func resolvedOutputSize(
            width: Int,
            height: Int,
            targetOutputResolution: MetalFXOutputResolution
        ) -> (Int, Int) {
            let ratio = min(
                Double(targetOutputResolution.maxWidth) / Double(width),
                Double(targetOutputResolution.maxHeight) / Double(height)
            )
            guard ratio > 1.0 else {
                return (width, height)
            }
            return (
                max(width, Int((Double(width) * ratio).rounded(.down))),
                max(height, Int((Double(height) * ratio).rounded(.down)))
            )
        }

        private func ensureScaler(
            device: MTLDevice,
            inputWidth: Int,
            inputHeight: Int,
            outputWidth: Int,
            outputHeight: Int
        ) -> MTLFXSpatialScaler? {
            if let scaler,
               let scalerInputSize,
               let scalerOutputSize,
               scalerInputSize.width == inputWidth,
               scalerInputSize.height == inputHeight,
               scalerOutputSize.width == outputWidth,
               scalerOutputSize.height == outputHeight
            {
                return scaler
            }
            guard #available(iOS 16.0, macOS 13.0, *) else {
                return nil
            }
            let descriptor = MTLFXSpatialScalerDescriptor()
            descriptor.inputWidth = inputWidth
            descriptor.inputHeight = inputHeight
            descriptor.outputWidth = outputWidth
            descriptor.outputHeight = outputHeight
            descriptor.colorTextureFormat = .bgra8Unorm
            descriptor.outputTextureFormat = .bgra8Unorm
            descriptor.colorProcessingMode = .perceptual
            guard let scaler = descriptor.makeSpatialScaler(device: device) else {
                return nil
            }
            self.scaler = scaler
            scalerInputSize = (inputWidth, inputHeight)
            scalerOutputSize = (outputWidth, outputHeight)
            privateOutputTexture = nil
            privateOutputTextureKey = nil
            return scaler
        }

        private func ensurePrivateOutputTexture(
            width: Int,
            height: Int,
            device: MTLDevice
        ) -> MTLTexture? {
            if let privateOutputTexture,
               let privateOutputTextureKey,
               privateOutputTextureKey.width == width,
               privateOutputTextureKey.height == height
            {
                return privateOutputTexture
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm,
                width: width,
                height: height,
                mipmapped: false
            )
            descriptor.storageMode = .private
            descriptor.usage = [.shaderRead, .shaderWrite, .renderTarget]
            let texture = device.makeTexture(descriptor: descriptor)
            privateOutputTexture = texture
            privateOutputTextureKey = (width, height)
            return texture
        }

        private func ensureBGRAPool(width: Int, height: Int) -> CVPixelBufferPool? {
            if let bgraPool,
               let bgraPoolKey,
               bgraPoolKey.width == width,
               bgraPoolKey.height == height
            {
                return bgraPool
            }
            let pool = CVPixelBufferPool.create(
                width: Int32(width),
                height: Int32(height),
                bytesPerRowAlignment: Int32(width * 4),
                pixelFormatType: kCVPixelFormatType_32BGRA,
                minimumBufferCount: 3
            )
            bgraPool = pool
            bgraPoolKey = (width, height)
            return pool
        }

        private func ensureOutputPool(width: Int, height: Int) -> CVPixelBufferPool? {
            if let outputPool,
               let outputPoolKey,
               outputPoolKey.width == width,
               outputPoolKey.height == height
            {
                return outputPool
            }
            let pool = CVPixelBufferPool.create(
                width: Int32(width),
                height: Int32(height),
                bytesPerRowAlignment: Int32(width * 4),
                pixelFormatType: kCVPixelFormatType_32BGRA,
                minimumBufferCount: 3
            )
            outputPool = pool
            outputPoolKey = (width, height)
            return pool
        }

        private func ensureTransferSession() -> VTPixelTransferSession? {
            if let transferSession {
                return transferSession
            }
            var session: VTPixelTransferSession?
            guard VTPixelTransferSessionCreate(
                allocator: kCFAllocatorDefault,
                pixelTransferSessionOut: &session
            ) == noErr,
                let session
            else {
                return nil
            }
            transferSession = session
            return session
        }

        private func pixelBufferAsBGRA(
            _ buffer: CVPixelBuffer,
            width: Int,
            height: Int
        ) -> CVPixelBuffer? {
            if CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA {
                return buffer
            }
            guard let pool = ensureBGRAPool(width: width, height: height) else {
                return nil
            }
            var outBuffer: CVPixelBuffer?
            guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outBuffer) == kCVReturnSuccess,
                  let outBuffer,
                  let transferSession = ensureTransferSession()
            else {
                return nil
            }
            if let attachments = CVBufferCopyAttachments(buffer, .shouldPropagate) {
                CVBufferSetAttachments(outBuffer, attachments, .shouldPropagate)
            }
            guard VTPixelTransferSessionTransferImage(
                transferSession,
                from: buffer,
                to: outBuffer
            ) == noErr else {
                return nil
            }
            return outBuffer
        }

        private func makeTexture(
            from pixelBuffer: CVPixelBuffer,
            textureCache: CVMetalTextureCache,
            pixelFormat: MTLPixelFormat
        ) -> MTLTexture? {
            let width = CVPixelBufferGetWidth(pixelBuffer)
            let height = CVPixelBufferGetHeight(pixelBuffer)
            var textureRef: CVMetalTexture?
            guard CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                pixelBuffer,
                nil,
                pixelFormat,
                width,
                height,
                0,
                &textureRef
            ) == kCVReturnSuccess,
                let textureRef
            else {
                return nil
            }
            return CVMetalTextureGetTexture(textureRef)
        }
    }

    nonisolated final class MetalFXSuperResolutionProcessor: VideoFrameProcessor,
        @unchecked Sendable
    {
        private let adapter: MetalFXSuperResolutionAdapter
        private let targetOutputResolution: MetalFXOutputResolution
        private let abCompareEnabled: Bool

        init(
            adapter: MetalFXSuperResolutionAdapter,
            targetOutputResolution: MetalFXOutputResolution,
            abCompareEnabled: Bool
        ) {
            self.adapter = adapter
            self.targetOutputResolution = targetOutputResolution
            self.abCompareEnabled = abCompareEnabled
        }

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            guard let enhanced = adapter.processSingleFrame(
                context: ctx,
                targetOutputResolution: targetOutputResolution,
                abCompareEnabled: abCompareEnabled
            ) else {
                return .passthrough
            }
            return .replace(pixelBuffer: enhanced)
        }

        func onInvalidate(newGeneration _: Int64) {}

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {}
    }
#else
    nonisolated final class MetalFXSuperResolutionAdapter: @unchecked Sendable {
        static let shared = MetalFXSuperResolutionAdapter()

        nonisolated static func isSupported(on _: MTLDevice? = nil) -> Bool {
            false
        }

        nonisolated func endSession() {}

        nonisolated func processSingleFrame(
            context _: VideoFrameContext,
            targetOutputResolution _: MetalFXOutputResolution,
            abCompareEnabled _: Bool = false
        ) -> CVPixelBuffer? {
            nil
        }
    }

    nonisolated final class MetalFXSuperResolutionProcessor: VideoFrameProcessor,
        @unchecked Sendable
    {
        init(
            adapter _: MetalFXSuperResolutionAdapter,
            targetOutputResolution _: MetalFXOutputResolution,
            abCompareEnabled _: Bool
        ) {}

        func onFrame(_: VideoFrameContext) -> VideoFrameResult {
            .passthrough
        }

        func onInvalidate(newGeneration _: Int64) {}

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {}
    }
#endif
#endif
