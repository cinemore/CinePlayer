import SwiftUI

#if os(iOS)
import AVFAudio
import CinePlayerSDK
import MediaPlayer

extension MPVolumeView {
    static func setVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            slider?.value = volume
        }
    }
}

enum GestureAction {
    case leftDoubleTap
    case rightDoubleTap
    case centerDoubleTap
    case doubleTapEnd
    case singleTap
    case longPressBegan
    case longPressEnded
}

@MainActor
struct GestureViewIOS: View {
    @ObservedObject var progress: PlayingProgress
    @State private var currentProgress: Double = 0
    @State private var brightness: CGFloat = 0.5
    @State private var volume: Float = 0
    @State private var isAdjustingBrightness = false
    @State private var isAdjustingVolume = false
    @State private var isAdjustingProgress = false
    @State private var lastDragLocation: CGPoint = .zero
    @State private var lastTapLocation: CGPoint = .init(x: 100, y: 100)
    @State private var singleTapTimer: Timer?
    @State private var longPressTimer: Timer?
    @State private var isLongPressing = false
    @State private var longPressComplete = false
    @State private var doubleTapEndTimer: Timer?

    private let bottomInactiveAreaHeight: CGFloat = 32
    private let topInactiveAreaHeight: CGFloat = 32

    var safeAreaInsets: EdgeInsets
    var onProgressChanged: ((Double) -> Void)?
    var onProgressEnded: ((Double) -> Void)?
    var onBrightnessChanged: ((CGFloat?) -> Void)?
    var action: ((GestureAction) -> Void)?

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let tapLocation = value.startLocation
                            if tapLocation.y > geometry.size.height - bottomInactiveAreaHeight ||
                                tapLocation.y < topInactiveAreaHeight
                            {
                                lastTapLocation = CGPoint(x: 100, y: 100)
                            } else {
                                lastTapLocation = tapLocation
                            }
                        }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            if value.startLocation.y > geometry.size.height - bottomInactiveAreaHeight ||
                                value.startLocation.y < topInactiveAreaHeight
                            {
                                return
                            }

                            if isLongPressing, !longPressComplete {
                                return
                            }

                            if lastDragLocation == .zero {
                                longPressTimer?.invalidate()
                                if isLongPressing {
                                    action?(.longPressEnded)
                                }
                                isLongPressing = false
                                longPressComplete = true
                            }

                            if lastDragLocation == .zero {
                                lastDragLocation = value.startLocation
                                currentProgress = Double(progress.currentTime) / max(Double(progress.totalTime), 1)
                            }

                            let dragLocation = value.location
                            let dragTranslation = CGPoint(
                                x: dragLocation.x - lastDragLocation.x,
                                y: dragLocation.y - lastDragLocation.y
                            )

                            if abs(dragTranslation.x) > abs(dragTranslation.y) {
                                if !isAdjustingBrightness, !isAdjustingVolume {
                                    withAnimation {
                                        isAdjustingProgress = true
                                    }

                                    let pixelsPerSecond = 300.0
                                    let totalDragWidth = value.translation.width
                                    let secondsAdjustment = Double(totalDragWidth) / pixelsPerSecond
                                    let totalTimeDouble = Double(progress.totalTime)
                                    let startTime = currentProgress * totalTimeDouble
                                    let newTime = startTime + secondsAdjustment
                                    let boundedTime = max(min(newTime, totalTimeDouble), 0)

                                    currentProgress = boundedTime / max(totalTimeDouble, 1)
                                    onProgressChanged?(currentProgress)
                                    DispatchQueue.main.async {
                                        progress.currentTime = Int(boundedTime)
                                    }
                                }
                            } else {
                                if dragLocation.x < geometry.size.width / 3 {
                                    if !isAdjustingProgress, !isAdjustingVolume {
                                        isAdjustingBrightness = true
                                        let newBrightness = brightness - (dragTranslation.y / geometry.size.height)
                                        brightness = max(min(newBrightness, 1), 0)
                                        PlatformServices.setScreenBrightness(brightness)
                                        onBrightnessChanged?(brightness)
                                    }
                                } else if dragLocation.x > 2 * geometry.size.width / 3 {
                                    if !isAdjustingProgress, !isAdjustingBrightness {
                                        isAdjustingVolume = true
                                        let newVolume = volume - Float(dragTranslation.y / geometry.size.height)
                                        volume = max(min(newVolume, 1), 0)
                                        MPVolumeView.setVolume(volume)
                                    }
                                }
                            }

                            lastDragLocation = dragLocation
                        }
                        .onEnded { _ in
                            if isAdjustingProgress {
                                onProgressEnded?(currentProgress)
                            }

                            isAdjustingProgress = false
                            if isAdjustingBrightness {
                                isAdjustingBrightness = false
                                onBrightnessChanged?(nil)
                            }
                            isAdjustingVolume = false
                            lastDragLocation = .zero
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 2)
                        .onEnded {
                            if lastTapLocation.y > geometry.size.height - bottomInactiveAreaHeight ||
                                lastTapLocation.y < topInactiveAreaHeight
                            {
                                return
                            }

                            singleTapTimer?.invalidate()
                            if !isLongPressing {
                                longPressTimer?.invalidate()
                                longPressComplete = true
                            } else {
                                action?(.longPressEnded)
                                isLongPressing = false
                                longPressComplete = true
                                longPressTimer?.invalidate()
                            }

                            let tapX = lastTapLocation.x
                            let width = geometry.size.width

                            if tapX < width / 4 {
                                action?(.leftDoubleTap)
                                doubleTapEndTimer?.invalidate()
                                doubleTapEndTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        action?(.doubleTapEnd)
                                    }
                                }
                            } else if tapX > 3 * width / 4 {
                                action?(.rightDoubleTap)
                                doubleTapEndTimer?.invalidate()
                                doubleTapEndTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                                    DispatchQueue.main.async {
                                        action?(.doubleTapEnd)
                                    }
                                }
                            } else {
                                action?(.centerDoubleTap)
                            }
                        }
                )
                .simultaneousGesture(
                    TapGesture(count: 1)
                        .onEnded {
                            if lastTapLocation.y > geometry.size.height - bottomInactiveAreaHeight ||
                                lastTapLocation.y < topInactiveAreaHeight
                            {
                                return
                            }

                            singleTapTimer?.invalidate()
                            if !isLongPressing {
                                longPressTimer?.invalidate()
                                longPressComplete = true
                            }
                            singleTapTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                                DispatchQueue.main.async {
                                    if !isLongPressing {
                                        action?(.singleTap)
                                    }
                                }
                            }
                        }
                )
                .onLongPressGesture(minimumDuration: 1) {} onPressingChanged: { inProgress in
                    if lastTapLocation.y > geometry.size.height - bottomInactiveAreaHeight ||
                        lastTapLocation.y < topInactiveAreaHeight
                    {
                        return
                    }

                    if inProgress {
                        isLongPressing = false
                        longPressComplete = false
                        longPressTimer?.invalidate()
                        longPressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
                            DispatchQueue.main.async {
                                if !longPressComplete {
                                    isLongPressing = true
                                    action?(.longPressBegan)
                                }
                            }
                        }
                    } else {
                        longPressComplete = true
                        if isLongPressing {
                            action?(.longPressEnded)
                        }
                        isLongPressing = false
                        longPressTimer?.invalidate()
                    }
                }
        }
        .edgesIgnoringSafeArea(.all)
        .onAppear {
            brightness = PlatformServices.screenBrightness()
            volume = AVAudioSession.sharedInstance().outputVolume
        }
    }
}
#endif
