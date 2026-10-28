import CinePlayerSDK
import Foundation

nonisolated enum FSRSharpness: String, CaseIterable, Identifiable, Sendable {
    case off, low, medium, high
    var id: String {
        rawValue
    }

    var displayName: String {
        switch self {
        case .off: String(localized: "关闭")
        case .low: String(localized: "低")
        case .medium: String(localized: "中")
        case .high: String(localized: "高")
        }
    }

    /// RCAS参数越小，锐化越强；nil只执行EASU。
    var parameter: Float? {
        switch self {
        case .off: nil
        case .low: 2
        case .medium: 1
        case .high: 0
        }
    }
}
