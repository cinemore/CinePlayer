## Why

右侧设置面板底部异常留白仍未定位到具体责任层。需要通过可视化分层底色快速识别是容器、页面还是表单层在撑高布局。

## What Changes

- 在右侧设置面板路径上的关键层级增加可区分半透明背景色。
- 颜色覆盖从弹层容器到设置页内容层，便于目测空白来自哪一层。
- 保持倍速面板和业务交互逻辑不变。

## Capabilities

### New Capabilities
- `debug-right-panel-layer-colors`: 右侧设置面板支持分层调试底色可视化，辅助定位异常间距来源。

### Modified Capabilities
- 无。

## Impact

- 影响代码：`SiderContanierView.swift`、`SiderSettingView.swift`、`PlaySettingPage.swift`。
- 不涉及数据模型、播放器控制逻辑、外部依赖。
