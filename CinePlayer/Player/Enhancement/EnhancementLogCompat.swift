import Foundation

nonisolated enum CinemoreLogLevel {
    case debug
    case info
    case warning
    case error
}

nonisolated func cinemoreLog(level: CinemoreLogLevel, _ message: String) {
    #if DEBUG
        let prefix: String
        switch level {
        case .debug: prefix = "[DEBUG]"
        case .info: prefix = "[INFO]"
        case .warning: prefix = "[WARN]"
        case .error: prefix = "[ERROR]"
        }
        print("\(prefix) \(message)")
    #else
        _ = level
        _ = message
    #endif
}
