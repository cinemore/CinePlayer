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
        case let .playbackRateChanged(num):
            return "playbackRate_\(num)"
        case let .skip(seconds):
            return "skip_\(seconds)"
        case let .continuousSeek(seconds):
            return "continuousSeek_\(seconds)"
        case .progressChanged:
            return "progressChanged"
        case let .brightness(value):
            return "brightness_\(value)"
        case .networkConnecting:
            return "networkConnecting"
        case let .networkRetrying(attempt, total):
            return "networkRetrying_\(attempt)_\(total)"
        case let .networkSwitchingURL(currentIndex, totalURLs):
            return "networkSwitchingURL_\(currentIndex)_\(totalURLs)"
        case let .networkError(message):
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
                        .f20m()
                    Image(systemName: "gauge.with.dots.needle.50percent")
                }
            case let .playbackRateChanged(num):
                let text = "\(num.playbackRateText)x"
                HStack(spacing: 10) {
                    Text("倍速")
                    Text(text)
                        .f20m()
                }
            case let .skip(seconds), let .continuousSeek(seconds):
                HStack(spacing: 10) {
                    Image(systemName: seconds < 0 ? "backward.fill" : "forward.fill")
                    Text("\(seconds) s")
                        .f20m()
                }
            case .progressChanged:
                HStack(spacing: 10) {
                    Text(progress.currentTime.toString(for: .minOrHour))
                    Text("/")
                    Text(progress.totalTime.toString(for: .minOrHour))
                }
                .f20m()
            case let .brightness(value):
                HStack(spacing: 12) {
                    ZStack {
                        Image(systemName: "sun.min")
                            .opacity(value < 0.33 ? 1 : 0)
                        Image(systemName: "sun.min.fill")
                            .opacity(value >= 0.33 && value < 0.66 ? 1 : 0)
                        Image(systemName: "sun.max.fill")
                            .opacity(value >= 0.66 ? 1 : 0)
                    }
                    .f20m()

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
            case .networkConnecting:
                label(icon: "antenna.radiowaves.left.and.right", text: "正在连接...")
            case let .networkRetrying(attempt, total):
                label(icon: "arrow.clockwise", text: "重试中 (\(attempt)/\(total))")
            case let .networkSwitchingURL(currentIndex, totalURLs):
                label(icon: "point.3.connected.trianglepath.dotted", text: "切换线路 (\(currentIndex)/\(totalURLs))")
            case let .networkError(message):
                label(icon: "wifi.exclamationmark", text: message)
            case .networkStable:
                label(icon: "checkmark.circle", text: "连接稳定")
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .modifier(GlassEffectModifier(cornerRadius: 24, useCapsule: true))
    }

    private func label(icon: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
            Text(text)
        }
        .f14m()
    }
}
