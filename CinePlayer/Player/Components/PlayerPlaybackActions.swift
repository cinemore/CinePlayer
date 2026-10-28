import CinePlayerSDK
import SwiftUI

@ViewBuilder
func playerSkipLabel(seconds: Int, forward: Bool) -> some View {
    let direction = forward ? "clockwise" : "counterclockwise"
    let baseSymbol: String =
        if #available(iOS 18, macOS 15, tvOS 18, visionOS 2, *) {
            "arrow.trianglehead.\(direction)"
        } else {
            forward ? "goforward" : "gobackward"
        }
    switch seconds {
    case 5, 10, 15, 30, 45, 60, 75, 90:
        if #available(iOS 18, macOS 15, tvOS 18, visionOS 2, *) {
            Image(systemName: "\(seconds).\(baseSymbol)")
        } else {
            Image(systemName: "\(baseSymbol).\(seconds)")
        }
    default:
        // 系统没有所有秒数的带数字符号，保留配置对应的准确秒数。
        Label("\(seconds)s", systemImage: baseSymbol)
            .labelStyle(.titleAndIcon)
            .monospacedDigit()
    }
}

@MainActor
extension PlayerController {
    /// 内核的 play 只更新播放状态；已结束的媒体需要公开 seek 接口重新准备队列。
    func playFromControls() {
        if playbackState == .finished || playbackState == .stopped {
            seek(time: 0, playbackBehavior: .resumePlayback)
        } else {
            play()
        }
    }

    func togglePlaybackFromControls() {
        if playbackState == .playing { pause() }
        else { playFromControls() }
    }
}
