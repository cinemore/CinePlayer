import CinePlayerSDK
import Foundation

/// 应用层字幕策略：目标语言判断、简繁转换和单语／双语文本组合。
struct AppSubtitleTranslationProcessor: Sendable {
    let mode: SubtitleTranslateMode
    let translateFunction: @Sendable (String, String, String) async throws -> String
    var translationOnTop = true

    func process(content: String, fromLang: String, toLang: String) async throws -> String {
        guard mode.needsTranslation else {
            return content
        }
        let source = fromLang.trimmingCharacters(in: .whitespacesAndNewlines)
        if Self.isSameLanguage(source, toLang) {
            return content
        }

        let pureText = Self.plainText(from: content)
        if let convertedText = Self.tryChineseVariantConversion(
            text: pureText, from: source, to: toLang
        ) {
            return buildFinalText(
                translatedText: convertedText, originalContent: content, mode: mode
            )
        }

        let sourceLanguage = source.isEmpty || source.lowercased() == "und"
            ? "auto" : Self.systemNormalizedLanguageIdentifier(source)
        let targetLanguage = Self.systemNormalizedLanguageIdentifier(toLang)
        let translatedText = try await translateFunction(pureText, sourceLanguage, targetLanguage)
        return buildFinalText(
            translatedText: translatedText, originalContent: content, mode: mode
        )
    }

    /// 判断源语言与目标语言是否一致（一致则不翻译），兼容 chi/cmn/yue/zh-Hans-CN 等；中文简繁视为不同
    static func isSameLanguage(_ fromLang: String, _ toLang: String) -> Bool {
        let fromNorm = normalizedIdentifierForComparison(fromLang)
        let toNorm = normalizedIdentifierForComparison(toLang)
        guard !fromNorm.isEmpty, !toNorm.isEmpty else {
            return false
        }

        return isSameLanguageNative(fromNorm: fromNorm, toNorm: toNorm, fromLangRaw: fromLang)
    }

    /// 转为系统统一格式（BCP-47 风格），用于传给翻译 API
    static func systemNormalizedLanguageIdentifier(_ identifier: String) -> String {
        let normalized = normalizedIdentifierForComparison(identifier)
        guard !normalized.isEmpty else {
            return identifier
        }
        return systemNormalizedLanguageIdentifierNative(normalized: normalized, fallback: identifier)
    }

    // MARK: - 私有语言/文本辅助

    private static func isSameLanguageNative(fromNorm: String, toNorm: String, fromLangRaw: String) -> Bool {
        let fromLangObj = Locale.Language(identifier: fromNorm)
        let toLangObj = Locale.Language(identifier: toNorm)
        let fromCodeStr = fromLangObj.languageCode.map { String(describing: $0) } ?? ""
        let toCodeStr = toLangObj.languageCode.map { String(describing: $0) } ?? ""
        guard !fromCodeStr.isEmpty, !toCodeStr.isEmpty, fromCodeStr == toCodeStr else {
            return false
        }
        if fromCodeStr != "zh" {
            return true
        }
        let fromRawLower = fromLangRaw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sourceIsAmbiguousChinese = fromRawLower == "chi" || fromRawLower == "cmn" || fromRawLower == "yue"
        let fromScript = sourceIsAmbiguousChinese ? nil : fromLangObj.script.map { String(describing: $0) }
        let toScript = toLangObj.script.map { String(describing: $0) }
        if let fs = fromScript, let ts = toScript {
            return fs == ts
        }
        return false
    }

    private static func systemNormalizedLanguageIdentifierNative(normalized: String, fallback: String) -> String {
        let lang = Locale.Language(identifier: normalized)
        guard let code = lang.languageCode else {
            return fallback
        }
        var result = String(describing: code)
        if let script = lang.script {
            result += "-\(String(describing: script))"
        }
        if let region = lang.region {
            result += "-\(String(describing: region))"
        }
        return result
    }

    private static func normalizedIdentifierForComparison(_ identifier: String) -> String {
        let raw = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return raw
        }
        let lower = raw.lowercased()
        if lower == "chi" || lower == "cmn" || lower == "yue" {
            return "zh"
        }
        let canonical = NSLocale.canonicalLanguageIdentifier(from: raw)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
        return canonical.isEmpty ? raw : canonical
    }

    private static func tryChineseVariantConversion(
        text: String, from fromLang: String, to toLang: String
    ) -> String? {
        let fromNorm = normalizedIdentifierForComparison(fromLang)
        let toNorm = normalizedIdentifierForComparison(toLang)
        let fromLangObj = Locale.Language(identifier: fromNorm)
        let toLangObj = Locale.Language(identifier: toNorm)
        let fromCode = fromLangObj.languageCode.map { String(describing: $0) }?.lowercased() ?? ""
        let toCode = toLangObj.languageCode.map { String(describing: $0) }?.lowercased() ?? ""

        guard fromCode == "zh", toCode == "zh" else {
            return nil
        }

        let toLangLower = toLang.lowercased()
        let isTargetSimplified: Bool
        if toLangLower.contains("hans") || toLangLower.hasPrefix("zh-cn")
            || toLangLower.hasPrefix("zh-sg")
        {
            isTargetSimplified = true
        } else if toLangLower.contains("hant") || toLangLower.hasPrefix("zh-tw")
            || toLangLower.hasPrefix("zh-hk") || toLangLower.hasPrefix("zh-mo")
        {
            isTargetSimplified = false
        } else {
            return nil
        }

        let convertedText: String? =
            isTargetSimplified
                ? (text as NSString).applyingTransform(.init(rawValue: "Hant-Hans"), reverse: false)
                : (text as NSString).applyingTransform(.init(rawValue: "Hans-Hant"), reverse: false)

        guard let result = convertedText else {
            return nil
        }
        if result == text {
            return text
        }
        return result
    }

    private func buildFinalText(
        translatedText: String, originalContent: String, mode: SubtitleTranslateMode
    ) -> String {
        switch mode {
        case .off:
            return originalContent
        case .translated:
            return translatedText
        case .bilingual:
            let originalClean =
                originalContent
                    .replacingOccurrences(of: "\\N", with: " ")
                    .replacingOccurrences(of: "\\n", with: " ")
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespaces)
            if translatedText.trimmingCharacters(in: .whitespaces).lowercased()
                == originalClean.lowercased()
            {
                return translatedText
            }
            if translationOnTop {
                return "\(translatedText)\\N{\\fscx75\\fscy75}\(originalClean)"
            }
            // 字号按上下位置区分：上行正常大小，下行缩小。
            return "\(originalClean)\\N{\\fscx75\\fscy75}\(translatedText)"
        @unknown default:
            return originalContent
        }
    }

    /// 翻译服务接收连续文本，换行布局由最终展示文本决定。
    private static func plainText(from text: String) -> String {
        text
            .replacingOccurrences(of: "\\N", with: " ")
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }
}
