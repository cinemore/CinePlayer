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
