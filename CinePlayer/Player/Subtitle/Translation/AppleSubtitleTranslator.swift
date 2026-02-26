#if !os(tvOS) && !os(visionOS)

import Foundation
import NaturalLanguage
@preconcurrency import Translation

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
        func canonicalizeLanguageID(_ raw: String) -> String? {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                return nil
            }
            guard trimmed.lowercased() != "und" else {
                return nil
            }

            let canonical =
                NSLocale
                .canonicalLanguageIdentifier(from: trimmed)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !canonical.isEmpty else {
                return nil
            }
            guard canonical.lowercased() != "und" else {
                return nil
            }

            return canonical.replacingOccurrences(of: "_", with: "-")
        }

        let resolvedFrom: String = {
            if from == "auto" {
                return detectLanguageCode(from: sampleText) ?? "en"
            }
            if let canonical = canonicalizeLanguageID(from) {
                return canonical
            }
            return detectLanguageCode(from: sampleText) ?? "en"
        }()

        let resolvedTo: String = canonicalizeLanguageID(to) ?? to

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
            subtitleTranslationLog(
                .debug,
                "Apple session prepared from=\(pair.from) to=\(pair.to) generation=\(startGeneration)"
            )
        } catch {
            subtitleTranslationLog(
                .error,
                "Apple session prepare failed from=\(pair.from) to=\(pair.to) error=\(error)"
            )
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
                    subtitleTranslationLog(
                        .debug,
                        "Apple session unavailable for request from=\(pair.from) to=\(pair.to) generation=\(generation)"
                    )
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
                        subtitleTranslationLog(
                            .error,
                            "Apple session translate failed from=\(pair.from) to=\(pair.to) error=\(error)"
                        )
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
