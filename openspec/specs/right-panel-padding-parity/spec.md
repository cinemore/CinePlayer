# right-panel-padding-parity Specification

## Purpose
TBD - created by archiving change right-panel-padding-parity. Update Purpose after archive.
## Requirements
### Requirement: Right-side panel edge spacing parity
The player right-side popup container MUST keep top, trailing, and bottom outer spacing consistent when rendered in trailing direction.

#### Scenario: Open settings panel in trailing direction
- **WHEN** the user opens the settings side panel that is presented from the right side
- **THEN** the container top, trailing, and bottom spacing MUST be equal

### Requirement: Playback-speed bottom spacing preservation
The playback-speed panel MUST keep its existing larger bottom spacing behavior.

#### Scenario: Open playback-speed panel
- **WHEN** the user opens the playback-speed panel presented from bottom direction
- **THEN** the panel MUST preserve its larger bottom spacing and MUST NOT be normalized to trailing panel spacing

