import CinePlayerSDK
import Combine
//
//  AppleSubtitleTranslator.swift
//  Cinemore
//
//  Apple Translation backed subtitle translator.
//  Critical constraint: TranslationSession must not escape SwiftUI .translationTask.
//

#if !os(tvOS) && !os(visionOS)

    import Foundation
    import NaturalLanguage
    @preconcurrency import Translation

    @available(iOS 18.0, macOS 15.0, *)
    nonisolated enum AppleTranslationLanguageSupport {
        static func normalizedIdentifier(_ raw: String) -> String? {
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
                    let normalizedScript =
                        second.prefix(1).uppercased() + second.dropFirst().lowercased()
                    normalizedParts.append(normalizedScript)
                }
            }
            return normalizedParts.joined(separator: "-")
        }

        static func normalizedLanguage(from raw: String) -> Locale.Language? {
            guard let identifier = normalizedIdentifier(raw) else {
                return nil
            }
            return Locale.Language(identifier: identifier)
        }

        static func availabilityStatus(from sourceIdentifier: String, to targetIdentifier: String)
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

        static func translationConfiguration(from sourceIdentifier: String, to targetIdentifier: String)
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
        struct Request {
            let id: UUID
            let generation: UInt64
            let text: String
        }

        private(set) var desiredPair: (from: String, to: String)?

        private var isPrepared = false
        private var generation: UInt64 = 0

        private var activeSessionID: UUID?
        private var preparationFailed = false
        private var queuedRequests: [Request] = []
        private var requestContinuation: AsyncStream<Request>.Continuation?

        private var pending: [UUID: CheckedContinuation<String, Error>] = [:]

        init() {}

        func invalidate() {
            generation &+= 1
            desiredPair = nil
            activeSessionID = nil
            preparationFailed = false
            requestContinuation?.finish()
            requestContinuation = nil
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
            activeSessionID = nil
            preparationFailed = false
            requestContinuation?.finish()
            requestContinuation = nil
            isPrepared = false
            failAllPending()
            return (newPair, true)
        }

        func translate(text: String) async throws -> String {
            try Task.checkCancellation()
            guard desiredPair != nil, !preparationFailed else {
                throw AppleSubtitleTranslationError.sessionUnavailable
            }

            let requestID = UUID()
            let request = Request(id: requestID, generation: generation, text: text)

            return try await withTaskCancellationHandler(
                operation: {
                    try await withCheckedThrowingContinuation { cont in
                        pending[requestID] = cont
                        queuedRequests.append(request)
                        // 未就绪时也先排队；新会话会接管尚未完成的请求。
                        if let requestContinuation {
                            if case let .dropped(dropped) = requestContinuation.yield(request) {
                                fail(requestID: dropped.id, error: AppleSubtitleTranslationError.sessionUnavailable)
                            }
                        }
                        if queuedRequests.count > 64, let oldest = queuedRequests.first {
                            fail(requestID: oldest.id, error: AppleSubtitleTranslationError.sessionUnavailable)
                        }
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
            guard !Task.isCancelled else {
                return
            }
            // 手动重启会创建新 translator，由本次挂载的固定语言对初始化。
            if desiredPair == nil {
                desiredPair = (from: pair.from, to: pair.to)
            }
            guard let desiredPair, desiredPair.from == pair.from, desiredPair.to == pair.to else {
                return
            }

            let sessionID = UUID()
            let startGeneration = generation
            cinemoreLog(level: .debug, "Apple 字幕会话开始准备: \(pair.from) → \(pair.to)，会话 \(sessionID)")
            activeSessionID = sessionID
            preparationFailed = false
            isPrepared = false

            // 每个会话使用独立的流，旧消费者不能取走新会话的请求。
            requestContinuation?.finish()
            var continuation: AsyncStream<Request>.Continuation?
            let stream = AsyncStream<Request>(bufferingPolicy: .bufferingNewest(64)) { continuation = $0 }
            requestContinuation = continuation
            for request in queuedRequests where pending[request.id] != nil {
                continuation?.yield(request)
            }

            defer {
                // 旧会话只能关闭自己的队列，不能清空后来会话的状态。
                continuation?.finish()
                if activeSessionID == sessionID {
                    activeSessionID = nil
                    requestContinuation = nil
                    isPrepared = false
                    failAllPending()
                }
            }

            // 已安装语言包的临时准备失败最多恢复一次；取消、不支持和缺包不循环重试。
            for attempt in 0 ... 1 {
                do {
                    try Task.checkCancellation()
                    try await session.prepareTranslation()
                    guard isCurrentSession(sessionID, generation: startGeneration) else {
                        return
                    }
                    isPrepared = true
                    cinemoreLog(level: .debug, "Apple 字幕会话已就绪: \(sessionID)")
                    break
                } catch {
                    guard isCurrentSession(sessionID, generation: startGeneration) else {
                        return
                    }
                    cinemoreLog(level: .debug, "Apple 字幕会话准备失败（第 \(attempt + 1) 次）: \(error)")
                    let status = await AppleTranslationLanguageSupport.availabilityStatus(
                        from: pair.from, to: pair.to
                    )
                    guard isCurrentSession(sessionID, generation: startGeneration) else {
                        return
                    }
                    guard attempt == 0, status == .installed else {
                        preparationFailed = true
                        return
                    }
                    do {
                        try await Task.sleep(nanoseconds: 300_000_000)
                    } catch {
                        return
                    }
                    guard isCurrentSession(sessionID, generation: startGeneration) else {
                        return
                    }
                }
            }

            guard isPrepared, isCurrentSession(sessionID, generation: startGeneration) else {
                return
            }
            for await request in stream {
                guard isCurrentSession(sessionID, generation: startGeneration) else {
                    return
                }
                guard pending[request.id] != nil else {
                    continue
                }
                guard request.generation == startGeneration else {
                    fail(requestID: request.id, error: AppleSubtitleTranslationError.sessionUnavailable)
                    continue
                }
                do {
                    let response = try await session.translate(request.text)
                    guard isCurrentSession(sessionID, generation: startGeneration) else {
                        return
                    }
                    succeed(requestID: request.id, value: response.targetText)
                } catch {
                    guard isCurrentSession(sessionID, generation: startGeneration) else {
                        return
                    }
                    fail(requestID: request.id, error: error)
                }
            }
        }

        private func isCurrentSession(_ id: UUID, generation expectedGeneration: UInt64) -> Bool {
            !Task.isCancelled && activeSessionID == id && generation == expectedGeneration
        }

        private func cancel(requestID: UUID) {
            queuedRequests.removeAll { $0.id == requestID }
            guard let cont = pending.removeValue(forKey: requestID) else {
                return
            }
            cont.resume(throwing: CancellationError())
        }

        private func succeed(requestID: UUID, value: String) {
            queuedRequests.removeAll { $0.id == requestID }
            guard let cont = pending.removeValue(forKey: requestID) else {
                return
            }
            cont.resume(returning: value)
        }

        private func fail(requestID: UUID, error: Error) {
            queuedRequests.removeAll { $0.id == requestID }
            guard let cont = pending.removeValue(forKey: requestID) else {
                return
            }
            cont.resume(throwing: error)
        }

        private func failAllPending() {
            queuedRequests.removeAll()
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
