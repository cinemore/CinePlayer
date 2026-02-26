## ADDED Requirements

### Requirement: macOS business controls SHALL include iOS-equivalent buttons except orientation toggle
The macOS panel SHALL include close, PiP, scale-fill toggle, skip backward, play/pause, skip forward, audio tracks, video tracks, playback speed, subtitle, settings, enhancement, and media info entry points; it MUST NOT require orientation toggle.

#### Scenario: Required button entries are visible and tappable/clickable
- **WHEN** the user opens the macOS control panel
- **THEN** all required macOS business buttons are present and each entry triggers its corresponding behavior

#### Scenario: macOS keeps full-screen control as platform-specific extension
- **WHEN** the user opens the macOS control panel
- **THEN** full-screen toggle MAY be present as a macOS-specific control without replacing required iOS-equivalent controls
