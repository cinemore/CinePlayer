//
//  DeferredMainActorCommandScheduler.swift
//  CinePlayer
//
//  Created by Assistant on 2026/3/17.
//

import Foundation

/// Sideview 交互用的小型命令调度器：
/// 先让 SwiftUI 落一帧即时选中态，再在下一次主线程调度中执行真正的播放器命令。
struct DeferredMainActorCommandScheduler {
    private var task: Task<Void, Never>?

    mutating func schedule(_ operation: @escaping @MainActor () -> Void) {
        cancel()
        task = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            operation()
        }
    }

    mutating func cancel() {
        task?.cancel()
        task = nil
    }
}
