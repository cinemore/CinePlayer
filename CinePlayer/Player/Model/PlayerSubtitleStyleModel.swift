import Combine
import SwiftUI

#if !os(tvOS)
struct TextPosition: Equatable, Sendable {
    var verticalAlign: VerticalAlignment = .bottom
    var horizontalAlign: HorizontalAlignment = .center
    var leftMargin: CGFloat = 0
    var rightMargin: CGFloat = 0
    var verticalMargin: CGFloat = 5

    mutating func ass(alignment: String?) {
        switch alignment {
        case "1":
            verticalAlign = .bottom
            horizontalAlign = .leading
        case "2":
            verticalAlign = .bottom
            horizontalAlign = .center
        case "3":
            verticalAlign = .bottom
            horizontalAlign = .trailing
        case "4":
            verticalAlign = .center
            horizontalAlign = .leading
        case "5":
            verticalAlign = .center
            horizontalAlign = .center
        case "6":
            verticalAlign = .center
            horizontalAlign = .trailing
        case "7":
            verticalAlign = .top
            horizontalAlign = .leading
        case "8":
            verticalAlign = .top
            horizontalAlign = .center
        case "9":
            verticalAlign = .top
            horizontalAlign = .trailing
        default:
            break
        }
    }
}

@MainActor
final class PlayerSubtitleStyleModel: ObservableObject {
    static let shared = PlayerSubtitleStyleModel()

    @Published var enableBitmapCustomization = false
    @Published var bitmapScale: CGFloat = 1.0
    @Published var bitmapHorizontalOffset: CGFloat = 0
    @Published var bitmapVerticalOffset: CGFloat = 0
    @Published var bitmapOpacity: Double = 1.0

    @Published var boostHDRbrightness: Double = 0.5

    @Published var overwriteSubtitleStyle = true
    @Published var textColor: Color = .white
    @Published var textColorOpacity: Double = 1.0
    @Published var textFontSize: CGFloat = 16
    @Published var textBold = false
    @Published var textItalic = false
    @Published var textPosition = TextPosition()
    @Published var letterSpacing: CGFloat = 0

    @Published var outlineColor: Color = .black
    @Published var outlineColorOpacity: Double = 1.0
    @Published var outlineWidth: CGFloat = 1
    @Published var borderStyle: Int = 1

    @Published var shadowColor: Color = .clear
    @Published var shadowColorOpacity: Double = 0.0
    @Published var shadowWidth: CGFloat = 1
}

typealias SubtitleStyleModel = PlayerSubtitleStyleModel
#endif
