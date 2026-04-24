#if !os(tvOS)
    import CinePlayerSDK
    import Foundation

    /// Shared owner for temporal processors: keeps a small reorder window and previous-frame snapshot.
    nonisolated final class TemporalReorderBuffer: @unchecked Sendable {
        private var previous: PreviousVideoFrameSnapshot?
        private var reorder: [VideoFrameContext] = []
        private let reorderDepth: Int
        private var lastSeenGeneration: Int64?

        init(reorderDepth: Int = 3) {
            self.reorderDepth = reorderDepth
        }

        func accept(
            _ ctx: VideoFrameContext,
            buildSegment: (PreviousVideoFrameSnapshot, VideoFrameContext) -> VideoFrameResult
        ) -> VideoFrameResult {
            if let lastSeenGeneration, lastSeenGeneration != ctx.generation {
                previous = nil
                reorder.removeAll(keepingCapacity: true)
            }
            lastSeenGeneration = ctx.generation

            insertSorted(ctx, into: &reorder)
            guard reorder.count > reorderDepth else {
                return .replaceMany([])
            }

            let current = reorder.removeFirst()
            guard let previous else {
                previous = snapshot(from: current)
                return rawFrameResult(from: current)
            }
            guard current.timestamp > previous.timestamp else {
                self.previous = nil
                return rawFrameResult(from: current)
            }

            let result = buildSegment(previous, current)
            self.previous = snapshot(from: current)
            if case .replaceMany = result {
                return result
            }
            return rawFrameResult(from: current)
        }

        func onInvalidate() {
            previous = nil
            reorder.removeAll(keepingCapacity: true)
            lastSeenGeneration = nil
        }

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            var generated = reorder.map {
                GeneratedVideoFrame(
                    pixelBuffer: $0.pixelBuffer,
                    timestamp: $0.timestamp,
                    duration: $0.duration
                )
            }
            if let previous {
                generated.append(
                    GeneratedVideoFrame(
                        pixelBuffer: previous.pixelBuffer,
                        timestamp: previous.timestamp,
                        duration: previous.duration
                    )
                )
            }
            defer {
                previous = nil
                reorder.removeAll(keepingCapacity: false)
            }
            return generated.sorted { $0.timestamp < $1.timestamp }
        }

        func onDrain() {
            previous = nil
            reorder.removeAll(keepingCapacity: false)
            lastSeenGeneration = nil
        }

        var hasPendingFrames: Bool {
            previous != nil || !reorder.isEmpty
        }

        private func snapshot(from ctx: VideoFrameContext) -> PreviousVideoFrameSnapshot {
            PreviousVideoFrameSnapshot(
                pixelBuffer: ctx.pixelBuffer,
                timestamp: ctx.timestamp,
                duration: ctx.duration,
                timebaseNum: ctx.timebaseNum,
                timebaseDen: ctx.timebaseDen,
                fps: ctx.fps,
                generation: ctx.generation
            )
        }

        private func rawFrameResult(from ctx: VideoFrameContext) -> VideoFrameResult {
            .replaceMany([
                GeneratedVideoFrame(
                    pixelBuffer: ctx.pixelBuffer,
                    timestamp: ctx.timestamp,
                    duration: ctx.duration
                )
            ])
        }

        private func insertSorted(_ ctx: VideoFrameContext, into buffer: inout [VideoFrameContext]) {
            var index = 0
            while index < buffer.count, buffer[index].timestamp < ctx.timestamp {
                index += 1
            }
            buffer.insert(ctx, at: index)
        }
    }
#endif
