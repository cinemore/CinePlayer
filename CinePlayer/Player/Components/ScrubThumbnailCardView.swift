import CinePlayerSDK
import SwiftUI

struct ScrubThumbnailCardView: View {
    let image: CGImage?
    let isLoading: Bool
    let timeText: String
    /// 视频画面原始宽高比（宽/高），为 nil 或无效时使用 16:9
    var videoAspectRatio: CGFloat?

    private var cornerRadius: CGFloat {
        #if os(tvOS)
            28
        #else
            16
        #endif
    }

    /// 用于 .aspectRatio 的有效比例，保证 > 0
    private var effectiveAspectRatio: CGFloat {
        guard let r = videoAspectRatio, r > 0 else {
            return 16.0 / 9.0
        }
        return r
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Group {
                if let image {
                    Image(decorative: image, scale: 1, orientation: .up)
                        .allowedDynamicRange(.high)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                } else if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Color.black.opacity(0.25)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            #if !os(macOS)
                Text(timeText)
                #if os(visionOS)
                    .font(.body.weight(.semibold).monospacedDigit())
                #elseif os(iOS)
                    .contentTextFont(.caption, weight: .semibold)
                    .monospacedDigit()
                #else
                    .font(.caption.weight(.semibold))
                #endif
                    .foregroundColor(.white)
                    .brightness(0.2)
                    .padding(.vertical, 4)
                    .shadow(color: .black, radius: 16, x: 0, y: 0)
            #endif
        }
        .aspectRatio(effectiveAspectRatio, contentMode: .fit)
        #if os(visionOS)
            .clipShape(ContainerRelativeShape())
            .glassBackgroundEffect()
        #else
            .modifier(
                GlassEffectModifier(
                    cornerRadius: cornerRadius,
                    useCapsule: false
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(lineWidth: 1)
                    .foregroundStyle(.quaternary)
            }
        #endif
            .allowsHitTesting(false)
    }
}
