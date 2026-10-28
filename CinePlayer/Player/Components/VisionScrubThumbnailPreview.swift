#if os(visionOS)
import CinePlayerSDK
import SwiftUI

/// 由视频层在面板上方呈现，独立于底部 Ornament 的裁切范围。
struct VisionScrubThumbnailPreview: View {
    let time: Int
    let controller: PlayerController
    let width: CGFloat

    @Environment(\.displayScale) private var displayScale
    @StateObject private var thumbnailPreview = ScrubThumbnailPreviewState()

    private var videoAspectRatio: CGFloat {
        let size = controller.videoNaturalSize
        guard size.width.isFinite, size.height.isFinite,
              size.width > 0, size.height > 0 else { return 16.0 / 9.0 }
        return size.width / size.height
    }

    var body: some View {
        let previewSize = CGSize(width: width, height: width / videoAspectRatio)
        let key = thumbnailPreview.retainingRequest(near: makeScrubThumbnailRequestKey(
            second: time, controller: controller, targetPointSize: previewSize, scale: displayScale
        ))
        ZStack {
            if thumbnailPreview.hasState {
                ScrubThumbnailCardView(
                    image: thumbnailPreview.image, isLoading: thumbnailPreview.isLoading,
                    timeText: time.toString(for: .minOrHour), videoAspectRatio: videoAspectRatio
                )
            }
        }
        .frame(width: previewSize.width, height: previewSize.height)
        .allowsHitTesting(false)
        .task(id: key) {
            await thumbnailPreview.request(
                key: key, controller: controller, targetPointSize: previewSize, scale: displayScale
            )
        }
        .onDisappear { thumbnailPreview.cancelRequests(using: controller) }
    }
}
#endif
