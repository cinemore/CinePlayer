#if os(macOS)

import AppKit
import Combine
import SwiftUI
import QuartzCore

@MainActor
final class PlayerWindowController: NSObject, ObservableObject, NSWindowDelegate {
    @Published var isFloating: Bool = false
    /// 是否处于播放界面（有 currentSource）
    @Published var isPlaybackActive: Bool = false

    /// 将自己设置为当前 keyWindow 的 delegate，用于拦截窗口大小调整并应用最小尺寸限制
    func attachToKeyWindowIfNeeded() {
        guard let window = NSApplication.shared.keyWindow else {
            return
        }
        if window.delegate !== self {
            window.delegate = self
        }
    }

    func toggleWindowLevel() {
        guard let window = NSApplication.shared.keyWindow else {
            return
        }

        if isFloating {
            window.level = .normal
            isFloating = false
        } else {
            window.level = .floating
            isFloating = true
            window.makeKeyAndOrderFront(nil)
        }
    }

    /// 在非播放态下调用：固定一个合适的初始窗口大小并禁用缩放
    func lockWindowToInitialSize() {
        guard let window = NSApplication.shared.keyWindow else {
            return
        }

        // 目标内容区域大小：优先使用 960x540（16:9），在小屏幕上按比例缩小以适配可见区域
        let targetContentSize = CGSize(width: 960, height: 540)
        let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero

        let scale = min(
            visibleFrame.width / targetContentSize.width,
            visibleFrame.height / targetContentSize.height,
            1.0
        )

        let contentSize = NSSize(
            width: targetContentSize.width * scale,
            height: targetContentSize.height * scale
        )

        // 将内容尺寸转换为窗口 frame，并居中到当前屏幕可见区域
        let contentRect = NSRect(origin: .zero, size: contentSize)
        var frame = window.frameRect(forContentRect: contentRect)
        frame.origin.x = visibleFrame.midX - frame.width / 2
        frame.origin.y = visibleFrame.midY - frame.height / 2

        // 使用显式动画平滑地过渡到目标大小
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(frame, display: true)
        }

        // 通过最小/最大尺寸和移除 .resizable 来禁止缩放
        window.minSize = frame.size
        window.maxSize = frame.size
        window.contentMinSize = contentSize
        window.contentMaxSize = contentSize

        var style = window.styleMask
        style.remove(.resizable)
        window.styleMask = style
    }

    /// 进入播放前调用：解锁窗口缩放，交给播放器逻辑设置最小大小和比例
    func unlockWindowForPlayback() {
        guard let window = NSApplication.shared.keyWindow else {
            return
        }

        // 恢复可缩放，具体的最小尺寸/比例由播放器布局代码控制
        var style = window.styleMask
        style.insert(.resizable)
        window.styleMask = style

        window.minSize = .zero
        window.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        window.contentMinSize = .zero
        window.contentMaxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    // MARK: - NSWindowDelegate

    func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
        // 非播放状态时完全禁止改变窗口大小，直接保持当前 frame
        if !isPlaybackActive {
            return sender.frame.size
        }

        // 全屏下不限制，交给系统处理
        if sender.styleMask.contains(.fullScreen) {
            return frameSize
        }

        guard let minContentSize = PlatformServices.macPlayerMinContentSize else {
            return frameSize
        }

        // 以内容区域为基准应用最小尺寸限制
        let targetContentRect = sender.contentRect(
            forFrameRect: NSRect(origin: .zero, size: frameSize)
        )
        var targetContentSize = targetContentRect.size
        targetContentSize.width = max(targetContentSize.width, minContentSize.width)
        targetContentSize.height = max(targetContentSize.height, minContentSize.height)

        let newFrame = sender.frameRect(
            forContentRect: NSRect(origin: .zero, size: targetContentSize)
        )
        return newFrame.size
    }
}

#endif

