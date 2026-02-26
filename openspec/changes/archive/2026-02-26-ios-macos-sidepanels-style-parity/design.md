## Context

当前仓库在功能层已逐步对齐 Cinemore，但侧边面板视觉层级仍明显偏简化版本。iOS 与 macOS 的媒体信息、增强、设置、字幕面板均未采用 Cinemore 的核心结构（分段、分组 Form、卡片化、标题层级）。用户要求两端统一严格对齐，并明确增强面板不需要画面填充项。

## Goals / Non-Goals

**Goals:**
- iOS 与 macOS 的四个面板采用与 Cinemore 一致的 UI 结构与视觉层级。
- 字幕面板采用 `内封字幕 / 外部字幕 / 字幕调整` 的分段布局。
- 增强面板移除“画面填充”能力项，仅保留增强设置区块样式。
- 在纯播放器仓库内使用可用数据能力完成等价 UI，不引入业务 API。

**Non-Goals:**
- 不复制 Cinemore 的业务数据链路（字幕搜索、文件源导入、云端配置）。
- 不改动 tvOS/visionOS 交互设计。
- 不新增跨仓库依赖。

## Decisions

### Decision 1: 结构对齐优先于功能全量复制
- 选择：先严格复刻 Cinemore 的面板结构（分组、分段、卡片、标题和间距），功能仅绑定纯播放器已有能力。
- 原因：满足“严格使用 Cinemore UI”且不破坏仓库边界。
- 备选：完全复制 Cinemore 业务功能。会引入大量缺失依赖并违背纯播放器约束。

### Decision 2: 字幕面板拆分为分段子视图
- 选择：将字幕面板改成 segmented + 三个子内容区（内封、外部、调整）。
- 原因：这是 Cinemore 字幕 UI 最关键的外观差异点。
- 备选：维持单页混排。无法达到视觉一致。

### Decision 3: 媒体信息卡片采用轨道分组卡片
- 选择：按视频/音频/字幕轨道分组展示，每轨道使用独立信息卡片，保留统一关闭按钮。
- 原因：与 Cinemore 信息面板结构一致，且可直接用当前播放器轨道数据。
- 备选：继续列表行展示。信息密度和布局均不一致。

## Risks / Trade-offs

- [风险] 样式重构后文件体积增加，可维护性下降。  
  -> Mitigation：拆出小型子视图并保持单一职责。

- [风险] 部分 Cinemore 能力在纯播放器不可用，导致“功能空洞”感。  
  -> Mitigation：保留同款容器与分区样式，明确“当前版本未提供”的提示。

- [风险] 新样式影响 tvOS/macOS 编译条件。  
  -> Mitigation：关键控件加平台条件分支，并执行 7 平台构建矩阵。

## Migration Plan

1. 重构 `PlayerMediaInfoCardView` 为 Cinemore 风格轨道卡片视图。
2. 重构 `SiderEnhancementView` 为 Form 分组并去掉画面填充项。
3. 重构 `SiderSettingView` 为 Cinemore 风格播放设置分组。
4. 重构 `SiderSubtitleView` 为 segmented 三分区布局并保持本地导入约束。
5. 执行 7 平台构建验证并更新 OpenSpec task 状态。

## Open Questions

- 字幕调整中的高级样式（字体、描边、位置）是否在纯播放器后续迭代实现（本次先实现样式骨架与可用项）。
