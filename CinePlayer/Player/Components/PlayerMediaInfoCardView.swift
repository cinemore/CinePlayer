import CinePlayerSDK
import AVFoundation
import SwiftUI

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

struct MediaInfoCardInPlayerView: View {
    @EnvironmentObject private var playerModel: VideoPlayerModel
    @EnvironmentObject var playerCoordinator: CinePlayer.Coordinator
    @Environment(\.accessibilityReduceMotion) var reduceMotion

    @Binding var showMediaInfo: Bool

    var body: some View {
        ZStack {
            Color.black
                .opacity(showMediaInfo ? 0.01 : 0)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8)) {
                        showMediaInfo = false
                    }
                }
                .allowsHitTesting(showMediaInfo)

            if let controller = playerCoordinator.controller, controller.playerInfo != nil {
                PlayerMediaInfoCardView(
                    controller: controller,
                    isPresented: $showMediaInfo,
                    isPlaybackInfoPinned: $playerModel.isPlaybackInfoPinned
                )
                .opacity(showMediaInfo ? 1 : 0)
                .scaleEffect(showMediaInfo ? 1 : 0.9)
                .offset(y: showMediaInfo ? 0 : 20)
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.8), value: showMediaInfo
        )
        .zIndex(showMediaInfo ? 1 : 0)
        .allowsHitTesting(showMediaInfo)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
/// 媒体信息卡片，显示视频和音频的详细信息
struct PlayerMediaInfoCardView: View {
    @ObservedObject var controller: PlayerController
    @ObservedObject private var playerInfo: PlayerInfo
    @Binding var isPresented: Bool
    @Binding var isPlaybackInfoPinned: Bool

    private let mediaInfoCardMinWidth: CGFloat = 240
    private var contentInset: CGFloat {
        PlayerPlatform.deviceType == .tv ? 48 : 24
    }

    private let closeButtonDiameter: CGFloat = 40

    private var keepsIntrinsicFieldWidth: Bool {
        #if os(visionOS)
            false
        #else
            true
        #endif
    }

    /// 用于区分不同平台的初始化器
    init(controller: PlayerController, isPresented: Binding<Bool> = .constant(true), isPlaybackInfoPinned: Binding<Bool> = .constant(false)) {
        self.controller = controller
        _playerInfo = ObservedObject(wrappedValue: controller.playerInfo!)
        _isPresented = isPresented
        _isPlaybackInfoPinned = isPlaybackInfoPinned
    }

