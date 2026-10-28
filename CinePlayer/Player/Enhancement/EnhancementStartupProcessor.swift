import CinePlayerSDK
#if canImport(Metal)
    import CoreMedia
    import CoreVideo
    import Foundation

    /// 启动期间原帧直通；只有后台资源准备成功后，才把帧交给独立的增强实例。
    final nonisolated class EnhancementStartupProcessor: VideoFrameProcessor, @unchecked Sendable {
        enum State: Sendable, Equatable { case preparing, ready, failed }
        struct Update: Sendable {
            let state: State
            let isCurrent: @Sendable () -> Bool
        }

        enum StartupError: Error { case unavailable }
        typealias Factory = @Sendable (CMVideoDimensions) async throws -> any VideoFrameProcessor

        private final class Prepared: @unchecked Sendable {
            let processor: any VideoFrameProcessor
            let queue = DispatchQueue(label: "cn.com.cinemore.enhancement.prepared", qos: .userInitiated)
            let lock = NSLock()
            var pending = false
            // 仅由 queue 访问；倍速期间保留已预热实例，恢复时清理补帧历史。
            var bypassing = false
            init(_ processor: any VideoFrameProcessor) {
                self.processor = processor
            }

            func retire() {
                queue.async { [self] in processor.onDrain() }
            }
        }

        private let lock = NSLock()
        private let factory: Factory
        private let onUpdate: @Sendable (Update) -> Void
        private var epoch = UUID()
        private var generation: Int64?
        private var dimensions: CMVideoDimensions?
        private var prepared: Prepared?
        private var task: Task<Void, Never>?
        private var stopped = false
        private var state: State = .preparing

        init(
            dimensions: CMVideoDimensions?,
            onUpdate: @escaping @Sendable (Update) -> Void,
            factory: @escaping Factory
        ) {
            self.factory = factory
            self.onUpdate = onUpdate
            self.dimensions = dimensions
            if let dimensions, dimensions.width > 0, dimensions.height > 0 {
                lock.withLock { startLocked(dimensions) }
            }
        }

        deinit { task?.cancel(); prepared?.retire() }

        private func isCurrent(_ value: UUID) -> Bool {
            lock.withLock { epoch == value && !stopped }
        }

        /// 只在状态锁内启动。后台任务不能读取解码器像素缓冲，仅接收尺寸值。
        private func startLocked(_ dimensions: CMVideoDimensions) {
            let value = epoch
            notifyLocked(.preparing, epoch: value)
            let factory = factory
            task = Task.detached(priority: .userInitiated) { [weak self] in
                do {
                    try Task.checkCancellation()
                    let result = try await factory(dimensions)
                    let box = Prepared(result)
                    guard let self else {
                        box.retire(); return
                    }
                    let accepted = lock.withLock {
                        guard self.epoch == value, !self.stopped, !Task.isCancelled else {
                            return false
                        }
                        self.prepared = box
                        self.task = nil
                        self.notifyLocked(.ready, epoch: value)
                        return true
                    }
                    if !accepted {
                        box.retire()
                    }
                } catch {
                    guard let self else {
                        return
                    }
                    lock.withLock {
                        guard self.epoch == value, !self.stopped, !Task.isCancelled else {
                            return
                        }
                        self.task = nil
                        self.notifyLocked(.failed, epoch: value)
                    }
                }
            }
        }

        private func notifyLocked(_ state: State, epoch: UUID) {
            self.state = state
            // 接收方异步更新 UI 前再次检查，旧请求即便已经排入主线程也不能覆盖新状态。
            onUpdate(Update(state: state, isCurrent: { [weak self] in
                guard let self else {
                    return false
                }
                return lock.withLock { self.epoch == epoch && !self.stopped && self.state == state }
            }))
        }

        func reserveOutputForNextFrame() -> Bool {
            let box = lock.withLock { prepared }
            return box?.processor.reserveOutputForNextFrame() ?? true
        }

        func onFrame(_ context: VideoFrameContext) -> VideoFrameResult {
            let size = CMVideoDimensions(width: Int32(CVPixelBufferGetWidth(context.pixelBuffer)),
                                         height: Int32(CVPixelBufferGetHeight(context.pixelBuffer)))
            let snapshot: (Prepared?, UUID) = lock.withLock {
                guard !stopped else {
                    return (nil, epoch)
                }
                if let generation, context.generation < generation {
                    return (nil, epoch)
                }
                if generation != context.generation || dimensions?.width != size.width || dimensions?.height != size.height {
                    let needsRestart = (generation != nil && generation != context.generation)
                        || dimensions?.width != size.width || dimensions?.height != size.height
                    generation = context.generation
                    dimensions = size
                    if needsRestart {
                        epoch = UUID(); task?.cancel(); task = nil
                        prepared?.retire(); prepared = nil
                        startLocked(size)
                    }
                }
                return (prepared, epoch)
            }
            guard let box = snapshot.0 else {
                return .passthrough
            }
            return box.queue.sync {
                guard isCurrent(snapshot.1) else {
                    return .passthrough
                }
                // 使用本次回调入口的倍率，覆盖长按临时倍速；不修改用户设置或 CinePlayer 接口。
                // 已经进入播放队列的帧照常显示，尚未处理的帧从这里开始直通。
                if let rate = context.playbackClock?.rate, rate.isFinite, rate > 1 {
                    let pending = box.bypassing ? [] : box.processor.drainPendingFrames()
                    box.bypassing = true
                    box.lock.withLock { box.pending = false }
                    guard isCurrent(snapshot.1), !pending.isEmpty else {
                        return .passthrough
                    }
                    // 重排窗口中尚未输出的原帧也要交还，不能因长按丢掉这一段时间轴。
                    return .replaceMany((pending + [GeneratedVideoFrame(pixelBuffer: context.pixelBuffer,
                                                                        timestamp: context.timestamp, duration: context.duration)])
                        .sorted { $0.timestamp < $1.timestamp })
                }
                if box.bypassing {
                    // 迟到计算可以自行结束，但不能把倍速前的历史用于恢复后的插值。
                    box.processor.onInvalidate(newGeneration: context.generation)
                    box.bypassing = false
                }
                let result = box.processor.onFrame(context)
                box.lock.withLock { box.pending = box.processor.hasPendingFrames }
                return isCurrent(snapshot.1) ? result : .passthrough
            }
        }

        func onInvalidate(newGeneration: Int64) {
            lock.withLock {
                if let generation, newGeneration < generation {
                    return
                }
                if generation == nil {
                    generation = newGeneration; return
                }
                generation = newGeneration
                epoch = UUID(); task?.cancel(); task = nil
                prepared?.retire(); prepared = nil
                if !stopped, let dimensions {
                    startLocked(dimensions)
                }
            }
        }

        func onDrain() {
            lock.withLock {
                stopped = true; epoch = UUID(); task?.cancel(); task = nil
                prepared?.retire(); prepared = nil
            }
        }

        func drainPendingFrames() -> [GeneratedVideoFrame] {
            let snapshot = lock.withLock { (prepared, epoch) }
            guard let box = snapshot.0 else {
                return []
            }
            return box.queue.sync {
                guard isCurrent(snapshot.1) else {
                    return []
                }
                let result = box.processor.drainPendingFrames()
                box.lock.withLock { box.pending = false }
                return result
            }
        }

        var hasPendingFrames: Bool {
            guard let box = lock.withLock({ prepared }) else {
                return false
            }
            return box.lock.withLock { box.pending }
        }

        /// 单帧增强的冷启动使用自有黑帧，绝不在后台继续访问可能被解码器复用的缓冲。
        static func warmupFrame(_ dimensions: CMVideoDimensions) throws -> VideoFrameContext {
            var buffer: CVPixelBuffer?
            guard CVPixelBufferCreate(nil, Int(dimensions.width), Int(dimensions.height), kCVPixelFormatType_32BGRA,
                                      [kCVPixelBufferIOSurfacePropertiesKey: [:], kCVPixelBufferMetalCompatibilityKey: true] as CFDictionary,
                                      &buffer) == kCVReturnSuccess, let buffer
            else {
                throw StartupError.unavailable
            }
            CVPixelBufferLockBaseAddress(buffer, [])
            if let base = CVPixelBufferGetBaseAddress(buffer) {
                memset(base, 0, CVPixelBufferGetBytesPerRow(buffer) * CVPixelBufferGetHeight(buffer))
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])
            return VideoFrameContext(pixelBuffer: buffer, timestamp: 0, duration: 100,
                                     timebaseNum: 1, timebaseDen: 2400, fps: 24, generation: 0)
        }
    }
#endif
