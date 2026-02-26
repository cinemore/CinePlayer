## 1. Right-side panel spacing fix

- [x] 1.1 Update trailing-direction side container spacing/height calculation in `SiderContanierView` so top, trailing, and bottom spacing are equal
- [x] 1.2 Keep bottom-direction playback-speed panel spacing unchanged (no edits to its bottom padding behavior)
- [x] 1.3 Make macOS play-setting form use content-height layout to avoid oversized bottom blank area

## 2. Verification

- [x] 2.1 Build CinePlayer for `iphoneos` and `iphonesimulator`
- [x] 2.2 Build CinePlayer for `appletvos` and `appletvsimulator`
- [x] 2.3 Build CinePlayer for `macosx`, `xros`, and `xrsimulator`
