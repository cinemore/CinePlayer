import CinePlayerSDK
import SwiftData
import SwiftUI

#if !os(tvOS) && !os(visionOS)
@preconcurrency import Translation
#endif

#if os(macOS)
import AppKit
#endif

#if !os(tvOS) && !os(visionOS)
private enum LanguagePackSheetStatus {
    case canDownload
    case unsupported
}

private struct LanguagePackSheetContent: View {
    let presetFrom: String?
    let presetTo: String?
    let packStatus: LanguagePackSheetStatus?
    let onComplete: () -> Void

    var body: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            if packStatus == .unsupported {
                unsupportedView
            } else {
                downloadView
            }
        } else {
            EmptyView()
        }
    }

    private var unsupportedView: some View {
        NavigationStack {
            List {
                Section {
                    Text("Apple 翻译暂不支持该语言对，已自动关闭字幕翻译。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("翻译语言")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成", action: onComplete)
                }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 280)
            #endif
        }
    }

    @ViewBuilder
    private var downloadView: some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            NavigationStack {
                AppleSubtitleTranslationLanguagePage(
                    presetFrom: presetFrom,
                    presetTo: presetTo
                )
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("完成", action: onComplete)
                    }
                }
            }
            #if os(macOS)
            .frame(minWidth: 420, minHeight: 480)
            #endif
        } else {
            EmptyView()
        }
    }
}
#endif

