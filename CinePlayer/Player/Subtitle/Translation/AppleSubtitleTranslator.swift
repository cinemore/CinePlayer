#if !os(tvOS) && !os(visionOS)

import Foundation
import NaturalLanguage
@preconcurrency import Translation

@available(iOS 18.0, macOS 15.0, *)
enum AppleTranslationLanguageSupport {
    nonisolated static func normalizedIdentifier(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let lowercased = trimmed.lowercased()
        guard lowercased != "und" else {
            return nil
        }

        if lowercased == "chi" || lowercased == "cmn" || lowercased == "yue" {
            return "zh"
        }

        let canonical = NSLocale.canonicalLanguageIdentifier(from: trimmed)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        guard !canonical.isEmpty else {
            return nil
        }

        let parts = canonical.split(separator: "-").map(String.init)
        guard let languageCode = parts.first, !languageCode.isEmpty else {
            return nil
        }

        var normalizedParts = [languageCode]
        if parts.count >= 2 {
            let second = parts[1]
            if second.count == 4, second.allSatisfy(\.isLetter) {
                let normalizedScript = second.prefix(1).uppercased() + second.dropFirst().lowercased()
                normalizedParts.append(normalizedScript)
            }
        }

        return normalizedParts.joined(separator: "-")
    }

    nonisolated static func normalizedLanguage(from raw: String) -> Locale.Language? {
        guard let identifier = normalizedIdentifier(raw) else {
            return nil
        }
        return Locale.Language(identifier: identifier)
    }

    nonisolated static func availabilityStatus(from sourceIdentifier: String, to targetIdentifier: String)
        async -> LanguageAvailability.Status
    {
        guard let source = normalizedLanguage(from: sourceIdentifier),
              let target = normalizedLanguage(from: targetIdentifier)
        else {
            return .unsupported
        }

        let availability = LanguageAvailability()
        return await availability.status(from: source, to: target)
    }

    nonisolated static func translationConfiguration(from sourceIdentifier: String, to targetIdentifier: String)
        -> TranslationSession.Configuration?
    {
        guard let source = normalizedLanguage(from: sourceIdentifier),
              let target = normalizedLanguage(from: targetIdentifier)
        else {
            return nil
        }

        return TranslationSession.Configuration(source: source, target: target)
    }
}

@available(iOS 18.0, macOS 15.0, *)
enum AppleSubtitleTranslationError: Error {
    case sessionUnavailable
}

