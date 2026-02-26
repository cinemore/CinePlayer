import CinePlayerSDK
import Foundation

#if !os(tvOS) && !os(visionOS)
@preconcurrency import Translation
#endif

actor SubtitleTranslationRouter {
    private let runtime: SubtitleTranslationRuntime
    private var mode: SubtitleTranslateMode = .off

    #if !os(tvOS) && !os(visionOS)
    private var appleTranslatorBox: AnyObject?
    private var appleRecoveryInProgress = false
    private var lastAppleRecoveryAt: Date?
    private let appleRecoveryCooldown: TimeInterval = 1.0
    #endif

    init(runtime: SubtitleTranslationRuntime) {
        self.runtime = runtime
    }

    func applySettings(mode: SubtitleTranslateMode) async {
        let wasNeedsTranslation = self.mode.needsTranslation
        self.mode = mode

        #if !os(tvOS) && !os(visionOS)
        if !mode.needsTranslation {
            await MainActor.run {
                self.runtime.desiredApplePair = nil
            }
            appleRecoveryInProgress = false
            lastAppleRecoveryAt = nil
            if #available(iOS 18.0, macOS 15.0, *) {
                await appleTranslator().invalidate()
            }
        }

        // Match cinemore's provider-switch recovery idea in pure Apple mode:
        // when turning translation back on after off, recreate translator instance
        // to avoid reusing a previously invalidated/terminated session path.
        if mode.needsTranslation,
           !wasNeedsTranslation,
           #available(iOS 18.0, macOS 15.0, *)
        {
            appleTranslatorBox = nil
            subtitleTranslationLog(
                .debug,
                "Apple translator recreated on mode transition off->\(mode)"
            )
        }
        #endif
    }

    func translate(text: String, from: String, to: String) async throws -> String {
        guard mode.needsTranslation else {
            return text
        }

        #if !os(tvOS) && !os(visionOS)
        if #available(iOS 18.0, macOS 15.0, *) {
            let pairResult = await appleTranslator()
                .updateDesiredPairIfNeeded(from: from, to: to, sampleText: text)
            await MainActor.run {
                self.runtime.desiredApplePair = .init(
                    from: pairResult.pair.0,
                    to: pairResult.pair.1
                )
            }
            do {
                return try await appleTranslator().translate(text: text)
            } catch {
                let sample = text.trimmingCharacters(in: .whitespacesAndNewlines)
                let samplePrefix = String(sample.prefix(40))
                subtitleTranslationLog(
                    .error,
                    "Apple translate failed from=\(pairResult.pair.0) to=\(pairResult.pair.1) sample=\"\(samplePrefix)\" error=\(error)"
                )
                if shouldRecoverAppleTranslator(after: error) {
                    await recoverAppleTranslatorIfNeeded(pair: pairResult.pair, failedError: error)
                }
                throw error
            }
        }
        #endif

        return text
    }

    #if !os(tvOS) && !os(visionOS)
    @available(iOS 18.0, macOS 15.0, *)
    func runAppleSession(_ session: TranslationSession, pair: (from: String, to: String)) async {
        await appleTranslator().run(session: session, pair: pair)
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func appleTranslator() -> AppleSubtitleTranslator {
        if let box = appleTranslatorBox as? AppleSubtitleTranslatorBox {
            return box.translator
        }
        let box = AppleSubtitleTranslatorBox()
        appleTranslatorBox = box
        return box.translator
    }

    @available(iOS 18.0, macOS 15.0, *)
    private final class AppleSubtitleTranslatorBox: NSObject {
        let translator = AppleSubtitleTranslator()
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func shouldRecoverAppleTranslator(after error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let appleError = error as? AppleSubtitleTranslationError {
            switch appleError {
            case .sessionUnavailable:
                return true
            }
        }
        return false
    }

    @available(iOS 18.0, macOS 15.0, *)
    private func recoverAppleTranslatorIfNeeded(pair: (String, String), failedError: Error) async {
        guard mode.needsTranslation else {
            return
        }
        guard !appleRecoveryInProgress else {
            return
        }

        let now = Date()
        if let lastAppleRecoveryAt,
           now.timeIntervalSince(lastAppleRecoveryAt) < appleRecoveryCooldown
        {
            return
        }

        appleRecoveryInProgress = true
        defer {
            appleRecoveryInProgress = false
            lastAppleRecoveryAt = now
        }

        let restorePair = await MainActor.run { () -> (String, String) in
            if let current = self.runtime.desiredApplePair {
                return (current.from, current.to)
            }
            return pair
        }

        if let oldTranslator = (appleTranslatorBox as? AppleSubtitleTranslatorBox)?.translator {
            await oldTranslator.invalidate()
        }
        appleTranslatorBox = nil

        await MainActor.run {
            self.runtime.desiredApplePair = nil
        }
        await Task.yield()
        guard mode.needsTranslation else {
            return
        }
        await MainActor.run {
            self.runtime.desiredApplePair = .init(from: restorePair.0, to: restorePair.1)
        }

        subtitleTranslationLog(
            .error,
            "[Recovery] recreated Apple translator after error=\(failedError) pair=\(restorePair.0)->\(restorePair.1)"
        )
    }
    #endif
}
