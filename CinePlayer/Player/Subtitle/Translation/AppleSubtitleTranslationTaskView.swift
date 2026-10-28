import CinePlayerSDK
import Combine
//
//  AppleSubtitleTranslationTaskView.swift
//  Cinemore
//
//  Hosts SwiftUI .translationTask and runs Apple subtitle translation within its task tree.
//  TranslationSession must not escape this view.
//

import SwiftUI

#if !os(tvOS) && !os(visionOS)
    @preconcurrency import Translation

    @available(iOS 18.0, macOS 15.0, *)
    struct AppleSubtitleTranslationTaskView: View {
        @ObservedObject var runtime: SubtitleTranslationRuntime
        let router: SubtitleTranslationRouter

        @EnvironmentObject private var sessionStore: PlayerSessionStore

        /// 安装检测结果绑定语言对，只有当前语言对已安装时才创建 Session。
        @State private var installedPair: SubtitleTranslationRuntime.LanguagePair?
        @State private var installedCheckID: String?

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
            return "\(pair.from)_\(pair.to)_\(runtime.appleSessionID)_\(runtime.languageAvailabilityRevision)"
        }

        private func updatePairInstalled() async {
            let checkID = pairTaskId
            installedCheckID = nil
            installedPair = nil
            guard !pairTaskId.isEmpty, let pair = runtime.desiredApplePair else {
                cinemoreLog(level: .debug, "Apple 字幕安装检测跳过：翻译关闭、服务非 Apple 或语言对未就绪")
                return
            }
            let startedAt = Date()
            cinemoreLog(level: .debug, "Apple 字幕安装检测开始：\(pair.from) → \(pair.to)，检测 \(checkID)")
            let status = await AppleTranslationLanguageSupport.availabilityStatus(
                from: pair.from,
                to: pair.to
            )
            guard !Task.isCancelled, checkID == pairTaskId,
                  runtime.desiredApplePair == pair
            else {
                cinemoreLog(level: .debug, "Apple 字幕安装检测丢弃：检测 \(checkID)，已取消 \(Task.isCancelled)，当前检测 \(pairTaskId)")
                return
            }
            cinemoreLog(
                level: .debug,
                "Apple 字幕安装检测完成：\(pair.from) → \(pair.to)，状态 \(String(describing: status))，耗时 \(Date().timeIntervalSince(startedAt)) 秒，检测 \(checkID)"
            )
            installedPair = status == .installed ? pair : nil
            installedCheckID = status == .installed ? checkID : nil
        }

        /// 仅在 Apple、configuration 有效且语言包已安装时挂载 .translationTask，否则仅 Color.clear，避免系统弹出无内容 sheet
        @ViewBuilder
        private var baseView: some View {
            if let pair = runtime.desiredApplePair,
               installedCheckID == pairTaskId,
               installedPair == pair, let config = translationConfiguration
            {
                let sessionID = runtime.appleSessionID
                Color.clear
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .translationTask(config) { session in
                        cinemoreLog(level: .debug, "Apple 字幕 translationTask 进入：\(pair.from) → \(pair.to)，会话 \(sessionID)")
                        guard !Task.isCancelled, runtime.desiredApplePair == pair,
                              runtime.appleSessionID == sessionID
                        else {
                            cinemoreLog(
                                level: .debug,
                                "Apple 字幕 translationTask 拒绝：会话 \(sessionID)，当前会话 \(runtime.appleSessionID)，已取消 \(Task.isCancelled)，语言对一致 \(runtime.desiredApplePair == pair)"
                            )
                            return
                        }
                        await router.runAppleSession(
                            session, pair: (from: pair.from, to: pair.to), sessionID: sessionID
                        )
                        cinemoreLog(level: .debug, "Apple 字幕 translationTask 退出：会话 \(sessionID)，已取消 \(Task.isCancelled)")
                    }
                    .id(sessionID)
            } else {
                Color.clear
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }

        /// 仅当选择 Apple 翻译且 from/to 就绪时返回有效 Configuration
        private var translationConfiguration: TranslationSession.Configuration? {
            let mode = sessionStore.controlConfig.subtitleTranslateMode
            let pair = runtime.desiredApplePair

            guard mode.needsTranslation,
                  let pair,
                  !pair.from.isEmpty, !pair.to.isEmpty
            else {
                return nil
            }
            return AppleTranslationLanguageSupport.translationConfiguration(
                from: pair.from,
                to: pair.to
            )
        }
    }

    /// 显式观察 runtime，使 desiredApplePair 变化时必定重绘，从而让 .translationTask 用最新 configuration 启动
    @available(iOS 18.0, macOS 15.0, *)
    struct AppleSubtitleTranslationTaskHostView: View {
        @ObservedObject var runtime: SubtitleTranslationRuntime
        let router: SubtitleTranslationRouter

        var body: some View {
            AppleSubtitleTranslationTaskView(runtime: runtime, router: router)
        }
    }
#endif
