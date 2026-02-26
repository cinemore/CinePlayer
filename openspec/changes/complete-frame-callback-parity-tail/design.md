## Context

纯播放器已完成增强主链路迁移。`DebugTemporalRGBFrameInserter` 属于临时测试工具，依赖额外的 CoreText/VideoToolbox 绘制与转换路径，不是产品功能。用户明确要求移除该测试逻辑，仅保留 `#if DEBUG` 的编译门禁。

## Goals / Non-Goals

**Goals:**
- 完整删除 `CINEMORE_DEBUG_TEMPORAL_INSERTER` 运行时开关逻辑。
- 删除 `DebugTemporalRGBFrameInserter` 相关辅助代码与依赖。
- 不影响现有 Anime4K/System VT/光流的策略映射与 Debug 门禁。

**Non-Goals:**
- 不调整增强算法实现与参数。
- 不变更播放器 UI/交互。
- 不改变 Release 下 VT/光流策略钳制行为。

## Decisions

1. 在 `makeFrameCallbackConfiguration` 中直接移除 temporal inserter 分支。
- 原因：该分支只服务测试，不应进入常规播放路径。
- 备选：保留分支但关闭环境变量入口。
- 不选原因：仍残留无用逻辑与维护成本。

2. 删除 `DebugTemporalRGBFrameInserter` 类型与额外 import。
- 原因：去除无用依赖，降低文件复杂度。
- 备选：保留类型但不调用。
- 不选原因：死代码容易造成后续误判与回归。

3. 保持现有 `#if DEBUG` 策略门禁不变。
- 原因：符合用户对 Debug/Release 能力边界的要求。

## Risks / Trade-offs

- [风险] 删除测试钩子后少一条 `replaceMany` 人工验证路径。 → 缓解：继续依赖 System VT/光流真实路径验证 temporal 回调。
- [风险] 删除代码时误删正常增强逻辑。 → 缓解：删除范围限定在 `CINEMORE_DEBUG_TEMPORAL_INSERTER` 与 helper，并执行 7 平台构建矩阵。

## Migration Plan

1. 删除 `VideoPlayerModel` 中测试分支与 helper。
2. 更新 OpenSpec 变更文档与任务。
3. 执行 7 平台构建矩阵验证。

## Open Questions

- 无。
