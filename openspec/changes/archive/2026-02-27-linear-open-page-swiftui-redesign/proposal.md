## Why

The current player start page is still demo-like and does not match the intended production visual quality or workflow. We need a focused, modern launch surface that fits CinePlayer's visual identity and core job: quickly open media by URL, file picker, or drag-and-drop.

## What Changes

- Redesign `PlayerOpenView` to a single full-window linear visual style instead of a stacked demo layout.
- Replace the top visual with `CinePlayerIcon` presentation aligned with the About page style.
- Keep only the essential entry actions:
  - enclosed URL input field
  - `播放` button for URL playback
  - `播放文件` button for local file picker
- Enable drag-and-drop file opening across the entire start window (not only a subsection).
- Show a bottom-centered hint/status line for drag-and-drop and action feedback.
- Remove non-essential start-page actions (for example, test-video shortcut and extra decorative controls).

## Capabilities

### New Capabilities
- `player-open-page-experience`: Defines the launch page visual structure and interaction behavior for URL input, file picker, and full-window drag-and-drop playback.

### Modified Capabilities
- None.

## Impact

- Affected code:
  - `CinePlayer/Player/Views/PlayerOpenView.swift`
- No API changes.
- No external dependencies added.
- UX behavior changes at app launch before playback begins.
