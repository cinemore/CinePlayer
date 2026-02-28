import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(iOS)
        TabView {
            IOSPlayerTabHostView()
                .tabItem {
                    Label("播放器", systemImage: "play.rectangle.fill")
                }

            NavigationStack {
                AboutPage()
            }
            .tabItem {
                Label("关于", systemImage: "info.circle")
            }
        }
        #else
        PlayerRootView()
        #endif
    }
}

#if os(iOS)
private struct IOSPlayerTabHostView: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore

    private var isPlayerPresented: Binding<Bool> {
        Binding(
            get: { sessionStore.currentSource != nil },
            set: { isPresented in
                if !isPresented {
                    sessionStore.close()
                }
            }
        )
    }

    var body: some View {
        PlayerOpenView()
            .fullScreenCover(isPresented: isPlayerPresented) {
                PlayerRootView()
            }
    }
}
#endif

#Preview {
    ContentView()
        .environmentObject(PlayerSessionStore())
        .environmentObject(VideoPlayerModel())
}
