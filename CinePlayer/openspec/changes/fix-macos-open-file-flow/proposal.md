## Why

当前在 macOS 下，通过 Finder 右键视频文件选择“打开方式 → CinePlayer”或双击已被 CinePlayer 设为默认播放器的文件时，应用可以被启动或激活，但文件并不总是被正确打开并交给播放器会话。这是因为文件 URL 在 `NSApplicationDelegate.application(_:open:)` 中被忽略，代码假定 SwiftUI 的 `.onOpenURL` 会统一接管，但在某些打开路径下系统并不会再次通过 `.onOpenURL` 分发 `file://` URL，导致文件打开流程被中途丢弃。现在需要修正这一行为，使所有从系统传入的文件 URL 都能可靠地进入统一的播放入口。

## What Changes

- 在 `MacAppDelegate.application(_:open:)` 中显式处理 `file://` URL，将其通过 `NotificationCenter` 转发为 `.cinePlayerOpenFileEvent`，与菜单/Dock 的“打开文件…”路径保持一致。
- 调整 `CinePlayerApp` 中 macOS 分支的 `rootContentView`，让文件打开流程完全依赖通知驱动（`cinePlayerOpenFileEvent` / `cinePlayerURLEvent`），不再依赖 `.onOpenURL` 来处理 macOS 的文件 URL，避免重复和不确定行为。
- 保持 iOS 等其他平台上使用 SwiftUI `.onOpenURL` 的实现不变，仅收敛 macOS 的行为，使“右键用本 App 打开”和“拖拽/文件选择器”最终都通过同一个 `sessionStore.open(url:)` 入口。

## Capabilities

### New Capabilities
- `macos-open-file-consistent-flow`: 统一并可靠地处理 macOS 平台下所有来自系统的文件/URL 打开请求（包括 Finder 右键打开方式、双击默认应用、Dock 图标、菜单命令等），始终通过单一的数据流路由到播放器会话。

### Modified Capabilities
- `player-open-entrypoints`: 现有的播放器打开入口（URL 输入、文件选择器、拖拽、菜单/Dock）在 macOS 上增加了来自系统文档打开的路径，但不改变已有入口的可见行为，仅保证它们在内部共享同一条 `sessionStore.open(url:)` 数据流。

## Impact

- 影响 `CinePlayer/CinePlayerApp.swift` 中 macOS 场景的根视图配置，需调整 `.onOpenURL` 使用方式。
- 影响 `CinePlayer/Player/App/MacAppDelegate.swift` 中对 `application(_:open:)` 的实现逻辑，增加对 `file://` URL 的统一转发处理。
- 变更仅限 macOS 平台行为，不影响 iOS/tvOS 上的打开流程；不涉及网络栈或播放内核，主要是应用层打开入口的行为修正。