@MainActor
struct PlayerControlView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel

    @StateObject private var playerControlModel = PlayerControlModel()
    @StateObject private var playerMaskModel = PlayerMaskModel()
    @StateObject private var toastModel = PlayerToastModel()
    @StateObject private var remoteCommandService = PurePlayerRemoteCommandService()

    #if os(macOS)
    @EnvironmentObject private var windowController: PlayerWindowController
    /// 是否已经为当前视频应用过一次窗口布局（避免每次 seek / 状态变化都重置用户手动调整过的窗口大小）
    @State private var hasAppliedMacWindowLayout = false
    #endif

    @State private var isPlayerInitializing = true
    @State private var brightness: CGFloat = 0.5
    @State private var didEnsureHistoryRecord = false
    @State private var didRequestHistoryThumbnail = false
    @State private var lastHistoryProgressSecond = -1
    @State private var lastHistoryDurationSecond = -1

    #if !os(tvOS) && !os(visionOS)
    @State private var showLanguagePackDownloadSheet = false
    @State private var languagePackSheetPresetPair: (from: String, to: String)?
    @State private var languagePackSheetStatus: LanguagePackSheetStatus?
    #endif

    private var controlConfig: PlayerControlConfig {
        sessionStore.controlConfig
    }

    private let mediaInfoMaskOpacity: Double = 0.01

    var body: some View {
        GeometryReader { geometry in
            #if os(macOS)
            // macOS: 对齐 cinemore 布局，将控制面板与 SiderView 放在同一个 overlay geometry 下
            playerSurface(geometry: geometry)
                .overlay {
                    GeometryReader { overlayGeometry in
                        ZStack {
                            if playerMaskModel.isMaskShow {
                                controlOverlay(geometry: overlayGeometry)
                                    .transition(.opacity)
                            }

                            if playerControlModel.showMediaInfoCard {
                                Color.black.opacity(mediaInfoMaskOpacity)
                                    .ignoresSafeArea()
                                    .onTapGesture {
                                        playerControlModel.showMediaInfoCard = false
                                        playerMaskModel.showMask()
                                    }

                                PlayerMediaInfoCardView {
                                    playerControlModel.showMediaInfoCard = false
                                    playerMaskModel.showMask()
                                }
                                .environmentObject(playerModel.playerCoordinator)
                                .padding(.horizontal, 16)
                            }

                            SiderView(geometry: overlayGeometry)
                                .environmentObject(sessionStore)
                                .environmentObject(playerModel)
                                .environmentObject(playerControlModel)
                                .environmentObject(playerMaskModel)
                                .environmentObject(playerModel.playerCoordinator)
                                .environmentObject(playerModel.config.subtitleStyle)

                            if !isLoadingOrErrorOverlayVisible,
                               let toast = toastModel.presentedToast
                            {
                                VStack {
                                    PlayerToastView(
                                        toast: toast,
                                        progress: playerModel.playerCoordinator.progress,
                                        playbackRate: playerModel.playerCoordinator.playbackRate,
                                        brightness: brightness
                                    )
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 28)
                                .ignoresSafeArea(edges: .top)
                            }
                        }
                    }
                }
                .background(.black)
                .onAppear {
                    brightness = PlatformServices.screenBrightness(default: brightness)
                    openCurrentSource(resetPlayerState: true)
                    remoteCommandService.activate(sessionStore: sessionStore, playerModel: playerModel)
                    DispatchQueue.main.async {
                        windowController.attachToKeyWindowIfNeeded()
                        PlatformServices.setMacTrafficLightsHidden(true)
                    }
                }
                .onDisappear {
                    PlatformServices.setMacTrafficLightsHidden(false)
                    remoteCommandService.deactivate()
                }
                .compatibleOnChange(of: sessionStore.currentSource?.id) { _ in
                    openCurrentSource(resetPlayerState: true)
                }
                .onReceive(playerModel.playerCoordinator.progress.$currentTime) { _ in
                    remoteCommandService.refreshNowPlayingInfo()
                }
                .onReceive(playerModel.playerCoordinator.$playbackRate) { _ in
                    remoteCommandService.refreshNowPlayingInfo()
                }
                .onReceive(playerModel.playerCoordinator.$playbackState) { _ in
                    remoteCommandService.refreshNowPlayingInfo()
                }
                .overlay {
                    loadingOrErrorOverlay
                }
            #else
            // 其它平台保持现有布局不变
            ZStack {
                playerSurface(geometry: geometry)

                if playerMaskModel.isMaskShow {
                    controlOverlay(geometry: geometry)
                        .transition(.opacity)
                }

                if playerControlModel.showMediaInfoCard {
                    Color.black.opacity(mediaInfoMaskOpacity)
                        .ignoresSafeArea()
                        .onTapGesture {
                            playerControlModel.showMediaInfoCard = false
                            playerMaskModel.showMask()
                        }

                    PlayerMediaInfoCardView {
                        playerControlModel.showMediaInfoCard = false
                        playerMaskModel.showMask()
                    }
                    .environmentObject(playerModel.playerCoordinator)
                }

                SiderView(geometry: geometry)
                    .environmentObject(sessionStore)
                    .environmentObject(playerModel)
                    .environmentObject(playerControlModel)
                    .environmentObject(playerMaskModel)
                    .environmentObject(playerModel.playerCoordinator)
                    .environmentObject(playerModel.config.subtitleStyle)

                if !isLoadingOrErrorOverlayVisible,
                   let toast = toastModel.presentedToast
                {
                    VStack {
                        PlayerToastView(
                            toast: toast,
                            progress: playerModel.playerCoordinator.progress,
                            playbackRate: playerModel.playerCoordinator.playbackRate,
                            brightness: brightness
                        )
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, 28)
                    .ignoresSafeArea(edges: .top)
                }

                loadingOrErrorOverlay
            }
            .background(.black)
            .onAppear {
                brightness = PlatformServices.screenBrightness(default: brightness)
                openCurrentSource(resetPlayerState: true)
                remoteCommandService.activate(sessionStore: sessionStore, playerModel: playerModel)
                #if os(iOS)
                PlatformServices.enterIOSPlaybackOrientationIfNeeded()
                #endif
            }
            .onDisappear {
                remoteCommandService.deactivate()
                #if os(iOS)
                PlatformServices.exitIOSPlaybackOrientationIfNeeded()
                #endif
            }
            .compatibleOnChange(of: sessionStore.currentSource?.id) { _ in
                openCurrentSource(resetPlayerState: true)
            }
            .onReceive(playerModel.playerCoordinator.progress.$currentTime) { _ in
                remoteCommandService.refreshNowPlayingInfo()
            }
            .onReceive(playerModel.playerCoordinator.$playbackRate) { _ in
                remoteCommandService.refreshNowPlayingInfo()
            }
            .onReceive(playerModel.playerCoordinator.$playbackState) { _ in
                remoteCommandService.refreshNowPlayingInfo()
            }
            #endif
        }
        .environmentObject(playerMaskModel)
        .background(subtitleTranslationTaskHost)
        .environment(\.colorScheme, .dark)
        .preferredColorScheme(.dark)
        .navigationTitle("")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
        #if !os(tvOS) && !os(visionOS)
        .modifier(
            PlayerLanguagePackCheckWhenAvailableModifier(
                translationRuntime: playerModel.translationRuntime,
                mode: sessionStore.controlConfig.subtitleTranslateMode,
                showLanguagePackDownloadSheet: $showLanguagePackDownloadSheet,
                presetPair: $languagePackSheetPresetPair,
                presetStatus: $languagePackSheetStatus,
                isPlaying: playerModel.playerCoordinator.playbackState == .playing,
                pause: { playerModel.playerCoordinator.controller?.pause() },
                disableTranslation: { reason, pair in
                    disableSubtitleTranslationMode(reason: reason, pair: pair)
                }
            )
        )
        .sheet(
            isPresented: $showLanguagePackDownloadSheet,
            onDismiss: {
                handleLanguagePackSheetDismiss()
            }
        ) {
            LanguagePackSheetContent(
                presetFrom: languagePackSheetPresetPair?.from,
                presetTo: languagePackSheetPresetPair?.to,
                packStatus: languagePackSheetStatus,
                onComplete: {
                    showLanguagePackDownloadSheet = false
                }
            )
        }
        #endif
        .compatibleOnChange(of: sessionStore.controlConfig.subtitleTranslateMode) { newMode in
            handleSubtitleTranslateModeChange(newMode)
        }
        #if os(macOS)
        .environmentObject(windowController)
        #endif
    }

    private func playerSurface(geometry: GeometryProxy) -> some View {
        ZStack {
            if playerModel.config.url != nil {
                CinePlayer(
                    coordinator: playerModel.playerCoordinator,
                    config: playerModel.config
                )
                .onPlaybackStateChanged { status in
                    if status == .ready || status == .playing {
                        isPlayerInitializing = false
                        let playbackTime = playerModel.playerCoordinator.controller?.currentPlaybackTime
                            ?? Double(playerModel.playerCoordinator.progress.currentTime)
                        handleHistoryRecordCreationIfNeeded(currentTime: playbackTime)
                        #if os(macOS)
                        // 只在当前视频第一次 ready / playing 时根据视频尺寸调整窗口，
                        // 后续 seek 或状态切换不再修改用户手动调整过的窗口大小
                        if !hasAppliedMacWindowLayout {
                            if let track = playerModel.playerCoordinator.controller?.videoTrack {
                                let size = track.naturalSize
                                if size.width > 0, size.height > 0 {
                                    hasAppliedMacWindowLayout = true
                                    DispatchQueue.main.async {
                                        PlatformServices.configureMacPlayerWindowForVideo(naturalSize: size)
                                    }
                                }
                            }
                        }
                        #endif

                        #if !os(tvOS)
                        if status == .ready {
                            if let track = playerModel.playerCoordinator.controller?.videoTrack {
                                let size = track.naturalSize
                                let width = Int(size.width)
                                let height = Int(size.height)
                                if width > 0, height > 0 {
                                    PlayerEnhancementModel.shared.updateAvailabilityForCurrentVideo(
                                        width: width,
                                        height: height
                                    )
                                } else {
                                    PlayerEnhancementModel.shared.updateAvailabilityForCurrentVideo(
                                        width: nil,
                                        height: nil
                                    )
                                }
                            } else {
                                PlayerEnhancementModel.shared.updateAvailabilityForCurrentVideo(
                                    width: nil,
                                    height: nil
                                )
                            }

                            handleHistoryThumbnailIfNeededOnReady()
                        }
                        #endif
                    }
                }
                .onTimeChanged { currentTime in
                    handleHistoryRecordCreationIfNeeded(currentTime: currentTime)
                    handleHistoryProgressUpdate(currentTime: currentTime)
                }
                .onBufferingStatusChanged { status in
                    handleBufferingStatus(status)
                }
                .onNetworkStatusChanged { status in
                    handleNetworkStatus(status)
                }
                .onNetworkError { type, message in
                    handleNetworkError(type: type, message: message)
                }
                .onError { _ in
                    isPlayerInitializing = false
                    toastModel.show(.networkError(message: "播放出错，请重试或检查网络"), duration: .infinity)
                }
                #if os(macOS)
                .onTapGesture(count: 2) {
                    // 如果窗口处于悬浮锁定状态，先恢复为普通层级
                    if windowController.isFloating {
                        windowController.toggleWindowLevel()
                    }

                    if let window = NSApplication.shared.keyWindow {
                        let wasPlaying = playerModel.playerCoordinator.playbackState == .playing
                        if wasPlaying {
                            playerModel.playerCoordinator.controller?.pause()
                        }
                        window.toggleFullScreen(nil)
                        if wasPlaying {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                playerModel.playerCoordinator.controller?.play()
                            }
                        }
                    }
                }
                #endif
                .ignoresSafeArea()
            } else {
                Color.black
                    .ignoresSafeArea()
            }

            #if os(iOS)
            GestureController(brightness: $brightness, geometry: geometry)
                .environmentObject(sessionStore)
                .environmentObject(playerModel.playerCoordinator)
                .environmentObject(playerMaskModel)
                .environmentObject(playerControlModel)
                .environmentObject(toastModel)
                .ignoresSafeArea()
            #endif

            #if os(tvOS)
            GestureController()
                .environmentObject(sessionStore)
                .environmentObject(playerModel.playerCoordinator)
                .environmentObject(playerMaskModel)
                .environmentObject(toastModel)
                .ignoresSafeArea()
            #endif

            #if os(macOS)
            MacInteractionLayer(
                onMouseMoved: {
                    // 与 cinemore-apple 一致：侧边面板或媒体信息卡片打开时，滑动鼠标不显示主控件
                    if !playerControlModel.isSiderContainerShow, !playerControlModel.showMediaInfoCard {
                        playerMaskModel.showMask()
                    }
                },
                onKeyDown: { event in
                    handleMacKeyDown(event)
                }
            )
            .ignoresSafeArea()
            #endif
        }
    }

    private func controlOverlay(geometry: GeometryProxy) -> some View {
        platformPanel(geometry: geometry)
            .environmentObject(sessionStore)
            .environmentObject(playerModel)
            .environmentObject(playerModel.playerCoordinator)
            .environmentObject(playerMaskModel)
            .environmentObject(playerControlModel)
            .environmentObject(toastModel)
    }

    @ViewBuilder
    private func platformPanel(geometry: GeometryProxy) -> some View {
        #if os(iOS)
        ControllerPanelViewIOS(geometry: geometry)
        #elseif os(macOS)
        ControllerPanelViewMacOS(geometry: geometry)
        #elseif os(tvOS)
        ControllerPanelViewTvOS(geometry: geometry)
        #elseif os(visionOS)
        ControllerPanelViewVision(geometry: geometry)
        #else
        EmptyView()
        #endif
    }

    @ViewBuilder
    private var subtitleTranslationTaskHost: some View {
        #if !os(tvOS) && !os(visionOS)
        if #available(iOS 18.0, macOS 15.0, *) {
            AppleSubtitleTranslationTaskHostView(
                runtime: playerModel.translationRuntime,
                router: playerModel.translationRouter
            )
        } else {
            Color.clear
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        #else
        EmptyView()
        #endif
    }

    /// 当前是否显示「初始化 / 错误」中间浮层，用于避免顶部 Toast 重复展示。
    private var isLoadingOrErrorOverlayVisible: Bool {
        if isPlayerInitializing { return true }
        if let toast = toastModel.presentedToast,
           case .networkError = toast
        {
            return true
        }
        return false
    }

    /// 初始化中与网络错误共用同一浮层：仅展示状态，不拦截点击，关闭按钮始终可点。
    @ViewBuilder
    private var loadingOrErrorOverlay: some View {
        let showLoading = isPlayerInitializing
        let errorMessage: String? = {
            guard let toast = toastModel.presentedToast,
                  case let .networkError(msg) = toast else { return nil }
            return msg
        }()
        if isLoadingOrErrorOverlayVisible {
            ZStack {
                if let message = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                        Text(message)
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(32)
                    .modifier(GlassEffectModifier(cornerRadius: 16, useCapsule: false))
                } else if showLoading {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text(loadingOrErrorOverlayMessage)
                            .f14m()
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .modifier(GlassEffectModifier(cornerRadius: 22, useCapsule: false))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }

    private var loadingOrErrorOverlayMessage: String {
        guard let toast = toastModel.presentedToast else { return "初始化中..." }
        switch toast {
        case .networkConnecting:
            return "正在连接..."
        case let .networkRetrying(attempt, total):
            return "重试中 (\(attempt)/\(total))"
        case let .networkSwitchingURL(currentIndex, totalURLs):
            return "切换线路 (\(currentIndex)/\(totalURLs))"
        default:
            return "初始化中..."
        }
    }

    private func openCurrentSource(resetPlayerState: Bool) {
        guard let source = sessionStore.currentSource else {
            return
        }
        if resetPlayerState {
            isPlayerInitializing = true
            didEnsureHistoryRecord = false
            didRequestHistoryThumbnail = false
            lastHistoryProgressSecond = -1
            lastHistoryDurationSecond = -1
            #if os(macOS)
            // 切换到新的视频源时，允许重新根据新视频尺寸应用一次窗口布局
            hasAppliedMacWindowLayout = false
            #endif
        }
        playerModel.open(url: source.url, startTime: source.startTime, controlConfig: controlConfig)
        remoteCommandService.refreshNowPlayingInfo()
    }

    private func handleHistoryRecordCreationIfNeeded(currentTime: TimeInterval) {
        guard !didEnsureHistoryRecord, let source = sessionStore.currentSource else {
            return
        }
        let totalDuration = historyTotalDuration()
        PlaybackHistoryRepository.ensureRecordExists(
            for: source,
            initialPlaybackTime: currentTime,
            totalDuration: totalDuration,
            in: modelContext
        )
        didEnsureHistoryRecord = true
        lastHistoryProgressSecond = Int(currentTime.rounded(.down))
        lastHistoryDurationSecond = Int(totalDuration.rounded(.down))
    }

    private func handleHistoryProgressUpdate(currentTime: TimeInterval) {
        guard didEnsureHistoryRecord, let source = sessionStore.currentSource else {
            return
        }
        let currentSecond = Int(currentTime.rounded(.down))
        let totalDuration = historyTotalDuration()
        let totalSecond = Int(totalDuration.rounded(.down))

        guard currentSecond != lastHistoryProgressSecond || totalSecond != lastHistoryDurationSecond else {
            return
        }
        lastHistoryProgressSecond = currentSecond
        lastHistoryDurationSecond = totalSecond

        PlaybackHistoryRepository.updatePlaybackProgress(
            for: source,
            currentTime: currentTime,
            totalDuration: totalDuration,
            in: modelContext
        )
    }

    private func historyTotalDuration() -> TimeInterval {
        let controllerDuration = playerModel.playerCoordinator.controller?.duration ?? 0
        return max(controllerDuration, Double(playerModel.playerCoordinator.progress.totalTime))
    }

    private func handleHistoryThumbnailIfNeededOnReady() {
        guard
            !didRequestHistoryThumbnail,
            let source = sessionStore.currentSource,
            let controller = playerModel.playerCoordinator.controller
        else {
            return
        }
        guard PlaybackHistoryRepository.hasThumbnail(for: source, in: modelContext) == false else {
            didRequestHistoryThumbnail = true
            return
        }

        let duration = max(controller.duration, Double(playerModel.playerCoordinator.progress.totalTime))
        guard duration > 0 else {
            return
        }

        didRequestHistoryThumbnail = true
        let captureTime = duration / 2
        let targetSize = CGSize(width: 320, height: 180)

        Task { @MainActor in
            guard let result = await controller.requestScrubThumbnail(
                time: captureTime,
                targetPointSize: targetSize,
                scale: 1
            ) else {
                return
            }
            PlaybackHistoryRepository.saveThumbnailIfNeeded(
                for: source,
                thumbnailData: result.imageData,
                in: modelContext
            )
        }
    }

    private func handleSubtitleTranslateModeChange(_ mode: SubtitleTranslateMode) {
        playerModel.applySubtitleTranslationSettings(mode: mode)
        refreshSubtitleForTranslationModeChange()
    }

    #if !os(tvOS) && !os(visionOS)
    private func disableSubtitleTranslationMode(
        reason: String,
        pair: (from: String, to: String)? = nil,
        availabilityStatus: String = "n/a"
    ) {
        let previousMode = sessionStore.controlConfig.subtitleTranslateMode
        guard previousMode.needsTranslation else {
            let pairText = pair.map { "\($0.from)->\($0.to)" } ?? "unknown"
            subtitleTranslationLog(
                .debug,
                "[LanguagePackPolicy] ignore disable request reason=\(reason) pair=\(pairText) mode=\(previousMode)"
            )
            return
        }

        var updatedConfig = sessionStore.controlConfig
        updatedConfig.subtitleTranslateMode = .off
        sessionStore.controlConfig = updatedConfig

        let pairText = pair.map { "\($0.from)->\($0.to)" } ?? "unknown"
        subtitleTranslationLog(
            .error,
            "[LanguagePackPolicy] force mode off reason=\(reason) pair=\(pairText) previousMode=\(previousMode) availability=\(availabilityStatus)"
        )
    }

    private func handleLanguagePackSheetDismiss() {
        let dismissedPair = languagePackSheetPresetPair
        let dismissedStatus = languagePackSheetStatus

        languagePackSheetPresetPair = nil
        languagePackSheetStatus = nil

        guard dismissedStatus == .canDownload,
              let pair = dismissedPair
        else {
            return
        }

        guard sessionStore.controlConfig.subtitleTranslateMode.needsTranslation else {
            subtitleTranslationLog(
                .debug,
                "[LanguagePackPolicy] sheet dismissed with mode already off pair=\(pair.from)->\(pair.to)"
            )
            return
        }

        if #available(iOS 18.0, macOS 15.0, *) {
            Task {
                let sourceLang = Locale.Language(identifier: pair.from)
                let targetLang = Locale.Language(identifier: pair.to)
                let status = await LanguageAvailability().status(from: sourceLang, to: targetLang)
                let statusText = String(describing: status)
                await MainActor.run {
                    if let currentPair = playerModel.translationRuntime.desiredApplePair,
                       currentPair.from != pair.from || currentPair.to != pair.to
                    {
                        subtitleTranslationLog(
                            .debug,
                            "[LanguagePackPolicy] skip dismiss fallback because pair changed dismissed=\(pair.from)->\(pair.to) current=\(currentPair.from)->\(currentPair.to)"
                        )
                        return
                    }
                    if status == .installed {
                        subtitleTranslationLog(
                            .debug,
                            "[LanguagePackPolicy] sheet dismissed after install pair=\(pair.from)->\(pair.to) status=\(statusText), keep mode=\(sessionStore.controlConfig.subtitleTranslateMode)"
                        )
                        return
                    }
                    disableSubtitleTranslationMode(
                        reason: "language_pack_sheet_dismissed_without_install",
                        pair: pair,
                        availabilityStatus: statusText
                    )
                }
            }
            return
        }

        disableSubtitleTranslationMode(
            reason: "language_pack_sheet_dismissed_on_unsupported_os",
            pair: pair,
            availabilityStatus: "unknown"
        )
    }
    #endif

    private func refreshSubtitleForTranslationModeChange() {
        guard let controller = playerModel.playerCoordinator.controller else {
            return
        }

        if !playerControlModel.currentSubtitlePath.isEmpty {
            if let item = playerControlModel.localSubtitleItems.first(
                where: { $0.id == playerControlModel.currentSubtitlePath }
            ) {
                controller.clearSubtitle()
                controller.loadSubtitleFile(subtitleID: item.displayName, url: item.url)
            }
        } else if playerModel.playerCoordinator.subtitleTrackIndex != -1 {
            let selectedIndex = playerModel.playerCoordinator.subtitleTrackIndex
            controller.clearSubtitle()
            controller.loadSubtitleTrack(subtitlesTrackIndex: selectedIndex)
        } else {
            return
        }

        let currentTime = controller.currentPlaybackTime
        let seekTime = max(currentTime - 2, 0)
        controller.seek(time: seekTime)
    }

    /// 与 cinemore-apple 一致：仅 .error 时 toast；错误时结束初始化态并常驻提示以便用户可点关闭
    private func handleBufferingStatus(_ status: BufferState) {
        if status == .error {
            isPlayerInitializing = false
            toastModel.show(.networkError(message: "加载失败"), duration: .infinity)
        }
    }

    /// 与 cinemore-apple 一致：仅更新 toast，不驱动 isPlayerInitializing；.stable duration 1.0，.switchingURL .infinity
    private func handleNetworkStatus(_ status: NetworkPlaybackStatus) {
        switch status {
        case .connecting:
            toastModel.show(.networkConnecting, duration: .infinity)
        case let .retrying(attempt, totalAttempts):
            toastModel.show(.networkRetrying(attempt: attempt, total: totalAttempts), duration: .infinity)
        case let .switchingURL(currentIndex, totalURLs):
            toastModel.show(.networkSwitchingURL(currentIndex: currentIndex, totalURLs: totalURLs), duration: .infinity)
        case .stable:
            toastModel.show(.networkStable, duration: 1.0)
        case let .failed(reason):
            isPlayerInitializing = false
            toastModel.show(.networkError(message: reason), duration: .infinity)
        case .buffering:
            break
        @unknown default:
            break
        }
    }

    private func handleNetworkError(type: NetworkErrorType, message: String) {
        let fallbackMessage: String
        switch type {
        case .timeout:
            fallbackMessage = "网络超时，请稍后重试"
        case .connectionRefused:
            fallbackMessage = "连接被拒绝，请检查线路"
        case .dnsResolution:
            fallbackMessage = "域名解析失败，请检查网络"
        case .httpClientError:
            fallbackMessage = "请求异常，请稍后重试"
        case .httpServerError:
            fallbackMessage = "服务器异常，请稍后重试"
        case .networkUnreachable:
            fallbackMessage = "当前网络不可用"
        case .temporaryFailure:
            fallbackMessage = "网络波动，正在重试"
        case .permanentFailure:
            fallbackMessage = "播放失败，请更换线路"
        case .unknown:
            fallbackMessage = "发生未知网络错误"
        @unknown default:
            fallbackMessage = "发生网络错误"
        }

        let text = message.isEmpty ? fallbackMessage : message
        isPlayerInitializing = false
        toastModel.show(.networkError(message: text), duration: .infinity)
    }

    #if os(macOS)
    private func handleMacKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 49: // Space
            playerModel.playerCoordinator.controller?.switchPlayPause()
        case 123: // Left Arrow
            playerModel.playerCoordinator.controller?.skip(interval: -controlConfig.skipBackwardSeconds)
            toastModel.show(.skip(seconds: -controlConfig.skipBackwardSeconds))
        case 124: // Right Arrow
            playerModel.playerCoordinator.controller?.skip(interval: controlConfig.skipForwardSeconds)
            toastModel.show(.skip(seconds: controlConfig.skipForwardSeconds))
        case 126: // Up Arrow
            let next = min(playerModel.playerCoordinator.playbackRate + controlConfig.macOSPlaybackRateStep, 6.0)
            playerModel.playerCoordinator.playbackRate = next.rounded(to: 2)
            toastModel.show(.playbackRateChanged(num: playerModel.playerCoordinator.playbackRate))
        case 125: // Down Arrow
            let next = max(playerModel.playerCoordinator.playbackRate - controlConfig.macOSPlaybackRateStep, 0.25)
            playerModel.playerCoordinator.playbackRate = next.rounded(to: 2)
            toastModel.show(.playbackRateChanged(num: playerModel.playerCoordinator.playbackRate))
        case 53: // Esc
            if let window = NSApplication.shared.keyWindow,
               window.styleMask.contains(.fullScreen)
            {
                window.toggleFullScreen(nil)
            }
        default:
            break
        }
    }
    #endif
}

