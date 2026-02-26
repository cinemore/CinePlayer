## Context

`RoundedCornerShape` has platform-specific implementations. The macOS branch currently builds a `Path` via `NSBezierPath` and a local `cgPath` bridge. Under Swift 6 strict concurrency with default `MainActor` isolation, the `Shape.path(in:)` requirement is treated as nonisolated, while the AppKit-backed `cgPath` access is actor-isolated, causing compilation failure.

## Goals / Non-Goals

**Goals:**
- Restore macOS compilation under current Swift concurrency settings.
- Keep `RoundedCornerShape` behavior equivalent for existing callers.
- Minimize scope to one utility file with no API churn.

**Non-Goals:**
- Redesign corner-selection behavior on macOS.
- Introduce new dependencies or broader UI refactors.

## Decisions

1. Use SwiftUI-native `Path(roundedRect:cornerRadius:style:)` in the macOS branch.
Reason: avoids crossing into AppKit actor-isolated APIs from a nonisolated `Shape` requirement.
Alternative considered: keep `NSBezierPath` + bridging property. Rejected because it triggers actor-isolation diagnostics.

2. Remove the local `NSBezierPath.cgPath` helper from this file.
Reason: it becomes unused after switching to SwiftUI-native path construction and keeps isolation surface minimal.
Alternative considered: force isolation with `MainActor.assumeIsolated`. Rejected due to brittle runtime assumptions for a synchronous protocol requirement.

3. Preserve existing public shape signature and caller contract.
Reason: this is a compile-safety fix, not behavior/API expansion.

## Risks / Trade-offs

- [Risk] Rounded corner rendering on macOS may have subtle curve differences versus AppKit path conversion.
  → Mitigation: use `.continuous` style and keep the same radius input; scope validation to build correctness and visual sanity.

- [Risk] Existing macOS `corners` field remains unused.
  → Mitigation: keep current behavior unchanged in this fix; address selective-corner parity separately if required.
