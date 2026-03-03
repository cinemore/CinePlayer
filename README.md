<div align="center">
  <a href="https://cinemore.com.cn/">
    <img src="assets/appicon-dark.png" alt="CinePlayer" width="120" height="120">
  </a>
  <h1>CinePlayer for Apple</h1>
  <p><strong>Next-generation player</strong></p>
  <p>
    <a href="README.md">English</a> · <a href="README-zh.md">简体中文</a>
  </p>
</div>

CinePlayer is an open-source player application built on top of `CinePlayerSDK`.  
`CinePlayerSDK` is the core playback engine used by **[Cinemore](https://cinemore.com.cn)** and has been battle-tested in production.  
This repository demonstrates how to use a high-performance playback core to deliver a premium audio/video experience while keeping the app layer flexible and extensible.

## 📸 Preview

<p align="center">
  <img src="assets/player.png" alt="CinePlayer playback interface" width="720">
</p>

## ✨ Features

- **Image & audio**: HLG, HDR10, HDR10+, Dolby Vision (with RPU); hardware-accelerated decoding; stereo/multichannel, spatial audio, Dolby Atmos where supported.
- **Gestures & shortcuts**: iOS — single tap show/hide controls, double-tap left/right skip or center play/pause, long-press temporary speed (configurable skip seconds and long-press speed in playback settings); tvOS — remote swipe/press skip, long-press continuous seek; macOS — Space play/pause, arrow keys skip/speed, Esc fullscreen, mouse to show controls.
- **Subtitles**: Embedded and external subtitles; full ASS-style customization; HDR subtitle support; translation (e.g. Apple).
- **Tracks & media info**: Detailed video/audio/subtitle track list with quick switching; media info card.
- **Enhancement**: Anime4K-style anime super-resolution (multiple presets, optional A/B compare).
- **Playback UX**: Progress scrub with thumbnail preview; portrait/landscape (iOS orientation lock), picture fill, PiP, fullscreen, variable playback speed; macOS window floating (always on top); Now Playing / lock screen & Control Center control.
- **Blu-ray**: ISO and BDMV.
- **Platforms**: iOS, macOS, tvOS, visionOS.

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

- **[dav1d](https://github.com/videolan/dav1d)** (libdav1d)
- **[dovi_tool](https://github.com/quietvoid/dovi_tool)** (libdovi)
- **[uavs3d](https://github.com/uavs3/uavs3d)** (libuavs3d)

### Subtitle rendering

- **[libass](https://github.com/libass/libass)**
- **[FreeType](https://github.com/freetype/freetype)**
- **[FriBidi](https://github.com/fribidi/fribidi)**
- **[HarfBuzz](https://github.com/harfbuzz/harfbuzz)**
- **[libunibreak](https://github.com/adah1972/libunibreak)**

### Blu-ray support

- **[libbluray](https://code.videolan.org/videolan/libbluray)**
- **[libudfread](https://code.videolan.org/videolan/libudfread)**

## 🧪 Building & Code Signing

To run on a real iOS device, open the `CinePlayer` iOS target in Xcode, go to **Signing & Capabilities**, and select your own **Team**. Other settings can generally stay as-is for local development.

## ⚖️ License

This project uses a **hybrid licensing model**:

- **Source code license**: See the [`LICENSE`](LICENSE) file at the repository root.
- **SDK license**: The binding terms for CinePlayerSDK are in the **License** file inside each platform slice’s `CinePlayerSDK.framework` (on macOS: `Versions/A/Resources/License`). Path: `Frameworks/CinePlayerSDK.xcframework/<platform>/CinePlayerSDK.framework/...`

Third-party libraries (FFmpeg, libass, etc.) are used under their own licenses; see the links in **Third-party Libraries** above.

### 1. Open-source components

The **CinePlayer** application-layer source code is released under the  
**[Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0)**.  
You are free to study, modify, and build your own applications based on this codebase, subject to the terms of Apache 2.0.

### 2. Proprietary SDK and commercial licensing

**CinePlayerSDK** (the prebuilt binary libraries in this repository) is proprietary software. The **definitive terms** are in the License file inside the SDK (see path above). You may not reverse engineer, decompile, or disassemble the SDK binaries.

For **this repository only**, the licensor permits:

- **Personal use only**:  
  You may use `CinePlayerSDK` **for personal use only**. No redistribution, sublicense, or commercial use without prior written permission.
- **Commercial use**:  
  **Strictly prohibited** for any third-party company without prior written permission.
- **Commercial license**:  
  Contact `cinemore@cinemore.com.cn` for commercial use or redistribution rights.

