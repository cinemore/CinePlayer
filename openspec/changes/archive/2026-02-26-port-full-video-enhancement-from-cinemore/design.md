## Context

当前纯播放器仓库中，增强面板仅有占位 UI，未接入任何帧回调增强逻辑。`cinemore-apple` 已存在可运行并经过验证的完整实现，覆盖 Anime4K、系统 VT（超分/插帧）和光流补帧。目标是在不引入业务层依赖的前提下，将该能力迁移到 `CinePlayer/Player`，并保持已验证行为的一致性。

约束：
- 仅修改当前仓库，且新增实现必须落在 `CinePlayer/Player` 范围。
- 必须支持 iOS、macOS、tvOS、visionOS 的工程编译；增强能力保持与原实现一致的条件编译门禁。
- 不重写算法逻辑，优先复用 `cinemore-apple` 现有代码路径。

## Goals / Non-Goals

**Goals:**
- 迁移完整增强功能栈：Anime4K、系统 VT、光流补帧。
- 迁移增强配置模型与增强面板交互逻辑，保持与源实现一致。
- 将增强策略接入 `CinePlayerSDK` 帧回调策略，并支持播放中热更新。
- 保持“每个视频独立”增强会话重置行为与可用性门禁行为。

**Non-Goals:**
- 不引入详情页、云盘、会员、历史、推荐等业务能力。
- 不新增与源实现不同的增强算法、参数语义或策略规则。
- 不在本次变更中重构播放器非增强模块。

## Decisions

1. 代码来源策略：按源实现迁移，而非重写。
- 决策：将 `cinemore-apple` 的增强 Runtime / Adapter / Shader 与配置逻辑按结构迁移到 `CinePlayer/Player`，仅做最小适配（命名、日志函数、路径、模型注入点）。
- 原因：用户明确要求使用已验证实现；该路径风险最低。
- 备选方案：基于当前仓库重写最小增强版本。拒绝原因：行为偏差和回归风险高。

2. 状态模型：新增独立增强模型并挂接现有控制模型。
- 决策：在 `CinePlayer/Player/Model` 中引入增强状态模型（策略、门禁、参数、每视频重置），并由 `PlayerControlModel` / `VideoPlayerModel` 驱动。
- 原因：与现有 UI 结构兼容，避免业务模型泄漏。
- 备选方案：把增强参数直接散落到现有控制模型。拒绝原因：可维护性差且难以与原逻辑对齐。

3. 管线接入：通过 `frameCallbackPolicy + onVideoFrame` 统一驱动。
- 决策：复用源实现的策略映射：`off`、`anime4k`、`systemML`、`opticalFlow` 分别映射到 `disabled`、`asyncSingle`、`asyncSingle/temporal`、`temporal`。
- 原因：与 SDK 能力模型天然匹配，且源实现已稳定。
- 备选方案：额外增加播放器外层渲染链。拒绝原因：复杂且偏离现有架构。

4. 平台门禁：保持条件编译与系统能力探测一致。
- 决策：增强代码保留 `#if !os(tvOS)` 以及系统版本/API 可用性检查，并在不支持条件下 fail-open 回退 passthrough。
- 原因：确保 7 平台可构建，且不支持平台行为可预测。
- 备选方案：强行跨平台启用。拒绝原因：会导致编译/运行风险。

## Risks / Trade-offs

- [迁移代码体量较大] → 按模块分批迁移（Model/UI/Enhancement Runtime），每步先编译再继续。
- [源仓库依赖符号差异] → 仅做最小适配层（日志、模型命名、入口调用），避免改动算法主体。
- [多平台条件编译错误] → 每次关键合入后跑 `xcodebuild` 多平台构建。
- [现有脏工作区干扰] → 仅修改增强相关文件，不回退任何既有用户改动。

## Migration Plan

1. 迁移增强状态模型与枚举，接入 `PlayerControlModel` 与播放器生命周期。
2. 迁移增强面板 UI 并绑定真实状态。
3. 迁移 Anime4K Runtime + shader，并接入 `VideoPlayerModel` 的 frame callback。
4. 迁移系统 VT 适配层并接入策略分发。
5. 迁移光流补帧适配层并接入时域策略。
6. 打通播放中配置热更新路径。
7. 运行 7 平台构建验证并修复编译问题。

## Open Questions

- 无阻塞性问题；按“与 `cinemore-apple` 行为一致”执行即可。
