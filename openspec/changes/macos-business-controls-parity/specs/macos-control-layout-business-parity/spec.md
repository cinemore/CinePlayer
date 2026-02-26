## ADDED Requirements

### Requirement: macOS control panel SHALL match iOS business grouping semantics
The macOS control panel SHALL use top and bottom regions whose button grouping semantics match the iOS business control layout, except iOS-specific orientation controls.

#### Scenario: Top region presents close and business action groups
- **WHEN** the macOS player control panel is visible
- **THEN** the top region MUST include close control, player action controls, and business action controls in stable groups

#### Scenario: Bottom region presents progress and playback groups
- **WHEN** the macOS player control panel is visible
- **THEN** the bottom region MUST include progress control and grouped playback/business controls with iOS-equivalent ordering
