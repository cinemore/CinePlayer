## 1. Warning-Site Code Cleanup

- [x] 1.1 Replace `nonisolated(unsafe)` with `nonisolated` in warninging global logger helpers.
- [x] 1.2 Update `PlayerOpenView` drop callback to call `openMedia(url:)` on `MainActor`.
- [x] 1.3 Convert non-mutated `var` locals to `let` in `VideoPlayerModel` frame callback closures.
- [x] 1.4 Update `Anime4KHostRuntime` command-buffer completion callback to return textures through a `MainActor` hop.

## 2. Verification

- [x] 2.1 Run macOS Debug clean build and verify warning set from the user report is eliminated.
- [x] 2.2 Run required multi-platform build matrix (`iphoneos`, `iphonesimulator`, `appletvos`, `appletvsimulator`, `macosx`, `xros`, `xrsimulator`) and confirm builds still succeed.
