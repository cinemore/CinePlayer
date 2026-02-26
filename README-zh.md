# CinePlayer For Apple

**次世代高性能跨平台视频播放器**

CinePlayer 是一款基于 `CinePlayerSDK` 构建的开源播放器。`CinePlayerSDK` 作为 **[Cinemore](https://cinemore.com.cn)** 的播放核心得到了广泛的验证，现在我们将成果进行拓展。它展示了如何利用高性能内核实现极致的音视频播放体验，同时保持了应用层的灵活性和可扩展性。

## ✨ 特性

- **纯播放器控制层：** 分平台控制面板（iOS / macOS / tvOS / visionOS），统一播放器遮罩、侧边面板与 Toast 交互。
- **手势与快捷键：**
  - iOS：单击显隐、双击快进/快退/播放暂停、长按临时倍速、亮度滑动。
  - tvOS：遥控器滑动/按键快进快退、长按连续快进、`pageUp/pageDown` 上一集/下一集。
  - macOS：空格、方向键、Esc + 鼠标移动唤起控制层。
- **轻量播放列表：** 内置 `PlayerPlaylist`（列表 + 索引），支持多文件打开与前后切换。
- **网络与错误反馈：** 支持网络连接/重试/切线/稳定/错误 Toast，并提供加载与错误卡片提示。
- **系统能力：** 支持 PiP（按平台能力启用）、iOS 旋转锁定按钮、Now Playing / Remote Command Center。
- **多平台支持：** iOS、macOS、tvOS、visionOS。

**杜比视界及杜比全景声由 Apple AVFoundation 的 [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer/) 负责处理。**

## 🚫 范围边界

本仓库是纯播放器示例，不包含以下业务能力：

- 详情页/剧集业务模型/历史上报/推荐
- 云盘多线路与会员逻辑
- 字幕下载与业务字幕服务
- Anime4K 或系统 ML 超分/补帧等增强功能

## 🛠 构建与运行

在仓库根目录执行（关闭签名）：

```bash
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=tvOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=tvOS Simulator' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=visionOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=visionOS Simulator' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## 🏗 项目架构与依赖

### 核心播放内核 (Closed Source)

* **CinePlayerSDK:** 本项目的核心播放引擎。它是一个闭源的商业组件，仅以二进制形式提供。

## 📚 第三方库列表 (Third-party Libraries)

CinePlayer 的强大功能离不开以下优秀开源项目的支持：

### 核心多媒体框架
* **[FFmpeg](https://github.com/FFmpeg/FFmpeg)**

### 视频与 HDR 处理
* **[libdav1d](https://github.com/videolan/dav1d)**
* **[libdovi](https://github.com/quietvoid/dovi_tool)**

### 字幕渲染引擎
* **[libass](https://github.com/libass/libass)**
* **[FreeType](https://github.com/freetype/freetype)**
* **[FriBidi](https://github.com/fribidi/fribidi)** 
* **[HarfBuzz](https://github.com/harfbuzz/harfbuzz)** 
* **[libunibreak](https://github.com/adah1972/libunibreak)** 

### 蓝光支持
* **[libbluray](https://code.videolan.org/videolan/libbluray)** 
* **[libudfread](https://code.videolan.org/videolan/libudfread)**

## ⚖️ 授权协议 (License)

本项目采用混合授权模式：源码许可详见仓库根目录的 `LICENSE` 文件，SDK 许可条款详见 `Frameworks/CinePlayerSDK.xcframework` 各平台子目录下 `CinePlayerSDK.framework/License` 文件。

### 1. 开源部分

**CinePlayer** 应用层源码基于 **[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)** 协议开源。你可以自由地学习、修改并基于本仓库代码开发自己的应用。

### 2. 闭源组件与商业授权

**CinePlayerSDK** (即项目中的二进制库文件) 属于专有软件：

* **个人/非商业用途：** 允许随本开源项目一同分发，仅限个人学习和测试使用。
* **商业用途：** **严禁**任何第三方公司在未经许可的情况下将 `CinePlayerSDK` 用于商业产品。
* **获取授权：** 如需在商业项目中使用此 SDK，请联系：`cinemore@cinemore.com.cn` 进行商务洽谈。
