## Why

用户明确要求右侧设置面板保持全高，并且与窗口上、右、下边界固定 16pt 距离。当前实现因调试改动与布局策略导致面板高度不足且边距不符合目标。

## What Changes

- 右侧（trailing）弹层容器使用 16pt 外边距并按全高可用区域布局。
- 设置页恢复为充满容器高度的布局（顶部内容 + 下方留白）。
- 移除本次排障引入的调试背景色，不影响倍速底部面板的既有大底距策略。

## Capabilities

### New Capabilities
- `right-panel-full-height-16pt`: 右侧设置面板以全高展示，并满足上/右/下 16pt 固定边距。

### Modified Capabilities
- 无。

## Impact

- 影响代码：`SiderContanierView.swift`、`SiderSettingView.swift`、`SiderView.swift`、`PlaySettingPage.swift`。
- 不涉及数据模型与播放器业务逻辑。
