#if os(macOS)
import AppKit
import SwiftUI
import UniformTypeIdentifiers
import CinePlayerSDK

extension Notification.Name {
    static let cinePlayerOpenFileEvent = Notification.Name("CinePlayerOpenFileEvent")
    static let cinePlayerURLEvent = Notification.Name("CinePlayerURLEvent")
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func openFileFromMenuOrDock() {
        DispatchQueue.main.async {
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
                NotificationCenter.default.post(
                    name: .cinePlayerOpenFileEvent,
                    object: nil,
                    userInfo: ["url": url]
                )
            }
        }
    }

    /// 完全复制 cinemore：输入 URL 后交由系统打开。
    func openURLFromMenuOrDock() {
        DispatchQueue.main.async {
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

            let text = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty, let url = URL(string: text) else { return }
            NSWorkspace.shared.open(url)
        }
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

    func application(_: NSApplication, open urls: [URL]) {
        cinemoreLog(level: .debug, "[OpenFlow] application:open urls=\(urls)")
        guard let url = urls.first else {
            cinemoreLog(level: .debug, "[OpenFlow] application:open received empty url list")
            return
        }

        let userInfo = ["url": url]
        if url.isFileURL {
            NotificationCenter.default.post(
                name: .cinePlayerOpenFileEvent,
                object: nil,
                userInfo: userInfo
            )
        } else {
            NotificationCenter.default.post(
                name: .cinePlayerURLEvent,
                object: nil,
                userInfo: userInfo
            )
        }

        cinemoreLog(level: .debug, "[OpenFlow] application:open dispatched url=\(url)")

        // 确保应用被前置到顶层，用户能立刻看到播放界面
        NSApp.activate(ignoringOtherApps: true)
        // 如已有窗口存在，尽量将其置为 keyWindow
        NSApp.mainWindow?.makeKeyAndOrderFront(nil)
    }
}
#endif
