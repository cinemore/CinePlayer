import SwiftUI

#if canImport(UIKit)
    import UIKit
#else
    import AppKit
#endif

struct ScrubThumbnailCardView: View {
    let imageData: Data?
    let isLoading: Bool
    let timeText: String
    /// 视频画面原始宽高比（宽/高），为 nil 或无效时使用 16:9
    var videoAspectRatio: CGFloat?

    private let cornerRadius: CGFloat = 16

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
                if let imageData, let image = decodeImage(from: imageData) {
                    imageView(image)
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

            Text(timeText)
                .font(.caption.weight(.semibold))
                .foregroundColor(.white)
                .brightness(0.2)
                .padding(.vertical, 4)
                .shadow(color: .black, radius: 16, x: 0, y: 0)
        }
        .aspectRatio(effectiveAspectRatio, contentMode: .fit)
        .modifier(
            GlassEffectModifier(
                cornerRadius: cornerRadius,
                useCapsule: false
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(lineWidth: 1)
                .foregroundStyle(.quaternary)
        }
        .allowsHitTesting(false)
    }

    #if canImport(UIKit)
        private func decodeImage(from data: Data) -> UIImage? {
            UIImage(data: data)
        }

        private func imageView(_ image: UIImage) -> some View {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        }
    #else
        private func decodeImage(from data: Data) -> NSImage? {
            NSImage(data: data)
        }

        private func imageView(_ image: NSImage) -> some View {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .clipped()
        }
    #endif
}
