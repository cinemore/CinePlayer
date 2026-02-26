## ADDED Requirements

### Requirement: Player SHALL map enhancement strategy to frame callback policy
The player runtime MUST translate selected enhancement strategy into `FrameCallbackPolicy` and `onVideoFrame` handlers matching the migrated behavior.

#### Scenario: Strategy is changed
- **WHEN** enhancement strategy changes between off / Anime4K / system VT / optical-flow
- **THEN** the player MUST apply the matching frame callback mode and handler (`disabled`, `asyncSingle`, or `temporal`)

### Requirement: Player SHALL support live callback reconfiguration
Enhancement parameter updates during playback MUST reconfigure frame callback settings on the active controller without restarting the app.

#### Scenario: User changes enhancement parameters while playing
- **WHEN** an enhancement toggle or parameter is modified during active playback
- **THEN** frame callback configuration MUST be updated on the active player controller and take effect for subsequent frames

### Requirement: Enhancement callback failures SHALL fail open
If enhancement processing cannot produce a valid frame result, playback MUST continue via passthrough behavior.

#### Scenario: Runtime processing fails or is unavailable
- **WHEN** an adapter/runtime cannot return a valid enhanced frame segment
- **THEN** callback result MUST fallback to passthrough and MUST NOT block playback
