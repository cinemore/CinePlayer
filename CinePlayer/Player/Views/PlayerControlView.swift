import CinePlayerSDK
import SwiftUI

#if os(macOS)
import AppKit
#endif

@MainActor
struct PlayerControlView: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel

    @StateObject private var playerControlModel = PlayerControlModel()
    @StateObject private var playerMaskModel = PlayerMaskModel()
    @StateObject private var toastModel = PlayerToastModel()
    @StateObject private var remoteCommandService = PurePlayerRemoteCommandService()

    #if os(macOS)
    @StateObject private var windowController = PlayerWindowController()
    #endif

    @State private var isPlayerInitializing = true
    @State private var brightness: CGFloat = 0.5

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
                                .environmentObject(playerControlModel)
                                .environmentObject(playerMaskModel)
                                .environmentObject(playerModel.playerCoordinator)
                                .environmentObject(playerModel.config.subtitleStyle)

                            if let toast = toastModel.presentedToast {
                                VStack {
                                    PlayerToastView(
                                        toast: toast,
                                        progress: playerModel.playerCoordinator.progress,
                                        playbackRate: playerModel.playerCoordinator.playbackRate,
                                        brightness: brightness
                                    )
                                    Spacer()
                                }
                                .padding(.top, 28)
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
                    ZStack {
                        if isPlayerInitializing {
                            loadingOverlay
                        }

                        if !isPlayerInitializing,
                           let presentedToast = toastModel.presentedToast,
                           case let .networkError(message) = presentedToast
                        {
                            errorOverlay(message: message)
                        }
                    }
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
                    .environmentObject(playerControlModel)
                    .environmentObject(playerMaskModel)
                    .environmentObject(playerModel.playerCoordinator)
                    .environmentObject(playerModel.config.subtitleStyle)

                if let toast = toastModel.presentedToast {
                    VStack {
                        PlayerToastView(
                            toast: toast,
                            progress: playerModel.playerCoordinator.progress,
                            playbackRate: playerModel.playerCoordinator.playbackRate,
                            brightness: brightness
                        )
                        Spacer()
                    }
                    .padding(.top, 28)
                }

                if isPlayerInitializing {
                    loadingOverlay
                }

                if !isPlayerInitializing,
                   let presentedToast = toastModel.presentedToast,
                   case let .networkError(message) = presentedToast
                {
                    errorOverlay(message: message)
                }
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
        #if os(macOS)
        .environmentObject(windowController)
        #endif
    }

    private func playerSurface(geometry: GeometryProxy) -> some View {
        ZStack {
            CinePlayer(
                coordinator: playerModel.playerCoordinator,
                config: playerModel.config
            )
            .onPlaybackStateChanged { status in
                if status == .ready || status == .playing {
                    isPlayerInitializing = false
                }
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
                toastModel.show(.networkError(message: "播放出错，请重试或检查网络"), duration: 1.8)
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
    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
            if let presentedToast = toastModel.presentedToast,
               case let .networkError(message) = presentedToast
            {
                VStack(spacing: 12) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                    Text(message)
                        .f14m()
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(24)
                .modifier(GlassEffectModifier(cornerRadius: 16, useCapsule: false))
            } else {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.large)
                        .tint(.white)
                    Text(loadingOverlayMessage)
                        .f14m()
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .modifier(GlassEffectModifier(cornerRadius: 22, useCapsule: false))
            }
        }
    }

    private var loadingOverlayMessage: String {
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

    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.85)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(32)
            .modifier(GlassEffectModifier(cornerRadius: 16, useCapsule: false))
        }
    }

    private func openCurrentSource(resetPlayerState: Bool) {
        guard let source = sessionStore.currentSource else {
            return
        }
        if resetPlayerState {
            isPlayerInitializing = true
        }
        playerModel.open(url: source.url)
        remoteCommandService.refreshNowPlayingInfo()
    }

    /// 与 cinemore-apple 一致：仅 .error 时 toast，不驱动 isPlayerInitializing / loadingMessage
    private func handleBufferingStatus(_ status: BufferState) {
        if status == .error {
            toastModel.show(.networkError(message: "加载失败"))
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
            toastModel.show(.networkError(message: reason))
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
        toastModel.show(.networkError(message: text), duration: 2)
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
