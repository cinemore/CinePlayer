import SwiftUI

#if canImport(UIKit)
struct RoundedCornerShape: Shape {
    var corners: UIRectCorner
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
#else
struct RoundedCornerShape: Shape {
    var corners: Int = 0
    var radius: CGFloat

    func path(in rect: CGRect) -> Path {
        Path(roundedRect: rect, cornerRadius: radius, style: .continuous)
    }
}
#endif
