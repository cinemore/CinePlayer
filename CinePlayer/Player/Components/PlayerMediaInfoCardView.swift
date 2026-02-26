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
                    .f16b()
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(.ultraThickMaterial)
                    .clipShape(Circle())
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

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                infoRow(label: "编码", value: video.codecName)
                if let profileName = optionalText(video.profileName) {
                    infoRow(label: "Profile", value: profileName)
                }
                infoRow(
                    label: "分辨率",
                    value: "\(Int(video.naturalSize.width))×\(Int(video.naturalSize.height))"
                )
                infoRow(label: "帧率", value: String(format: "%.2f fps", video.nominalFrameRate))
                infoRow(label: "比特率", value: formatBitrate(Int(video.bitRate)))
                infoRow(label: "动态范围", value: video.dynamicRange.description)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 280, alignment: .leading)
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
                if let language = optionalText(audio.language) {
                    infoRow(label: "语言", value: language)
                }
                infoRow(label: "编码", value: audio.codecName)
                if let profileName = optionalText(audio.profileName) {
                    infoRow(label: "Profile", value: profileName)
                }
                infoRow(label: "比特率", value: formatBitrate(Int(audio.bitRate)))
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 280, alignment: .leading)
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
                if let language = optionalText(subtitle.language) {
                    infoRow(label: "语言", value: language)
                }
                infoRow(label: "编码", value: subtitle.codecName)
                if let title = optionalText(subtitle.title) {
                    infoRow(label: "标题", value: title)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 280, alignment: .leading)
        .padding(.vertical, 20)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.5))
        )
    }

    private func infoRow(label: String, value: String) -> some View {
        GridRow {
            Text("\(label):")
                .foregroundColor(.gray)
                .f14r()
            Text(value)
                .foregroundColor(.white)
                .f14r()
        }
    }

    private func optionalText(_ text: String?) -> String? {
        guard let text, !text.isEmpty else {
            return nil
        }
        return text
    }

    private func formatBitrate(_ bitrate: Int) -> String {
        if bitrate <= 0 {
            return "未知"
        }
        if bitrate >= 1_000_000 {
            return String(format: "%.2f Mbps", Double(bitrate) / 1_000_000)
        }
        return "\(bitrate / 1000) kbps"
    }
}
