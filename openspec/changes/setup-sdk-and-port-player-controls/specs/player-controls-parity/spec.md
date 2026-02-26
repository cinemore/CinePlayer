## ADDED Requirements

### Requirement: Player UI SHALL match reference control behavior and visual style across supported platforms
The app SHALL provide a player control experience that matches the reference implementation for iOS, macOS, tvOS, and visionOS, including control visibility behavior, panel structure, and visual styling.

#### Scenario: Control layers render with matching style and transitions
- **WHEN** playback starts and user interacts with player surface
- **THEN** control panels, overlays, and transitions appear and hide with the same interaction timing and visual pattern as the reference implementation

### Requirement: Player SHALL provide parity progress slider behavior
The app SHALL use the migrated custom slider implementation with drag seek behavior and platform-specific preview interactions consistent with the reference implementation.

#### Scenario: User drags progress slider to seek
- **WHEN** the user drags the progress knob to a target position
- **THEN** the player updates displayed time during drag and seeks playback to the selected time when drag ends

#### Scenario: macOS hover preview is displayed on progress slider
- **WHEN** the user hovers the pointer over the progress slider on macOS
- **THEN** the app displays the same style of time/thumbnail preview and chapter hint behavior as the reference implementation

### Requirement: Player SHALL provide parity sider controls for audio, video tracks, and speed
The app SHALL include migrated SiderView containers for audio tracks, video tracks, and playback speed controls, and SHALL apply selected values to active player controller state.

#### Scenario: User changes audio or video track from sider panel
- **WHEN** the user selects a different track in audio/video sider panels
- **THEN** the player switches to the selected track and reflects selected state in the UI

#### Scenario: User changes speed from sider speed panel
- **WHEN** the user selects a preset speed or taps step controls
- **THEN** the active playback rate updates immediately and the selected speed state is visible

### Requirement: Player gesture behavior SHALL match reference platform-specific interactions
The app SHALL preserve reference gesture mapping per platform, including macOS double-click fullscreen behavior and platform-specific control toggles.

#### Scenario: macOS double click toggles fullscreen with playback continuity handling
- **WHEN** the user double clicks the player surface on macOS
- **THEN** the app toggles fullscreen with the same pre/post playback state handling logic used in the reference implementation

### Requirement: Migrated player controls SHALL not depend on legacy business modules
The project SHALL replace business-layer dependencies in migrated player code with pure player session/state abstractions.

#### Scenario: Player module compiles without legacy business imports
- **WHEN** the migrated player files are compiled in CinePlayer
- **THEN** no file in the player module requires legacy business modules or app-business service dependencies