#if !os(tvOS) && !os(visionOS)
private struct PlayerLanguagePackCheckWhenAvailableModifier: ViewModifier {
    @ObservedObject var translationRuntime: SubtitleTranslationRuntime
    let mode: SubtitleTranslateMode
    @Binding var showLanguagePackDownloadSheet: Bool
    @Binding var presetPair: (from: String, to: String)?
    @Binding var presetStatus: LanguagePackSheetStatus?
    let isPlaying: Bool
    let pause: () -> Void
    let disableTranslation: (_ reason: String, _ pair: (from: String, to: String)?) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.modifier(
                PlayerLanguagePackCheckModifier(
                    translationRuntime: translationRuntime,
                    mode: mode,
                    showLanguagePackDownloadSheet: $showLanguagePackDownloadSheet,
                    presetPair: $presetPair,
                    presetStatus: $presetStatus,
                    isPlaying: isPlaying,
                    pause: pause,
                    disableTranslation: disableTranslation
                )
            )
        } else {
            content
        }
    }
}

@available(iOS 18.0, macOS 15.0, *)
private struct PlayerLanguagePackCheckModifier: ViewModifier {
    @ObservedObject var translationRuntime: SubtitleTranslationRuntime
    let mode: SubtitleTranslateMode
    @Binding var showLanguagePackDownloadSheet: Bool
    @Binding var presetPair: (from: String, to: String)?
    @Binding var presetStatus: LanguagePackSheetStatus?
    let isPlaying: Bool
    let pause: () -> Void
    let disableTranslation: (_ reason: String, _ pair: (from: String, to: String)?) -> Void

    private var languagePackCheckId: String {
        guard mode.needsTranslation, isPlaying, let pair = translationRuntime.desiredApplePair else {
            return ""
        }
        return "\(pair.from)_\(pair.to)_\(isPlaying)"
    }

    func body(content: Content) -> some View {
        content
            .task(id: languagePackCheckId) {
                guard !languagePackCheckId.isEmpty,
                      !showLanguagePackDownloadSheet,
                      let pair = translationRuntime.desiredApplePair
                else {
                    return
                }

                let sourceLang = Locale.Language(identifier: pair.from)
                let targetLang = Locale.Language(identifier: pair.to)
                let availability = LanguageAvailability()
                let status = await availability.status(from: sourceLang, to: targetLang)

                if status == .unsupported {
                    let currentPair = (from: pair.from, to: pair.to)
                    await MainActor.run {
                        disableTranslation("apple_language_pair_unsupported", currentPair)
                    }
                    presetPair = currentPair
                    presetStatus = .unsupported
                    showLanguagePackDownloadSheet = true
                } else if status != .installed {
                    pause()
                    presetPair = (pair.from, pair.to)
                    presetStatus = .canDownload
                    showLanguagePackDownloadSheet = true
                }
            }
    }
}
#endif
