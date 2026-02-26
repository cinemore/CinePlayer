import SwiftUI

struct ContentView: View {
    var body: some View {
        PlayerRootView()
            .environment(\.colorScheme, .dark)
            .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(PlayerSessionStore())
        .environmentObject(VideoPlayerModel())
}
