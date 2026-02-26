## Why

Current macOS Debug builds emit multiple Swift 6 concurrency and code-quality warnings in core player files, which obscures real issues and degrades signal during verification. Cleaning these warnings now keeps the migration to strict concurrency maintainable.

## What Changes

- Replace global `nonisolated(unsafe)` logging helpers with `nonisolated` where `unsafe` has no effect.
- Fix `PlayerOpenView` drop-handler actor isolation by dispatching `openMedia(url:)` to `MainActor`.
- Remove unnecessary mutable locals in `VideoPlayerModel` frame callback closures.
- Fix `Anime4KHostRuntime` command-buffer completion callback isolation so it no longer touches main-actor-isolated members from a synchronous nonisolated `@Sendable` closure.
- Add spec delta requiring macOS source compilation warning cleanup for these classes.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `all-platform-build-pass`: macOS source compilation should remain free of known Swift warning classes in player warning-cleanup scope.

## Impact

- Affected code:
  - `CinePlayer/Player/Enhancement/EnhancementLogCompat.swift`
  - `CinePlayer/Player/Subtitle/Translation/SubtitleTranslationLog.swift`
  - `CinePlayer/Player/Views/PlayerOpenView.swift`
  - `CinePlayer/Player/Model/VideoPlayerModel.swift`
  - `CinePlayer/Player/Enhancement/Anime4K/Anime4KHostRuntime.swift`
- Affected spec:
  - `openspec/specs/all-platform-build-pass/spec.md` (delta in this change)
