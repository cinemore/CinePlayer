## ADDED Requirements

### Requirement: macOS player source build SHALL remain warning-clean for known Swift concurrency hygiene cases
Player source files covered by this change MUST compile on macOS without the known Swift warning classes for redundant global `nonisolated(unsafe)`, main-actor calls from synchronous nonisolated callbacks, and immutable local binding misuse.

#### Scenario: Build macOS after warning-cleanup changes
- **WHEN** developers build target `CinePlayer` in Debug configuration for macOS
- **THEN** build output MUST not include the previously reported warnings from:
- **THEN** `EnhancementLogCompat.swift` global `nonisolated(unsafe)` logger declaration
- **THEN** `SubtitleTranslationLog.swift` global `nonisolated(unsafe)` logger declaration
- **THEN** `PlayerOpenView.swift` synchronous callback calls into main-actor `openMedia(url:)`
- **THEN** `VideoPlayerModel.swift` non-mutated `var` local bindings in frame callback closures
- **THEN** `Anime4KHostRuntime.swift` synchronous nonisolated callback access to main-actor-isolated pool-return path
