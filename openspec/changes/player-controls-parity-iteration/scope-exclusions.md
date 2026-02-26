# 显式排除清单（纯播放器边界）

本文档用于落实 `tasks.md` 的 1.1，确保实现范围与 `proposal.md`、`design.md` 一致。

## 明确不做（本次变更排除）

- 字幕下载、在线字幕导入、字幕翻译服务接入
- 云盘多线路、线路切换策略、会员或付费鉴权逻辑
- 详情页、剧集数据模型、历史上报、推荐与业务导航
- Anime4K、系统 ML 超分/补帧、光流补帧、AB 对比增强
- 依赖业务层模型（如 `DetailPageModel`、`PlayerParams`）的播放器功能

## 本次保留并补齐

- 分平台控制面板布局（iOS / macOS / tvOS / visionOS）
- 手势与快捷键对齐（iOS/tvOS 手势，macOS 键盘与鼠标唤起）
- 轻量播放列表（仅列表与索引）
- 网络/缓冲相关 Toast 与加载/错误反馈
- PiP、iOS 旋转锁定按钮、Now Playing / Remote Command

## 一致性检查

- `proposal.md` 的排除项与本文档逐项一致
- `design.md` 的 Non-Goals 与本文档逐项一致
- 所有新增实现均限定在 `CinePlayer/Player` 内，不引入业务依赖
