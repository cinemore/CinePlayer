# CinePlayer For Apple

**次世代高性能跨平台视频播放器**

CinePlayer 是一款基于 `CinePlayerSDK` 构建的开源播放器。`CinePlayerSDK` 作为 **[Cinemore](https://cinemore.com.cn)** 的播放核心得到了广泛的验证，现在我们将成果进行拓展。它展示了如何利用高性能内核实现极致的音视频播放体验，同时保持了应用层的灵活性和可扩展性。

## ✨ 特性

* **极致画质：** 支持 HLG、HDR10、HDR10+ (含 Metadata) 以及杜比视界 (Dolby Vision with RPU)。
* **顶级音频：** 支持立体声/多声道、空间音频，以及特定场景下的杜比全景声 (Dolby Atmos)。
* **高性能解码：** 全面的硬件加速解码方案。
* **播放控制：** 精准倍速播放、多音轨/多字幕轨道快速切换。
* **字幕支持：** 完善的内封及外挂字幕渲染，支持字幕翻译功能。
* **蓝光支持：** 支持 ISO 和 BDMV 蓝光原盘播放。
* **丰富信息：** 支持显示网络读取速度、音视频轨道信息
* **全平台：** 支持 iOS、macOS、tvOS、visionOS

** 杜比视界及杜比全景声使用 Apple AVFoundation  [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer/)

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

本项目采用混合授权模式，源码详见 LICENSE，SDK 详见 libs/CinePlayerSDK/LICENSE_SDK。

### 1. 开源部分

**CinePlayer** 应用层源码基于 **[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)** 协议开源。你可以自由地学习、修改并基于本仓库代码开发自己的应用。

### 2. 闭源组件与商业授权

**CinePlayerSDK** (即项目中的二进制库文件) 属于专有软件：

* **个人/非商业用途：** 允许随本开源项目一同分发，仅限个人学习和测试使用。
* **商业用途：** **严禁**任何第三方公司在未经许可的情况下将 `CinePlayerSDK` 用于商业产品。
* **获取授权：** 如需在商业项目中使用此 SDK，请联系：`cinemore@cinemore.com.cn` 进行商务洽谈。
