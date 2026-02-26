import SwiftUI
#if os(iOS)
import UIKit
#endif

@main
struct CinePlayerApp: App {
    @StateObject private var sessionStore = PlayerSessionStore()
    @StateObject private var playerModel = VideoPlayerModel()

    #if os(iOS)
    @UIApplicationDelegateAdaptor(CinePlayerIOSAppDelegate.self) var iosAppDelegate
    #endif

    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) var macAppDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        Window("CinePlayer", id: "main-window") {
            rootContentView
        }
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(after: .newItem) {
                Button("打开文件…") {
                    macAppDelegate.openFileFromMenuOrDock()
                }
                .keyboardShortcut("o", modifiers: [.command])

                Button("打开URL…") {
                    macAppDelegate.openURLFromMenuOrDock()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }
        }
        #else
        WindowGroup {
            rootContentView
        }
        #endif
    }

    @ViewBuilder
    private var rootContentView: some View {
        ContentView()
            .environmentObject(sessionStore)
            .environmentObject(playerModel)
            #if os(macOS)
                .onOpenURL { url in
                    if url.isFileURL {
                        sessionStore.open(url: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .cinePlayerOpenFileEvent)) { notification in
                    if let url = notification.userInfo?["url"] as? URL {
                        sessionStore.open(url: url)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .cinePlayerURLEvent)) { notification in
                    if let url = notification.userInfo?["url"] as? URL {
                        sessionStore.open(url: url)
                    }
                }
            #else
                .onOpenURL { url in
                    if url.isFileURL {
                        sessionStore.open(url: url)
                    }
                }
            #endif
    }
}

#if os(iOS)
final class CinePlayerIOSAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _: UIApplication,
        supportedInterfaceOrientationsFor _: UIWindow?
    ) -> UIInterfaceOrientationMask {
        if UIDevice.current.userInterfaceIdiom != .phone {
            return .all
        }
        return PlatformServices.currentIOSPlayerOrientationLock()
    }
}
#endif
