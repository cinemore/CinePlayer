## 1. Mac AppDelegate URL routing

- [ ] 1.1 Update `MacAppDelegate.application(_:open:)` to forward both file and non-file URLs via `NotificationCenter` to `cinePlayerOpenFileEvent` / `cinePlayerURLEvent`.
- [ ] 1.2 Verify that Finder “打开方式 → CinePlayer” 与双击默认播放器文件都会触发相应通知，并在运行时观察 `PlayerSessionStore.open(url:)` 被调用一次。

## 2. SwiftUI root view integration for macOS

- [ ] 2.1 Adjust macOS branch of `CinePlayerApp.rootContentView` to rely solely on `onReceive` for `cinePlayerOpenFileEvent` / `cinePlayerURLEvent`, removing `.onOpenURL` handling for macOS file URLs.
- [ ] 2.2 Manually test应用内“打开文件…”、Dock 菜单、“拖拽到窗口”等入口，确认行为与变更前一致且不会重复打开同一文件。

## 3. Build and platform verification

- [ ] 3.1 Run xcodebuild for iOS, iOS Simulator, macOS, tvOS, tvOS Simulator, visionOS, and visionOS Simulator targets to ensure no regressions.
- [ ] 3.2 Document verification results in the change discussion or PR description when integrating this change.

