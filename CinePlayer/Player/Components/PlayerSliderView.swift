import CinePlayerSDK
import Combine
//
//  PlayerSliderView.swift
//  Cinemore
//
//  Created by lf on 2024/12/25.
//

import Foundation
import ImageIO
import SwiftUI

// MARK: 自定义进度条 View

struct ScrubThumbnailRequestKey: Equatable {
    let second: Int
    let controllerID: ObjectIdentifier
    let mediaIdentifier: UUID
}

@MainActor
private func makeScrubThumbnailImage(from data: Data) -> CGImage? {
    guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
        return nil
    }
    let options: [CFString: Any] = [
        kCGImageSourceDecodeRequest: kCGImageSourceDecodeToHDR
    ]
    return CGImageSourceCreateImageAtIndex(source, 0, options as CFDictionary)
}

@MainActor
func makeScrubThumbnailRequestKey(
    second: Int,
    controller: PlayerController,
    targetPointSize: CGSize,
    scale: CGFloat
) -> ScrubThumbnailRequestKey? {
    guard second >= 0, targetPointSize.width.isFinite, targetPointSize.width > 0,
          targetPointSize.height.isFinite, targetPointSize.height > 0,
          scale.isFinite, scale > 0
    else {
        return nil
    }

    return ScrubThumbnailRequestKey(
        second: second,
        controllerID: ObjectIdentifier(controller),
        mediaIdentifier: controller.mediaIdentifier
    )
}

@MainActor
final class ScrubThumbnailPreviewState: ObservableObject {
    private static let initialPreviewDelayNanoseconds: UInt64 = 200_000_000
    @Published private(set) var image: CGImage?
    @Published private(set) var isLoading = false

    @Published private var retainedKey: ScrubThumbnailRequestKey?

    private var generation: UInt64 = 0
    private var hasEnteredPreviewSession = false

    var hasState: Bool {
        image != nil || isLoading
    }

    /// 等待首次 200 ms 时还没有图片和 spinner，但也必须在离开时结束会话。
    var hasSession: Bool {
        retainedKey != nil || hasState
    }

    func retainingRequest(near key: ScrubThumbnailRequestKey?) -> ScrubThumbnailRequestKey? {
        guard let key, let retainedKey,
              key.controllerID == retainedKey.controllerID,
              key.mediaIdentifier == retainedKey.mediaIdentifier,
              abs(Double(key.second) - Double(retainedKey.second)) <= 3
        else {
            return key
        }
        // 锚点始终是原请求的位置；连续小幅移动不能让复用范围无限漂移。
        return retainedKey
    }

    func reset() {
        generation &+= 1
        retainedKey = nil
        image = nil
        isLoading = false
        hasEnteredPreviewSession = false
    }

    func cancelRequests(using controller: PlayerController?) {
        reset()
        controller?.cancelScrubThumbnailRequests()
    }

    func request(
        key: ScrubThumbnailRequestKey?,
        controller: PlayerController?,
        targetPointSize: CGSize,
        scale: CGFloat
    ) async {
        guard !Task.isCancelled else {
            return
        }
        guard let key, let controller else {
            if hasSession {
                cancelRequests(using: controller)
            }
            return
        }

        await request(key: key) { second, immediately in
            await controller.requestScrubThumbnail(
                time: TimeInterval(second), targetPointSize: targetPointSize, scale: scale,
                immediately: immediately
            )
        }
    }

