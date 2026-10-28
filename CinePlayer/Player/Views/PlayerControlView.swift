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
    #if os(tvOS)
        @StateObject private var tvOSPlaybackControlModel = TVOSPlaybackControlModel()
        enum TVOSFocusableView: Hashable {
            case controller
        }
        @FocusState private var tvOSFocusableView: TVOSFocusableView?
    #endif

    #if os(macOS)
        @EnvironmentObject private var windowController: PlayerWindowController
        @StateObject private var macKeyboardFocus = MacPlayerKeyboardFocus()
        /// 是否已经为当前视频应用过一次窗口布局（避免每次 seek / 状态变化都重置用户手动调整过的窗口大小）
        @State private var hasAppliedMacWindowLayout = false
    #endif

    @State private var isPlayerInitializing = true
    @State private var brightness: CGFloat = 0.5
    @State private var didEnsureHistoryRecord = false
    @State private var didRequestHistoryThumbnail = false
    @State private var lastHistoryProgressSecond = -1
    @State private var lastHistoryDurationSecond = -1
    @State private var translationRefreshTask: Task<Void, Never>?
    #if os(visionOS)
        @StateObject private var visionScrubState = PlayerSliderScrubState()
    #endif

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

                                    MediaInfoCardInPlayerView(showMediaInfo: $playerControlModel.showMediaInfoCard)
                                        .environmentObject(playerModel)
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

                                // macOS: 顶部 toast 独立于 mask 显示，保持与顶部控制栏同一高度
                                if !isLoadingOrErrorOverlayVisible,
                                    let toast = toastModel.presentedToast
                                {
                                    VStack {
                                        PlayerToastView(
                                            toast: toast,
                                            progress: playerModel.playerCoordinator.progress,
                                            playbackRate: playerModel.playerCoordinator
                                                .playbackRate,
                                            brightness: brightness
                                        )
                                        .frame(height: 44)
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
                        remoteCommandService.activate(
                            sessionStore: sessionStore, playerModel: playerModel)
                        let windowCount = NSApp.windows.count
                        let visibleCount = NSApp.windows.filter { $0.isVisible }.count
                        cinemoreLog(
                            level: .debug,
                            "[WindowDebug] PlayerControlView.onAppear currentSource=\(sessionStore.currentSource != nil) windows=\(windowCount) visible=\(visibleCount)"
                        )
                        DispatchQueue.main.async {
                            windowController.attachToKeyWindowIfNeeded()
                            PlatformServices.setMacTrafficLightsHidden(true)
                            // 确保用于播放的窗口在视图出现时可见且前置（与 SwiftUI 场景切换解耦）。
                            let windows = NSApp.windows
                            let target =
                                NSApp.keyWindow
                                ?? NSApp.mainWindow
                                ?? windows.first(where: { $0.isVisible })
                                ?? windows.first(where: { $0.contentView != nil })

                            if let window = target {
                                if !window.isVisible {
                                    window.orderFrontRegardless()
                                }
                                if !window.isKeyWindow {
                                    window.makeKeyAndOrderFront(nil)
                                }
                            }

                            let afterVisible = NSApp.windows.filter { $0.isVisible }.count
                            cinemoreLog(
                                level: .debug,
                                "[WindowDebug] PlayerControlView.ensureVisible currentSource=\(sessionStore.currentSource != nil) windows=\(windows.count) visibleAfter=\(afterVisible)"
                            )
                        }
                    }
                    .onDisappear {
                        let windowCount = NSApp.windows.count
                        let visibleCount = NSApp.windows.filter { $0.isVisible }.count
                        cinemoreLog(
                            level: .debug,
                            "[WindowDebug] PlayerControlView.onDisappear currentSource=\(sessionStore.currentSource != nil) windows=\(windowCount) visible=\(visibleCount)"
                        )
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
                // 视频与控制层共用稳定身份，折叠设备由系统分配两个区域。
                playerSurface(geometry: geometry)
                    .modifier(PlayerArrangementModifier { hasSeparateControls in
                        GeometryReader { geometry in
                            ZStack {

                    #if !os(visionOS)
                    if playerMaskModel.isMaskShow || hasSeparateControls {
                        controlOverlay(geometry: geometry, hasSeparateControls: hasSeparateControls)
                            .transition(.opacity)
                    }

                    if playerControlModel.showMediaInfoCard {
                        Color.black.opacity(mediaInfoMaskOpacity)
                            .ignoresSafeArea()
                            .onTapGesture {
                                playerControlModel.showMediaInfoCard = false
                                playerMaskModel.showMask()
                            }

                        MediaInfoCardInPlayerView(showMediaInfo: $playerControlModel.showMediaInfoCard)
                                        .environmentObject(playerModel)
                        .environmentObject(playerModel.playerCoordinator)
                    }

                    #if !os(tvOS)
                    SiderView(geometry: geometry)
                        .environmentObject(sessionStore)
                        .environmentObject(playerModel)
                        .environmentObject(playerControlModel)
                        .environmentObject(playerMaskModel)
                        .environmentObject(playerModel.playerCoordinator)
                        .environmentObject(playerModel.config.subtitleStyle)
                    #endif
                    #endif

                    if !isLoadingOrErrorOverlayVisible,
                        toastModel.showContainer,
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
                        .padding(
                            .top,
                            {
                                #if os(iOS)
                                    // 竖屏模式下顶部 toast 额外向下偏移，避免贴近状态栏 / 刘海
                                    return geometry.size.height > geometry.size.width ? 44 : 28
                                #elseif os(tvOS)
                                    return PlayerToastLayout.topInset
                                #else
                                    return 28
                                #endif
                            }()
                        )
                        .ignoresSafeArea(edges: .top)
                    }

                    loadingOrErrorOverlay
                            }
                        }
                    })
                    #if os(visionOS)
                    .modifier(VisionPlayerPresentation(geometry: geometry, sessionStore: sessionStore,
                        playerModel: playerModel, controls: playerControlModel, mask: playerMaskModel, toast: toastModel,
                        scrubState: visionScrubState, isInitializing: isPlayerInitializing))
                    #endif
                .background(.black)
                .onAppear {
                    brightness = PlatformServices.screenBrightness(default: brightness)
                    openCurrentSource(resetPlayerState: true)
                    remoteCommandService.activate(
                        sessionStore: sessionStore, playerModel: playerModel)
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
        #if os(tvOS)
            .compatibleOnChange(of: playerMaskModel.isMaskShow) { newValue in
                if !newValue {
                    // 控件面板隐藏后把焦点还给 GestureController，方便用户再次用遥控唤起
                    tvOSFocusableView = .controller
                }
            }
            .onExitCommand {
                tvOSPlaybackControlModel.handleExitCommand(
                    controls: playerControlModel, mask: playerMaskModel,
                    coordinator: playerModel.playerCoordinator
                ) {
                    playerModel.close()
                    sessionStore.close()
                }
            }
        #endif
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
                .modifier(PlayerPresentationAppearance())
            }
        #endif
        .compatibleOnChange(of: sessionStore.controlConfig) { oldValue, newValue in
            if oldValue.systemAudioPathEnabled != newValue.systemAudioPathEnabled {
                playerModel.applySystemAudioPathPreferenceToActivePlayer(newValue.systemAudioPathEnabled)
            }
            if oldValue.subtitleTranslateMode != newValue.subtitleTranslateMode
                || oldValue.subtitleTranslationTargetLanguage != newValue.subtitleTranslationTargetLanguage
                || oldValue.subtitleTranslationOnTop != newValue.subtitleTranslationOnTop {
                handleSubtitleTranslateModeChange(newValue.subtitleTranslateMode)
            }
        }
        .onDisappear {
            translationRefreshTask?.cancel()
            playerControlModel.cancelSubtitleLoad()
        }
        .compatibleOnChange(of: playerModel.playerCoordinator.videoTrack?.streamIndex) { _ in
            playerModel.refreshEnhancementForSelectedVideoTrack()
        }
        .compatibleOnChange(of: playerControlModel.showMediaInfoCard) { shown in
            #if !os(visionOS)
            if shown { playerMaskModel.hideMask() } else { playerMaskModel.showMask() }
            #endif
        }
        .environment(\.usesPlayerPanelTypography, true)
        .environment(\.usesVisionPlayerTypography, true)
        .overlay(alignment: .topLeading) {
            if playerModel.isPlaybackInfoPinned {
                PlayerPlaybackInfoHUD(coordinator: playerModel.playerCoordinator)
            }
        }
        // Keep the shared macOS window and its main app pages on their own appearance.
        .environment(\.colorScheme, .dark)
        #if os(macOS)
            .modifier(MacPlayerKeyboardFocusObserver(focus: macKeyboardFocus))
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
                        #if os(visionOS)
                        if isPlayerInitializing { playerMaskModel.showMask() }
                        #endif
                        isPlayerInitializing = false
                        let playbackTime =
                            playerModel.playerCoordinator.controller?.currentPlaybackTime
                            ?? Double(playerModel.playerCoordinator.progress.currentTime)
                        handleHistoryRecordCreationIfNeeded(currentTime: playbackTime)
                        #if os(macOS)
                            // 只在当前视频第一次 ready / playing 时根据视频尺寸调整窗口，
                            // 后续 seek 或状态切换不再修改用户手动调整过的窗口大小
                            if !hasAppliedMacWindowLayout {
                                if let controller = playerModel.playerCoordinator.controller,
                                   let window = windowController.playbackWindow
                                {
                                    let size = controller.videoNaturalSize
                                    if size.width > 0, size.height > 0 {
                                        hasAppliedMacWindowLayout = true
                                        DispatchQueue.main.async {
                                            PlatformServices.configureMacPlayerWindowForVideo(
                                                naturalSize: size, window: window)
                                        }
                                    }
                                }
                            }
                        #endif

                        if status == .ready {
                            playerModel.refreshEnhancementCapabilities()
                            handleHistoryThumbnailIfNeededOnReady()
                        }
                    }
                }
                .onTimeChanged { progress in
                    handleHistoryRecordCreationIfNeeded(
                        currentTime: TimeInterval(progress.currentTime)
                    )
                    handleHistoryProgressUpdate(
                        currentTime: TimeInterval(progress.currentTime)
                    )
                    if !didRequestHistoryThumbnail {
                        handleHistoryThumbnailIfNeededOnReady()
                    }
                    #if os(tvOS)
                        // 面板显示时，.focused(equals: .controller) 所在的 GestureController
                        // 已从视图树移除；此时若继续把焦点写回 .controller，会使面板按钮失焦，
                        // 导致 Menu 键绕过 .onExitCommand 被系统默认行为接管，把播放器整个关掉。
                        if !playerMaskModel.isMaskShow,
                           tvOSFocusableView != .controller
                        {
                            tvOSFocusableView = .controller
                        }
                    #endif
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
                #if os(macOS) || os(visionOS)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("显示播放控制")
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { playerMaskModel.disableAutoHide() }
                #endif
                #if os(macOS)
                    .onTapGesture(count: 2) {
                        // 如果窗口处于悬浮锁定状态，先恢复为普通层级
                        if windowController.isFloating {
                            windowController.toggleWindowLevel()
                        }

                        windowController.playbackWindow?.toggleFullScreen(nil)
                    }
                #endif
                #if os(visionOS)
                .onTapGesture {
                    guard !isPlayerInitializing else { return }
                    playerControlModel.showPlaybackSpeedContainer = false
                    playerMaskModel.toggleMask()
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
                // 面板显示时把 GestureController 从视图树里移除，避免它与面板里的
                // Button / ProgressSlider 同时可聚焦，导致面板元素拿不到焦点、
                // .onExitCommand 里 "isMaskShow → hideMask" 分支被绕过（菜单键
                // 被外层 fullScreenCover 的系统默认行为接管，直接关掉播放器）。
                if !playerMaskModel.isMaskShow {
                    GestureController()
                        .environmentObject(sessionStore)
                        .environmentObject(playerModel.playerCoordinator)
                        .environmentObject(playerMaskModel)
                        .environmentObject(toastModel)
                        .environmentObject(tvOSPlaybackControlModel)
                        .contentShape(Rectangle())
                        .focused($tvOSFocusableView, equals: .controller)
                        .onAppear {
                            tvOSFocusableView = .controller
                            // 从带 TextField 焦点的入口（首页 URL 输入框）进入时，
                            // tvOS 焦点引擎可能来不及把焦点切到 GestureViewTVOS，
                            // 延迟一帧再补一次赋值作为保险。
                            Task { @MainActor in
                                try? await Task.sleep(for: .milliseconds(50))
                                tvOSFocusableView = .controller
                            }
                        }
                        .ignoresSafeArea()
                }
            #endif

            #if os(macOS)
                MacInteractionLayer(
                    onMouseMoved: {
                        // 与 cinemore-apple 一致：侧边面板或媒体信息卡片打开时，滑动鼠标不显示主控件
                        if !playerControlModel.isSiderContainerShow,
                            !playerControlModel.showMediaInfoCard
                        {
                            playerMaskModel.showMask()
                        }
                    },
                    onKeyDown: { event in handleMacKeyDown(event) },
                    keyboardFocus: macKeyboardFocus,
                    onWindowAttached: { window in windowController.attach(to: window) }
                )
                .ignoresSafeArea()
            #endif
        }
    }

    private func controlOverlay(geometry: GeometryProxy, hasSeparateControls: Bool = false) -> some View {
        platformPanel(geometry: geometry, hasSeparateControls: hasSeparateControls)
            .environmentObject(sessionStore)
            .environmentObject(playerModel)
            .environmentObject(playerModel.playerCoordinator)
            .environmentObject(playerMaskModel)
            .environmentObject(playerControlModel)
            .environmentObject(toastModel)
            #if os(tvOS)
                .environmentObject(tvOSPlaybackControlModel)
                // 面板显示且焦点在面板内部时，把 Menu 键拦在这里处理：
                // 先取消正在进行的 seek；否则收起面板，而不是让外层 fullScreenCover
                // 走系统默认的 "dismiss modal" 把整个播放器关掉。
                .onExitCommand {
                    if tvOSPlaybackControlModel.isSeeking {
                        tvOSPlaybackControlModel.cancelSeeking(
                            progress: playerModel.playerCoordinator.progress
                        ) {
                            playerModel.playerCoordinator.controller?.play()
                        }
                        return
                    }
                    playerMaskModel.enableAutoHide()
                    playerMaskModel.hideMask()
                }
            #endif
    }

    @ViewBuilder
    private func platformPanel(geometry: GeometryProxy, hasSeparateControls: Bool = false) -> some View {
        #if os(iOS)
            ControllerPanelViewIOS(geometry: geometry, hasSeparateControls: hasSeparateControls)
        #elseif os(macOS)
            ControllerPanelViewMacOS(geometry: geometry)
        #elseif os(tvOS)
            ControllerPanelViewTvOS(geometry: geometry)
        #elseif os(visionOS)
            ControllerPanelViewVision(scrubState: visionScrubState, isInitializing: isPlayerInitializing)
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
                case .networkError(let msg) = toast
            else { return nil }
            return msg
        }()
        if isLoadingOrErrorOverlayVisible {
            ZStack {
                if let message = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(.red)
                        Text(LocalizedStringKey(message))
                            .font(.headline)
                            .foregroundStyle(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(32)
                    .modifier(LoadingOverlayBackground(cornerRadius: 16))
                } else if showLoading {
                    VStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                        Text(loadingOrErrorOverlayMessage)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 16)
                    .modifier(LoadingOverlayBackground(cornerRadius: 22))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    private var loadingOrErrorOverlayMessage: LocalizedStringKey {
        guard let toast = toastModel.presentedToast else { return "初始化中..." }
        switch toast {
        case .networkConnecting:
            return "正在连接..."
        case .networkRetrying(let attempt, let total):
            return "重试中 (\(attempt)/\(total))"
        case .networkSwitchingURL(let currentIndex, let totalURLs):
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
            #if os(tvOS)
            _ = tvOSPlaybackControlModel.finishSeeking()
            #endif
            translationRefreshTask?.cancel()
            playerControlModel.cancelSubtitleLoad()
            playerControlModel.currentSubtitlePath = ""
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

        guard currentSecond != lastHistoryProgressSecond || totalSecond != lastHistoryDurationSecond
        else {
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

        let duration = max(
            controller.duration, Double(playerModel.playerCoordinator.progress.totalTime))
        guard duration > 0 else {
            return
        }

        didRequestHistoryThumbnail = true
        let captureTime = duration / 2
        let targetSize = CGSize(width: 320, height: 180)
        let mediaID = controller.mediaIdentifier

        Task { @MainActor in
            let result = await controller.requestScrubThumbnail(
                    time: captureTime,
                    targetPointSize: targetSize,
                    scale: 1
                )
            guard controller.mediaIdentifier == mediaID, sessionStore.currentSource?.id == source.id else { return }
            guard let result else {
                // 本次抓取失败（可能缩略图会话尚未就绪），允许后续 onTimeChanged 重试
                didRequestHistoryThumbnail = false
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
        translationRefreshTask?.cancel()
        let settings = sessionStore.controlConfig
        let controller = playerModel.playerCoordinator.controller
        let mediaID = controller?.mediaIdentifier
        translationRefreshTask = Task { @MainActor in
            await playerModel.applySubtitleTranslationSettings(settings)
            guard !Task.isCancelled, controller?.mediaIdentifier == mediaID,
                  sessionStore.controlConfig == settings else { return }
            await controller?.setSubtitleTranslationMode(mode)
            guard !Task.isCancelled, controller?.mediaIdentifier == mediaID else { return }
            if let controller {
                controller.seek(time: max(controller.currentPlaybackTime - 2, 0), playbackBehavior: .restorePreviousState)
            }
        }
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
                    let status = await AppleTranslationLanguageSupport.availabilityStatus(
                        from: pair.from,
                        to: pair.to
                    )
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
                            playerModel.translationRuntime.languageAvailabilityRevision &+= 1
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
        case .retrying(let attempt, let totalAttempts):
            toastModel.show(
                .networkRetrying(attempt: attempt, total: totalAttempts), duration: .infinity)
        case .switchingURL(let currentIndex, let totalURLs):
            toastModel.show(
                .networkSwitchingURL(currentIndex: currentIndex, totalURLs: totalURLs),
                duration: .infinity)
        case .stable:
            toastModel.show(.networkStable, duration: 1.0)
        case .failed(let reason):
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
            fallbackMessage = String(localized: "网络超时，请稍后重试")
        case .connectionRefused:
            fallbackMessage = String(localized: "连接被拒绝，请检查线路")
        case .dnsResolution:
            fallbackMessage = String(localized: "域名解析失败，请检查网络")
        case .httpClientError:
            fallbackMessage = String(localized: "请求异常，请稍后重试")
        case .httpServerError:
            fallbackMessage = String(localized: "服务器异常，请稍后重试")
        case .networkUnreachable:
            fallbackMessage = String(localized: "当前网络不可用")
        case .temporaryFailure:
            fallbackMessage = String(localized: "网络波动，正在重试")
        case .permanentFailure:
            fallbackMessage = String(localized: "播放失败，请更换线路")
        case .unknown:
            fallbackMessage = String(localized: "发生未知网络错误")
        @unknown default:
            fallbackMessage = String(localized: "发生网络错误")
        }

        let text = message.isEmpty ? fallbackMessage : message
        isPlayerInitializing = false
        toastModel.show(.networkError(message: text), duration: .infinity)
    }

    #if os(macOS)
        private func handleMacKeyDown(_ event: NSEvent) -> Bool {
            guard event.window === windowController.playbackWindow else { return false }
            let coordinator = playerModel.playerCoordinator
            switch event.keyCode {
            case 49:
                coordinator.controller?.togglePlaybackFromControls()
            case 123:
                coordinator.controller?.skip(interval: -controlConfig.skipBackwardSeconds)
                toastModel.show(.skip(seconds: -controlConfig.skipBackwardSeconds))
            case 124:
                coordinator.controller?.skip(interval: controlConfig.skipForwardSeconds)
                toastModel.show(.skip(seconds: controlConfig.skipForwardSeconds))
            case 126:
                let step: Float = coordinator.playbackRate >= 2 ? 1 : controlConfig.macOSPlaybackRateStep
                coordinator.playbackRate = min(6, coordinator.playbackRate + step).rounded(to: 2)
                toastModel.show(.playbackRateChanged(num: coordinator.playbackRate))
            case 125:
                let step: Float = coordinator.playbackRate > 2 ? 1 : controlConfig.macOSPlaybackRateStep
                coordinator.playbackRate = max(0.25, coordinator.playbackRate - step).rounded(to: 2)
                toastModel.show(.playbackRateChanged(num: coordinator.playbackRate))
            case 53:
                guard let window = event.window, window.styleMask.contains(.fullScreen) else { return false }
                window.toggleFullScreen(nil)
            default: return false
            }
            return true
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
            guard mode.needsTranslation, isPlaying, let pair = translationRuntime.desiredApplePair
            else {
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

                    let status = await AppleTranslationLanguageSupport.availabilityStatus(
                        from: pair.from,
                        to: pair.to
                    )

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
