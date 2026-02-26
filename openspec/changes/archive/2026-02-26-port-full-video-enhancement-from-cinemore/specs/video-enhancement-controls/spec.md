## ADDED Requirements

### Requirement: Enhancement panel SHALL provide full strategy controls
The player enhancement panel MUST expose configurable controls for Anime4K, system VT enhancement, and optical-flow interpolation, with parameter bindings consistent with the migrated `cinemore-apple` implementation.

#### Scenario: User opens enhancement panel
- **WHEN** the enhancement sider panel is shown
- **THEN** the panel MUST render strategy controls and related parameters for the migrated enhancement stack instead of placeholder-only text

### Requirement: Enhancement settings SHALL be per-video session
Enhancement states and runtime toggles MUST reset for each new video session to avoid leaking prior video settings.

#### Scenario: User switches to a new video source
- **WHEN** a new source is opened in the player
- **THEN** enhancement strategy and per-session toggles MUST reset to default off state

### Requirement: Enhancement controls SHALL enforce capability gates
The UI and model MUST gate strategy enablement by platform/system support and current video resolution constraints.

#### Scenario: Current video or platform does not satisfy requirements
- **WHEN** strategy prerequisites are not met (e.g. unsupported system VT capability or out-of-range resolution)
- **THEN** the corresponding strategy toggle MUST be unavailable and the panel MUST show state feedback
