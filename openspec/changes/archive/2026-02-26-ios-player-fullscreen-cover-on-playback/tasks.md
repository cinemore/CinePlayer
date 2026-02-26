## 1. iOS Playback Presentation Wiring

- [x] 1.1 Add an iOS player-tab host view that keeps `PlayerOpenView` in-tab and presents playback with `fullScreenCover`.
- [x] 1.2 Drive full-screen presentation from shared player session state (`currentSource`) and render `PlayerRootView` inside the cover.

## 2. Platform Scope And Navigation Safety

- [x] 2.1 Update iOS `ContentView` tab composition to use the new player-tab host while keeping the about tab unchanged.
- [x] 2.2 Ensure non-iOS branches remain unchanged and compile.

## 3. Verification

- [x] 3.1 Run required `xcodebuild` builds for iphoneos, iphonesimulator, appletvos, appletvsimulator, macosx, xros, and xrsimulator.
- [x] 3.2 Mark tasks complete and confirm OpenSpec status is implementation-complete.
