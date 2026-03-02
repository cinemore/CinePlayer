## Context

当前 CinePlayer 在 macOS 上通过多种入口打开媒体：应用内 URL 输入、SwiftUI `.fileImporter` 文件选择、拖拽文件、菜单栏与 Dock 中的“打开文件…”项，以及系统层面的 Finder 右键“打开方式…”或双击文件。应用内部已经将大部分入口收敛到 `PlayerSessionStore.open(url:)`，并通过 `NotificationCenter` 的 `cinePlayerOpenFileEvent` / `cinePlayerURLEvent` 在 SwiftUI 根视图中统一接收。但 `NSApplicationDelegate.application(_:open:)` 目前只对非 `file://` URL 发通知，假设文件 URL 会由 SwiftUI `.onOpenURL` 自动处理，这在 Finder 右键/双击的路径下并不可靠，导致部分文件打开请求被丢弃。

## Goals / Non-Goals

**Goals:**

- 确保所有来自系统（Finder 右键、双击默认应用、Dock 图标、URL Scheme 等）的 URL，在 macOS 上都能可靠地路由到 `PlayerSessionStore.open(url:)`。
- 统一 macOS 下文件/URL 打开的数据流，复用现有的通知机制，减少分支逻辑和平台特有行为假设。
- 保持 iOS/tvOS 上的 `.onOpenURL` 行为不变，只对 macOS 分支做最小侵入的修正。

**Non-Goals:**

- 不改变播放器内部对媒体 URL 的解析和播放实现，仅修正入口路由。
- 不引入新的窗口管理策略（例如多窗口播放），继续沿用现有的窗口控制逻辑。
- 不调整 Info.plist 中现有的文档类型或 URL Scheme 声明。

## Decisions

- **Decision 1：在 AppDelegate 中统一处理系统 URL，并通过通知转发**
  - 方案：在 `MacAppDelegate.application(_:open:)` 中，无论 URL 是否为 `file://`，都根据类型分别转发为 `cinePlayerOpenFileEvent` 或 `cinePlayerURLEvent`，由 SwiftUI 根视图统一调用 `sessionStore.open(url:)`。
  - 备选：继续依赖 SwiftUI `.onOpenURL` 处理 `file://`，在 AppDelegate 中保持忽略文件 URL。
  - 理由：系统是否、何时将文档 URL 透传到 SwiftUI `.onOpenURL` 具有实现细节差异，AppDelegate 是所有系统级打开路径的唯一可靠入口。通过通知转发可以最大程度重用现有逻辑，并且不会增加新的依赖。

- **Decision 2：在 macOS 场景下移除对 `.onOpenURL` 的依赖**
  - 方案：`CinePlayerApp` 的 macOS 分支不再使用 `.onOpenURL` 处理 URL，而是仅通过 `onReceive` 监听 `cinePlayerOpenFileEvent` / `cinePlayerURLEvent`。
  - 备选：保留 macOS `.onOpenURL` 并同时在 AppDelegate 中发送通知，通过去重逻辑防止重复打开。
  - 理由：单一路径更易于理解和维护，也避免了未来 SwiftUI 行为变化造成的双重处理或竞态。既然所有系统 URL 已经在 AppDelegate 被转为通知，就不再需要 macOS 的 `.onOpenURL`。

## Risks / Trade-offs

- **Risk：未来若在 macOS 上需要利用 `.onOpenURL` 处理额外场景**
  - Mitigation：可以在保持通知驱动为主的前提下，为特定 URL scheme 单独增加 `.onOpenURL` 逻辑，并在实现中显式避免与通知路径重复。

- **Risk：多 URL 打开请求目前只处理第一个**
  - Mitigation：当前 Info.plist 与 UI 都主要面向单文件播放场景。若将来需要批量播放，可在 `application(_:open:)` 中扩展为遍历所有 URL 并依次发送通知。

