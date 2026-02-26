import SwiftUI

#if !os(tvOS) && !os(visionOS)
@preconcurrency import Translation

@available(iOS 18.0, macOS 15.0, *)
private struct AvailableLanguage: Identifiable, Hashable, Comparable {
    let locale: Locale.Language

    var id: String {
        localeIdentifier
    }

    static func < (lhs: AvailableLanguage, rhs: AvailableLanguage) -> Bool {
        lhs.localizedName() < rhs.localizedName()
    }

    func localizedName() -> String {
        let locale = Locale.current
        let code = localeIdentifier
        let name =
            locale.localizedString(forLanguageCode: code)
            ?? locale.localizedString(forIdentifier: code)
            ?? code
        return "\(name) (\(code))"
    }

    var localeIdentifier: String {
        let language = locale.languageCode.map { String(describing: $0) } ?? ""
        let region = locale.region.map { String(describing: $0) } ?? ""
        if region.isEmpty {
            return language
        }
        if language.isEmpty {
            return region
        }
        return "\(language)-\(region)"
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct AppleSubtitleTranslationLanguagePage: View {
    var presetFrom: String?
    var presetTo: String?

    @State private var availableLanguages: [AvailableLanguage] = []
    @State private var selectedSource: AvailableLanguage?
    @State private var selectedTarget: AvailableLanguage?
    @State private var lockedTaskConfig: TranslationSession.Configuration?
    @State private var isPreparing = false
    @State private var prepareError: String?
    @State private var pairStatus: LanguageAvailability.Status?

    private var isPresetMode: Bool {
        presetFrom != nil && presetTo != nil && presetFrom != presetTo
    }

    private var presetSourceLocale: Locale.Language? {
        guard let from = presetFrom else {
            return nil
        }
        return Locale.Language(identifier: from)
    }

    private var presetTargetLocale: Locale.Language? {
        guard let to = presetTo else {
            return nil
        }
        return Locale.Language(identifier: to)
    }

    private var canDownload: Bool {
        if isPresetMode {
            return presetSourceLocale != nil && presetTargetLocale != nil
        }
        guard let selectedSource, let selectedTarget else {
            return false
        }
        return selectedSource.locale != selectedTarget.locale
    }

    private var pairTaskId: String {
        if isPresetMode,
           let from = presetFrom,
           let to = presetTo
        {
            return "\(from)_\(to)"
        }

        guard let source = selectedSource,
              let target = selectedTarget
        else {
            return ""
        }

        return "\(source.localeIdentifier)_\(target.localeIdentifier)"
    }

    var body: some View {
        List {
            if isPresetMode {
                Section {
                    Text("当前字幕翻译需要以下语言包，请下载后继续播放。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let src = presetSourceLocale,
                   let tgt = presetTargetLocale
                {
                    Section("语言对") {
                        LabeledContent("源语言", value: displayName(for: src))
                        LabeledContent("目标语言", value: displayName(for: tgt))
                    }
                }
            } else {
                Section {
                    Text("选择源语言和目标语言后，点击“下载语言包”可离线使用 Apple 翻译。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("源语言") {
                    Picker("源语言", selection: $selectedSource) {
                        Text("请选择").tag(nil as AvailableLanguage?)
                        ForEach(availableLanguages) { language in
                            Text(language.localizedName()).tag(language as AvailableLanguage?)
                        }
                    }
                }

                Section("目标语言") {
                    Picker("目标语言", selection: $selectedTarget) {
                        Text("请选择").tag(nil as AvailableLanguage?)
                        ForEach(availableLanguages) { language in
                            Text(language.localizedName()).tag(language as AvailableLanguage?)
                        }
                    }
                }
            }

            if let error = prepareError {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section {
                if canDownload, pairStatus == .installed {
                    Label("已下载", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }

                Button {
                    startPrepare()
                } label: {
                    HStack {
                        Text("下载语言包")
                        Spacer()
                        if isPreparing {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                }
                .disabled(!canDownload || isPreparing || pairStatus == .installed)
            }
        }
        .task {
            await loadSupportedLanguagesIfNeeded()
        }
        .task(id: pairTaskId) {
            await refreshPairStatus()
        }
        .translationTask(lockedTaskConfig) { session in
            guard lockedTaskConfig != nil else {
                return
            }
            do {
                try await session.prepareTranslation()
            } catch {
                await MainActor.run {
                    prepareError = error.localizedDescription
                }
            }
            // Keep state stable during system download flow to avoid task view rebuild.
        }
        .onDisappear {
            isPreparing = false
            lockedTaskConfig = nil
        }
        .navigationTitle("翻译语言")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func displayName(for locale: Locale.Language) -> String {
        let code = AvailableLanguage(locale: locale).localeIdentifier
        return availableLanguages.first(where: { $0.locale == locale })?.localizedName()
            ?? Locale.current.localizedString(forLanguageCode: code)
            ?? code
    }

    private func loadSupportedLanguagesIfNeeded() async {
        guard !isPresetMode else {
            return
        }
        guard availableLanguages.isEmpty else {
            return
        }
        let supportedLanguages = await LanguageAvailability().supportedLanguages
        await MainActor.run {
            availableLanguages = supportedLanguages.map { AvailableLanguage(locale: $0) }.sorted()
        }
    }

    private func refreshPairStatus() async {
        if isPresetMode,
           let src = presetSourceLocale,
           let tgt = presetTargetLocale
        {
            let status = await LanguageAvailability().status(from: src, to: tgt)
            await MainActor.run {
                pairStatus = status
            }
            return
        }

        guard let src = selectedSource,
              let tgt = selectedTarget,
              src.locale != tgt.locale
        else {
            await MainActor.run {
                pairStatus = nil
            }
            return
        }

        let status = await LanguageAvailability().status(from: src.locale, to: tgt.locale)
        await MainActor.run {
            pairStatus = status
        }
    }

    private func startPrepare() {
        prepareError = nil
        isPreparing = true

        if isPresetMode,
           let src = presetSourceLocale,
           let tgt = presetTargetLocale
        {
            lockedTaskConfig = TranslationSession.Configuration(source: src, target: tgt)
            return
        }

        guard let src = selectedSource,
              let tgt = selectedTarget,
              src.locale != tgt.locale
        else {
            isPreparing = false
            return
        }

        lockedTaskConfig = TranslationSession.Configuration(source: src.locale, target: tgt.locale)
    }
}
#endif

#if os(tvOS) || os(visionOS)
struct AppleSubtitleTranslationLanguagePage: View {
    var presetFrom: String?
    var presetTo: String?

    var body: some View {
        List {
            Section {
                Text("当前平台不支持 Apple 翻译语言包下载。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("翻译语言")
    }
}
#endif
