#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CinePlayerSDK

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func openFileFromMenuOrDock() {
        DispatchQueue.main.async { [weak self] in
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = false

            var videoTypes: [UTType] = [.video]
            for ext in VideoSupportedFormats.extensions {
                if let type = UTType(filenameExtension: ext) {
                    videoTypes.append(type)
                }
            }
            panel.allowedContentTypes = videoTypes

            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                Task { @MainActor in
                    self?.routeOpen(url: url)
                }
            }
        }
    }

    func openURLFromMenuOrDock() {
        DispatchQueue.main.async { [weak self] in
            let alert = NSAlert()
            alert.messageText = "打开URL"
            alert.informativeText = "请输入要播放的视频地址（例如 http 或 https 链接）。"

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 320, height: 24))
            input.placeholderString = "https://example.com/video.m3u8"
            alert.accessoryView = input

            alert.addButton(withTitle: "打开")
            alert.addButton(withTitle: "取消")

            let response = alert.runModal()
            guard response == .alertFirstButtonReturn else { return }

            guard let url = Self.resolveInputURL(input.stringValue) else { return }
            Task { @MainActor in
                self?.routeOpen(url: url)
            }
        }
    }

    /// 将用户输入解析为 URL（支持已有 scheme、绝对路径、裸地址）
    private static func resolveInputURL(_ rawInput: String) -> URL? {
        let text = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }

        if let url = URL(string: text), url.scheme != nil {
            return url
        }

        let expandedPath = (text as NSString).expandingTildeInPath
        if expandedPath.hasPrefix("/") {
            return URL(fileURLWithPath: expandedPath)
        }

        return URL(string: text)
    }

    func applicationDockMenu(_: NSApplication) -> NSMenu? {
        let menu = NSMenu()

        let openFileItem = NSMenuItem(
            title: "打开文件…",
            action: #selector(handleDockOpenFile),
            keyEquivalent: ""
        )
        openFileItem.target = self
        menu.addItem(openFileItem)

        let openURLItem = NSMenuItem(
            title: "打开URL…",
            action: #selector(handleDockOpenURL),
            keyEquivalent: ""
        )
        openURLItem.target = self
        menu.addItem(openURLItem)

        return menu
    }

    @objc private func handleDockOpenFile() {
        openFileFromMenuOrDock()
    }

    @objc private func handleDockOpenURL() {
        openURLFromMenuOrDock()
    }

    // SwiftUI 单窗口 Scene 在收到 LaunchServices 的 open 事件时，会先关闭现有窗口
    // 再重建，期间窗口数为 0；若不覆盖默认策略，AppKit 会触发「最后窗口关闭即退出」，
    // 表现为拖文件到 Dock 图标后 app 闪退。
    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    func application(_: NSApplication, open urls: [URL]) {
        cinemoreLog(level: .debug, "[OpenFlow] application:open urls=\(urls)")
        guard let url = urls.first else {
            cinemoreLog(level: .debug, "[OpenFlow] application:open received empty url list")
            return
        }
        Task { @MainActor in
            routeOpen(url: url)
        }
    }

    /// 单一入口：把 URL 直接交给 sessionStore 触发 replace 语义，并保证主窗口可见。
    /// 不再走 NotificationCenter — 通知在 SwiftUI Window Scene 切换的窗口期可能丢失。
    @MainActor
    private func routeOpen(url: URL) {
        guard Self.isSupportedScheme(url) else {
            cinemoreLog(level: .debug, "[OpenFlow] application:open ignored unsupported url=\(url)")
            return
        }
        PlayerSessionStore.shared.open(url: url)
        cinemoreLog(level: .debug, "[OpenFlow] application:open dispatched url=\(url)")

        guard NSApp.isActive else {
            // Cold launch / 后台被唤起：SwiftUI 自己会建窗口，rescue 无意义且会
            // 触发 AppKit 在初始化窗口上的 constraint loop crash。
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        // app 已在运行收到新 open：SwiftUI 会把现有窗口 orderOut，这里推迟一次 orderFront
        // 把它救回来。避开同步调用，留给 SwiftUI 完成自己的 close 流程。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            guard let window = Self.findMainSceneWindow(), !window.isVisible else { return }
            window.makeKeyAndOrderFront(nil)
        }
    }

    private static func isSupportedScheme(_ url: URL) -> Bool {
        if url.isFileURL { return true }
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// 优先按我们在 `Window(_, id:)` 设置的 identifier 匹配；匹配不上时退回到
    /// SwiftUI 私有窗口类名启发（Apple 改名后 rescue 静默失效，影响仅是用户需点 dock）。
    private static func findMainSceneWindow() -> NSWindow? {
        if let byID = NSApp.windows.first(where: {
            $0.identifier?.rawValue.contains(mainSceneID) == true
        }) {
            return byID
        }
        return NSApp.windows.first { window in
            String(describing: type(of: window)).contains("AppKitWindow")
        }
    }

    private static let mainSceneID = "main-window"
}
#endif