    var body: some View {
        #if os(visionOS)
            visionTrackColumns
        #else
            ZStack(alignment: .topTrailing) {
                trackSections

                // 关闭按钮
                #if !os(tvOS)
                    HStack {
                        #if os(iOS) || os(macOS) || os(visionOS)
                            Toggle("固定", isOn: $isPlaybackInfoPinned)
                                .toggleStyle(.switch)
                                .fixedSize()
                                .accessibilityIdentifier("player.infoHUD.pin")
                            Spacer()
                        #endif
                        GlassControlButton(
                            icon: "xmark",
                            accessibilityLabel: "关闭",
                            diameter: closeButtonDiameter
                        ) {
                            isPresented = false
                        }
                    }
                    .padding(contentInset)
                #endif
            }
            #if os(iOS)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
            }
            #elseif os(tvOS)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            #else
            .frame(maxWidth: 900, maxHeight: 500)
            .frame(minWidth: 400, minHeight: 200)
            .background(.regularMaterial)
            .roundedCorner(AppCornerRadius.featureEntry)
            .overlay {
                RoundedRectangle(cornerRadius: AppCornerRadius.featureEntry)
                    .strokeBorder(lineWidth: 1)
                    .foregroundStyle(.quaternary)
            }
            #endif
        #endif
    }

    #if os(visionOS)
        /// 空间布局只调整容器，轨道字段与实时元数据继续复用下方实现。
        private var visionTrackColumns: some View {
            VStack(alignment: .leading, spacing: 12) {
                Toggle("固定", isOn: $isPlaybackInfoPinned)
                    .toggleStyle(.switch)
                    .fixedSize()
                    .accessibilityIdentifier("player.infoHUD.pin")
                    .padding(contentInset)
                    .glassBackgroundEffect()

                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 24) {
                        ForEach(controller.videoTracks, id: \.streamIndex) { video in
                            visionTrackCard { videoSection(video: video, showsTrackTitle: true) }
                        }
                        ForEach(controller.tracks(mediaType: .audio), id: \.streamIndex) { audio in
                            visionTrackCard { audioSection(audio: audio) }
                        }
                        ForEach(controller.coverTracks, id: \.streamIndex) { cover in
                            visionTrackCard { coverSection(cover: cover) }
                        }
                        ForEach(controller.subtitleTracks, id: \.streamIndex) { subtitle in
                            visionTrackCard { subtitleSection(subtitle: subtitle) }
                        }
                    }
                }
                .scrollClipDisabled()
                .frame(height: 420)
            }
        }

        private func visionTrackCard(@ViewBuilder content: () -> some View) -> some View {
            ScrollView(.vertical) {
                content()
                    .padding(.vertical, contentInset)
            }
            // 横向采用内容理想宽度；较长技术字段仍受上限约束并换行。
            .frame(minWidth: mediaInfoCardMinWidth, maxWidth: 560)
            .fixedSize(horizontal: true, vertical: false)
            .frame(height: 420)
            .glassBackgroundEffect()
        }
    #endif

    private var trackSections: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // 所有视频轨道信息
                if !controller.videoTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("视频轨道")
                            .playerMediaInfoHeadingFont()
                            .foregroundColor(.white)
                            .padding(.leading, contentInset)
                        ForEach(controller.videoTracks, id: \.streamIndex) { video in
                            videoSection(
                                video: video,
                                showsTrackTitle: controller.videoTracks.count > 1
                            )
                        }
                    }
                }

                // 所有音频轨道信息
                let audioTracks = controller.tracks(mediaType: .audio)
                if !audioTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("音频轨道")
                            .playerMediaInfoHeadingFont()
                            .foregroundColor(.white)
                            .padding(.leading, contentInset)

                        ScrollView(.horizontal, showsIndicators: PlayerPlatform.deviceType == .mac) {
                            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                                GridRow(alignment: .top) {
                                    ForEach(audioTracks, id: \.streamIndex) { audio in
                                        audioSection(audio: audio)
                                            .applyFocusable(PlayerPlatform.deviceType == .tv)
                                            .padding(.trailing)
                                    }
                                }
                            }
                            .padding(.horizontal, contentInset)
                        }
                    }
                }

                // 所有封面图片轨道信息
                if !controller.coverTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("封面轨道")
                            .playerMediaInfoHeadingFont()
                            .foregroundColor(.white)
                            .padding(.leading, contentInset)

                        ScrollView(.horizontal, showsIndicators: PlayerPlatform.deviceType == .mac) {
                            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                                GridRow(alignment: .top) {
                                    ForEach(controller.coverTracks, id: \.streamIndex) { cover in
                                        coverSection(cover: cover)
                                            .applyFocusable(PlayerPlatform.deviceType == .tv)
                                            .padding(.trailing)
                                    }
                                }
                            }
                            .padding(.horizontal, contentInset)
                        }
                    }
                }

                // 所有字幕轨道信息
                if !controller.subtitleTracks.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("字幕轨道")
                            .playerMediaInfoHeadingFont()
                            .foregroundColor(.white)
                            .padding(.leading, contentInset)

                        ScrollView(.horizontal, showsIndicators: PlayerPlatform.deviceType == .mac) {
                            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                                GridRow(alignment: .top) {
                                    ForEach(controller.subtitleTracks, id: \.streamIndex) { subtitle in
                                        subtitleSection(subtitle: subtitle)
                                            .applyFocusable(PlayerPlatform.deviceType == .tv)
                                            .padding(.trailing)
                                    }
                                }
                            }
                            .padding(.horizontal, contentInset)
                        }
                    }
                }
            }
            .padding(.vertical, contentInset)
            #if os(tvOS)
                .frame(maxWidth: .infinity, alignment: .leading)
                .focusSection()
            #endif
            #if !os(tvOS)
            // 首屏内容避开悬浮关闭按钮，滚动时仍可经过按钮下方。
            .padding(.top, closeButtonDiameter + contentInset)
            #endif
        }
    }

    private func videoSection(
        video: FFmpegStreamAsset,
        showsTrackTitle: Bool
    ) -> some View {
        let liveStaticMetadata = playerInfo.hdrStaticMetadata
        let staticMetadata = liveStaticMetadata?.streamIndex == video.streamIndex
            ? liveStaticMetadata?.metadata
            : video.hdrStaticMetadata
        let snapshot = playerInfo.videoPlaybackSnapshot
        let playbackSnapshot = video.isEnabled && snapshot?.streamIndex == video.streamIndex
            ? snapshot
            : nil

        return VStack(alignment: .leading, spacing: 10) {
            if showsTrackTitle {
                HStack(spacing: 8) {
                    Text("视频 #\(video.streamIndex)")
                        .playerMediaInfoHeadingFont()
                        .foregroundColor(.white)

                    if video.isEnabled {
                        Text("(当前)")
                            .playerMediaInfoDetailFont()
                            .foregroundColor(.green)
                    }
                }
                .padding(.horizontal, contentInset)
            }

            videoGroupsLayout {
                mediaInfoGroup(title: "Stream", icon: "film.fill") {
                    videoInfoRow(label: "编码", value: video.codecName)
                    if let profileVal = video.profileName {
                        videoInfoRow(label: "Profile", value: String(profileVal))
                    }
                    videoInfoRow(
                        label: "分辨率",
                        value: "\(Int(video.naturalSize.width))×\(Int(video.naturalSize.height))"
                    )
                    videoInfoRow(label: "帧率", value: String(format: "%.3f", video.nominalFrameRate))
                    if video.trackDuration > 0 {
                        videoInfoRow(label: "轨道时长", value: formatDuration(seconds: video.trackDuration))
                    }
                    videoInfoRow(label: "比特率", value: formatBitrate(Int(video.bitRate)))
                    if let playbackSnapshot {
                        videoInfoRow(label: "Decoder", value: playbackSnapshot.decoder)
                        videoInfoRow(label: "实时码率", value: formatBitrate(playbackSnapshot.bitrate))
                        videoInfoRow(label: "缓冲", value: String(format: "%.2f s", playbackSnapshot.bufferedDuration))
                        videoInfoRow(label: "Packet Queue", value: "\(playbackSnapshot.packetCount)")
                        videoInfoRow(
                            label: "Frame Queue",
                            value: "\(playbackSnapshot.frameCount) / \(playbackSnapshot.frameCapacity)"
                        )
                    }
                }

                mediaInfoGroup(title: "Video Signal", icon: "waveform") {
                    videoInfoRow(label: "动态范围", value: video.dynamicRange.description)
                    if let color = video.colorPrimaries {
                        videoInfoRow(label: "基色", value: color)
                    }
                    if let transfer = video.transferFunction {
                        videoInfoRow(label: "色调映射", value: transfer)
                    }
                    if let matrix = video.yCbCrMatrix {
                        videoInfoRow(label: "色彩矩阵", value: matrix)
                    }
                    videoInfoRow(label: "位深度", value: "\(video.bitDepth) bit")
                    if let formatName = video.formatName {
                        videoInfoRow(label: "像素格式", value: formatName)
                    }
                    if video.fullRange {
                        videoInfoRow(label: "范围", value: String(localized: "Full"))
                    } else {
                        videoInfoRow(label: "范围", value: String(localized: "Limited"))
                    }
                    if isInterlacedScanType(video.fieldOrder) {
                        videoInfoRow(label: "扫描类型", value: String(localized: "隔行扫描 (交错)"))
                    }
                    if let scanOrder = scanOrderText(for: video.fieldOrder) {
                        localizedVideoInfoRow(label: "扫描顺序", value: scanOrder)
                    }
                }

                if let config = video.dolbyVisionConfig {
                    dolbyVisionGroup(
                        config: config,
                        streamIndex: video.streamIndex,
                        usesSeparateEnhancementLayerTrack: video.isDualTrackDolbyVision,
                        baseLayerHDRStaticMetadata: staticMetadata
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func videoGroupsLayout(@ViewBuilder content: () -> some View) -> some View {
        #if os(visionOS)
            VStack(alignment: .leading, spacing: 12, content: content)
        #else
            ScrollView(.horizontal, showsIndicators: PlayerPlatform.deviceType == .mac) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow(alignment: .top, content: content)
                }
                .padding(.horizontal, contentInset)
                .padding(.vertical, 4)
            }
        #endif
    }

    @ViewBuilder
    private func dolbyVisionGroup(
        config: DolbyVisionConfig,
        streamIndex: Int32,
        usesSeparateEnhancementLayerTrack: Bool,
        baseLayerHDRStaticMetadata: HDRStaticMetadata?
    ) -> some View {
        let rpuMetadata = playerInfo.dolbyVisionRPUMetadata?.streamIndex == streamIndex
            ? playerInfo.dolbyVisionRPUMetadata?.metadata
            : nil

        mediaInfoGroup(title: "Dolby Vision", icon: "sparkles") {
            if let metadata = rpuMetadata,
               let contentMappingVersion = metadata.contentMappingVersion
            {
                videoInfoRow(label: "Metadata", value: contentMappingText(metadata, version: contentMappingVersion))
            }
            if !config.codecTag.isEmpty {
                videoInfoRow(
                    label: "Codec",
                    value: "\(config.codecTag).\(config.profile).\(config.level)"
                )
            }
            videoInfoRow(label: "DOVI Version", value: config.version)
            videoInfoRow(label: "Source Profile", value: config.profileString)
            videoInfoRow(label: "DOVI Level", value: "\(config.level)")
            videoInfoRow(label: "Compatibility ID", value: "\(config.compatibilityId)")
            if config.isLayeredProfile7 {
                videoInfoRow(
                    label: "Layer Layout",
                    value: usesSeparateEnhancementLayerTrack ? "DT-DL" : "ST-DL"
                )
            }
            videoPresenceRow(label: "RPU", isPresent: config.layers.contains("RPU"))
            videoPresenceRow(label: "BL", isPresent: config.layers.contains("BL"))
            videoPresenceRow(label: "EL", isPresent: config.layers.contains("EL"))
            if let type = rpuMetadata?.enhancementLayerType {
                videoInfoRow(label: "EL Type", value: type.uppercased())
            } else if !config.layers.contains("EL") {
                videoInfoRow(label: "EL Type", value: "—")
            }
        }

        if let rpuMetadata {
            rpuMetadataGroup(rpuMetadata, baseLayerHDRStaticMetadata: baseLayerHDRStaticMetadata)
        }
    }

    private func contentMappingText(_ metadata: DolbyVisionRPUMetadata, version: String) -> String {
        guard let level2Count = metadata.level2Count, level2Count > 0 else {
            return version
        }
        return "\(version) · L2 × \(level2Count)"
    }

    private func videoPresenceRow(label: LocalizedStringKey, isPresent: Bool) -> some View {
        GridRow(alignment: .top) {
            Text("\(Text(label)):")
                .foregroundColor(.white.opacity(0.68))
                .playerMediaInfoDetailFont()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Image(systemName: isPresent ? "checkmark.circle.fill" : "minus.circle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isPresent ? Color.mint : Color.gray)
                .accessibilityValue(isPresent ? Text("Present") : Text("Absent"))
        }
    }

    private func mediaInfoGroup(
        title: LocalizedStringKey,
        icon: String? = nil,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .foregroundColor(.white)
            .playerMediaInfoDetailFont(weight: .semibold)
            .padding(.bottom, 10)
            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 7) {
                content()
            }
        }
        .padding()
        #if !os(visionOS)
            .fixedSize(horizontal: true, vertical: false)
            .frame(minWidth: mediaInfoCardMinWidth, alignment: .leading)
            .frame(maxHeight: .infinity, alignment: .top)
            .background(groupBackground)
            .applyFocusable(PlayerPlatform.deviceType == .tv)
            .padding(.trailing)
        #endif
    }

    private func rpuMetadataGroup(
        _ metadata: DolbyVisionRPUMetadata,
        baseLayerHDRStaticMetadata: HDRStaticMetadata?
    ) -> some View {
        mediaInfoGroup(title: "RPU Metadata", icon: "square.stack.3d.up.fill") {
            if let baseLayerHDRStaticMetadata {
                if let masteringDisplay = masteringDisplayText(baseLayerHDRStaticMetadata) {
                    videoInfoRow(label: "HDR10 MDL", value: masteringDisplay)
                }
                if let contentLight = contentLightText(baseLayerHDRStaticMetadata) {
                    videoInfoRow(label: "HDR10 CLL/FALL", value: contentLight)
                }
            }
            if let level6 = metadata.level6 {
                videoInfoRow(label: "RPU MDL", value: rpuMasteringDisplayText(level6))
                videoInfoRow(label: "RPU CLL/FALL", value: rpuContentLightText(level6))
            }
            if let level1 = metadata.level1 {
                videoInfoRow(label: "PQ Min / Max / Avg", value: "\(level1.minPQ) / \(level1.maxPQ) / \(level1.averagePQ) 12-bit")
                videoInfoRow(label: "L1 Min / Max / Avg", value: l1NitsText(level1))
            }
            if let area = metadata.activeArea {
                videoInfoRow(label: "L5 Active Offsets", value: "\(area.left) / \(area.right) / \(area.top) / \(area.bottom)")
            }
            videoInfoRow(label: "RPU", value: "Type \(metadata.rpuType) · Format \(metadata.rpuFormat)")
            videoInfoRow(label: "BL / EL / RPU", value: bitDepthText(metadata))
            if metadata.sceneRefresh != nil || metadata.metadataBlockCount != nil {
                let sceneRefresh = metadata.sceneRefresh.map { $0 ? String(localized: "Yes") : String(localized: "No") } ?? "—"
                let blocks = metadata.metadataBlockCount.map(String.init) ?? "—"
                videoInfoRow(label: "Scene / Blocks", value: "\(sceneRefresh) / \(blocks)")
            }
            if metadata.level2Count != nil || metadata.level8Count != nil {
                let level2Count = metadata.level2Count.map(String.init) ?? "—"
                let level8Count = metadata.level8Count.map(String.init) ?? "—"
                videoInfoRow(label: "L2 / L8 Trims", value: "\(level2Count) / \(level8Count)")
            }
            if metadata.hasLevel9 == true || metadata.level10Count != nil || metadata.contentType != nil {
                let level9 = metadata.hasLevel9 == true ? String(localized: "Present") : "—"
                let level10 = metadata.level10Count.map(String.init) ?? "—"
                let level11 = metadata.contentType.map(String.init) ?? "—"
                videoInfoRow(label: "L9 / L10 / L11", value: "\(level9) / \(level10) / \(level11)")
            }
            if let sampleTime = metadata.sampleTime {
                videoInfoRow(label: "RPU Sample", value: formatDuration(seconds: sampleTime))
            }
        }
    }

    @ViewBuilder
    private func videoInfoRow(label: LocalizedStringKey, value: String) -> some View {
        if !value.isEmpty {
            GridRow(alignment: .top) {
                Text("\(Text(label)):")
                    .foregroundColor(.white.opacity(0.68))
                    .playerMediaInfoDetailFont()
                    .lineLimit(keepsIntrinsicFieldWidth ? 1 : nil)
                    .fixedSize(horizontal: keepsIntrinsicFieldWidth, vertical: false)

                Text(value)
                    .foregroundColor(.white)
                    .playerMediaInfoDetailFont()
                    .fixedSize(horizontal: keepsIntrinsicFieldWidth, vertical: false)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func localizedVideoInfoRow(label: LocalizedStringKey, value: LocalizedStringKey) -> some View {
        GridRow(alignment: .top) {
            Text("\(Text(label)):")
                .foregroundColor(.white.opacity(0.68))
                .playerMediaInfoDetailFont()
                .lineLimit(keepsIntrinsicFieldWidth ? 1 : nil)
                .fixedSize(horizontal: keepsIntrinsicFieldWidth, vertical: false)

            Text(value)
                .foregroundColor(.white)
                .playerMediaInfoDetailFont()
                .fixedSize(horizontal: keepsIntrinsicFieldWidth, vertical: false)
                .multilineTextAlignment(.leading)
        }
    }

    private func bitDepthText(_ metadata: DolbyVisionRPUMetadata) -> String {
        let el = metadata.enhancementLayerBitDepth.map(String.init) ?? "—"
        return "\(metadata.baseLayerBitDepth) / \(el) / \(metadata.rpuBitDepth) bit"
    }

    private func masteringDisplayText(_ metadata: HDRStaticMetadata) -> String? {
        guard let minimum = metadata.masteringMinimumNits,
              let maximum = metadata.masteringMaximumNits
        else {
            return nil
        }
        return "\(formatNits(minimum))–\(formatNits(maximum)) cd/m²"
    }

    private func contentLightText(_ metadata: HDRStaticMetadata) -> String? {
        guard let maxCLL = metadata.maxCLL,
              let maxFALL = metadata.maxFALL
        else {
            return nil
        }
        return "\(maxCLL) / \(maxFALL) cd/m²"
    }

    private func rpuMasteringDisplayText(_ level6: DolbyVisionRPUMetadata.Level6) -> String {
        "\(level6.masteringMinimum)–\(level6.masteringMaximum) cd/m²"
    }

    private func rpuContentLightText(_ level6: DolbyVisionRPUMetadata.Level6) -> String {
        "\(level6.maxCLL) / \(level6.maxFALL) cd/m²"
    }

    private func l1NitsText(_ level1: DolbyVisionRPUMetadata.Level1) -> String {
        [level1.minimumNits, level1.maximumNits, level1.averageNits]
            .map { formatNits($0) }
            .joined(separator: " / ")
    }

    private func formatNits(_ nits: Double) -> String {
        if nits < 0.01 {
            return String(format: "%.4f", nits)
        }
        if nits < 1 {
            return String(format: "%.3f", nits)
        }
        if nits < 100 {
            return String(format: "%.1f", nits)
        }
        return String(format: "%.0f", nits)
    }

    private func audioSection(audio: FFmpegStreamAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 显示音轨编号和选中状态
            HStack {
                Text("音频 #\(audio.streamIndex)")
                    .playerMediaInfoDetailFont(weight: .semibold)
                    .foregroundColor(.white)

                if audio.isEnabled {
                    Text("(当前)")
                        .foregroundColor(.green)
                        .playerMediaInfoDetailFont()
                }
            }
            .padding(.bottom, 10)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                if let language = audio.language {
                    infoRow(label: "语言", value: language)
                }

                infoRow(label: "编码", value: audio.codecName)
                if let profileVal = audio.profileName {
                    infoRow(label: "Profile", value: String(profileVal))
                }

                // 显示轨道时长
                if audio.trackDuration > 0 {
                    infoRow(label: "轨道时长", value: formatDuration(seconds: audio.trackDuration))
                }

                infoRow(label: "声道", value: audio.audioChannelLayoutDescription)
                infoRow(label: "采样率", value: "\(audio.audioSampleRate) Hz")

                // 显示静态比特率
                infoRow(label: "比特率", value: "\(formatBitrate(Int(audio.bitRate)))")
            }
        }
        #if os(visionOS)
        .padding(.horizontal, contentInset)
        #else
        .padding()
        #endif
        .frame(minWidth: mediaInfoCardMinWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(groupBackground)
    }

    private func coverSection(cover: FFmpegStreamAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 显示封面轨道编号
            HStack {
                Text("封面 #\(cover.streamIndex)")
                    .playerMediaInfoDetailFont(weight: .semibold)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 10)

            // 显示解码后的图片
            if let coverImage = cover.coverImage {
                Image(decorative: coverImage, scale: 1)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 250)
                    .roundedCorner(AppCornerRadius.poster)
                    .padding(.bottom, 8)
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                infoRow(label: "编码", value: cover.codecName)
                infoRow(
                    label: "分辨率",
                    value: "\(Int(cover.naturalSize.width))x\(Int(cover.naturalSize.height))"
                )
            }
        }
        #if os(visionOS)
        .padding(.horizontal, contentInset)
        #else
        .padding()
        #endif
        .frame(minWidth: mediaInfoCardMinWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(groupBackground)
    }

    private func subtitleSection(subtitle: FFmpegStreamAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // 显示字幕轨道编号和选中状态
            HStack {
                Text("字幕 #\(subtitle.streamIndex)")
                    .playerMediaInfoDetailFont(weight: .semibold)
                    .foregroundColor(.white)

                if subtitle.isEnabled {
                    Text("(当前)")
                        .foregroundColor(.green)
                        .playerMediaInfoDetailFont()
                }
            }
            .padding(.bottom, 10)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                if let language = subtitle.language {
                    infoRow(label: "语言", value: language)
                }

                infoRow(label: "编码", value: subtitle.codecName)

                if let title = subtitle.title, !title.isEmpty {
                    infoRow(label: "标题", value: title)
                }
            }
        }
        #if os(visionOS)
        .padding(.horizontal, contentInset)
        #else
        .padding()
        #endif
        .frame(minWidth: mediaInfoCardMinWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(groupBackground)
    }

    @ViewBuilder
    private var groupBackground: some View {
        #if os(visionOS)
            // visionOS 由每条轨道的外层玻璃提供背景，字段组不重复铺底。
            EmptyView()
        #else
            RoundedRectangle(cornerRadius: AppCornerRadius.featureEntry)
                .fill(Color.black.opacity(0.5))
        #endif
    }

    @ViewBuilder
    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
        if !value.isEmpty {
            GridRow(alignment: .top) {
                // 将 label 和冒号组合起来
                Text("\(Text(label)):")
                    .foregroundColor(.white.opacity(0.68))
                    .playerMediaInfoDetailFont()

                Text(value)
                    .foregroundColor(.white)
                    .playerMediaInfoDetailFont()
                    .fixedSize(horizontal: keepsIntrinsicFieldWidth, vertical: false)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    /// 格式化比特率显示
    private func formatBitrate(_ bitrate: Int) -> String {
        if bitrate <= 0 {
            String(localized: "未知")
        } else if bitrate >= 1_000_000 {
            String(format: "%.2f Mbps", Double(bitrate) / 1_000_000)
        } else {
            "\(bitrate / 1000) kbps"
        }
    }

    /// 格式化时长显示
    private func formatDuration(seconds: Float64) -> String {
        if seconds <= 0 {
            return String(localized: "未知")
        }

        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }

    private func isInterlacedScanType(_ fieldOrder: FFmpegFieldOrder) -> Bool {
        switch fieldOrder {
        case .tt,
             .bb,
             .tb,
             .bt:
            true
        case .unknown,
             .progressive:
            false
        @unknown default:
            false
        }
    }

    private func scanOrderText(for fieldOrder: FFmpegFieldOrder) -> LocalizedStringKey? {
        switch fieldOrder {
        case .tt:
            "顶场优先 (TFF)"
        case .bb:
            "底场优先 (BFF)"
        case .tb:
            "底场优先 (BFF，顶场先编码)"
        case .bt:
            "顶场优先 (TFF，底场先编码)"
        case .unknown,
             .progressive:
            nil
        @unknown default:
            nil
        }
    }
}

private extension View {
    /// 技术名称和数值共用 13pt 展示层级，空间端及 TV 保留原 subheadline。
    @ViewBuilder
    func playerMediaInfoDetailFont(weight: Font.Weight? = nil) -> some View {
        #if os(iOS) || os(macOS)
            contentTextFont(.technical, weight: weight)
        #else
            if let weight {
                font(.subheadline.weight(weight))
            } else {
                font(.subheadline)
            }
        #endif
    }

    @ViewBuilder
    func playerMediaInfoHeadingFont() -> some View {
        #if os(iOS) || os(macOS)
            contentTextFont(.heading)
        #else
            font(.headline)
        #endif
    }
}
