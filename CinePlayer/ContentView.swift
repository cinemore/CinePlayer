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
        #elseif os(tvOS)
        TVOSPlayerHostView()
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

#if os(tvOS)
private struct TVOSPlayerHostView: View {
    @EnvironmentObject private var sessionStore: PlayerSessionStore
    @EnvironmentObject private var playerModel: VideoPlayerModel

    private var isPlayerPresented: Binding<Bool> {
        Binding(
            get: { sessionStore.currentSource != nil },
            set: { isPresented in
                if !isPresented {
                    playerModel.close()
                    sessionStore.close()
                }
            }
        )
    }

    var body: some View {
        TabView {
            PlayerOpenView()
                .tabItem {
                    Label("播放", systemImage: "play.rectangle.fill")
                }

            NavigationStack {
                PlaybackHistoryListView()
            }
            .tabItem {
                Label("历史", systemImage: "clock.arrow.circlepath")
            }

            NavigationStack {
                TVOSSettingsView()
            }
            .tabItem {
                Label("设置", systemImage: "gearshape")
            }
        }
        .fullScreenCover(isPresented: isPlayerPresented) {
            PlayerControlView()
        }
    }
}
#endif

#Preview {
    ContentView()
        .environmentObject(PlayerSessionStore())
        .environmentObject(VideoPlayerModel())
}
