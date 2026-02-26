## Context

macOS Debug builds currently produce a repeated set of Swift warnings concentrated in player UI/concurrency integration points and logging helpers. The warnings are deterministic and stem from Swift 6 actor-isolation inference (`View` main actor isolation, global function isolation defaults) plus small code-quality issues (`var` not mutated).

## Goals / Non-Goals

**Goals:**
- Remove all warnings listed in the current user-provided macOS build log.
- Preserve runtime behavior while aligning with Swift 6 actor-isolation semantics.
- Keep the fix minimal and scoped to touched warning sites.

**Non-Goals:**
- Refactor player architecture or callback threading model broadly.
- Change subtitle/enhancement feature behavior.
- Rebuild external binary frameworks.

## Decisions

1. Convert global log helpers from `nonisolated(unsafe)` to `nonisolated`.
Reason: compiler explicitly states `unsafe` has no effect for global functions.
Alternative: remove annotation entirely. Rejected to keep explicit nonisolated intent under default main-actor isolation mode.

2. Dispatch `PlayerOpenView` drop callback media-open calls onto `MainActor` via `Task { @MainActor ... }`.
Reason: `View` methods are main-actor isolated; drop provider completion runs in a synchronous nonisolated callback.
Alternative: mark callback helper/main methods nonisolated. Rejected because UI state/session open should stay main-actor safe.

3. Replace non-mutated locals in `VideoPlayerModel` closures from `var` to `let`.
Reason: resolves warnings without behavioral change.

4. In `Anime4KHostRuntime`, execute texture-pool return inside `Task { @MainActor ... }` from command-buffer completion callback.
Reason: completion handler is synchronous nonisolated `@Sendable`; direct call to main-actor method and isolated property access triggers warnings.
Alternative: force `nonisolated(unsafe)` on pool-return method/properties. Rejected to avoid weakening isolation guarantees.

## Risks / Trade-offs

- [Risk] MainActor hop in completion callback introduces slight scheduling delay before texture returns to pool.
  → Mitigation: operation is non-critical cleanup; lock-protected pool logic remains unchanged.

- [Risk] Additional `Task` allocation in drop callbacks and completion handlers.
  → Mitigation: warning-safe fix is minimal; overhead is negligible relative to I/O/GPU callback boundaries.
