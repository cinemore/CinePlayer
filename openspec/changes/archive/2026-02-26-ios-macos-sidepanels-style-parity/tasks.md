## 1. 媒体信息卡片样式对齐

- [x] 1.1 重构 `PlayerMediaInfoCardView` 为 Cinemore 风格分组卡片布局（视频/音频/字幕/封面）
- [x] 1.2 统一 iOS/macOS 的媒体信息关闭入口与遮罩行为

## 2. 设置与增强面板样式对齐

- [x] 2.1 重构 `SiderSettingView` 为 Cinemore 播放设置结构（分组样式）
- [x] 2.2 重构 `SiderEnhancementView` 为 Cinemore 分组 Form 样式，并移除画面填充项

## 3. 字幕面板样式对齐

- [x] 3.1 重构 `SiderSubtitleView` 为 segmented 三分区（内封/外部/调整）
- [x] 3.2 保持外部字幕仅“本地导入”，不出现“从文件源导入”入口
- [x] 3.3 字幕调整页提供 Cinemore 风格样式骨架并绑定纯播放器可用项

## 4. 验证

- [x] 4.1 执行 AGENTS.md 要求的 7 平台 `xcodebuild` 构建验证
- [x] 4.2 iOS + macOS 面板手工回归：媒体信息、增强、设置、字幕四项样式与交互
