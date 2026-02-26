import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

#if os(iOS)
@MainActor
enum IOSPlayerOrientationLock {
    static var value: UIInterfaceOrientationMask = .portrait
}
#endif

enum PlatformServices {
    static func displayCornerRadius(default fallback: CGFloat = 16) -> CGFloat {
        #if canImport(UIKit) && !os(visionOS)
        let key = "_displayCornerRadius"
        let radius = UIScreen.main.value(forKey: key) as? CGFloat ?? 0
        return radius > 0 ? radius : fallback
        #else
        return fallback
        #endif
    }

    #if canImport(AppKit) && os(macOS)
    static func setMacTrafficLightsHidden(_ hidden: Bool) {
        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            return
        }

        let buttonTypes: [NSWindow.ButtonType] = [
            .closeButton,
            .miniaturizeButton,
            .zoomButton
        ]

        for type in buttonTypes {
            window.standardWindowButton(type)?.isHidden = hidden
        }
    }

    /// 根据视频原始尺寸更新播放器窗口的大小、比例和最小/最大限制
    static func configureMacPlayerWindowForVideo(naturalSize: CGSize) {
        guard naturalSize.width > 0, naturalSize.height > 0 else {
            return
        }

        guard let window = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first else {
            return
        }

        // 全屏或即将全屏时不再调整窗口大小，防止破坏全屏体验
        if window.styleMask.contains(.fullScreen) {
            return
        }

        let aspectRatio = naturalSize.width / naturalSize.height
        let screenFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        guard screenFrame.width > 0, screenFrame.height > 0 else {
            return
        }

        let maxWidth = screenFrame.width
        let maxHeight = screenFrame.height

        // 参考 cinemore-apple：计算一个合适的最小内容尺寸，保证不小于一定值且不超过屏幕
        let defaultWidth: CGFloat = 640
        var minWidth: CGFloat =
            if defaultWidth > (maxWidth * 0.9) {
                max(600, maxWidth * 0.9)
            } else {
                defaultWidth
            }
        var minHeight = minWidth / aspectRatio

        if minHeight > maxHeight {
            minHeight = maxHeight
            minWidth = max(minHeight * aspectRatio, 360)
        }

        let minContentSize = NSSize(width: minWidth, height: minHeight)
        window.contentMinSize = minContentSize
        window.contentMaxSize = NSSize(width: maxWidth, height: maxHeight)
        window.contentAspectRatio = NSSize(width: aspectRatio, height: 1.0)

        // 同步设置基于 frame 的最小/最大尺寸，确保拖动窗口时也无法缩得过小
        let minFrameSize = window.frameRect(
            forContentRect: NSRect(origin: .zero, size: minContentSize)
        ).size
        window.minSize = minFrameSize
        window.maxSize = NSSize(width: maxWidth, height: maxHeight)

        // 目标内容尺寸：优先使用屏幕宽度的 80%，并按比例计算高度，限制在可见区域内
        let preferredWidth = min(maxWidth * 0.8, maxWidth)
        var targetWidth = max(preferredWidth, minContentSize.width)
        var targetHeight = targetWidth / aspectRatio

        if targetHeight > maxHeight {
            targetHeight = maxHeight
            targetWidth = targetHeight * aspectRatio
        }

        targetWidth = min(max(targetWidth, minContentSize.width), maxWidth)
        targetHeight = min(max(targetHeight, minContentSize.height), maxHeight)

        let targetContentSize = NSSize(width: targetWidth, height: targetHeight)

        // 保持窗口中心不变地调整到目标尺寸
        let currentFrame = window.frame
        let currentContentRect = window.contentRect(forFrameRect: currentFrame)
        let newContentRect = NSRect(origin: currentContentRect.origin, size: targetContentSize)
        var newFrame = window.frameRect(forContentRect: newContentRect)

        newFrame.origin.x = currentFrame.midX - newFrame.width / 2
        newFrame.origin.y = currentFrame.midY - newFrame.height / 2

        window.setFrame(newFrame, display: true, animate: true)
    }
    #endif

    static func screenBrightness(default fallback: CGFloat = 0.5) -> CGFloat {
        #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
        UIScreen.main.brightness
        #else
        fallback
        #endif
    }

    static func setScreenBrightness(_ brightness: CGFloat) {
        #if canImport(UIKit) && !os(tvOS) && !os(visionOS)
        UIScreen.main.brightness = max(0, min(1, brightness))
        #endif
    }

    static func toggleIOSPlaybackOrientationLock() {
        #if os(iOS)
        if isIOSPlayerPortraitLock() {
            setIOSPlayerOrientationLock(.landscape)
        } else {
            setIOSPlayerOrientationLock(.portrait)
        }
        #endif
    }

    static func isIOSPlayerPortraitLock() -> Bool {
        #if os(iOS)
        IOSPlayerOrientationLock.value == .portrait
        #else
        false
        #endif
    }

    #if os(iOS)
    static func currentIOSPlayerOrientationLock() -> UIInterfaceOrientationMask {
        IOSPlayerOrientationLock.value
    }
    #endif

    static func enterIOSPlaybackOrientationIfNeeded() {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return
        }
        setIOSPlayerOrientationLock(.landscape)
        #endif
    }

    static func exitIOSPlaybackOrientationIfNeeded() {
        #if os(iOS)
        guard UIDevice.current.userInterfaceIdiom == .phone else {
            return
        }
        setIOSPlayerOrientationLock(.portrait)
        #endif
    }

    #if os(iOS)
    static func setIOSPlayerOrientationLock(_ lock: UIInterfaceOrientationMask) {
        IOSPlayerOrientationLock.value = lock
        applyIOSOrientationLock(lock)
    }

    private static func applyIOSOrientationLock(_ lock: UIInterfaceOrientationMask) {
        if #available(iOS 16.0, *) {
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: lock)
            for scene in UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }) {
                for window in scene.windows {
                    window.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
                }
                scene.requestGeometryUpdate(geometryPreferences)
            }
        } else {
            let orientationValue: UIInterfaceOrientation = lock == .portrait ? .portrait : .landscapeRight
            UIDevice.current.setValue(orientationValue.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
        }
    }
    #endif
}
