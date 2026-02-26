## Context

CinePlayer 当前是纯播放器应用，主界面聚焦播放能力，尚未提供独立“关于”页面。`cinemore-apple` 已有成熟关于页，包含版本信息、联系方式、法律链接与版权备案信息；macOS 通过应用菜单“关于”打开独立窗口。当前需求要求在本仓库对齐该能力，并明确去除 IMDb/TMDB 相关展示，且应用图标改为 `CinePlayerIcon`。

## Goals / Non-Goals

**Goals:**
- 提供一个可复用的 SwiftUI 关于页视图，信息结构与 `cinemore-apple` 保持一致（IMDb/TMDB 项除外）。
- 页面顶部图标使用 `CinePlayerIcon`，并展示版本号与构建号。
- 在 macOS 通过应用菜单（`CommandGroup(replacing: .appInfo)`）打开独立关于窗口，行为与 cinemore 对齐。
- 保持跨平台可编译，不破坏纯播放器主流程。

**Non-Goals:**
- 不引入新的业务入口或设置体系重构。
- 不修改播放器手势、控制栏和播放流程。
- 不新增 IMDb/TMDB 数据来源展示或相关链接。

## Decisions

1. 新建独立 `AboutPage` 视图，封装版本信息、联系方式、法律链接和版权备案信息。
- 选择原因：避免把展示逻辑混入 `CinePlayerApp`，便于后续在 iOS/tvOS/visionOS 复用。
- 备选方案：仅在 macOS 内联一个简单窗口视图；未采用，因为复用性差，后续扩展成本高。

2. 参考 `cinemore-apple` 的文案与链接，逐项对齐并移除 IMDb/TMDB 相关显示。
- 选择原因：满足用户追加要求。
- 备选方案：保留 TMDB 声明；未采用，因为与当前明确要求冲突。

3. macOS 入口采用 `CommandGroup(replacing: .appInfo)` + 独立 `NSWindow`。
- 选择原因：与 cinemore 的打开路径一致，用户可从系统应用菜单稳定访问。
- 备选方案：使用 `MenuBarExtra` 或设置页入口；未采用，因为与参考实现不一致。

4. 关于页图标使用现有资源 `CinePlayerIcon`，并在页面内按固定尺寸显示。
- 选择原因：符合用户显式要求，避免引入外部品牌资源依赖。
- 备选方案：新增专用 About 图标资源；未采用，因为无必要且增加维护成本。

## Risks / Trade-offs

- [关于页视觉细节与 cinemore 样式体系存在差异] → 采用相同信息结构与链接，保留当前工程可用样式能力，避免引入大范围主题依赖。
- [macOS 窗口对象生命周期导致重复创建或释放] → 采用独立窗口并缓存窗口实例，避免重复初始化。
- [外链 URL 后续变更] → 统一集中在 About 页面常量，便于后续单点更新。
