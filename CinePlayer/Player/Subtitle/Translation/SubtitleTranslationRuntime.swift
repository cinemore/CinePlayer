import Foundation
import SwiftUI
import Combine

@MainActor
final class SubtitleTranslationRuntime: ObservableObject {
    struct LanguagePair: Equatable {
        var from: String
        var to: String
    }

    @Published var desiredApplePair: LanguagePair?
}
