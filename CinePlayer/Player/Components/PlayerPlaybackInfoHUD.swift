import CinePlayerSDK
import AVFoundation
import SwiftUI

extension EnvironmentValues {
    @Entry var tvPlaybackInfoPinned: Binding<Bool> = .constant(false)
}

/// 只读取媒体信息面板已有的轨道和 PlayerInfo 快照，不参与播放器配置或帧处理。
struct PlayerPlaybackInfoHUD: View {
    @ObservedObject var coordinator: CinePlayer.Coordinator

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            VStack(alignment: .leading, spacing: 2) {
                if let controller = coordinator.controller {
                    if let video = controller.videoTracks.first(where: \.isEnabled) {
                        let snapshot = controller.playerInfo?.videoPlaybackSnapshot
                        line("视频", values: [
                            "\(Int(video.naturalSize.width))×\(Int(video.naturalSize.height))",
                            video.codecName.uppercased(), video.profileName,
                            video.nominalFrameRate > 0 ? "\(video.nominalFrameRate.formatted(.number.precision(.fractionLength(0 ... 3)))) fps" : nil,
                            snapshot?.streamIndex == video.streamIndex ? snapshot?.decoder : nil,
                        ])
                        signalInfo(video: video, info: controller.playerInfo)
                    }
                    if let audio = controller.tracks(mediaType: .audio).first(where: \.isEnabled) {
                        line("音频", values: [
                            audio.language, audio.codecName.uppercased(),
                            audio.audioChannelLayoutDescription,
                            audio.audioSampleRate > 0
                                ? "\((Double(audio.audioSampleRate) / 1000).formatted(.number.precision(.fractionLength(0 ... 1)))) kHz" : nil,
                            audio.bitRate > 0 ? "\(Int(audio.bitRate) / 1000) kbps" : nil,
                        ])
                    }
                    if let info = controller.playerInfo {
                        let snapshot = info.videoPlaybackSnapshot
                        let current = snapshot.flatMap { snapshot in
                            controller.videoTracks.contains(where: { $0.isEnabled && $0.streamIndex == snapshot.streamIndex }) ? snapshot : nil
                        }
                        line("状态", values: [
                            current
                                .flatMap {
                                    $0
                                        .bitrate > 0 ? String(localized: "码率") +
                                        " \((Double($0.bitrate) / 1_000_000).formatted(.number.precision(.fractionLength(1)))) Mbps" : nil
                                },
                            controller.config.url?.isFileURL == false && info.networkSpeed.isFinite && info.networkSpeed >= 0
                                ? String(localized: "下载") +
                                " \((info.networkSpeed / 1_000_000).formatted(.number.precision(.fractionLength(1)))) MB/s" : nil,
                            current
                                .map { String(localized: "缓冲") + " \(max(0, $0.bufferedDuration).formatted(.number.precision(.fractionLength(1)))) s"
                                },
                        ])
                    }
                }
            }
            #if os(iOS) || os(macOS)
            .contentTextFont(.caption)
            #elseif os(visionOS)
            .font(.body)
            #else
            .font(.caption)
            #endif
            .monospacedDigit()
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.9), radius: 2, y: 1)
            #if os(visionOS)
                .pageHorizontalPadding()
                .padding(.leading, 16)
                .padding(.top, 32)
                .padding(.bottom)
            #elseif os(tvOS)
                .padding(.leading, 64)
                .padding(.top, 48)
            #else
                .pageHorizontalPadding()
                .padding(.vertical)
            #endif
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .accessibilityIdentifier("player.infoHUD")
        }
        #if os(tvOS)
        // 媒体信息以屏幕边缘为基准，避免安全区与内部留白叠加。
        .ignoresSafeArea(.container)
        #endif
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private func signalInfo(video: FFmpegStreamAsset, info: PlayerInfo?) -> some View {
        line("色彩", values: [
            video.dynamicRange.description,
            video.bitDepth > 0 ? "\(video.bitDepth) bit" : nil,
            video.formatName,
        ])
        line("解码色彩参数", values: [
            video.colorPrimaries, video.transferFunction, video.yCbCrMatrix,
            video.fullRange ? "Full" : "Limited",
        ])
        let liveHDR = info?.hdrStaticMetadata
        let hdr = liveHDR?.streamIndex == video.streamIndex ? liveHDR?.metadata : video.hdrStaticMetadata
        if let hdr {
            line("HDR 元数据", values: [
                hdr.maxCLL.flatMap { $0 > 0 ? "MaxCLL \($0) nit" : nil },
                hdr.maxFALL.flatMap { $0 > 0 ? "MaxFALL \($0) nit" : nil },
            ])
            line("母版显示器", values: [
                hdr.masteringMinimumNits.map { "Min \($0.formatted(.number.precision(.fractionLength(0 ... 4)))) nit" },
                hdr.masteringMaximumNits.map { "Max \($0.formatted(.number.precision(.fractionLength(0 ... 2)))) nit" },
            ])
        }
        if let config = video.dolbyVisionConfig {
            line("杜比视界片源", values: [
                config.profileString, "Level \(config.level)",
                "Compatibility ID \(config.compatibilityId)",
                config.layers.joined(separator: " + "),
                config.isLayeredProfile7 ? (video.isDualTrackDolbyVision ? "DT-DL" : "ST-DL") : nil,
            ])
            if let sample = info?.dolbyVisionRPUMetadata, sample.streamIndex == video.streamIndex {
                let rpu = sample.metadata
                line("RPU 元数据", values: [
                    rpu.contentMappingVersion.map { "CM \($0)" },
                    rpu.enhancementLayerType?.uppercased(),
                    "BL \(rpu.baseLayerBitDepth) bit",
                    rpu.enhancementLayerBitDepth.map { "EL \($0) bit" },
                    "RPU \(rpu.rpuBitDepth) bit",
                ])
                if let level6 = rpu.level6 {
                    line("RPU HDR 元数据", values: [
                        "\(level6.masteringMinimum)–\(level6.masteringMaximum) nit",
                        level6.maxCLL > 0 ? "MaxCLL \(level6.maxCLL) nit" : nil,
                        level6.maxFALL > 0 ? "MaxFALL \(level6.maxFALL) nit" : nil,
                    ])
                }
                if let level1 = rpu.level1 {
                    line("RPU L1 PQ", values: [
                        "Min \(level1.minPQ) · Max \(level1.maxPQ) · Avg \(level1.averagePQ) · 12 bit",
                    ])
                }
            }
        }
    }

    @ViewBuilder
    private func line(_ title: LocalizedStringKey, values: [String?]) -> some View {
        let values = values.compactMap(\.self).filter { !$0.isEmpty }
        if !values.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 16) {
                Text(title)
                    .fixedSize()
                Text(values.joined(separator: " · "))
            }
        }
    }
}
