# CinePlayer for Apple

**Next-generation high-performance cross-platform video player**

CinePlayer is an open-source player application built on top of `CinePlayerSDK`.  
`CinePlayerSDK` is the core playback engine used by **[Cinemore](https://cinemore.com.cn)** and has been battle-tested in production.  
This repository demonstrates how to use a high-performance playback core to deliver a premium audio/video experience while keeping the app layer flexible and extensible.

For the Simplified Chinese README, see `README-zh.md`.

## ✨ Features

- **Stunning image quality**: Supports HLG, HDR10, HDR10+ (with metadata), and Dolby Vision (Dolby Vision with RPU).
- **Premium audio**: Supports stereo/multichannel audio, spatial audio, and Dolby Atmos in supported scenarios.
- **High-performance decoding**: Comprehensive hardware-accelerated decoding pipeline.
- **Playback controls**: Precise playback speed control, fast switching between multiple audio and subtitle tracks.
- **Subtitle support**: Robust rendering for embedded and external subtitles, with optional subtitle translation features.
- **Blu-ray support**: Supports ISO and BDMV Blu-ray disc images.
- **Rich diagnostics**: Can display network throughput and detailed audio/video track information.
- **Multi-platform**: Runs on iOS, macOS, tvOS, and visionOS.

**Dolby Vision and Dolby Atmos playback are handled by Apple AVFoundation’s [AVPlayer](https://developer.apple.com/documentation/avfoundation/avplayer/).**

## 🏗 Architecture & Dependencies

### Core Playback Engine (Closed Source)

- **CinePlayerSDK**: The core playback engine of this project.  
  It is a proprietary commercial component distributed in binary form only.

## 📚 Third-party Libraries

CinePlayer’s capabilities are built on top of the following excellent open-source projects:

### Core multimedia framework

- **[FFmpeg](https://github.com/FFmpeg/FFmpeg)**

### Video & HDR processing

- **[libdav1d](https://github.com/videolan/dav1d)**
- **[libdovi](https://github.com/quietvoid/dovi_tool)**

### Subtitle rendering

- **[libass](https://github.com/libass/libass)**
- **[FreeType](https://github.com/freetype/freetype)**
- **[FriBidi](https://github.com/fribidi/fribidi)**
- **[HarfBuzz](https://github.com/harfbuzz/harfbuzz)**
- **[libunibreak](https://github.com/adah1972/libunibreak)**

### Blu-ray support

- **[libbluray](https://code.videolan.org/videolan/libbluray)**
- **[libudfread](https://code.videolan.org/videolan/libudfread)**

## ⚖️ License

This project uses a **hybrid licensing model**:

- **Source code license**: See the `LICENSE` file at the repository root.
- **SDK license**: See the `CinePlayerSDK.framework/License` files under `Frameworks/CinePlayerSDK.xcframework` for each supported platform slice.

### 1. Open-source components

The **CinePlayer** application-layer source code is released under the  
**[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)**.  
You are free to study, modify, and build your own applications based on this codebase, subject to the terms of Apache 2.0.

### 2. Proprietary SDK and commercial licensing

**CinePlayerSDK** (the prebuilt binary libraries in this repository) is proprietary software:

- **Personal / non-commercial use**:  
  You may redistribute `CinePlayerSDK` as part of this open-source project **for personal learning and testing only**.
- **Commercial use**:  
  It is **strictly prohibited** for any third-party company to use `CinePlayerSDK` in commercial products without prior written permission.
- **Obtaining a commercial license**:  
  For commercial usage of the SDK, please contact: `cinemore@cinemore.com.cn`.

