import SwiftUI

extension View {
    func playerToastFont() -> some View {
        #if os(tvOS)
            font(.title3.weight(.bold))
        #else
            font(.headline)
        #endif
    }

    func playerToastIconFont() -> some View {
        #if os(tvOS)
            font(.title3.weight(.bold))
        #else
            font(.headline)
        #endif
    }
}
