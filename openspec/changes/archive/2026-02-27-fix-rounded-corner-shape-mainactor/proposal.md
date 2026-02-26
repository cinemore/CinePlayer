## Why

Swift 6 strict concurrency with default `MainActor` isolation currently breaks macOS compilation in `RoundedCornerShape` because `Shape.path(in:)` executes in a nonisolated context while the implementation touches an AppKit-isolated `cgPath` accessor. This violates the repository requirement that all platform destinations build successfully.

## What Changes

- Refactor macOS `RoundedCornerShape.path(in:)` to build the rounded path without relying on AppKit-isolated `NSBezierPath.cgPath`.
- Remove now-unnecessary AppKit bridge code used only for this conversion path.
- Add an OpenSpec delta under `all-platform-build-pass` to require actor-isolation-safe rounded-corner path construction that compiles under Swift 6 concurrency checks.

## Capabilities

### New Capabilities
- None.

### Modified Capabilities
- `all-platform-build-pass`: Mac builds must remain Swift 6 concurrency-clean for shared UI utilities, including `RoundedCornerShape` path generation.

## Impact

- Affected code: `CinePlayer/Player/UICommon/RoundedCornerShape.swift`
- Affected spec: `openspec/specs/all-platform-build-pass/spec.md` (delta in this change)
- No runtime API changes; this is a compilation-safety fix.
