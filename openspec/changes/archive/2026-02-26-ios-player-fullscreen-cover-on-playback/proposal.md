## Why

iOS now uses a native `TabView` to switch between player and about pages. When playback starts, rendering the player inside the tab causes the tab bar to overlap controls and diverge from `cinemore-apple` behavior.

## What Changes

- Keep iOS tab navigation (`播放器` / `关于`) as-is for idle navigation.
- Present playback UI via `fullScreenCover` when a playable source is active, so the tab bar is not visible during playback.
- Ensure dismiss/close transitions return to the tabbed player entry page cleanly.
- Keep macOS and other platforms unchanged.

## Capabilities

### New Capabilities
- `ios-tabbed-player-fullscreen-presentation`: On iOS, playback launched from the player tab is presented full screen and isolated from tab bar chrome.

### Modified Capabilities
- None.

## Impact

- Affected code: iOS view composition around `ContentView` and player entry/presentation wiring.
- No API or dependency changes.
- Runtime behavior change is limited to iOS playback presentation.
