import CinePlayerSDK
import Foundation

nonisolated enum FSROutputResolution: String, CaseIterable, Identifiable, Sendable {
    case fullHD = "1080p"
    case ultraHD = "4K"

    var id: String {
        rawValue
    }

    func outputSize(width: Int, height: Int) -> (width: Int, height: Int) {
        guard width > 0, height > 0 else {
            return (0, 0)
        }
        let scale = min(Double(self == .fullHD ? 1920 : 3840) / Double(width),
                        Double(self == .fullHD ? 1080 : 2160) / Double(height))
        guard scale > 1 else {
            return (width, height)
        }
        return (Int((Double(width) * scale).rounded(.down)),
                Int((Double(height) * scale).rounded(.down)))
    }

    func enlarges(width: Int, height: Int) -> Bool {
        let output = outputSize(width: width, height: height)
        return output.width > width || output.height > height
    }
}
