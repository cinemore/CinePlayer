//
//  PlayerMaskModel.swift
//  VideoPlayer
//
//  Created by Zero on 2024/10/27.
//

import Foundation
import SwiftUI
import Combine

#if os(macOS)
    import AppKit
#endif

// MARK: 播放器掩盖层控制

@MainActor
class PlayerMaskModel: ObservableObject {
    // MARK: Lifecycle

    init() {
        startTimer()
    }

    deinit {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Internal

    @Published var isMaskShow: Bool = true {
        didSet {
            // 只在值真正改变时才执行操作
            guard oldValue != isMaskShow else {
                return
            }
            if isMaskShow {
                #if os(macOS)
                    NSCursor.unhide()
                #endif
                #if os(macOS)
                    delayHideTime = 2
                #else
                    delayHideTime = 3
                #endif
                timer?.fireDate = .distantPast
            } else {
                timer?.fireDate = .distantFuture
            }
        }
    }

    /// Controls whether the mask can auto-hide
    @Published var allowAutoHide: Bool = true

    /// 停止计时器
    func stopTimer() {
        timer?.invalidate()
        timer = nil
        #if os(macOS)
            NSCursor.unhide()
        #endif
    }

    /// 暂停计时器
    func pauseTimer() {
        timer?.fireDate = .distantFuture
    }

    /// 重启计时器
    func restartTimer() {
        timer?.fireDate = .distantPast
    }

    /// Temporarily disable auto-hiding
    func disableAutoHide() {
        showMask()
        allowAutoHide = false
    }

    /// Re-enable auto-hiding
    func enableAutoHide() {
        allowAutoHide = true
    }

    func showMask() {
        withAnimation {
            isMaskShow = true
        }
    }

    func hideMask() {
        withAnimation {
            isMaskShow = false
        }
    }

    func toggleMask() {
        withAnimation {
            isMaskShow.toggle()
        }
    }

    // MARK: Private

    #if os(iOS) || os(tvOS)
        private var delayHideTime: Double = 3
    #else
        private var delayHideTime: Double = 2
    #endif

    private nonisolated(unsafe) var timer: Timer?

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                if !allowAutoHide {
                    return
                }

                if delayHideTime <= 0 {
                    hideMask()
                    #if os(macOS)
                        NSCursor.setHiddenUntilMouseMoves(true)
                    #endif
                }
                if delayHideTime > 0 {
                    delayHideTime -= 0.1
                }
            }
        }
    }
}
