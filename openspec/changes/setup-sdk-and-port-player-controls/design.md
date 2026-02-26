## Context

`CinePlayer` 当前是 Xcode 新建模板，尚无可运行的纯播放器架构。目标是基于 SDK 文档与示例工程完成全平台基础集成，并将参考播放器实现中的交互与视觉完整迁移到当前工程。

约束：
- 必须是纯播放器，不引入历史业务模块依赖。
- 必须覆盖 iOS / macOS / tvOS / visionOS。
- 外部打开行为需与参考实现一致，特别是 macOS 菜单和 Dock 行为。
- OpenSpec 产物需先于实现完成，并可追踪任务进度。

## Goals / Non-Goals

**Goals:**
- 完成 CinePlayerSDK 全平台可编译、可运行的基础接入。
- 迁移播放器控制层（手势、进度条、SiderView、控制面板、Toast）并保持视觉与行为一致。
- 建立纯播放器会话模型，替代历史业务模型。
- 实现双击文件打开、URL scheme、macOS 顶部菜单与 Dock 菜单入口。

**Non-Goals:**
- 不迁移详情页、历史记录、云盘、订阅、账号、翻译服务等业务能力。
- 不改变参考实现当前“打开URL”菜单行为（保持弹窗输入后交由系统打开）。
- 不在本变更中引入新的播放器功能设计。

## Decisions

### Decision 1: 采用“播放器子系统整体迁移 + 业务适配层替换”而非零散拷贝
- 选择：整体迁移参考实现中的播放器 UI/交互相关文件，再以新建纯播放器模型替换业务依赖。
- 原因：用户要求交互与视觉完全一致，零散拷贝会导致行为和样式偏差。
- 备选方案：
  - 只迁点名控件：速度快，但一致性风险高。
  - 先做 SDK Demo 再迭代：阶段性偏差大、重复改造成本高。

### Decision 2: 入口采用统一事件路由 `OpenEventRouter`
- 选择：将 `onOpenURL`、`application(_:open:)`、菜单和 Dock 入口统一映射到播放器打开动作。
- 原因：避免多入口下行为不一致，降低平台差异处理复杂度。
- 备选方案：每个平台独立处理入口。该方案重复代码多，回归风险高。

### Decision 3: URL 菜单行为严格复制参考实现
- 选择：macOS “打开URL…”使用 `NSAlert + NSTextField` 收集输入，再 `NSWorkspace.shared.open(url)`。
- 原因：用户明确要求完全复制该实现。
- 备选方案：直接应用内播放 URL。被用户否决。

### Decision 4: SDK 集成遵循文档显式配置
- 选择：按 SDK 文档与示例工程完整配置 frameworks、linker、build settings、auth key、capabilities。
- 原因：降低隐式依赖与平台链接错误，确保跨平台一致构建。
- 备选方案：仅最小可编译配置。风险是平台切换时隐性失败。

### Decision 5: 样式基础抽离为 Player UI Common
- 选择：从参考实现提取播放器必需的 modifier/字体扩展/样式常量，放入 `Player/UICommon`。
- 原因：保持视觉一致的同时隔离无关通用代码，减少迁移噪音。
- 备选方案：全量复制 `Share/Extension`。体积过大且耦合高。

## Risks / Trade-offs

- [风险] 播放器文件跨平台差异较大，迁移后可能出现条件编译断裂。
  -> Mitigation: 先建立共享最小可运行主链，再逐平台接入控制层并逐平台编译验证。

- [风险] 参考实现中的控件依赖大量样式扩展，缺失会导致视觉偏差或编译失败。
  -> Mitigation: 在首次迁移阶段先补齐 `Player/UICommon` 最小闭包依赖并集中维护。

- [风险] Xcode 项目文件一次性改动大，容易遗漏 framework/link 设定。
  -> Mitigation: 以 SDK 示例工程为基线逐项对照，完成后执行全平台 build 验证。

- [风险] “完全一致”要求导致迁移范围扩大，初版节奏受影响。
  -> Mitigation: 使用 OpenSpec tasks 分批落地，优先交付核心播放与外部打开主链，再补全平台细节。

## Migration Plan

1. 在 OpenSpec 中完成 proposal/design/specs/tasks，冻结执行范围。
2. 完成 SDK 基础接入和工程构建配置，确保四平台可链接。
3. 建立纯播放器模型与入口路由，打通最小播放链路。
4. 迁移控制层（进度条、手势、SiderView、控制面板、Toast）。
5. 接入外部打开能力（双击文件、URL scheme、菜单、Dock）。
6. 逐平台编译与回归检查，修复差异并收敛任务。

回滚策略：
- 每个任务块独立提交（或独立变更区块），出现严重回归时仅回退对应区块。
- OpenSpec tasks 未完成前不执行归档。

## Open Questions

- 是否需要在首版同时加入播放器窗口多实例能力（当前设计按单会话优先）。
- 是否要在 pure player 中保留参考实现中的部分调试日志与高级增强开关。
