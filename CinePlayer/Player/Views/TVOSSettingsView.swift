#if os(tvOS)
import SwiftUI

struct TVOSSettingsView: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @StateObject private var adapter = PlaySettingParityAdapter()

    var body: some View {
        PlaySettingPage(adapter: adapter, hideBackground: true)
            .onAppear {
                adapter.bind(sessionStore: sessionStore)
            }
    }
}
#endif
