import CinePlayerSDK
import AVFoundation
import SwiftUI
#if os(iOS)
import UIKit
import AVFAudio
import MediaPlayer
import Combine
#endif

#if os(iOS)
@MainActor
struct ControllerPanelViewIOS: View {
    var geometry: GeometryProxy
    var hasSeparateControls = false
    @State private var scrubPlayback = PlayerScrubPlaybackSession()
    @State private var consoleBrightness: CGFloat = 0.5
    @State private var consoleVolume: CGFloat = 0.5

    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator
    @EnvironmentObject private var playerMaskModel: PlayerMaskModel
    @EnvironmentObject private var playerControlModel: PlayerControlModel
    @EnvironmentObject private var toastModel: PlayerToastModel

    private var config: PlayerControlConfig {
        sessionStore.controlConfig
    }

    private var titleText: String {
        sessionStore.currentSource?.displayName ?? ""
    }

    private var isPad: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }

    private var isPortraitLayout: Bool { geometry.size.height >= geometry.size.width }

    var body: some View {
        Group {
            if hasSeparateControls { separateControls }
            else if isPortraitLayout { portraitLayout }
            else { landscapeLayout }
        }
    }

    private var landscapeLayout: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                PlayerTitleView(title: titleText)
                Spacer()
            }
            .frame(height: 24)

            HStack(spacing: 8) {
                PlayerCloseButton {
                    playerModel.close()
                    sessionStore.close()
                }

                playerControlButtonGroup

                Spacer()

                settingsButtonGroup
            }

            Spacer()

            VStack(spacing: 8) {
                progressSlider

                HStack {
                    playControlButtonGroup
                        .padding(.leading, 8)

                    Spacer()

                    playbackControlButtonGroup
                }
            }
            .padding(.bottom, isPad ? 24 : 0)
        }
        .padding(.horizontal, isPad ? 16 : 0)
        .background { backgroundGradient }
    }

    private var portraitLayout: some View {
        VStack(spacing: 8) {
            PlayerTitleView(title: titleText)
            HStack {
                PlayerCloseButton { playerModel.close(); sessionStore.close() }
                Spacer()
                playerControlButtonGroup
            }.padding(.horizontal, 16)
            Spacer()
            progressSlider
            HStack(spacing: 8) {
                playControlButtonGroup
                Spacer(minLength: 0)
                groupIconButton(icon: "captions.bubble", title: "字幕") {
                    playerControlModel.hideContainer()
                    playerControlModel.showSubtitleContainer = true
                }
                Menu {
                    Button("倍速", systemImage: "barometer") { playerControlModel.hideContainer(); playerControlModel.showPlaybackSpeedContainer = true }
                    Button("音轨", systemImage: "waveform") { playerControlModel.hideContainer(); playerControlModel.showAudioContainer = true }
                    Button("视频轨道", systemImage: "video") { playerControlModel.hideContainer(); playerControlModel.showVideoTrackContainer = true }
                    Button("视频增强", systemImage: "wand.and.rays") { playerControlModel.hideContainer(); playerControlModel.showEnhancementContainer = true }
                    Button("媒体信息", systemImage: "info.circle") { playerControlModel.hideContainer(); playerControlModel.showMediaInfoCard = true }
                    Button("播放设置", systemImage: "gearshape") { playerControlModel.hideContainer(); playerControlModel.showSettingContainer = true }
                } label: {
                    Image(systemName: "ellipsis").frame(width: 44, height: 44).contentShape(Circle())
                }
                .playerControlButtonStyle()
                .accessibilityLabel("更多播放操作")
            }.padding(.horizontal, 16)
        }
        .padding(.bottom, isPad ? 24 : 0)
        .background { backgroundGradient }
    }

    private var separateControls: some View {
        VStack(spacing: 12) {
            HStack {
                PlayerCloseButton { playerModel.close(); sessionStore.close() }
                PlayerTitleView(title: titleText)
                settingsButtonGroup
            }
            HStack(spacing: 12) {
                PlayerConsoleVerticalSlider(value: $consoleBrightness, title: "亮度", icon: "sun.max.fill") {
                    PlatformServices.setScreenBrightness($0)
                }.frame(width: 64)
                VStack(spacing: 16) {
                    Spacer(minLength: 0)
                    playControlButtonGroup
                        .controlSize(.extraLarge)
                    Spacer(minLength: 0)
                    progressSlider
                        .padding(.vertical, 8)
                        .modifier(GlassEffectModifier(cornerRadius: 12, useCapsule: false))
                }
                PlayerConsoleVerticalSlider(value: $consoleVolume, title: "音量", icon: "speaker.wave.2.fill") {
                    MPVolumeView.setVolume(Float($0))
                }.frame(width: 64)
            }
            .frame(maxHeight: .infinity)
            playbackControlButtonGroup
        }
        .padding(12)
        .background(.black)
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .onAppear {
            consoleBrightness = PlatformServices.screenBrightness()
            consoleVolume = CGFloat(AVAudioSession.sharedInstance().outputVolume)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIScreen.brightnessDidChangeNotification)) { _ in
            consoleBrightness = PlatformServices.screenBrightness()
        }
        .onReceive(AVAudioSession.sharedInstance().publisher(for: \.outputVolume).receive(on: RunLoop.main)) {
            consoleVolume = CGFloat($0)
        }
    }

    private var backgroundGradient: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color.black.opacity(0.60), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: isPad ? 240 : 120)

            VStack {
                Spacer()
                LinearGradient(
                    colors: [.clear, Color.black.opacity(0.80)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: isPad ? 240 : 120)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }

    private var progressSlider: some View {
        PlayerSliderView(
            coordinator: playerCoordinator,
            progress: playerCoordinator.progress,
            onProgressEditingChanged: { editing, seconds in
                if editing {
                    playerMaskModel.showMask()
                    playerMaskModel.pauseTimer()
                    scrubPlayback.begin(controller: playerCoordinator.controller)
                } else {
                    playerMaskModel.restartTimer()
                    scrubPlayback.commit(time: TimeInterval(seconds), controller: playerCoordinator.controller)
                }
            }
        )
        .frame(height: 36)
        .padding(.horizontal, 8)
    }

    private var playerControlButtonGroup: some View {
        HStack(spacing: 8) {
            if PlayerController.isPictureInPictureSupported() {
                groupIconButton(
                    icon: playerCoordinator.isPictureInPictureActive
                        ? "pip.exit" : "pip.enter",
                    title: "画中画"
                ) {
                    playerCoordinator.controller?.togglePictureInPicture()
                }
            }

            groupIconButton(
                icon: playerCoordinator.isScaleAspectFill
                    ? "rectangle.arrowtriangle.2.inward"
                    : "rectangle.arrowtriangle.2.outward",
                title: "缩放"
            ) {
                playerCoordinator.isScaleAspectFill.toggle()
            }

            if UIDevice.current.userInterfaceIdiom == .phone {
                groupIconButton(
                    icon: PlatformServices.isIOSPlayerPortraitLock() ? "rotate.right" : "rotate.left",
                    title: "旋转屏幕"
                ) {
                    PlatformServices.toggleIOSPlaybackOrientationLock()
                }
            }
        }
        .padding(.horizontal, 8)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private var settingsButtonGroup: some View {
        HStack(spacing: 8) {
            groupIconButton(icon: "info.circle", title: "媒体信息") {
                playerMaskModel.hideMask()
                playerControlModel.hideContainer()
                playerControlModel.showMediaInfoCard.toggle()
            }

            groupIconButton(icon: "wand.and.rays", title: "视频增强") {
                playerControlModel.hideContainer()
                playerControlModel.showEnhancementContainer = true
            }

            groupIconButton(icon: "gearshape", title: "播放设置") {
                playerControlModel.hideContainer()
                playerControlModel.showSettingContainer = true
            }
        }
        .padding(.horizontal, 8)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private var playbackControlButtonGroup: some View {
        HStack(spacing: 8) {
            speedButton

            groupIconButton(icon: "captions.bubble", title: "字幕") {
                playerControlModel.hideContainer()
                playerControlModel.showSubtitleContainer = true
            }

            if hasMultipleAudioTracks {
                groupIconButton(icon: "waveform", title: "音轨") {
                    playerControlModel.hideContainer()
                    playerControlModel.showAudioContainer = true
                }
            }

            if hasMultipleVideoTracks {
                groupIconButton(icon: "video.fill", title: "视频轨道") {
                    playerControlModel.hideContainer()
                    playerControlModel.showVideoTrackContainer = true
                }
            }
        }
        .padding(.horizontal, 8)
        .modifier(GlassEffectModifier(cornerRadius: 22))
    }

    private var speedButton: some View {
        Button {
            playerControlModel.hideContainer()
            playerControlModel.showPlaybackSpeedContainer = true
        } label: {
            if playerCoordinator.playbackRate == 1.0 {
                Image(systemName: "barometer")
                    .brightness(0.2)
                    .foregroundColor(.white)
                    .font(.system(size: 20, weight: .regular))
                    .frame(width: 44, height: 44)
                    .background(Color.clear)
                    .contentShape(Rectangle())
            } else {
                Text("\(playerCoordinator.playbackRate.playbackRateText)x")
                    .brightness(0.2)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(height: 44)
                    .frame(minWidth: 44)
                    .padding(.horizontal, 8)
                    .contentShape(Rectangle())
            }
        }
        .playerControlButtonStyle()
        .accessibilityLabel("播放速度")
        .accessibilityValue(Text(verbatim: "\(playerCoordinator.playbackRate.playbackRateText)x"))
    }

    private var playControlButtonGroup: some View {
        HStack(spacing: 8) {
            groupIconButton(icon: "gobackward.\(config.skipBackwardSeconds)", title: "后退", useGlass: false) {
                playerCoordinator.controller?.skip(interval: -config.skipBackwardSeconds)
                toastModel.show(.skip(seconds: -config.skipBackwardSeconds))
            }

            groupIconButton(
                icon: playerCoordinator.playbackState == .playing ? "pause.fill" : "play.fill",
                title: playerCoordinator.playbackState == .playing ? "暂停" : "播放",
                useGlass: false,
                font: .system(size: 24, weight: .regular)
            ) {
                playerCoordinator.controller?.togglePlaybackFromControls()
            }

            groupIconButton(icon: "goforward.\(config.skipForwardSeconds)", title: "前进", useGlass: false) {
                playerCoordinator.controller?.skip(interval: config.skipForwardSeconds)
                toastModel.show(.skip(seconds: config.skipForwardSeconds))
            }
        }
    }

    private func groupIconButton(
        icon: String,
        title: LocalizedStringKey,
        useGlass: Bool = false,
        font: Font = .system(size: 20, weight: .regular),
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .brightness(0.2)
                .foregroundColor(.white)
                .font(font)
                .frame(width: 44, height: 44)
                .background(Color.clear)
                .contentShape(Rectangle())
        }
        .playerControlButtonStyle()
        .accessibilityLabel(Text(title))
        .if(useGlass) {
            $0.modifier(GlassEffectModifier(cornerRadius: 22))
        }
    }

    private var hasMultipleAudioTracks: Bool {
        (playerCoordinator.controller?.tracks(mediaType: .audio).count ?? 0) > 1
    }

    private var hasMultipleVideoTracks: Bool {
        (playerCoordinator.controller?.videoTracks.count ?? 0) > 1
    }
}
#endif
