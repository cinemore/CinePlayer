## 1. Launch Canvas Layout

- [x] 1.1 Refactor `PlayerOpenView` from demo stack into a single full-window launch canvas with linear visual styling.
- [x] 1.2 Replace launch branding area with `Image("CinePlayerIcon")` styled consistently with About page icon presentation.
- [x] 1.3 Remove non-essential launch actions (including test-video shortcut and external icon affordances) and keep only core open controls.

## 2. Open Controls And Interaction

- [x] 2.1 Implement enclosed URL input plus `播放` / `播放文件` buttons with clear hierarchy and existing URL parsing behavior.
- [x] 2.2 Keep file picker flow for non-tvOS platforms and wire `播放文件` to the importer.
- [x] 2.3 Add full-window drag-and-drop file opening and bottom-centered hint/status feedback updates.
- [x] 2.4 Refine URL input presentation to a single-line enclosed control instead of a large multiline panel.

## 3. Verification

- [x] 3.1 Manually sanity-check URL open, file picker open, and drag-drop open paths in `PlayerOpenView` logic.
- [x] 3.2 Run required all-platform builds (`iphoneos`, `iphonesimulator`, `appletvos`, `appletvsimulator`, `macosx`, `xros`, `xrsimulator`) and confirm pass.
