//
//  PlayerSliderView.swift
//  Cinemore
//
//  Created by lf on 2024/12/25.
//

import Foundation
import SwiftUI
import CinePlayerSDK

// MARK: 自定义进度条 View

#if !os(tvOS)
    private struct ScrubThumbnailRequestKey: Equatable {
        let second: Int
        let controllerID: ObjectIdentifier
    }

    struct ProgressSliderView: View {
        @Binding var currentTime: Int
        var totalTime: Int
        var controller: PlayerController?
        var onEditingChanged: (Bool) -> Void

        @State private var isHovering = false
        @State private var isDragging = false
        @Environment(\.displayScale) private var displayScale
        @State private var previewImageData: Data? = nil
        @State private var isPreviewLoading = false
        #if os(macOS)
            @State private var hoverTime: Int? = nil
            @State private var hoverPosition: CGPoint? = nil
        #endif

        var body: some View {
            HStack {
                Text(currentTime.toString(for: .minOrHour))
                    .brightness(0.2)
                    .f14r()
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(alignment: .center)
                    .frame(width: 60, alignment: .center)

                Spacer()

                CustomSlider(
                    value: $currentTime,
                    range: (0, totalTime),
                    knobWidth: 15,
                    onEditingChanged: { value in
                        isDragging = value
                        if value {
                            isHovering = true
                        } else {
                            #if !os(macOS)
                                withAnimation {
                                    isHovering = false
                                }
                            #endif
                            #if os(macOS)
                                // 拖动结束时清除 hover 时间提示，让 onContinuousHover 重新计算
                                hoverTime = nil
                                hoverPosition = nil
                            #endif
                        }
                        onEditingChanged(value)
                    }
                ) { sliderData in
                    // 使用固定高度的容器，简化布局
                    ZStack {
                        GeometryReader { geometry in
                            // 按视频画面原始比例计算缩略图卡片尺寸，限制在最大宽高内
                            let maxCardSize = CGSize(width: 240, height: 135)
                            let videoRatio: CGFloat = {
                                guard let controller,
                                      let track = controller.videoTrack,
                                      track.naturalSize.width > 0,
                                      track.naturalSize.height > 0
                                else {
                                    return 240.0 / 135.0
                                }
                                let s = track.naturalSize
                                return s.width / s.height
                            }()
                            let previewCardSize =
                                if videoRatio >= maxCardSize.width / maxCardSize.height {
                                    CGSize(
                                        width: maxCardSize.width,
                                        height: maxCardSize.width / videoRatio
                                    )
                                } else {
                                    CGSize(
                                        width: maxCardSize.height * videoRatio,
                                        height: maxCardSize.height
                                    )
                                }
                            let previewCardY: CGFloat = -previewCardSize.height * 0.5 - 10

                            // 计算 tooltip 位置：允许向两侧时间文本区域延伸一定余量，避免缩略图被限制得过紧
                            let halfWidth: CGFloat = previewCardSize.width / 2
                            let outwardAllowance: CGFloat = 72 // 向左右时间区域延伸的余量（两侧时间各 60pt 宽）

                            #if os(macOS)
                                let timeValue: Int? =
                                    isDragging ? currentTime : (isHovering ? hoverTime : nil)
                                let positionX: CGFloat? =
                                    isDragging
                                        ? sliderData.knobCenterX
                                        : (isHovering && hoverPosition != nil
                                            ? max(0, min(geometry.size.width, hoverPosition!.x))
                                            : nil)
                                let showPreview = isDragging || (isHovering && hoverTime != nil)
                            #else
                                let timeValue: Int? = isDragging ? currentTime : nil
                                let positionX: CGFloat? = isDragging ? sliderData.knobCenterX : nil
                                let showPreview = isDragging
                            #endif

                            let tooltipX: CGFloat? = positionX.map { pos in
                                let minX = halfWidth - outwardAllowance
                                let maxX = geometry.size.width - halfWidth + outwardAllowance
                                return min(max(pos, minX), maxX)
                            }

                            let requestKey: ScrubThumbnailRequestKey? = {
                                guard showPreview, let timeValue, let controller else {
                                    return nil
                                }
                                return ScrubThumbnailRequestKey(
                                    second: timeValue,
                                    controllerID: ObjectIdentifier(controller)
                                )
                            }()

                            ZStack {
                                // 进度条背景（完整宽度）
                                Rectangle()
                                    .fill(Color.clear)
                                    .frame(width: geometry.size.width)
                                Capsule()
                                    .fill(Color.white.opacity(0.3))
                                    .brightness(0.2)
                                    .frame(width: geometry.size.width, height: isHovering ? 5 : 3)
                                    .position(
                                        x: geometry.size.width * 0.5, y: geometry.size.height * 0.5
                                    )

                                // 已完成的进度条（从左边到锚点中心）
                                if sliderData.knobCenterX > 0 {
                                    Capsule()
                                        .fill(Color.white)
                                        .brightness(0.2)
                                        .frame(
                                            width: sliderData.knobCenterX,
                                            height: isHovering ? 5 : 3
                                        )
                                        .position(
                                            x: sliderData.knobCenterX * 0.5,
                                            y: geometry.size.height * 0.5
                                        )
                                }

                                // 章节时间点小圆点
                                if let controller {
                                    let chapters = controller.chapters
                                    ForEach(Array(chapters.enumerated()), id: \.offset) {
                                        _, chapter in
                                        let chapterProgress =
                                            CGFloat(chapter.start)
                                                / CGFloat(TimeInterval(totalTime))
                                        if chapterProgress > 0, chapterProgress < 1 {
                                            let chapterPosition =
                                                chapterProgress * geometry.size.width
                                            let chapterPiontHeight = isHovering ? 5.0 : 3.0
                                            Circle()
                                                .fill(Color.white.opacity(0.8))
                                                .brightness(0.2)
                                                .frame(
                                                    width: chapterPiontHeight,
                                                    height: chapterPiontHeight
                                                )
                                                .position(
                                                    x: chapterPosition - (chapterPiontHeight / 2),
                                                    y: geometry.size.height * 0.5
                                                )
                                        }
                                    }
                                }

                                // 锚点（可以超出边界）
                                Circle()
                                    .fill(Color.white)
                                    .brightness(0.2)
                                    .frame(
                                        width: sliderData.knobSize.width,
                                        height: sliderData.knobSize.height
                                    )
                                    .position(
                                        x: sliderData.knobCenterX, y: geometry.size.height * 0.5
                                    )
                                    .opacity(isHovering ? 0.8 : 1)

                                if showPreview, let timeValue, let tooltipX {
                                    ScrubThumbnailCardView(
                                        imageData: previewImageData,
                                        isLoading: isPreviewLoading,
                                        timeText: timeValue.toString(for: .minOrHour),
                                        videoAspectRatio: videoRatio
                                    )
                                    .frame(
                                        width: previewCardSize.width, height: previewCardSize.height
                                    )
                                    .position(x: tooltipX, y: previewCardY)
                                }

                                #if os(macOS)
                                    // 显示章节提示（下方）
                                    if let controller, let timeValue, let positionX {
                                        if let chapter = controller.chapters.first(where: {
                                            chapter in
                                            TimeInterval(timeValue) >= chapter.start
                                                && TimeInterval(timeValue) < chapter.end
                                        }), !chapter.title.isEmpty {
                                            // 估算文本宽度：11px 字体，每个字符约 6.5px
                                            let estimatedCharWidth: CGFloat = 6.5
                                            let chapterTextWidth =
                                                CGFloat(chapter.title.count) * estimatedCharWidth
                                            let chapterHalfWidth = chapterTextWidth / 2
                                            let chapterOverflow: CGFloat = 6 // 允许章节超出边界的距离

                                            // 计算章节文本位置，允许稍微超出边界
                                            let chapterX =
                                                positionX <= chapterHalfWidth - chapterOverflow
                                                    ? chapterHalfWidth - chapterOverflow // 左边：允许超出一些
                                                    : (positionX >= geometry.size.width
                                                        - chapterHalfWidth + chapterOverflow
                                                        ? geometry.size.width - chapterHalfWidth
                                                        + chapterOverflow // 右边：允许超出一些
                                                        : positionX) // 中间：文本中心跟随位置

                                            Text(chapter.title)
                                                .brightness(0.2)
                                                .f11r()
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .position(x: chapterX, y: geometry.size.height - 8)
                                        }
                                    }
                                #endif
                            }
                            .task(id: requestKey) {
                                guard let requestKey else {
                                    previewImageData = nil
                                    isPreviewLoading = false
                                    return
                                }

                                isPreviewLoading = true
                                previewImageData = nil

                                try? await Task.sleep(nanoseconds: 100_000_000)
                                if Task.isCancelled {
                                    return
                                }

                                guard let controller else {
                                    isPreviewLoading = false
                                    return
                                }

                                let result = await controller.requestScrubThumbnail(
                                    time: TimeInterval(requestKey.second),
                                    targetPointSize: previewCardSize,
                                    scale: displayScale
                                )
                                if Task.isCancelled {
                                    return
                                }

                                previewImageData = result?.imageData
                                isPreviewLoading = false
                            }
                            #if os(macOS)
                            .onContinuousHover { phase in
                                // 拖动时不更新 hover 时间（拖动时使用 currentTime）
                                guard !isDragging else {
                                    return
                                }

                                switch phase {
                                case let .active(location):
                                    // 计算对应的时间
                                    let progressRatio = max(
                                        0, min(1, location.x / geometry.size.width)
                                    )
                                    let time = Int(Double(totalTime) * Double(progressRatio))
                                    hoverTime = time
                                    hoverPosition = location
                                case .ended:
                                    hoverTime = nil
                                    hoverPosition = nil
                                }
                            }
                            #endif
                        }
                    }
                }
                .onHover { hovering in
                    withAnimation {
                        isHovering = hovering
                    }
                    #if os(macOS)
                        // 鼠标离开时清除 hover 时间
                        if !hovering {
                            hoverTime = nil
                            hoverPosition = nil
                        }
                    #endif
                }

                Spacer()

                Text(totalTime.toString(for: .minOrHour))
                    .brightness(0.2)
                    .f14r()
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(width: 60, alignment: .center)
            }
        }
    }
