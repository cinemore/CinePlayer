## Context

`ContentView` currently uses a native iOS `TabView` with two tabs: player and about. Playback is driven by shared player session state, and when a source becomes active the player UI is rendered inline within the player tab hierarchy. This keeps the tab bar visible and can overlap the player control surface.

The requirement is parity with `cinemore-apple`: on iOS, playback should transition into a full-screen modal layer while preserving tab navigation for non-playing states. macOS behavior must remain unchanged.

## Goals / Non-Goals

**Goals:**
- Present active playback via iOS `fullScreenCover` so tab bar chrome is hidden during playback.
- Keep tab switching behavior for idle state (`播放器` and `关于`) unchanged.
- Reuse existing player session state (`currentSource`) as the single presentation trigger.

**Non-Goals:**
- No redesign of player controls or playback business logic.
- No changes to macOS, tvOS, or visionOS navigation patterns.
- No new persistence or deep-link behavior changes.

## Decisions

Use a lightweight iOS-only tab-host wrapper for the player tab.
Rationale: keeping `ContentView` as the platform switch point avoids broad refactors and localizes behavior change to iOS composition.
Alternative considered: moving full-screen presentation into `PlayerRootView`. Rejected because it would blur responsibilities and risk affecting non-iOS flows that also use `PlayerRootView`.

Drive `fullScreenCover` with `PlayerSessionStore.currentSource != nil`.
Rationale: this state already represents “playback active” and is the canonical trigger used by current player routing.
Alternative considered: adding a new explicit `isPresentingPlayer` flag. Rejected to avoid duplicated state and synchronization bugs.

Host `PlayerOpenView` in the tab and present `PlayerRootView` inside the cover.
Rationale: users keep the normal open/import entry UI in-tab; once media starts, full player controls appear in modal full screen.
Alternative considered: presenting `PlayerControlView` directly. Rejected because `PlayerRootView` already encapsulates source-driven transitions and close handling.

## Risks / Trade-offs

- [Risk] Session state not clearing could keep the cover stuck open. → Mitigation: rely on existing close path that sets `currentSource = nil` and verify close/dismiss behavior manually.
- [Risk] Duplicate environment objects could diverge state. → Mitigation: reuse the same shared `PlayerSessionStore` and `VideoPlayerModel` environment chain already injected at app root.
- [Trade-off] Modal presentation introduces an extra transition animation step. → Mitigation: this is intentional for parity and removes UI overlap with tab bar.
