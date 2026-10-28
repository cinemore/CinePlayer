#if os(visionOS)
import CoreGraphics
import Foundation

/// 仅用于播放窗口的显示比例与尺寸，不参与渲染或解码。
enum VisionPlayerWindowSizing {
    static func aspectRatio(size: CGSize, pixelAspect: CGSize, rotation: Double) -> CGFloat? {
        guard size.width.isFinite, size.height.isFinite,
              pixelAspect.width.isFinite, pixelAspect.height.isFinite, rotation.isFinite,
              size.width > 0, size.height > 0, pixelAspect.width > 0, pixelAspect.height > 0
        else {
            return nil
        }
        let ratio = (size.width / size.height) * (pixelAspect.width / pixelAspect.height)
        let angle = (rotation.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
        let result = abs(angle - 90) <= 1 || abs(angle - 270) <= 1 ? 1 / ratio : ratio
        return result.isFinite && result > 0 ? result : nil
    }

    static func size(preserving current: CGSize, aspectRatio: CGFloat) -> CGSize? {
        guard current.width.isFinite, current.height.isFinite, aspectRatio.isFinite,
              current.width > 0, current.height > 0, aspectRatio > 0
        else {
            return nil
        }
        let area = current.width * current.height
        let width = sqrt(area * aspectRatio)
        let height = sqrt(area / aspectRatio)
        guard width.isFinite, height.isFinite, width > 0, height > 0 else {
            return nil
        }
        return CGSize(width: width, height: height)
    }
}

#if os(visionOS)
    import SwiftUI
import Combine
    import UIKit

    /// 从所属视图取得播放窗口，避免误调整主窗口或其他系统场景。
    struct VisionPlayerWindowGeometry: UIViewRepresentable {
        var aspectRatio: CGFloat?

        func makeUIView(context _: Context) -> GeometryView {
            let view = GeometryView()
            view.isUserInteractionEnabled = false
            view.backgroundColor = .clear
            return view
        }

        func updateUIView(_ view: GeometryView, context _: Context) {
            view.aspectRatio = aspectRatio
            view.updateWindowIfNeeded()
        }

        final class GeometryView: UIView {
            var aspectRatio: CGFloat?
            private weak var requestedScene: UIWindowScene?
            private var requestedRatio: CGFloat?

            override func didMoveToWindow() {
                super.didMoveToWindow()
                updateWindowIfNeeded()
            }

            override func layoutSubviews() {
                super.layoutSubviews()
                updateWindowIfNeeded()
            }

            func updateWindowIfNeeded() {
                guard let window, let scene = window.windowScene, let aspectRatio else {
                    return
                }
                if requestedScene === scene, let requestedRatio, abs(requestedRatio - aspectRatio) < 0.0001 {
                    return
                }
                guard let size = VisionPlayerWindowSizing.size(preserving: window.bounds.size, aspectRatio: aspectRatio) else {
                    return
                }
                requestedScene = scene
                requestedRatio = aspectRatio
                scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.Vision(
                    size: size,
                    resizingRestrictions: .uniform
                )) { error in
                    cinemoreLog(level: .error, "播放窗口比例更新失败：\(error.localizedDescription)")
                }
            }
        }
    }
#endif

#endif
