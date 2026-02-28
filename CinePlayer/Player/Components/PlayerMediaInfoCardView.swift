import AVFoundation
import CinePlayerSDK
import SwiftUI

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

struct PlayerMediaInfoCardView: View {
    @EnvironmentObject private var playerCoordinator: CinePlayer.Coordinator

    var onClose: () -> Void

    private var padding: CGFloat {
        #if os(iOS)
        UIDevice.current.userInterfaceIdiom == .phone ? 16 : 24
        #else
        24
        #endif
    }

    private var paddingTop: CGFloat {
        #if os(iOS)
        PlatformServices.isIOSPlayerPortraitLock() ? padding + 44 : padding
        #else
        padding
        #endif
    }

    private var paddingRight: CGFloat {
        #if os(iOS)
        PlatformServices.isIOSPlayerPortraitLock() ? 24 : 64
        #else
        24
        #endif
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // 视频轨道
                    if !videoTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("视频轨道")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.leading, titleLeadingPadding)

                            ScrollView(.horizontal, showsIndicators: showHorizontalIndicators) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(videoTracks, id: \.streamIndex) { video in
                                        videoSection(video: video)
                                    }
                                }
                                .padding(.horizontal, titleLeadingPadding)
                            }
                        }
                    }

                    // 音频轨道
                    if !audioTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("音频轨道")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.leading, titleLeadingPadding)

                            ScrollView(.horizontal, showsIndicators: showHorizontalIndicators) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(audioTracks, id: \.streamIndex) { audio in
                                        audioSection(audio: audio)
                                    }
                                }
                                .padding(.horizontal, titleLeadingPadding)
                            }
                        }
                    }

                    // 封面轨道
                    if !coverTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("封面轨道")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.leading, titleLeadingPadding)

                            ScrollView(.horizontal, showsIndicators: showHorizontalIndicators) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(coverTracks, id: \.streamIndex) { cover in
                                        coverSection(cover: cover)
                                    }
                                }
                                .padding(.horizontal, titleLeadingPadding)
                            }
                        }
                    }

                    // 字幕轨道
                    if !subtitleTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("字幕轨道")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding(.leading, titleLeadingPadding)

                            ScrollView(.horizontal, showsIndicators: showHorizontalIndicators) {
                                HStack(alignment: .top, spacing: 16) {
                                    ForEach(subtitleTracks, id: \.streamIndex) { subtitle in
                                        subtitleSection(subtitle: subtitle)
                                    }
                                }
                                .padding(.horizontal, titleLeadingPadding)
                            }
                        }
                    }
                }
                .padding(.vertical, paddingTop)
            }

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .brightness(0.2)
                    .f16b()
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(.ultraThickMaterial)
                    .clipShape(Circle())
                    .contentShape(Circle())
            }
            .accessibilityLabel("关闭")
            .padding(.top, 24)
            .padding(.trailing, paddingRight)
            .buttonStyle(.plain)
        }
        #if os(iOS) || os(visionOS)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .ignoresSafeArea()
        #else
        .frame(maxWidth: 900, maxHeight: 500)
        .frame(minWidth: 400, minHeight: 200)
        .modifier(
            GlassEffectModifier(
                cornerRadius: 16,
                useCapsule: false,
                clipsContent: true
            )
        )
        #endif
    }

    private var titleLeadingPadding: CGFloat {
        #if os(iOS) || os(visionOS)
        paddingRight
        #else
        24
        #endif
    }

    private var showHorizontalIndicators: Bool {
        #if os(macOS)
        true
        #else
        false
        #endif
    }

    private var videoTracks: [FFmpegStreamAsset] {
        playerCoordinator.controller?.videoTracks ?? []
    }

    private var audioTracks: [FFmpegStreamAsset] {
        playerCoordinator.controller?.tracks(mediaType: .audio) ?? []
    }

    private var coverTracks: [FFmpegStreamAsset] {
        playerCoordinator.controller?.coverTracks ?? []
    }

    private var subtitleTracks: [FFmpegStreamAsset] {
        playerCoordinator.controller?.sortByLanguageTracks(mediaType: .subtitle) ?? []
    }

    private func videoSection(video: FFmpegStreamAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("视频 #\(video.streamIndex)")
                    .font(.headline)
                    .foregroundColor(.white)

                if video.isEnabled {
                    Text("(当前)")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
            }
            .padding(.bottom, 10)

            if let config = video.dolbyVisionConfig {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Dolby Vision")
                        .font(.system(size: 14))
                        .foregroundColor(.white)

                    Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                        infoRow(label: "Profile", value: config.profileString)
                        if !config.codecTag.isEmpty {
                            infoRow(
                                label: "Codec",
                                value: "\(config.codecTag).\(config.profile).\(config.level)"
                            )
                        }
                        if !config.layers.isEmpty {
                            infoRow(
                                label: "Layers",
                                value: "\(config.layers.joined(separator: "+"))"
                            )
                        }
                    }
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.black.opacity(0.5))
                )
            }

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                infoRow(label: "编码", value: video.codecName)
                if let profileName = video.profileName, !profileName.isEmpty {
                    infoRow(label: "Profile", value: profileName)
                }
                infoRow(
                    label: "分辨率",
                    value: "\(Int(video.naturalSize.width))×\(Int(video.naturalSize.height))"
                )

                let frameRate = String(format: "%.3f", video.nominalFrameRate)
                infoRow(label: "帧率", value: frameRate)

                if video.trackDuration > 0 {
                    infoRow(label: "轨道时长", value: formatDuration(seconds: video.trackDuration))
                }

                infoRow(label: "比特率", value: formatBitrate(Int(video.bitRate)))

                infoRow(label: "动态范围", value: video.dynamicRange.description)

                if let color = video.colorPrimaries, !color.isEmpty {
                    infoRow(label: "基色", value: color)
                }

                if let transfer = video.transferFunction, !transfer.isEmpty {
                    infoRow(label: "色调映射", value: transfer)
                }

                if let matrix = video.yCbCrMatrix, !matrix.isEmpty {
                    infoRow(label: "色彩矩阵", value: matrix)
                }

                infoRow(label: "位深度", value: "\(video.bitDepth) bit")

                if let formatName = video.formatName, !formatName.isEmpty {
                    infoRow(label: "像素格式", value: formatName)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }

    private func audioSection(audio: FFmpegStreamAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("音频 #\(audio.streamIndex)")
                    .font(.headline)
                    .foregroundColor(.white)

                if audio.isEnabled {
                    Text("(当前)")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
            }
            .padding(.bottom, 10)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                if let language = audio.language, !language.isEmpty {
                    infoRow(label: "语言", value: language)
                }

                infoRow(label: "编码", value: audio.codecName)
                if let profileName = audio.profileName, !profileName.isEmpty {
                    infoRow(label: "Profile", value: profileName)
                }

                if audio.trackDuration > 0 {
                    infoRow(label: "轨道时长", value: formatDuration(seconds: audio.trackDuration))
                }

                if audio.audioChannelLayoutDescription != "" {
                    infoRow(label: "声道", value: "\(audio.audioChannelLayoutDescription)")
                }
                if audio.audioSampleRate > 0 {
                    infoRow(label: "采样率", value: "\(audio.audioSampleRate) Hz")
                }
                infoRow(label: "比特率", value: formatBitrate(Int(audio.bitRate)))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }

    private func coverSection(cover: FFmpegStreamAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("封面 #\(cover.streamIndex)")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(.bottom, 10)

            if let coverImage = cover.coverImage {
                #if canImport(UIKit)
                Image(uiImage: UIImage(cgImage: coverImage))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 250)
                    .roundedCorner(8)
                    .padding(.bottom, 8)
                #elseif canImport(AppKit)
                Image(nsImage: NSImage(cgImage: coverImage, size: .zero))
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 200, maxHeight: 250)
                    .roundedCorner(8)
                    .padding(.bottom, 8)
                #endif
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top, spacing: 8) {
                    Text("编码:")
                        .foregroundColor(.gray)
                        .f14r()
                    Text(cover.codecName)
                        .foregroundColor(.white)
                        .f14r()
                }

                HStack(alignment: .top, spacing: 8) {
                    Text("分辨率:")
                        .foregroundColor(.gray)
                        .f14r()
                    Text("\(Int(cover.naturalSize.width))x\(Int(cover.naturalSize.height))")
                        .foregroundColor(.white)
                        .f14r()
                }
            }
        }
        .frame(maxWidth: 220)
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }

    private func subtitleSection(subtitle: FFmpegStreamAsset) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("字幕 #\(subtitle.streamIndex)")
                    .font(.headline)
                    .foregroundColor(.white)

                if subtitle.isEnabled {
                    Text("(当前)")
                        .foregroundColor(.green)
                        .font(.subheadline)
                }
            }
            .padding(.bottom, 10)

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                if let language = subtitle.language, !language.isEmpty {
                    infoRow(label: "语言", value: language)
                }

                infoRow(label: "编码", value: subtitle.codecName)

                if let title = subtitle.title, !title.isEmpty {
                    infoRow(label: "标题", value: title)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }

    @ViewBuilder
    private func infoRow(label: LocalizedStringKey, value: String) -> some View {
        if !value.isEmpty {
            GridRow(alignment: .top) {
                (Text(label) + Text(":"))
                    .foregroundColor(.gray)
                    .f14r()

                Text(value)
                    .foregroundColor(.white)
                    .f14r()
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(width: 200, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
    }

    private func formatBitrate(_ bitrate: Int) -> String {
        if bitrate <= 0 {
            return "未知"
        } else if bitrate >= 1000000 {
            return String(format: "%.2f Mbps", Double(bitrate) / 1000000)
        } else {
            return "\(bitrate / 1000) kbps"
        }
    }

    private func formatDuration(seconds: Float64) -> String {
        if seconds <= 0 {
            return "未知"
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
}