    func request(
        key: ScrubThumbnailRequestKey,
        loadThumbnail: (Int, Bool) async -> ThumbnailResult?
    ) async {
        guard !Task.isCancelled else {
            return
        }
        if retainedKey?.controllerID != key.controllerID || retainedKey?.mediaIdentifier != key.mediaIdentifier {
            hasEnteredPreviewSession = false
        }
        generation &+= 1
        let requestGeneration = generation
        retainedKey = key
        image = nil

        // 首次经过进度条可能只是鼠标掠过；只有稳定停留 200 ms 才进入预览会话。
        // 原请求前后 3 秒内保持 task identity，轻微移动不会重新计时。
        let isInitialRequest = !hasEnteredPreviewSession
        if isInitialRequest {
            do {
                try await Task.sleep(
                    nanoseconds: Self.initialPreviewDelayNanoseconds
                )
            } catch {
                return
            }
            guard !Task.isCancelled, generation == requestGeneration else {
                return
            }
            hasEnteredPreviewSession = true
        }

        isLoading = true

        // 首次等待已在预览状态中完成；进入预览会话后的新位置由 controller
        // 统一执行 100 ms trailing debounce。
        let result = await loadThumbnail(key.second, isInitialRequest)
        guard !Task.isCancelled, generation == requestGeneration else {
            return
        }

        image = result.flatMap { makeScrubThumbnailImage(from: $0.imageData) }
        isLoading = false
    }
}

/// 原生进度条的编辑目标独立于内核时间；仅由 visionOS 播放器使用。
@MainActor
final class PlayerSliderScrubState: ObservableObject {
    @Published private(set) var targetTime: Int?
    @Published private(set) var isEditing = false
    private var generation: UInt64 = 0
    private var submittedGeneration: UInt64?

    func begin(at currentTime: Int) {
        guard !isEditing else {
            return
        }
        generation &+= 1
        isEditing = true
        // 原生 Slider 可能先写入点击位置，再通知开始编辑。
        if targetTime == nil {
            targetTime = currentTime
        }
    }

    func update(to time: Int, onCommit: (@MainActor () -> Void)? = nil) {
        // 点击值先于开始回调到达时，也要立即隔离上一轮 seek 的回执。
        generation &+= 1
        targetTime = time
        guard !isEditing, let onCommit else {
            return
        }
        let updatedGeneration = generation
        // 原生 Slider 的点击／辅助功能调整可能只写 Binding，不回调编辑结束。
        // 等本次同步回调结束，若没有进入拖动，再提交离散变化；不添加手势或延时阈值。
        Task { @MainActor [weak self] in
            guard let self, !self.isEditing,
                  generation == updatedGeneration,
                  submittedGeneration != updatedGeneration
            else {
                return
            }
            onCommit()
        }
    }

    func end() -> (time: Int, generation: UInt64)? {
        isEditing = false
        guard let targetTime, submittedGeneration != generation else {
            return nil
        }
        submittedGeneration = generation
        return (targetTime, generation)
    }

    func complete(generation: UInt64) {
        guard self.generation == generation, !isEditing else {
            return
        }
        targetTime = nil
    }

    func reset() {
        generation &+= 1
        submittedGeneration = nil
        isEditing = false
        targetTime = nil
    }
}

