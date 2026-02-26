## Context

`PlayerOpenView` currently uses a simple demo layout and does not reflect the intended production launch experience. The product goal for this iteration is a single full-window launch canvas with a strong linear visual style, the About-page icon treatment (`CinePlayerIcon`), and only essential media-open actions.

The implementation must stay inside the current SwiftUI architecture and avoid introducing new dependencies. The view needs to preserve cross-platform behavior where possible, while keeping drag-and-drop file open behavior available across the whole start window.

## Goals / Non-Goals

**Goals:**
- Implement a single-canvas launch view in `PlayerOpenView` (no split top/bottom zones).
- Use `CinePlayerIcon` at the top visual area with styling consistent with About page icon treatment.
- Keep only core actions: enclosed URL text field, `播放` button, and `播放文件` button.
- Enable full-window drag-and-drop file opening and show bottom-centered hint/status text.
- Keep existing URL resolution and file importer behavior.

**Non-Goals:**
- No changes to playback control UI (`PlayerControlView`) after media starts.
- No new settings/preferences for launch-page theming.
- No addition of external links/icons (including GitHub icon).

## Decisions

1. Use a single root `ZStack` canvas with layered linear/radial gradients.
- Rationale: This directly matches the requested full-region design and avoids the previous split layout artifacts.
- Alternative considered: Keep `VStack` top/bottom segmentation and soften divider. Rejected because it still implies two regions.

2. Reuse About-page icon asset usage (`Image("CinePlayerIcon")`) in launch view.
- Rationale: Ensures visual consistency with existing app branding and avoids introducing new logo primitives.
- Alternative considered: Custom shape/logo recreation in SwiftUI. Rejected due to mismatch risk and unnecessary complexity.

3. Keep URL input as enclosed field using rounded shape and material-like background.
- Rationale: Matches requested SwiftUI enclosed text field feel while keeping a custom style consistent with launch canvas.
- Alternative considered: Native `.textFieldStyle(.roundedBorder)` only. Rejected because platform differences can reduce visual consistency.

4. Implement drag-and-drop at full-window container level.
- Rationale: User explicitly requested drag-to-open from any window region.
- Alternative considered: Restrict drop to control panel area. Rejected by requirement.

5. Centralize status/hint text at bottom center with live updates from URL/file/drop actions.
- Rationale: Provides one stable feedback location and avoids inline UI noise.

## Risks / Trade-offs

- [Platform drag-drop compatibility variance] → Mitigation: Keep file importer button as guaranteed fallback and ensure drop handling only supplements it.
- [Custom field/button styling may diverge from platform-native tone] → Mitigation: keep styling minimal and use existing SwiftUI components with light custom decoration.
- [Whole-window drop highlight can visually overpower content] → Mitigation: use low-opacity overlay and clear state reset on drop/leave.

## Migration Plan

1. Update `PlayerOpenView` layout and interactions behind existing no-source branch (`sessionStore.currentSource == nil`).
2. Verify manual flows: URL play, file importer play, and drag-drop play.
3. Build all required target platforms before completion claim.
4. Rollback plan: revert `PlayerOpenView.swift` to previous implementation if regressions appear.

## Open Questions

- None for this iteration.
