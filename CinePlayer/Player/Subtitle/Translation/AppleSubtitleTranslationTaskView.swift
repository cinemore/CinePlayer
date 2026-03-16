import CinePlayerSDK
import SwiftUI

#if !os(tvOS) && !os(visionOS)
@preconcurrency import Translation

@available(iOS 18.0, macOS 15.0, *)
struct AppleSubtitleTranslationTaskView: View {
    @ObservedObject var runtime: SubtitleTranslationRuntime
    let router: SubtitleTranslationRouter

    @State private var pairInstalled: Bool? = nil

    var body: some View {
        baseView
            .task(id: pairTaskId) {
                await updatePairInstalled()
            }
    }

    private var pairTaskId: String {
        guard translationConfiguration != nil,
              let pair = runtime.desiredApplePair
        else {
            return ""
        }
        return "\(pair.from)_\(pair.to)"
    }

    private func updatePairInstalled() async {
        guard !pairTaskId.isEmpty,
              let pair = runtime.desiredApplePair
        else {
            await MainActor.run {
                pairInstalled = nil
            }
            return
        }

        let status = await AppleTranslationLanguageSupport.availabilityStatus(
            from: pair.from,
            to: pair.to
        )
        await MainActor.run {
            pairInstalled = (status == .installed)
        }
    }

    @ViewBuilder
    private var baseView: some View {
        if let config = translationConfiguration, pairInstalled == true {
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .translationTask(config) { session in
                    guard let pair = runtime.desiredApplePair else {
                        return
                    }
                    await router.runAppleSession(session, pair: (from: pair.from, to: pair.to))
                }
        } else {
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    private var translationConfiguration: TranslationSession.Configuration? {
        guard let pair = runtime.desiredApplePair,
              !pair.from.isEmpty,
              !pair.to.isEmpty
        else {
            return nil
        }

        return AppleTranslationLanguageSupport.translationConfiguration(
            from: pair.from,
            to: pair.to
        )
    }
}

@available(iOS 18.0, macOS 15.0, *)
struct AppleSubtitleTranslationTaskHostView: View {
    @ObservedObject var runtime: SubtitleTranslationRuntime
    let router: SubtitleTranslationRouter

    var body: some View {
        AppleSubtitleTranslationTaskView(runtime: runtime, router: router)
    }
}
#endif
