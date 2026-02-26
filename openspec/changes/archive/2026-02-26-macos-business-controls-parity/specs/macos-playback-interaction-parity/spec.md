## ADDED Requirements

### Requirement: macOS playback interaction SHALL use skip-based controls aligned with iOS
The macOS panel SHALL use skip backward and skip forward controls driven by configured seconds, plus play/pause, as the primary playback interaction set.

#### Scenario: Skip backward uses configured seconds
- **WHEN** the user activates skip backward
- **THEN** the player seeks backward by configured skip-backward seconds and emits matching feedback

#### Scenario: Skip forward uses configured seconds
- **WHEN** the user activates skip forward
- **THEN** the player seeks forward by configured skip-forward seconds and emits matching feedback

### Requirement: macOS panel entries SHALL open existing side containers
The macOS panel SHALL open existing subtitle, settings, enhancement, audio, video-track, and playback-speed containers through `PlayerControlModel` state.

#### Scenario: Clicking business entry opens matching container
- **WHEN** the user clicks any supported container entry button
- **THEN** the panel MUST hide other side containers and show only the matching target container
