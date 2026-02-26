import SwiftUI
import Foundation
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func roundedCorner(_ radius: CGFloat) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius))
    }

    func applyFocusable(_ enabled: Bool) -> some View {
        #if os(tvOS)
            return AnyView(focusable(enabled))
        #else
            return AnyView(self)
        #endif
    }

    @ViewBuilder
    func compatibleOnChange<Value: Equatable>(of value: Value, perform action: @escaping (Value) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *) {
            onChange(of: value) { _, newValue in
                action(newValue)
            }
        } else {
            onChange(of: value, perform: action)
        }
    }

    @ViewBuilder
    func compatibleOnChange<Value: Equatable>(of value: Value, perform action: @escaping (Value, Value) -> Void) -> some View {
        if #available(iOS 17.0, macOS 14.0, tvOS 17.0, visionOS 1.0, *) {
            onChange(of: value) { oldValue, newValue in
                action(oldValue, newValue)
            }
        } else {
            onChange(of: value) { newValue in
                action(value, newValue)
            }
        }
    }
}

extension Float {
    func rounded(to places: Int) -> Float {
        let multiplier = pow(10.0, Float(places))
        return (self * multiplier).rounded() / multiplier
    }

    var playbackRateText: String {
        let formatter = NumberFormatter()
        formatter.minimumIntegerDigits = 1
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        formatter.decimalSeparator = "."
        return formatter.string(from: NSNumber(value: self)) ?? String(format: "%.2f", self)
    }
}

extension Color {
    static let foreground = Color.white

    func toABGRHexString() -> String {
        #if canImport(UIKit)
        let rgbColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
            let a = 255 - Int(alpha * 255)
            let b = Int(blue * 255)
            let g = Int(green * 255)
            let r = Int(red * 255)
            return String(format: "&H%02X%02X%02X%02X", a, b, g, r)
        }
        return "&H00FFFFFF"
        #else
        let rgbColor = NSColor(self).usingColorSpace(.deviceRGB)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        if let rgbColor {
            rgbColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            let a = 255 - Int(alpha * 255)
            let b = Int(blue * 255)
            let g = Int(green * 255)
            let r = Int(red * 255)
            return String(format: "&H%02X%02X%02X%02X", a, b, g, r)
        }
        return "&H00FFFFFF"
        #endif
    }
}
