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

    @State private var isPlayerInitializing = true
    @State private var showPlayerError = false
    @State private var playerErrorMessage = "播放错误，请稍后重试"
    @State private var loadingMessage = "初始化中..."
    @State private var brightness: CGFloat = 0.5

    private var controlConfig: PlayerControlConfig {
        sessionStore.controlConfig
    }

    private let mediaInfoMaskOpacity: Double = 0.01

    var body: some View {
        GeometryReader { geometry in
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
                    #if os(macOS)
                    .padding(.horizontal, 16)
                    #endif
                }

                SiderView(geometry: geometry)
                    .environmentObject(sessionStore)
                    .environmentObject(playerControlModel)
                    .environmentObject(playerMaskModel)
                    .environmentObject(playerModel.playerCoordinator)
                    .environmentObject(PlayerSubtitleStyleModel.shared)

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

                if showPlayerError {
                    errorOverlay
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
        }
        .environmentObject(playerMaskModel)
    }

    private func playerSurface(geometry: GeometryProxy) -> some View {
        ZStack {
            CinePlayer(
                coordinator: playerModel.playerCoordinator,
                config: playerModel.config
            )
            .onBufferingStatusChanged { status in
                handleBufferingStatus(status)
            }
            .onNetworkStatusChanged { status in
                handleNetworkStatus(status)
            }
            .onNetworkError { type, message in
                handleNetworkError(type: type, message: message)
            }
            .onError { error in
                handlePlayerError(error.localizedDescription)
            }
            #if os(macOS)
            .onTapGesture(count: 2) {
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
                    playerMaskModel.showMask()
                    playerMaskModel.restartTimer()
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

    private var loadingOverlay: some View {
        VStack(spacing: 10) {
            ProgressView()
                .controlSize(.large)
            Text(loadingMessage)
                .f14m()
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private var errorOverlay: some View {
        VStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
            Text(playerErrorMessage)
                .f14m()
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private func openCurrentSource(resetPlayerState: Bool) {
        guard let source = sessionStore.currentSource else {
            return
        }
        if resetPlayerState {
            isPlayerInitializing = true
            showPlayerError = false
            loadingMessage = "初始化中..."
        }
        playerModel.open(url: source.url)
        remoteCommandService.refreshNowPlayingInfo()
    }

    private func handleBufferingStatus(_ status: BufferState) {
        switch status {
        case .notReady:
            isPlayerInitializing = true
            loadingMessage = "初始化中..."
            showPlayerError = false
        case .buffering:
            isPlayerInitializing = true
            loadingMessage = "缓冲中..."
        case .sufficient, .complete:
            isPlayerInitializing = false
            showPlayerError = false
        case .error:
            handlePlayerError("播放错误，请检查网络或重试")
        @unknown default:
            isPlayerInitializing = false
        }
    }

    private func handleNetworkStatus(_ status: NetworkPlaybackStatus) {
        switch status {
        case .connecting:
            loadingMessage = "正在连接..."
            isPlayerInitializing = true
            toastModel.show(.networkConnecting, duration: .infinity)
        case .buffering:
            loadingMessage = "缓冲中..."
            isPlayerInitializing = true
        case let .retrying(attempt, totalAttempts):
            loadingMessage = "重试中..."
            isPlayerInitializing = true
            toastModel.show(.networkRetrying(attempt: attempt, total: totalAttempts), duration: .infinity)
        case let .switchingURL(currentIndex, totalURLs):
            loadingMessage = "切换线路..."
            isPlayerInitializing = true
            toastModel.show(.networkSwitchingURL(currentIndex: currentIndex, totalURLs: totalURLs), duration: 1.2)
        case .stable:
            isPlayerInitializing = false
            showPlayerError = false
            toastModel.show(.networkStable)
        case let .failed(reason):
            handlePlayerError(reason)
            toastModel.show(.networkError(message: reason), duration: 1.8)
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
        handlePlayerError(text)
        toastModel.show(.networkError(message: text), duration: 2)
    }

    private func handlePlayerError(_ message: String) {
        isPlayerInitializing = false
        showPlayerError = true
        playerErrorMessage = message
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
