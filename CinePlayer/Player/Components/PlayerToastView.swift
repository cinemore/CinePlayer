import CinePlayerSDK
import Combine
import SwiftUI

@MainActor
final class PlayerToastModel: ObservableObject {
    @Published var presentedToast: PlayerToast?
    @Published var showContainer = false

    func show(_ toast: PlayerToast, duration: TimeInterval = 0.75) {
        presentedToast = toast
        showContainer = true

        guard duration.isFinite else {
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) { [weak self] in
            guard let self else { return }
            if presentedToast?.id == toast.id {
                presentedToast = nil
                showContainer = false
            }
        }
    }

    func showContinuousSeek(seconds: Int) {
        presentedToast = .continuousSeek(seconds: seconds)
        showContainer = true
    }

    func hide() {
        presentedToast = nil
        showContainer = false
    }
}

enum PlayerToast: Identifiable {
    case playbackRate
    case playbackRateChanged(num: Float)
    case skip(seconds: Int)
    case continuousSeek(seconds: Int)
    case progressChanged
    case brightness(value: CGFloat)
    case networkConnecting
    case networkRetrying(attempt: Int, total: Int)
    case networkSwitchingURL(currentIndex: Int, totalURLs: Int)
    case networkError(message: String)
    case networkStable

    var id: String {
        switch self {
        case .playbackRate:
            return "playbackRate"
        case .playbackRateChanged(let num):
            return "playbackRate_\(num)"
        case .skip(let seconds):
            return "skip_\(seconds)"
        case .continuousSeek(let seconds):
            return "continuousSeek_\(seconds)"
        case .progressChanged:
            return "progressChanged"
        case .brightness(let value):
            return "brightness_\(value)"
        case .networkConnecting:
            return "networkConnecting"
        case .networkRetrying(let attempt, let total):
            return "networkRetrying_\(attempt)_\(total)"
        case .networkSwitchingURL(let currentIndex, let totalURLs):
            return "networkSwitchingURL_\(currentIndex)_\(totalURLs)"
        case .networkError(let message):
            return "networkError_\(message)"
        case .networkStable:
            return "networkStable"
        }
    }
}

struct PlayerToastView: View {
    let toast: PlayerToast
    @ObservedObject var progress: PlayingProgress
    var playbackRate: Float = 1
    var brightness: CGFloat = 0.5

    var body: some View {
        Group {
            switch toast {
            case .playbackRate:
                let text = "\(playbackRate.playbackRateText)x"
                HStack(spacing: 10) {
                    Text(text)
                    Image(systemName: "forward.fill")
                }
                .f17s()
            case .playbackRateChanged(let num):
                let text = "\(num.playbackRateText)x"
                HStack(spacing: 10) {
                    Text("倍速")
                    Text(text)
                }
                .f17s()
            case .skip(let seconds), .continuousSeek(let seconds):
                HStack(spacing: 10) {
                    if seconds < 0 {
                        Image(systemName: "backward.fill")
                    }
                    Text("\(seconds) s")
                    if seconds > 0 {
                        Image(systemName: "forward.fill")
                    }
                }
                .f17s()
            case .progressChanged:
                HStack(spacing: 10) {
                    Text(progress.currentTime.toString(for: .minOrHour))
                    Text("/")
                    Text(progress.totalTime.toString(for: .minOrHour))
                }
                .f17s()
            case .brightness(let value):
                HStack(spacing: 12) {
                    ZStack {
                        Image(systemName: "sun.min")
                            .opacity(value < 0.33 ? 1 : 0)
                        Image(systemName: "sun.min.fill")
                            .opacity(value >= 0.33 && value < 0.66 ? 1 : 0)
                        Image(systemName: "sun.max.fill")
                            .opacity(value >= 0.66 ? 1 : 0)
                    }
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: 3)
                        Capsule()
                            .fill(Color.white)
                            .frame(width: 120 * value, height: 3)
                    }
                    .frame(width: 120)
                }
                .f17s()
            case .networkConnecting:
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("正在连接...")
                }
                .f17s()
            case .networkRetrying(let attempt, let total):
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("网络重试中 (\(attempt)/\(total))")
                }
                .f17s()
            case .networkSwitchingURL(let currentIndex, let totalURLs):
                HStack(spacing: 6) {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("切换备用源 (\(currentIndex)/\(totalURLs))")
                }
                .f17s()
            case .networkError(let message):
                HStack(spacing: 6) {
                    Image(systemName: "wifi.exclamationmark")
                        .foregroundStyle(.red)
                    Text(message)
                        .lineLimit(2)
                }
                .f17s()
            case .networkStable:
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .foregroundStyle(.green)
                    Text("连接稳定")
                }
                .f17s()
            }
        }
        .brightness(0.2)
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .modifier(GlassEffectModifier(cornerRadius: 24))
        #if os(macOS)
            .shadow(radius: 10)
        #endif
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text)
        }
        .f17s()
    }
}
