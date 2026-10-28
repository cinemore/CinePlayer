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
    private let historyContainer: ModelContainer = {
        #if DEBUG
        let inMemory = ProcessInfo.processInfo.environment["CINEPLAYER_TEST_STORAGE"] == "memory"
        #else
        let inMemory = false
        #endif
        do {
            return try ModelContainer(for: PlaybackHistoryRecord.self,
                                      configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory))
        } catch { fatalError("无法打开播放历史：\(error)") }
    }()
    @StateObject private var sessionStore = PlayerSessionStore.shared
    @StateObject private var playerModel = VideoPlayerModel()
    #if os(visionOS)
    @StateObject private var immersiveCoordinator = VisionImmersivePlaybackCoordinator()
    @StateObject private var visionSettings = VisionSettings.shared
    #endif

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
        #elseif os(visionOS)
        Window("CinePlayer", id: "main-window") {
            rootContentView
                // 外部文件交给已有主窗口，避免系统为单实例 Window 再创建场景。
                .handlesExternalEvents(preferring: ["*"], allowing: ["*"])
        }
        .defaultSize(width: 1280, height: 720)

        Window("播放", id: VisionPlayerWindowView.windowID) {
            VisionPlayerWindowView()
                .environmentObject(sessionStore)
                .environmentObject(playerModel)
                .environmentObject(immersiveCoordinator)
                .environmentObject(visionSettings)
                .modelContainer(historyContainer)
        }
        .defaultSize(width: 1920, height: 1080)
        .restorationBehavior(.disabled)
        .defaultLaunchBehavior(.suppressed)
        ImmersiveSpace(id: VisionImmersiveSpaceView.spaceID) {
            VisionImmersiveSpaceView()
                .environmentObject(sessionStore)
                .environmentObject(playerModel)
                .environmentObject(immersiveCoordinator)
                .environmentObject(visionSettings)
        }
        .immersionStyle(
            selection: visionSettings.immersionStyleBinding.styleErased,
            in: ProgressiveImmersionStyle(), MixedImmersionStyle(), FullImmersionStyle()
        )
        .immersiveContentBrightness(.dim)
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
            .modelContainer(historyContainer)
            #if os(visionOS)
                .environmentObject(immersiveCoordinator)
                .environmentObject(visionSettings)
            #endif
            #if os(macOS)
                .environmentObject(windowController)
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
