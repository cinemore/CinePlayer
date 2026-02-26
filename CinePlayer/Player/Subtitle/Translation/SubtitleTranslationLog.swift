import Foundation

enum SubtitleTranslationLogLevel {
    case debug
    case error
}

nonisolated func subtitleTranslationLog(_ level: SubtitleTranslationLogLevel, _ message: String) {
    switch level {
    case .debug:
        #if DEBUG
        print("[SubtitleTranslation][DEBUG] \(message)")
        #endif
    case .error:
        print("[SubtitleTranslation][ERROR] \(message)")
    }
}
