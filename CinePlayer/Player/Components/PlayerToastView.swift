import CinePlayerSDK
import Combine
import SwiftUI

enum PlayerToastLayout {
    #if os(tvOS)
        static let topInset: CGFloat = 44
        static let prominentSpacing: CGFloat = 18
        static let compactSpacing: CGFloat = 14
        static let brightnessTrackWidth: CGFloat = 220
        static let brightnessTrackHeight: CGFloat = 6
        static let horizontalPadding: CGFloat = 34
        static let verticalPadding: CGFloat = 20
        static let cornerRadius: CGFloat = 34
        static let minimumHeight: CGFloat = 96
        static let progressScale: CGFloat = 1.25
    #else
        static let topInset: CGFloat = 28
        static let prominentSpacing: CGFloat = 10
        static let compactSpacing: CGFloat = 12
        static let brightnessTrackWidth: CGFloat = 120
        static let brightnessTrackHeight: CGFloat = 3
        static let horizontalPadding: CGFloat = 20
        static let verticalPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 24
        static let minimumHeight: CGFloat = 0
        static let progressScale: CGFloat = 0.8
    #endif
}

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
                HStack(spacing: PlayerToastLayout.prominentSpacing) {
                    Text(text)
                    Image(systemName: "forward.fill")
                }
                .playerToastFont()
            case .playbackRateChanged(let num):
                let text = "\(num.playbackRateText)x"
                HStack(spacing: PlayerToastLayout.prominentSpacing) {
                    Text("倍速")
                    Text(text)
                }
                .playerToastFont()
            case .skip(let seconds), .continuousSeek(let seconds):
                HStack(spacing: PlayerToastLayout.prominentSpacing) {
                    if seconds < 0 {
                        Image(systemName: "backward.fill")
                            .playerToastIconFont()
                    }
                    Text("\(seconds) s")
                    if seconds > 0 {
                        Image(systemName: "forward.fill")
                            .playerToastIconFont()
                    }
                }
                .playerToastFont()
            case .progressChanged:
                HStack(spacing: PlayerToastLayout.prominentSpacing) {
                    Text(progress.currentTime.toString(for: .minOrHour))
                    Text("/")
                    Text(progress.totalTime.toString(for: .minOrHour))
                }
                .playerToastFont()
            case .brightness(let value):
                HStack(spacing: PlayerToastLayout.compactSpacing) {
                    ZStack {
                        Image(systemName: "sun.min")
                            .playerToastIconFont()
                            .opacity(value < 0.33 ? 1 : 0)
                        Image(systemName: "sun.min.fill")
                            .playerToastIconFont()
                            .opacity(value >= 0.33 && value < 0.66 ? 1 : 0)
                        Image(systemName: "sun.max.fill")
                            .playerToastIconFont()
                            .opacity(value >= 0.66 ? 1 : 0)
                    }
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.3))
                            .frame(height: PlayerToastLayout.brightnessTrackHeight)
                        Capsule()
                            .fill(Color.white)
                            .frame(
                                width: PlayerToastLayout.brightnessTrackWidth * value,
                                height: PlayerToastLayout.brightnessTrackHeight
                            )
                    }
                    .frame(width: PlayerToastLayout.brightnessTrackWidth)
                }
                .playerToastFont()
            case .networkConnecting:
                HStack(spacing: PlayerToastLayout.compactSpacing) {
                    ProgressView()
                        .scaleEffect(PlayerToastLayout.progressScale)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("正在连接...")
                }
                .playerToastFont()
            case .networkRetrying(let attempt, let total):
                HStack(spacing: PlayerToastLayout.compactSpacing) {
                    ProgressView()
                        .scaleEffect(PlayerToastLayout.progressScale)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("网络重试中 (\(attempt)/\(total))")
                }
                .playerToastFont()
            case .networkSwitchingURL(let currentIndex, let totalURLs):
                HStack(spacing: PlayerToastLayout.compactSpacing) {
                    ProgressView()
                        .scaleEffect(PlayerToastLayout.progressScale)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("切换备用源 (\(currentIndex)/\(totalURLs))")
                }
                .playerToastFont()
            case .networkError(let message):
                HStack(spacing: PlayerToastLayout.compactSpacing) {
                    Image(systemName: "wifi.exclamationmark")
                        .playerToastIconFont()
                        .foregroundStyle(.red)
                    Text(message)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
                .playerToastFont()
            case .networkStable:
                HStack(spacing: PlayerToastLayout.compactSpacing) {
                    Image(systemName: "wifi")
                        .playerToastIconFont()
                        .foregroundStyle(.green)
                    Text("连接稳定")
                }
                .playerToastFont()
            }
        }
        .brightness(0.2)
        .foregroundStyle(.white)
        .frame(minHeight: PlayerToastLayout.minimumHeight)
        .padding(.horizontal, PlayerToastLayout.horizontalPadding)
        .padding(.vertical, PlayerToastLayout.verticalPadding)
        .modifier(GlassEffectModifier(cornerRadius: PlayerToastLayout.cornerRadius))
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