#endif

#if os(tvOS)
    private struct ScrubThumbnailRequestKey: Equatable {
        let second: Int
        let controllerID: ObjectIdentifier
    }
#endif

struct PlayerSliderView: View {
    @ObservedObject var coordinator: CinePlayer.Coordinator
    /// 监听播放进度
    @ObservedObject var progress: PlayingProgress

    #if !os(tvOS)
        @State private var isHovering = false
    #else
        var isHovering: Bool
        var isSeeking: Bool = false
        @Environment(\.displayScale) private var displayScale
        @State private var previewImageData: Data? = nil
        @State private var isPreviewLoading = false
    #endif
    var onProgressEditingChanged: (Bool, Int) -> Void

    var body: some View {
        if progress.totalTime <= 0 || progress.currentTime > progress.totalTime {
            // 直接返回空视图
            EmptyView()
        } else {
            #if !os(tvOS)
                ProgressSliderView(
                    currentTime: $progress.currentTime,
                    totalTime: progress.totalTime,
                    controller: coordinator.controller,
                    onEditingChanged: { value in
                        onProgressEditingChanged(value, progress.currentTime)
                    }
                )
            #else
                VStack(spacing: 0) {
                    GeometryReader { geo in
                        let width = geo.size.width
                        let currentTime = CGFloat(progress.currentTime)
                        let totalTime = CGFloat(progress.totalTime)
                        let controller = coordinator.controller
                        // 按视频画面原始比例计算缩略图卡片尺寸，限制在最大宽高内
                        let maxCardSize = CGSize(width: 480, height: 270)
                        let videoRatio: CGFloat = {
                            guard let controller,
                                  let track = controller.videoTrack,
                                  track.naturalSize.width > 0,
                                  track.naturalSize.height > 0
                            else {
                                return 480.0 / 270.0
                            }
                            let s = track.naturalSize
                            return s.width / s.height
                        }()
                        let previewCardSize =
                            if videoRatio >= maxCardSize.width / maxCardSize.height {
                                CGSize(
                                    width: maxCardSize.width, height: maxCardSize.width / videoRatio
                                )
                            } else {
                                CGSize(
                                    width: maxCardSize.height * videoRatio,
                                    height: maxCardSize.height
                                )
                            }
                        let previewCardY: CGFloat = -previewCardSize.height * 0.5 - 10
                        let rightMargin: CGFloat = 6
                        let halfWidth = previewCardSize.width / 2

                        let requestKey: ScrubThumbnailRequestKey? = {
                            guard isSeeking, let controller else {
                                return nil
                            }
                            return ScrubThumbnailRequestKey(
                                second: progress.currentTime,
                                controllerID: ObjectIdentifier(controller)
                            )
                        }()

                        ZStack {
                            ZStack(alignment: .leading) {
                                // 进度条背景
                                Capsule()
                                    .fill(.white.opacity(0.3))
                                    .background(.regularMaterial)
                                    .frame(width: width, height: isHovering ? 20 : 10)

                                // 章节时间点小圆点 - tvOS版本
                                if let controller {
                                    let chapters = controller.chapters
                                    ForEach(Array(chapters.enumerated()), id: \.offset) {
                                        _, chapter in
                                        let chapterProgress =
                                            CGFloat(chapter.start)
                                                / CGFloat(TimeInterval(progress.totalTime))
                                        if chapterProgress > 0, chapterProgress < 1 {
                                            let chapterPosition = chapterProgress * width
                                            let progressBarHeight = isHovering ? 20.0 : 10.0

                                            Rectangle()
                                                .fill(Color.white.opacity(0.6))
                                                .frame(width: 2, height: progressBarHeight)
                                                .position(
                                                    x: chapterPosition - 1, // 减去1以使小圆点居中
                                                    y: progressBarHeight / 2
                                                )
                                        }
                                    }
                                }

                                // 已完成的进度条
                                RoundedCornerShape(
                                    corners: [.topLeft, .bottomLeft], radius: isHovering ? 10 : 5
                                )
                                .fill(.white.opacity(0.8))
                                .background(.regularMaterial)
                                .frame(
                                    width: (width * currentTime) / max(totalTime, 1),
                                    height: isHovering ? 20 : 10
                                )
                            }
                            .frame(width: width, height: isHovering ? 20 : 10)
                            .clipShape(RoundedRectangle(cornerRadius: isHovering ? 20 : 10))
                            .overlay {
                                // 锚点
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white)
                                    .frame(width: 4, height: isHovering ? 26 : 10)
                                    .position(
                                        x: (width * currentTime) / max(totalTime, 1) - 1,
                                        y: isHovering ? 10 : 5
                                    )
                            }

                            if isSeeking {
                                let knobX = (width * currentTime) / max(totalTime, 1)
                                let cardX = min(
                                    max(knobX, halfWidth), width - halfWidth - rightMargin
                                )
                                ScrubThumbnailCardView(
                                    imageData: previewImageData,
                                    isLoading: isPreviewLoading,
                                    timeText: progress.currentTime.toString(for: .minOrHour),
                                    videoAspectRatio: videoRatio
                                )
                                .frame(width: previewCardSize.width, height: previewCardSize.height)
                                .position(x: cardX, y: previewCardY)
                            }
                        }
                        .task(id: requestKey) {
                            guard let requestKey else {
                                previewImageData = nil
                                isPreviewLoading = false
                                return
                            }

                            isPreviewLoading = true
                            previewImageData = nil

                            try? await Task.sleep(nanoseconds: 100_000_000)
                            if Task.isCancelled {
                                return
                            }

                            guard let controller else {
                                isPreviewLoading = false
                                return
                            }

                            let result = await controller.requestScrubThumbnail(
                                time: TimeInterval(requestKey.second),
                                targetPointSize: previewCardSize,
                                scale: displayScale
                            )
                            if Task.isCancelled {
                                return
                            }

                            previewImageData = result?.imageData
                            isPreviewLoading = false
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)

                    HStack {
                        Text(progress.currentTime.toString(for: .minOrHour))
                        Spacer()
                        Text(progress.totalTime.toString(for: .minOrHour))
                    }
                    .font(.system(size: 23, weight: .bold))
                    .frame(maxWidth: .infinity)
                }

            #endif
        }
    }
}
