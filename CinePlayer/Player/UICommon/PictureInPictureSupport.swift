import CinePlayerSDK
import Foundation

enum PictureInPictureSupport {
    static func toggle(controller: PlayerController?) {
        guard let controller else {
            return
        }
        let toggleSelector = NSSelectorFromString("togglePictureInPicture")
        guard controller.responds(to: toggleSelector) else {
            return
        }
        _ = controller.perform(toggleSelector)
    }

    static func isActive(controller: PlayerController?) -> Bool {
        guard let controller else {
            return false
        }
        let activeSelector = NSSelectorFromString("isPictureInPictureActive")
        guard controller.responds(to: activeSelector) else {
            return false
        }
        return controller.perform(activeSelector)?.takeUnretainedValue() as? Bool ?? false
    }
}
