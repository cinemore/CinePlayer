## ADDED Requirements

### Requirement: macOS system file URL opens go through player session
应用在 macOS 上 **必须** 确保所有来自系统层面的文件 URL 打开请求（包括 Finder 中右键选择“打开方式 → CinePlayer”、双击已设为 CinePlayer 默认播放器的视频文件、Dock 图标的文件拖放或打开）最终都通过 `PlayerSessionStore.open(url:)` 进入播放器会话。

#### Scenario: Finder open with CinePlayer opens file in player
- **WHEN** 用户在 Finder 中右键某个受支持的视频文件并选择“打开方式 → CinePlayer”
- **THEN** CinePlayer 应用被启动或激活
- **THEN** 该文件被立即交给 `PlayerSessionStore.open(url:)`，主窗口展示为播放界面并开始加载该媒体

#### Scenario: Double-click default video file opens in player
- **WHEN** 用户双击一个已将 CinePlayer 设为默认播放器的视频文件
- **THEN** CinePlayer 应用被启动或激活
- **THEN** 该文件被立即交给 `PlayerSessionStore.open(url:)`，主窗口展示为播放界面并开始加载该媒体

### Requirement: macOS system URL scheme opens go through player session
应用在 macOS 上 **必须** 确保通过 Info.plist 中声明的 URL Scheme（例如 `cineplayer://`、`cineplayerapp://`）触发的打开请求最终也通过 `PlayerSessionStore.open(url:)` 进入播放器会话。

#### Scenario: cineplayer URL opens in player
- **WHEN** 系统将一个 `cineplayer://` 或 `cineplayerapp://` URL 交给 CinePlayer
- **THEN** CinePlayer 应用被启动或激活
- **THEN** 该 URL 被交给 `PlayerSessionStore.open(url:)`，并按照现有逻辑解析和播放相应媒体资源

