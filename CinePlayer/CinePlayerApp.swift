import SwiftUI
import SwiftData
#if os(iOS)
import UIKit
#endif
#if os(macOS)
import AppKit
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
    @StateObject private var windowController = PlayerWindowController()
    @State private var aboutWindow: NSWindow?
    #endif

    var body: some Scene {
        #if os(macOS)
        Window("CinePlayer", id: "main-window") {
            rootContentView
        }
//        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("关于") {
                    showAboutWindow()
                }
            }
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
            .modelContainer(for: [PlaybackHistoryRecord.self])
            #if os(macOS)
                .environmentObject(windowController)
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

    #if os(macOS)
    private func showAboutWindow() {
        if let aboutWindow {
            aboutWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: AboutPage())
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        aboutWindow = window
    }
    #endif
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
