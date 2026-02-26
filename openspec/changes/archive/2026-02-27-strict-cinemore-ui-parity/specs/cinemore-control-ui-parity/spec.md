## ADDED Requirements

### Requirement: iOS and macOS control overlays SHALL use Cinemore-equivalent component structure
The player control overlays on iOS and macOS MUST use the same control-group structure and visual hierarchy as Cinemore, including top/bottom control grouping, button cluster composition, and playback cluster arrangement.

#### Scenario: Control overlay layout matches Cinemore grouping
- **WHEN** the user reveals player controls during playback
- **THEN** the control overlay MUST present the same group ordering and cluster structure as Cinemore on the same platform

### Requirement: Required business controls MUST be present and disallowed controls MUST be absent
Control overlays MUST include close, PiP, fill mode, rotate (mobile only), seek backward/forward, play/pause, audio track, video track, and playback speed controls; and MUST NOT include source-switch or episode-list controls in pure-player mode.

#### Scenario: Required controls are visible with pure-player exclusions
- **WHEN** the user opens the control overlay
- **THEN** all required controls MUST be visible and source-switch/episode-list controls MUST NOT be rendered

### Requirement: Playback state transitions SHALL update control icons immediately
Play/pause state changes MUST update the corresponding control button icon without requiring pointer hover, focus movement, or extra interaction to trigger redraw.

#### Scenario: Play button updates immediately after pause
- **WHEN** the user taps or clicks the play/pause button
- **THEN** the icon state MUST update immediately to reflect the new playback state

### Requirement: iOS player session SHALL enter landscape playback orientation on open
On iOS phone devices, opening player playback MUST enter the Cinemore-equivalent landscape playback orientation behavior.

#### Scenario: iOS player opens in landscape playback mode
- **WHEN** the user opens player playback on iPhone
- **THEN** the player UI MUST switch to landscape playback orientation behavior
