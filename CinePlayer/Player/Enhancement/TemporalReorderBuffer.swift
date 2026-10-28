import CinePlayerSDK
#if canImport(Metal)
    import Foundation

    /// 时域插帧 processor 共享的窗口 owner：维护 reorder buffer + previous 快照，
    /// 调用方只负责提供算法（`buildSegment`），不再各自复制 reorder/previous/drain 逻辑。
    ///
    /// 契约与 OF/SystemVT 原实现一致：
    /// - reorder.count ≤ reorderDepth 时先吞帧，返回 `.replaceMany([])`。
    /// - 窗口成熟后 pop 最早 ctx 作为 current；若尚无 previous 或时间戳非单调，发 raw current 并更新 previous。
    /// - 否则调用 `buildSegment(previous, current)`；返回值是 `.replaceMany` 直接透传，其余一律回落到 raw current。
    ///
    /// Generation 自愈：accept 检测到 ctx.generation 与上一帧不同时，自动等价于一次 onInvalidate
    /// （清 reorder + previous）后再吞当前帧。即使 Center 漏调用 onInvalidate，buffer 也不会跨代污染。
    final nonisolated class TemporalReorderBuffer: @unchecked Sendable {
        nonisolated enum DeadlineOutcome { case notAttempted, busy, completed, timedOut }
        private(set) var lastDeadlineOutcome: DeadlineOutcome = .notAttempted
        private var previous: PreviousVideoFrameSnapshot?
        private var reorder: [VideoFrameContext] = []
        private let reorderDepth: Int
        private let worker = DispatchQueue(label: "cn.com.cinemore.interpolation.deadline", qos: .userInitiated)
        private let workLock = NSLock()
        private var working = false

        private final nonisolated class ResultSlot: @unchecked Sendable {
            let lock = NSLock()
            let ready = DispatchSemaphore(value: 0)
            var result: VideoFrameResult?
        }

        /// 上一次 accept 的 ctx.generation。nil 表示 buffer 为空 / 未启动。
        private var lastSeenGeneration: Int64?

        init(reorderDepth: Int = 3) {
            self.reorderDepth = reorderDepth
        }

        func accept(
            _ ctx: VideoFrameContext,
            holdFirstFrame: Bool = false,
            buildSegment: (PreviousVideoFrameSnapshot, VideoFrameContext) -> VideoFrameResult
        ) -> VideoFrameResult {
            // Self-heal: 如果当前 ctx 跨代，把 buffer 当成已 invalidate 处理，避免新代帧
            // 与残留旧代帧混入同一 reorder 窗口。Center 通常会先调 onInvalidate，但留这条
            // 防线让 buffer 对调用方的疏漏鲁棒。
            if let last = lastSeenGeneration, last != ctx.generation {
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
                return holdFirstFrame ? .replaceMany([]) : rawFrameResult(from: current)
            }
            guard current.timestamp > previous.timestamp else {
                // 非单调 / 重复 PTS：放弃当前 previous，让下一帧重建窗口，避免
                // 下一次 buildSegment 在陈旧 previous 与跨多帧 current 之间插值导致拖影。
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

        func acceptWithDeadline(
            _ context: VideoFrameContext,
            fallbackBudgetFraction: Double = 0.5,
            fallbackMaximumWait: Double = 0.020,
            buildSegment: @escaping @Sendable (PreviousVideoFrameSnapshot, VideoFrameContext) -> VideoFrameResult
        ) -> VideoFrameResult {
            lastDeadlineOutcome = .notAttempted
            return accept(context, holdFirstFrame: true) { previous, current in
                let result = buildWithDeadline(previous, current, fallbackBudgetFraction: fallbackBudgetFraction,
                                               fallbackMaximumWait: fallbackMaximumWait, playbackClock: context.playbackClock,
                                               buildSegment: buildSegment)
                if case .replaceMany = result {
                    return result
                }
                // 成功与失败必须覆盖同一 [previous, current) 时间段，否则下一段会重叠。
                return .replaceMany([GeneratedVideoFrame(pixelBuffer: previous.pixelBuffer,
                                                         timestamp: previous.timestamp, duration: current.timestamp - previous.timestamp)])
            }
        }

        private func buildWithDeadline(
            _ previous: PreviousVideoFrameSnapshot,
            _ current: VideoFrameContext,
            fallbackBudgetFraction: Double,
            fallbackMaximumWait: Double,
            playbackClock: VideoPlaybackClockSnapshot?,
            buildSegment: @escaping @Sendable (PreviousVideoFrameSnapshot, VideoFrameContext) -> VideoFrameResult
        ) -> VideoFrameResult {
            let wait = Self.waitBudget(previous: previous, current: current, clock: playbackClock,
                                       fallbackBudgetFraction: fallbackBudgetFraction, fallbackMaximumWait: fallbackMaximumWait)
            // 已赶不上该段最早的 PTS，不再启动必然迟到的计算。
            guard wait > 0 else {
                lastDeadlineOutcome = .notAttempted
                return .passthrough
            }
            workLock.lock()
            guard !working else {
                workLock.unlock(); lastDeadlineOutcome = .busy; return .passthrough
            }
            working = true
            workLock.unlock()
            let slot = ResultSlot()
            // 优先按播放时钟估算剩余时间；无法推算时才使用调用方的兜底预算。
            // 截止时间限制本次等待，不取消底层计算；迟到结果不再采用。
            let deadline = DispatchTime.now() + wait
            worker.async { [self] in
                let result = buildSegment(previous, current)
                // 每次调用独占结果槽；超时结果不能被后续帧或新 generation 取走。
                if DispatchTime.now() <= deadline {
                    slot.lock.lock(); slot.result = result; slot.lock.unlock()
                }
                workLock.lock(); working = false; workLock.unlock()
                slot.ready.signal()
            }
            guard slot.ready.wait(timeout: deadline) == .success else {
                lastDeadlineOutcome = .timedOut
                return .passthrough
            }
            slot.lock.lock()
            defer { slot.lock.unlock() }
            lastDeadlineOutcome = slot.result == nil ? .timedOut : .completed
            return slot.result ?? .passthrough
        }

        static func waitBudget(
            previous: PreviousVideoFrameSnapshot,
            current: VideoFrameContext,
            clock: VideoPlaybackClockSnapshot?,
            fallbackBudgetFraction: Double,
            fallbackMaximumWait: Double,
            now: UInt64 = DispatchTime.now().uptimeNanoseconds
        ) -> Double {
            if previous.timebaseDen > 0, previous.timebaseNum > 0,
               let remaining = clock?.remainingTime(
                   until: Double(previous.timestamp) * Double(previous.timebaseNum) / Double(previous.timebaseDen),
                   now: now
               )
            {
                // 给结果提交保留 5ms；异常远期 PTS 也不允许无限等待。
                return min(0.250, max(0, remaining - 0.005))
            }
            let fps = current.fps.isFinite && current.fps > 0 ? Double(current.fps) : 30
            // 无快照或时钟停止等情况下，无法推算显示期限，使用有限等待兜底。
            return min(fallbackMaximumWait, fallbackBudgetFraction / fps)
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