#if !os(tvOS)

    struct ProgressSliderView: View {
        @Binding var currentTime: Int
        var totalTime: Int
        var controller: PlayerController?
        var foregroundColor: Color = .white
        var onEditingChanged: (Bool) -> Void

        #if !os(visionOS)
            @State private var isHovering = false
            @State private var isDragging = false
            @Environment(\.displayScale) private var displayScale
            @StateObject private var thumbnailPreview = ScrubThumbnailPreviewState()
        #endif
        #if os(macOS)
            @State private var hoverTime: Int? = nil
            @State private var hoverPosition: CGPoint? = nil
        #endif

        #if !os(visionOS)
            private func endPreviewSession() {
                guard thumbnailPreview.hasSession else {
                    return
                }
                thumbnailPreview.cancelRequests(using: controller)
            }
        #endif

        var body: some View {
            #if os(visionOS)
                spatialSlider
            #else
                HStack {
                    Text(currentTime.toString(for: .minOrHour))
                        .brightness(0.2)
                        .contentTextFont(.value, weight: .medium)
                        .foregroundColor(foregroundColor)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 60, alignment: .center)

                    Spacer()

                    CustomSlider(
                        value: $currentTime,
                        range: (0, totalTime),
                        knobWidth: 15,
                        onEditingChanged: { value in
                            let wasDragging = isDragging
                            isDragging = value
                            if value {
                                isHovering = true
                            } else {
                                if wasDragging {
                                    endPreviewSession()
                                }
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
                                let maxCardSize = CGSize(width: 320, height: 180)
                                let videoRatio: CGFloat = {
                                    guard let controller, controller.videoNaturalSize.width > 0,
                                          controller.videoNaturalSize.height > 0
                                    else {
                                        return 240.0 / 135.0
                                    }
                                    let s = controller.videoNaturalSize
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
                                    let shouldRequestPreview =
                                        isDragging || (isHovering && hoverTime != nil)
                                    let showPreview = shouldRequestPreview && thumbnailPreview.hasState
                                #else
                                    let timeValue: Int? = isDragging ? currentTime : nil
                                    let positionX: CGFloat? = isDragging ? sliderData.knobCenterX : nil
                                    let shouldRequestPreview = isDragging
                                    let showPreview = shouldRequestPreview
                                #endif

                                let tooltipX: CGFloat? = positionX.map { pos in
                                    let minX = halfWidth - outwardAllowance
                                    let maxX = geometry.size.width - halfWidth + outwardAllowance
                                    return min(max(pos, minX), maxX)
                                }

                                let requestKey = thumbnailPreview.retainingRequest(near: {
                                    guard shouldRequestPreview,
                                          let timeValue,
                                          let controller,
                                          geometry.size.width > 0
                                    else {
                                        return nil
                                    }
                                    return makeScrubThumbnailRequestKey(
                                        second: timeValue,
                                        controller: controller,
                                        targetPointSize: previewCardSize,
                                        scale: displayScale
                                    )
                                }())

                                ZStack {
                                    // 进度条背景（完整宽度）
                                    Rectangle()
                                        .fill(Color.clear)
                                        .frame(width: geometry.size.width)
                                    Capsule()
                                        .fill(foregroundColor.opacity(0.3))
                                        .brightness(0.2)
                                        .frame(width: geometry.size.width, height: isHovering ? 5 : 3)
                                        .position(
                                            x: geometry.size.width * 0.5, y: geometry.size.height * 0.5
                                        )

                                    // 已完成的进度条（从左边到锚点中心）
                                    if sliderData.knobCenterX > 0 {
                                        Capsule()
                                            .fill(foregroundColor)
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
                                                    .fill(foregroundColor.opacity(0.8))
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
                                        .fill(foregroundColor)
                                        .brightness(0.2)
                                        .frame(
                                            width: sliderData.knobSize.width,
                                            height: sliderData.knobSize.height
                                        )
                                        .position(
                                            x: sliderData.knobCenterX, y: geometry.size.height * 0.5
                                        )
                                        .opacity(isHovering ? 0.8 : 1)

                                    if controller != nil, showPreview, let timeValue, let tooltipX {
                                        ScrubThumbnailCardView(
                                            image: thumbnailPreview.image,
                                            isLoading: thumbnailPreview.isLoading,
                                            timeText: timeValue.toString(for: .minOrHour),
                                            videoAspectRatio: videoRatio
                                        )
                                        .frame(
                                            width: previewCardSize.width, height: previewCardSize.height
                                        )
                                        .position(x: tooltipX, y: previewCardY)
                                    }

                                    #if os(macOS)
                                        // 时间位于进度条上方，与下方章节名称形成对应布局。
                                        if let timeValue, let positionX {
                                            let timeText = timeValue.toString(for: .minOrHour)
                                            let estimatedCharacterWidth: CGFloat = 7
                                            let timeTextWidth = max(
                                                32,
                                                CGFloat(timeText.count) * estimatedCharacterWidth
                                            )
                                            let timeHalfWidth = timeTextWidth / 2
                                            let timeOverflow: CGFloat = 6
                                            let timeX = min(
                                                max(positionX, timeHalfWidth - timeOverflow),
                                                geometry.size.width - timeHalfWidth + timeOverflow
                                            )

                                            Text(timeText)
                                                .brightness(0.2)
                                                .contentTextFont(.caption, weight: .semibold)
                                                .foregroundColor(.white)
                                                .lineLimit(1)
                                                .position(x: timeX, y: 8)
                                        }

                                        // 显示章节提示（下方）
                                        if let controller, let timeValue, let positionX {
                                            if let chapter = controller.chapters.first(where: {
                                                chapter in
                                                TimeInterval(timeValue) >= chapter.start
                                                    && TimeInterval(timeValue) < chapter.end
                                            }), !chapter.title.isEmpty {
                                                // 估算文本宽度：12pt 字体，每个字符约 7pt。
                                                let estimatedCharWidth: CGFloat = 7
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
                                                    .contentTextFont(.caption)
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                                    .position(x: chapterX, y: geometry.size.height - 8)
                                            }
                                        }
                                    #endif
                                }
                                .task(id: requestKey) {
                                    await thumbnailPreview.request(
                                        key: requestKey,
                                        controller: controller,
                                        targetPointSize: previewCardSize,
                                        scale: displayScale
                                    )
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
                                        endPreviewSession()
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
                                endPreviewSession()
                                hoverTime = nil
                                hoverPosition = nil
                            }
                        #endif
                    }
                    .onDisappear {
                        endPreviewSession()
                    }

                    Spacer()

                    Text(totalTime.toString(for: .minOrHour))
                        .brightness(0.2)
                        .contentTextFont(.value, weight: .medium)
                        .foregroundColor(foregroundColor)
                        .fixedSize(horizontal: true, vertical: false)
                        .frame(minWidth: 60, alignment: .center)
                }
            #endif
        }

        #if os(visionOS)
            /// 系统滑块负责注视、捏合和辅助功能；缩略图由视频层承载，避免被 Ornament 裁切。
            private var spatialSlider: some View {
                VStack(spacing: 0) {
                    Slider(
                        value: Binding(
                            get: { Double(currentTime) },
                            set: { currentTime = Int($0) }
                        ),
                        in: 0 ... Double(max(totalTime, 1)),
                        step: 1,
                        onEditingChanged: onEditingChanged
                    ) {
                        Text("播放进度")
                    }
                    .accessibilityValue(currentTime.toString(for: .minOrHour))
                    .accessibilityIdentifier("player.seekSlider")
                    HStack {
                        Text(currentTime.toString(for: .minOrHour))
                            .accessibilityIdentifier("player.seekPosition")
                        Spacer()
                        Text(totalTime.toString(for: .minOrHour))
                    }
                    .font(.body.monospacedDigit())
                }
            }
        #endif
    }
#endif

struct PlayerSliderView: View {
    @ObservedObject var coordinator: CinePlayer.Coordinator
    /// 监听播放进度
    @ObservedObject var progress: PlayingProgress
    #if os(visionOS)
        @ObservedObject var scrubState: PlayerSliderScrubState
    #endif

    #if !os(tvOS)
        @State private var isHovering = false
    #else
        var isHovering: Bool
        var isSeeking: Bool = false
        var showsSeekingThumbnail: Bool = true
        var seekingPreviewTime: Int?
        var seekingTotalTime: Int?
        @Environment(\.displayScale) private var displayScale
        @StateObject private var thumbnailPreview = ScrubThumbnailPreviewState()
    #endif
    var onProgressEditingChanged: (Bool, Int) -> Void

    private var previewCurrentTime: Int {
        #if os(tvOS)
        isSeeking ? (seekingPreviewTime ?? progress.currentTime) : progress.currentTime
        #else
        progress.currentTime
        #endif
    }
    private var previewTotalTime: Int {
        #if os(tvOS)
        isSeeking ? (seekingTotalTime ?? progress.totalTime) : progress.totalTime
        #else
        progress.totalTime
        #endif
    }

    var body: some View {
        if progress.totalTime <= 0 {
            // 未知时长只展示已播放时间，不提供没有有效范围的百分比拖动。
            HStack {
                Text(progress.currentTime.toString(for: .minOrHour))
                    .accessibilityIdentifier("player.seekPosition")
                Spacer()
                Text("未知")
                    .accessibilityLabel(Text("总时长未知"))
                    .accessibilityIdentifier("player.unknownDuration")
            }
            #if os(visionOS)
            .font(.body.monospacedDigit())
            #elseif os(iOS) || os(macOS)
            .contentTextFont(.value, weight: .medium)
            .monospacedDigit()
            #else
            .font(.caption.monospacedDigit())
            #endif
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
        } else if progress.currentTime > progress.totalTime {
            // 直接返回空视图
            EmptyView()
        } else {
            #if os(visionOS)
                ProgressSliderView(
                    currentTime: Binding(
                        get: { scrubState.targetTime ?? progress.currentTime },
                        set: { time in
                            scrubState.update(to: time) {
                                onProgressEditingChanged(false, time)
                            }
                        }
                    ),
                    totalTime: progress.totalTime,
                    controller: coordinator.controller,
                    onEditingChanged: { editing in
                        if editing {
                            scrubState.begin(at: progress.currentTime)
                        }
                        onProgressEditingChanged(editing, scrubState.targetTime ?? progress.currentTime)
                    }
                )
            #elseif !os(tvOS)
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
                        let currentTime = CGFloat(previewCurrentTime)
                        let totalTime = CGFloat(previewTotalTime)
                        let controller = coordinator.controller
                        // 按视频画面原始比例计算缩略图卡片尺寸，限制在最大宽高内
                        let maxCardSize = CGSize(width: 480, height: 270)
                        let videoRatio: CGFloat = {
                            guard let controller, controller.videoNaturalSize.width > 0,
                                  controller.videoNaturalSize.height > 0
                            else {
                                return 480.0 / 270.0
                            }
                            let s = controller.videoNaturalSize
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
                        let shouldRequestPreview = isSeeking && showsSeekingThumbnail
                        let showPreviewThumbnail = shouldRequestPreview && thumbnailPreview.hasState

                        let requestKey = thumbnailPreview.retainingRequest(near: {
                            guard shouldRequestPreview,
                                  let controller,
                                  width > 0
                            else {
                                return nil
                            }
                            return makeScrubThumbnailRequestKey(
                                second: previewCurrentTime,
                                controller: controller,
                                targetPointSize: previewCardSize,
                                scale: displayScale
                            )
                        }())

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
                                                / CGFloat(TimeInterval(previewTotalTime))
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

                            if showPreviewThumbnail {
                                let knobX = (width * currentTime) / max(totalTime, 1)
                                let cardX = min(
                                    max(knobX, halfWidth), width - halfWidth - rightMargin
                                )
                                ScrubThumbnailCardView(
                                    image: thumbnailPreview.image,
                                    isLoading: thumbnailPreview.isLoading,
                                    timeText: previewCurrentTime.toString(for: .minOrHour),
                                    videoAspectRatio: videoRatio
                                )
                                .frame(width: previewCardSize.width, height: previewCardSize.height)
                                .position(x: cardX, y: previewCardY)
                                .accessibilityIdentifier("player.seekThumbnail")
                            }
                        }
                        .task(id: requestKey) {
                            await thumbnailPreview.request(
                                key: requestKey,
                                controller: controller,
                                targetPointSize: previewCardSize,
                                scale: displayScale
                            )
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 24)

                    HStack {
                        Text(previewCurrentTime.toString(for: .minOrHour))
                            .accessibilityIdentifier("player.seekPosition")
                        Spacer()
                        Text(previewTotalTime.toString(for: .minOrHour))
                    }
                    .font(.caption.monospacedDigit())
                    .frame(maxWidth: .infinity)
                }
                .onDisappear {
                    thumbnailPreview.cancelRequests(using: coordinator.controller)
                }

            #endif
        }
    }
}
