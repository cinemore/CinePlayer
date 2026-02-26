## Why

用户确认右侧设置面板已实现等边距全高，但需要将上/右/下边距由 16pt 调整为 8pt。该调整属于视觉规格修正，需要立即落地。

## What Changes

- 将 trailing 方向右侧面板容器边距规格从 16pt 调整为 8pt。
- 保持全高策略不变。
- 保持底部倍速面板原有间距行为不变。

## Capabilities

### New Capabilities
- `right-panel-full-height-8pt`: 右侧设置面板在 trailing 方向使用上/右/下 8pt 等边距并保持全高布局。

### Modified Capabilities
- 无。

## Impact

- 影响代码：`CinePlayer/Player/SiderView/SiderContanierView.swift`。
- 不涉及业务状态、交互逻辑和外部依赖。
