## Why

当前 `CinePlayer` 是新建模板工程，尚未完成 SDK 接入、播放器控件迁移和外部打开流程，无法作为可用的纯播放器产品。需要在一次变更中建立可运行的全平台基础能力，并保证与参考播放器实现的交互和视觉表现一致。

## What Changes

- 集成 SDK 文档要求的全部基础配置（Frameworks、Linker、Build Settings、Info.plist、Capabilities）。
- 迁移参考播放器实现中的控件体系，包含手势、控制面板、SiderView（音轨/视频轨/倍速）和自定义进度条，保持交互与视觉一致。
- 将迁移代码去业务化，移除历史业务模块依赖，改为纯播放器会话模型与状态管理。
- 复制参考实现的文件关联与 URL scheme 相关 `Info.plist` 能力，支持双击视频文件打开应用。
- 复制参考实现的 macOS 顶部菜单和 Dock 菜单行为，支持“打开文件…”与“打开URL…”。
- 为 iOS/macOS/tvOS/visionOS 提供统一的入口路由与播放器窗口/页面打开流程。

## Capabilities

### New Capabilities
- `sdk-bootstrap`: 在新工程中完成 CinePlayerSDK 全平台集成与运行所需基础配置。
- `player-controls-parity`: 提供与参考播放器一致的手势、控件与视觉表现，并去除业务耦合。
- `external-open-integration`: 支持双击文件打开、URL scheme 打开、macOS 菜单与 Dock 打开入口。

### Modified Capabilities
- 无

## Impact

- 影响 `CinePlayer.xcodeproj` 的构建配置、链接依赖与平台能力设置。
- 新增并重构 `CinePlayer` 下播放器相关视图、模型、平台控制层和样式基础设施。
- 更新 `CinePlayer/Info.plist` 以引入文档类型、UTI、URL scheme 与播放器授权字段。
- 需要同步引入 SDK 发布包中的 Frameworks 目录并保持与 SDK 版本一致。
