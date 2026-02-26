## Context

全平台构建矩阵中仅 tvOS 方向失败。错误集中在两类：
1) `GestureControllerTVOS` 读取了不存在的 `sessionStore`。
2) 字幕视图使用 `.toggleStyle(.switch)` 触发 tvOS 目标版本可用性错误。

## Goals / Non-Goals

**Goals:**
- 修复现有 tvOS 编译错误，使 7 平台构建全部通过。
- 保持播放器交互与业务行为不变。
- 变更最小化，避免引入无关重构。

**Non-Goals:**
- 不重构手势系统整体架构。
- 不改动字幕导入/选择业务流程。
- 不处理与当前报错无关的 UI 优化或功能扩展。

## Decisions

- 决策 1：在 `GestureControllerTVOS` 显式注入缺失的 `sessionStore` 环境对象。
  - 原因：报错根因是标识符未定义，补齐依赖即可恢复编译。
  - 备选：改为硬编码默认配置；会丢失统一配置来源，不采用。
- 决策 2：在字幕开关样式上使用平台条件编译，tvOS 不强制 `.switch`。
  - 原因：`.switch` 样式在当前 tvOS 目标版本触发可用性限制；去掉强制样式可保持功能并避免版本门槛。
  - 备选：整体提高 tvOS deployment target；影响面大，不作为本次最小修复。

## Risks / Trade-offs

- [Risk] tvOS 不再强制指定 `.switch` 样式后视觉可能与 iOS 略有差异。→ Mitigation：仅在 tvOS 跳过样式，保持功能一致，后续可单独做样式对齐。
- [Risk] 补齐环境对象依赖后若上层未注入会在运行时崩溃。→ Mitigation：上层 `PlayerControlView` 已统一注入 `sessionStore`，并通过 tvOS 编译验证链确认。
