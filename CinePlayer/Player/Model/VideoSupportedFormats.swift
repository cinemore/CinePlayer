import Foundation

/// 与 cinemore 保持一致的视频扩展名集合，用于文件选择器过滤。
enum VideoSupportedFormats {
    static let extensions: Set<String> = [
        "mp4", "mkv", "avi", "mov", "flv", "ts", "mts", "m2ts", "m4v", "webm",
        "mpg", "mpeg", "mpe", "wmv", "rmvb", "rm", "3gp", "3g2", "3gpp", "3gp2",
        "ogv", "ogm", "vob", "asf", "f4v", "f4p", "f4a", "f4b", "mxf", "wtv",
        "dv", "divx", "amv", "nsv", "dat", "m2v", "m1v", "mpv", "m2p",
        "tp", "m2t", "mt2s", "swf", "dvr-ms", "mod", "dvdmedia", "iso",
        "m3u8", "mpd",
    ]

    static func isVideoFile(url: URL) -> Bool {
        extensions.contains(url.pathExtension.lowercased())
    }
}
