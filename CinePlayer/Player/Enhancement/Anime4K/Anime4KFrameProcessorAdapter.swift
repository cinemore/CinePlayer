import Anime4KMetal
import CinePlayerSDK
import CoreVideo
import Foundation

#if !os(tvOS)
    nonisolated enum Anime4KHostBridge {
        private final class EngineStore: @unchecked Sendable {
            let lock = NSLock()
            var engine: Anime4KHostEngine?
        }

        private static let store = EngineStore()

        static func reset() {
            store.lock.lock()
            store.engine?.reset()
            store.engine = nil
            store.lock.unlock()
        }

        static func makeEngine() throws -> Anime4KHostEngine {
            store.lock.lock()
            defer { store.lock.unlock() }
            if let engine = store.engine {
                return engine
            }
            let newEngine = try Anime4KHostEngine()
            store.engine = newEngine
            return newEngine
        }

        static func abCompareRedLineHalfWidth(outputWidth: Int) -> Int {
            Anime4KHostEngine.abCompareRedLineHalfWidth(outputWidth: outputWidth)
        }

        static func makeABComparePixelBuffer(
            original: CVPixelBuffer,
            enhanced: CVPixelBuffer
        ) -> CVPixelBuffer? {
            try? makeEngine().makeABComparePixelBuffer(original: original, enhanced: enhanced)
        }
    }

    nonisolated final class Anime4KSingleFrameProcessor: VideoFrameProcessor, @unchecked Sendable {
        private let interpolator: Anime4KInterpolator
        private let preset: Anime4KPreset
        private let abCompareEnabled: Bool
        private let maxOutputWidth: Int
        private let maxOutputHeight: Int

        init(
            interpolator: Anime4KInterpolator,
            preset: Anime4KPreset,
            abCompareEnabled: Bool,
            maxOutputWidth: Int,
            maxOutputHeight: Int
        ) {
            self.interpolator = interpolator
            self.preset = preset
            self.abCompareEnabled = abCompareEnabled
            self.maxOutputWidth = maxOutputWidth
            self.maxOutputHeight = maxOutputHeight
        }

        func onFrame(_ ctx: VideoFrameContext) -> VideoFrameResult {
            do {
                let enhanced = try interpolator.enhance(
                    pixelBuffer: ctx.pixelBuffer,
                    preset: preset,
                    maxOutputWidth: maxOutputWidth,
                    maxOutputHeight: maxOutputHeight,
                    abCompareEnabled: abCompareEnabled
                )
                return .replace(pixelBuffer: enhanced)
            } catch {
                return .passthrough
            }
        }

        func onInvalidate(newGeneration _: Int64) {
            interpolator.reset()
        }

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            []
        }

        func onDrain() {}
    }
#endif
