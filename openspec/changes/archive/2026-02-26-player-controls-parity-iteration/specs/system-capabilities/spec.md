## ADDED Requirements

### Requirement: Player SHALL expose Picture-in-Picture where supported
The app SHALL provide a PiP button in the control panel on iOS and macOS (where SDK supports it) that toggles Picture-in-Picture with the same icon and placement behavior as the reference implementation.

#### Scenario: PiP button toggles Picture-in-Picture on iOS
- **WHEN** the user taps the PiP button on iOS and PiP is supported
- **THEN** the player enters or exits Picture-in-Picture and the button icon reflects the state as in the reference

#### Scenario: PiP button available on macOS when not fullscreen
- **WHEN** the user views the player on macOS in windowed mode and PiP is supported
- **THEN** the control panel includes the PiP button with the same behavior as the reference

### Requirement: Player SHALL provide iOS orientation lock button
The app SHALL provide an orientation lock / rotate button on iOS that controls the current player’s orientation or system orientation lock, with the same placement and icon (e.g. rotate.right / rotate.left) as the reference, without depending on app-wide AppDelegate orientation state if that is business-specific.

#### Scenario: Orientation button toggles lock or rotation
- **WHEN** the user taps the orientation button on iOS
- **THEN** the device orientation lock or player orientation is toggled and the button icon updates as in the reference

### Requirement: Player SHALL integrate with Now Playing and Remote Command Center
The app SHALL register with MPRemoteCommandCenter and update Now Playing info (title, duration, elapsed time, playback rate, play/pause state) so that lock screen, Control Center, and external controls (e.g. headphones) control playback. Title and artwork SHALL be derived from PlayerSessionStore.currentSource and VideoPlayerModel only, with no dependency on DetailPageModel or business metadata.

#### Scenario: Remote commands control playback
- **WHEN** the user triggers play, pause, skip forward/backward, or seek from the lock screen, Control Center, or headphones
- **THEN** the player responds to the command and playback state matches the user action

#### Scenario: Now Playing shows current source info
- **WHEN** playback is active
- **THEN** Now Playing displays title (e.g. from currentSource.displayName or URL filename), duration, elapsed time, and playback rate, and optionally artwork when available from pure-player state only
