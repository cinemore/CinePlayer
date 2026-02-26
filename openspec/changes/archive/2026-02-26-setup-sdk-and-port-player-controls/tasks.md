## 1. SDK 基础集成

- [x] 1.1 将 SDK 发布包中的 Frameworks xcframework 复制并接入当前工程 target
- [x] 1.2 按 SDK 文档配置 Build Settings、Other Linker Flags、系统 frameworks/tbd 和平台过滤规则

## 2. 纯播放器壳与会话主链

- [x] 2.1 移除模板示例（SwiftData Item 列表）并建立纯播放器入口结构
- [x] 2.2 基于 SDK Demo 建立四平台可运行的最小播放主链（本地文件 + URL）
- [x] 2.3 新建纯播放器状态模型（source/session/control），替代业务模型依赖

## 3. 控件与样式整体迁移

- [x] 3.1 迁移播放器 UICommon（玻璃效果、必要扩展、字体样式）以保证视觉一致
- [x] 3.2 迁移自定义进度条（`CustomSlider` + `PlayerSliderView`）并接入 seek 控制
- [x] 3.3 迁移 SiderView 及音轨/视频轨/倍速面板并接入播放器控制器

## 4. 分平台控制层与手势迁移

- [x] 4.1 迁移并接入 iOS/macOS/tvOS/visionOS 的 ControllerPanel 与 GestureController
- [x] 4.2 完成 `PlayerControlView` 集成，保持控件显隐、手势和 Toast 行为一致
- [x] 4.3 清理迁移代码中的历史业务模块依赖并替换为纯播放器接口

## 5. 外部打开能力复制

- [x] 5.1 复制参考实现的文件类型与 UTI 声明，支持双击媒体文件打开
- [x] 5.2 接入统一 OpenEventRouter，打通 `onOpenURL` 与 app delegate 打开回调
- [x] 5.3 复制 macOS 顶部菜单与 Dock 菜单“打开文件…/打开URL…”行为

## 6. 验证与收口

- [x] 6.1 执行 iOS/macOS/tvOS/visionOS 编译验证并修复构建问题
- [x] 6.2 对照参考实现完成手势、进度条、SiderView、外部打开行为验收
- [x] 6.3 更新 OpenSpec 任务勾选与变更状态，准备后续归档
