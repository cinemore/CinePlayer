import CinePlayerSDK
import Combine
//
//  SubtitleTranslationRuntime.swift
//  Cinemore
//
//  Runtime state for subtitle translation session configuration.
//  Used to drive SwiftUI .translationTask configuration without leaking TranslationSession.
//

import Foundation
import SwiftUI

@MainActor
final class SubtitleTranslationRuntime: ObservableObject {
    struct LanguagePair: Equatable, Sendable {
        var from: String
        var to: String
    }

    /// Desired Apple Translation language pair for the current playback context.
    /// When nil, SwiftUI should not attach a TranslationSession.
    @Published var desiredApplePair: LanguagePair? {
        didSet {
            if oldValue != desiredApplePair {
                appleSessionID = UUID()
            }
        }
    }

    /// 即使相同语言对重启，也让旧的 SwiftUI 回调无法接管新会话。
    @Published private(set) var appleSessionID = UUID()

    /// 保留语言对，仅要求 SwiftUI 为本次重启创建新会话。
    func restartAppleSession() {
        appleSessionID = UUID()
    }

    /// 下载页面关闭后重新核对同一语言对的安装状态。
    @Published var languageAvailabilityRevision = 0
}
