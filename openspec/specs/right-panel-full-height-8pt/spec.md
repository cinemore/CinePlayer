# right-panel-full-height-8pt Specification

## Purpose
TBD - created by archiving change right-panel-full-height-8pt. Update Purpose after archive.
## Requirements
### Requirement: Right settings panel SHALL use 8pt equal edge spacing
The trailing-direction settings panel MUST keep top, trailing, and bottom spacing equal to 8pt while preserving full-height behavior.

#### Scenario: Open settings panel in trailing direction
- **WHEN** the user opens the right-side settings panel
- **THEN** top, trailing, and bottom spacing to window boundary MUST each be 8pt
- **AND** panel MUST remain full-height within those insets

### Requirement: Playback-speed panel spacing SHALL remain unchanged
The bottom playback-speed panel MUST keep its existing spacing behavior unchanged.

#### Scenario: Open playback-speed panel after 8pt update
- **WHEN** the user opens playback-speed panel
- **THEN** its spacing behavior MUST remain the same as before this change