@available(iOS 18.0, macOS 15.0, *)
actor AppleSubtitleTranslator {
    struct Request: Sendable {
        let id: UUID
        let generation: UInt64
        let text: String
    }

    private(set) var desiredPair: (from: String, to: String)?

    private var hasActiveSession = false
    private var isPrepared = false
    private var generation: UInt64 = 0

    private var requestStream: AsyncStream<Request>
    private var requestContinuation: AsyncStream<Request>.Continuation?

    private var pending: [UUID: CheckedContinuation<String, Error>] = [:]

    init() {
        var continuation: AsyncStream<Request>.Continuation?
        requestStream = AsyncStream<Request>(bufferingPolicy: .bufferingNewest(64)) { cont in
            continuation = cont
        }
        requestContinuation = continuation
    }

    func invalidate() {
        generation &+= 1
        desiredPair = nil
        hasActiveSession = false
        isPrepared = false
        failAllPending()
    }

    func updateDesiredPairIfNeeded(from: String, to: String, sampleText: String) -> (
        pair: (String, String), didChange: Bool
    ) {
        let resolvedFrom: String = {
            if from == "auto" {
                let detected = detectLanguageCode(from: sampleText) ?? "en"
                return AppleTranslationLanguageSupport.normalizedIdentifier(detected) ?? "en"
            }
            if let canonical = AppleTranslationLanguageSupport.normalizedIdentifier(from) {
                return canonical
            }
            let detected = detectLanguageCode(from: sampleText) ?? "en"
            return AppleTranslationLanguageSupport.normalizedIdentifier(detected) ?? "en"
        }()

        let resolvedTo: String = AppleTranslationLanguageSupport.normalizedIdentifier(to) ?? to

        let newPair = (resolvedFrom, resolvedTo)
        if let current = desiredPair, current.from == newPair.0, current.to == newPair.1 {
            return (newPair, false)
        }

        generation &+= 1
        desiredPair = (from: newPair.0, to: newPair.1)
        hasActiveSession = false
        isPrepared = false
        failAllPending()
        return (newPair, true)
    }

    func translate(text: String) async throws -> String {
        guard desiredPair != nil, requestContinuation != nil else {
            throw AppleSubtitleTranslationError.sessionUnavailable
        }

        let requestID = UUID()
        let request = Request(id: requestID, generation: generation, text: text)

        return try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { cont in
                    pending[requestID] = cont
                    requestContinuation?.yield(request)
                }
            },
            onCancel: { [weak self] in
                guard let self else {
                    return
                }
                Task {
                    await self.cancel(requestID: requestID)
                }
            }
        )
    }

    func run(session: TranslationSession, pair: (from: String, to: String)) async {
        if desiredPair == nil {
            desiredPair = (from: pair.from, to: pair.to)
        }
        guard let desiredPair, desiredPair.from == pair.from, desiredPair.to == pair.to else {
            hasActiveSession = false
            isPrepared = false
            failAllPending()
            return
        }

        hasActiveSession = true
        isPrepared = false

        let startGeneration = generation

        do {
            try await session.prepareTranslation()
            markPreparedIfStillValid(generation: startGeneration, pair: pair)
            let preparedMessage =
                "Apple session prepared from=\(pair.from) to=\(pair.to) generation=\(startGeneration)"
            await MainActor.run {
                subtitleTranslationLog(
                    .debug,
                    preparedMessage
                )
            }
        } catch {
            let errorMessage =
                "Apple session prepare failed from=\(pair.from) to=\(pair.to) error=\(error)"
            await MainActor.run {
                subtitleTranslationLog(
                    .error,
                    errorMessage
                )
            }
        }

        do {
            for await request in requestStream {
                if Task.isCancelled {
                    break
                }

                guard let current = self.desiredPair,
                      current.from == pair.from, current.to == pair.to
                else {
                    break
                }

                guard pending[request.id] != nil else {
                    continue
                }

                guard request.generation == generation else {
                    fail(
                        requestID: request.id,
                        error: AppleSubtitleTranslationError.sessionUnavailable
                    )
                    continue
                }

                guard hasActiveSession, isPrepared else {
                    let unavailableMessage =
                        "Apple session unavailable for request from=\(pair.from) to=\(pair.to) generation=\(generation)"
                    await MainActor.run {
                        subtitleTranslationLog(
                            .debug,
                            unavailableMessage
                        )
                    }
                    fail(
                        requestID: request.id,
                        error: AppleSubtitleTranslationError.sessionUnavailable
                    )
                    continue
                }

                do {
                    let response = try await session.translate(request.text)
                    succeed(requestID: request.id, value: response.targetText)
                } catch {
                    if Task.isCancelled {
                        fail(
                            requestID: request.id,
                            error: AppleSubtitleTranslationError.sessionUnavailable
                        )
                    } else {
                        let translateErrorMessage =
                            "Apple session translate failed from=\(pair.from) to=\(pair.to) error=\(error)"
                        await MainActor.run {
                            subtitleTranslationLog(
                                .error,
                                translateErrorMessage
                            )
                        }
                        fail(requestID: request.id, error: error)
                    }
                }
            }
        }

        hasActiveSession = false
        isPrepared = false
        failAllPending()
    }

    private func cancel(requestID: UUID) {
        guard let cont = pending.removeValue(forKey: requestID) else {
            return
        }
        cont.resume(throwing: CancellationError())
    }

    private func markPreparedIfStillValid(generation: UInt64, pair: (from: String, to: String)) {
        guard self.generation == generation,
              let desiredPair,
              desiredPair.from == pair.from,
              desiredPair.to == pair.to
        else {
            return
        }
        hasActiveSession = true
        isPrepared = true
    }

    private func succeed(requestID: UUID, value: String) {
        guard let cont = pending.removeValue(forKey: requestID) else {
            return
        }
        cont.resume(returning: value)
    }

    private func fail(requestID: UUID, error: Error) {
        guard let cont = pending.removeValue(forKey: requestID) else {
            return
        }
        cont.resume(throwing: error)
    }

    private func failAllPending() {
        let all = pending
        pending.removeAll()
        for (_, cont) in all {
            cont.resume(throwing: AppleSubtitleTranslationError.sessionUnavailable)
        }
    }

    private func detectLanguageCode(from sample: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(sample)
        return recognizer.dominantLanguage?.rawValue
    }
}

#endif
