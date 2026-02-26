## Why

当前播放器右侧弹出面板在底部出现了明显大于顶部和右侧的留白，导致面板容器边距不一致，视觉上与已有样式规范不一致。该问题已在播放设置面板中直接可见，需要立即收敛。

## What Changes

- 调整右侧弹出面板容器（trailing 方向）的高度与边距计算，使上、右、下边距一致。
- 保持底部弹出的倍速面板现有较大底部留白不变，不修改其布局与交互。
- 对变更影响范围做最小化约束，仅修改右侧面板容器相关实现。

## Capabilities

### New Capabilities
- `right-panel-padding-parity`: 右侧弹出面板在播放器内呈现统一的上、右、下边距。

### Modified Capabilities
- 无。

## Impact

- 影响代码：`CinePlayer/Player/SiderView/SiderContanierView.swift`。
- 不涉及 API、数据模型、外部依赖变更。
- 不影响倍速面板（`SiderPlaybackSpeedView`）既有底部大留白策略。
