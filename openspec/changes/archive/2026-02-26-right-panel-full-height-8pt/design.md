## Context

当前 trailing 方向面板已经按窗口坐标实现等边距全高，但边距常量为 16。用户要求统一为 8，并保持当前布局策略与倍速面板不变。

## Goals / Non-Goals

**Goals:**
- 将 trailing 面板 top/trailing/bottom 边距改为 8pt。
- 保持面板全高占位策略。
- 不影响 bottom 方向（倍速面板）布局。

**Non-Goals:**
- 不重构侧栏容器结构。
- 不调整面板宽度、动画、玻璃效果。

## Decisions

- 决策：只修改 `trailingOuterInset` 常量值，其他逻辑不动。
  - 原因：需求仅变更边距数值，最小改动风险最低。

## Risks / Trade-offs

- [Risk] 面板更贴近窗口边界，视觉呼吸感减少。→ Mitigation：这是用户明确要求。
