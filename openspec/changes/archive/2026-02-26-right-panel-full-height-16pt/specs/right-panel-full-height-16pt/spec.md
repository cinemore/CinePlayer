## ADDED Requirements

### Requirement: Right settings panel SHALL be full-height with 16pt trailing edge insets
When rendered in trailing direction, the settings panel container MUST occupy full available height minus fixed 16pt top and bottom insets and MUST keep 16pt trailing inset from window boundary.

#### Scenario: Open settings panel on macOS trailing layout
- **WHEN** the user opens the settings panel in trailing direction
- **THEN** the panel top, trailing, and bottom distances to window boundary MUST each be 16pt
- **AND** the panel height MUST fill the remaining vertical space between those insets

### Requirement: Playback-speed bottom panel spacing SHALL remain unchanged
Bottom-direction playback-speed panel MUST preserve its existing larger bottom spacing behavior.

#### Scenario: Open playback-speed panel after settings layout update
- **WHEN** the user opens the playback-speed panel
- **THEN** its bottom spacing behavior MUST remain unchanged from previous implementation
