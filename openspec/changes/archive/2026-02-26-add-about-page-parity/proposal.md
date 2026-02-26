## Why

当前 CinePlayer 缺少独立“关于”页面，用户无法查看版本信息、联系邮箱与法律链接；macOS 版本也缺少与 cinemore 一致的菜单入口。该缺口直接影响产品一致性与基础信息可达性，需要补齐。

## What Changes

- 新增跨平台“关于”页面，信息结构与 `cinemore-apple` 关于页保持一致。
- 页面顶部图标使用 `CinePlayerIcon`。
- macOS 增加与 cinemore 一致的应用菜单“关于”入口，可打开独立关于窗口。
- 关于页保留隐私政策、第三方许可、EULA、联系方式与版权/备案信息。
- 按要求移除 IMDb 与 TMDB 相关展示内容。

## Capabilities

### New Capabilities
- `about-page-parity`: 提供与 cinemore 对齐的关于页面与 macOS 菜单入口（不包含 IMDb/TMDB 相关项）。

### Modified Capabilities
- None.

## Impact

- `CinePlayer/CinePlayerApp.swift`
- `CinePlayer` 下新增关于页 SwiftUI 视图与必要公共辅助代码
