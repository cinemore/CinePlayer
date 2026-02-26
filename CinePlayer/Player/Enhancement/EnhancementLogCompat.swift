import Foundation

enum CinemoreLogLevel {
    case debug
    case error
}

func cinemoreLog(level: CinemoreLogLevel, _ message: String) {
    #if DEBUG
    let prefix: String
    switch level {
    case .debug: prefix = "[Enhancement][DEBUG]"
    case .error: prefix = "[Enhancement][ERROR]"
    }
    print("\(prefix) \(message)")
    #else
    _ = level
    _ = message
    #endif
}
