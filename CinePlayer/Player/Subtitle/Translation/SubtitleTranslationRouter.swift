import CinePlayerSDK
import Foundation
#if !os(tvOS) && !os(visionOS)
@preconcurrency import Translation
#endif

/// 独立播放器使用 Apple 翻译；会话始终由 SwiftUI translationTask 持有。
@MainActor
final class SubtitleTranslationRouter {
    private let runtime: SubtitleTranslationRuntime
    private var mode: SubtitleTranslateMode = .off
    #if !os(tvOS) && !os(visionOS)
    private var appleTranslatorBox: AnyObject?
    #endif

    init(runtime: SubtitleTranslationRuntime) { self.runtime = runtime }

    static var isAvailable: Bool {
        #if !os(tvOS) && !os(visionOS)
        if #available(iOS 18.0, macOS 15.0, *) { return true }
        #endif
        return false
    }

    func applySettings(mode: SubtitleTranslateMode) async {
        self.mode = Self.isAvailable ? mode : .off
        #if !os(tvOS) && !os(visionOS)
        if !self.mode.needsTranslation {
            runtime.desiredApplePair = nil
            if #available(iOS 18.0, macOS 15.0, *) {
                let previous = (appleTranslatorBox as? AppleSubtitleTranslatorBox)?.translator
                appleTranslatorBox = nil
                await previous?.invalidate()
            }
        }
        #endif
    }

    func processSubtitle(text: String, from: String, targetLanguage: String, translationOnTop: Bool = true) async throws -> String {
        let processor = AppSubtitleTranslationProcessor(
            mode: mode,
            translateFunction: { [self] text, from, to in
                try await translate(text: text, from: from, to: to)
            },
            translationOnTop: translationOnTop
        )
        return try await processor.process(content: text, fromLang: from, toLang: targetLanguage)
    }

    private func translate(text: String, from: String, to: String) async throws -> String {
        guard mode.needsTranslation else { return text }
        #if !os(tvOS) && !os(visionOS)
        if #available(iOS 18.0, macOS 15.0, *) {
            let translator = appleTranslator()
            let pair = await translator.updateDesiredPairIfNeeded(from: from, to: to, sampleText: text).pair
            guard mode.needsTranslation, translator === appleTranslator(), !Task.isCancelled else {
                throw CancellationError()
            }
            runtime.desiredApplePair = .init(from: pair.0, to: pair.1)
            return try await translator.translate(text: text)
        }
        #endif
        return text
    }

    func restartTranslationService() async {
        #if !os(tvOS) && !os(visionOS)
        guard mode.needsTranslation else { return }
        if #available(iOS 18.0, macOS 15.0, *) {
            let previous = (appleTranslatorBox as? AppleSubtitleTranslatorBox)?.translator
            appleTranslatorBox = AppleSubtitleTranslatorBox()
            runtime.restartAppleSession()
            await previous?.invalidate()
        }
        #endif
    }

    #if !os(tvOS) && !os(visionOS)
    @available(iOS 18.0, macOS 15.0, *)
    func runAppleSession(_ session: TranslationSession, pair: (from: String, to: String), sessionID: UUID) async {
        guard mode.needsTranslation, !Task.isCancelled,
              runtime.appleSessionID == sessionID,
              runtime.desiredApplePair == .init(from: pair.from, to: pair.to) else { return }
        await appleTranslator().run(session: session, pair: pair)
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func appleTranslator() -> AppleSubtitleTranslator {
        if let box = appleTranslatorBox as? AppleSubtitleTranslatorBox { return box.translator }
        let box = AppleSubtitleTranslatorBox()
        appleTranslatorBox = box
        return box.translator
    }

    @available(iOS 18.0, macOS 15.0, *)
    private final class AppleSubtitleTranslatorBox: NSObject {
        let translator = AppleSubtitleTranslator()
    }
    #endif
}
