#if os(visionOS)
//
//  VisionImmersivePlaybackCoordinator.swift
//  CinemoreVision
//
//  Created by Zero on 2026/2/19.
//

import SwiftUI
import Combine

/// 沉浸空间播放状态
enum VisionImmersivePlaybackState: Equatable {
    case closed
    case opening(requestID: UUID)
    case open(requestID: UUID)
    case dismissing
    case failed(message: String)

    var isClosed: Bool {
        if case .closed = self {
            return true
        }
        return false
    }

    var isOpen: Bool {
        if case .open = self {
            return true
        }
        return false
    }

    var isTransitioning: Bool {
        switch self {
        case .opening,
             .dismissing: true
        default: false
        }
    }
}

/// 沉浸空间播放编排器
/// 集中管理 ImmersiveSpace 的 open/dismiss 和并发防抖，播放内容由系统窗口持有。
@MainActor
final class VisionImmersivePlaybackCoordinator: ObservableObject {
    /// 当前沉浸状态
    @Published var state: VisionImmersivePlaybackState = .closed

    private var dismissWhenOpened = false
    /// dismissImmersiveSpace 返回与 onDisappear 的先后顺序不固定，保留已打开标记到消失回调。
    private var hasOpenedSpace = false

    // MARK: - 打开沉浸空间

    /// 请求打开沉浸空间
    /// - Parameters:
    ///   - openAction: 调用 openImmersiveSpace 的闭包，返回结果
    func requestOpen(
        openAction: () async -> OpenImmersiveSpaceAction.Result,
        dismissAction: () async -> Void
    ) async {
        // 并发防抖：正在过渡中不接受新请求
        guard !state.isTransitioning else {
            cinemoreLog(level: .debug, "[ImmersiveCoordinator] 忽略请求：当前正在过渡 \(state)")
            return
        }

        // 已打开的空间继续复用，不重复发起系统呈现。
        if state.isOpen {
            return
        }

        let requestID = UUID()
        dismissWhenOpened = false
        state = .opening(requestID: requestID)

        cinemoreLog(level: .debug, "[ImmersiveCoordinator] 开始打开沉浸空间 requestID=\(requestID)")

        let result = await openAction()

        // 空间可能在 await 返回前已被系统关闭，不再恢复过期的播放状态。
        guard state == .opening(requestID: requestID) else {
            return
        }

        switch result {
        case .opened:
            hasOpenedSpace = true
            state = .open(requestID: requestID)
            if dismissWhenOpened {
                await requestDismiss(dismissAction: dismissAction)
                return
            }
            cinemoreLog(level: .debug, "[ImmersiveCoordinator] 沉浸空间已打开")

        case .userCancelled:
            state = .closed
            cinemoreLog(level: .debug, "[ImmersiveCoordinator] 用户取消，保持窗口播放")

        case .error:
            state = .failed(message: "打开沉浸空间失败")
            cinemoreLog(level: .error, "[ImmersiveCoordinator] 打开失败，保持窗口播放")

        @unknown default:
            state = .failed(message: "未知错误")
        }
    }

    // MARK: - 关闭沉浸空间

    /// 请求关闭沉浸空间
    /// - Parameter dismissAction: 调用 dismissImmersiveSpace 的闭包
    func requestDismiss(dismissAction: () async -> Void) async {
        if case .opening = state {
            // 系统打开操作不能中途取消；播放窗口已关闭时，成功返回后立即退出环境。
            dismissWhenOpened = true
            return
        }
        guard state.isOpen else {
            cinemoreLog(level: .debug, "[ImmersiveCoordinator] 忽略关闭请求：未打开")
            return
        }

        state = .dismissing
        cinemoreLog(level: .debug, "[ImmersiveCoordinator] 开始关闭沉浸空间")

        await dismissAction()

        // 系统消失回调可能已完成关闭，不能覆盖随后开始的新请求。
        guard state == .dismissing else {
            return
        }
        state = .closed
        cinemoreLog(level: .debug, "[ImmersiveCoordinator] 沉浸空间已关闭")
    }

    /// 返回是否需要同步结束窗口播放；打开被取消时不结束窗口播放。
    func spaceDidDisappear() -> Bool {
        let shouldClosePlayer = hasOpenedSpace
        hasOpenedSpace = false
        dismissWhenOpened = false
        state = .closed
        return shouldClosePlayer
    }
}

#endif
