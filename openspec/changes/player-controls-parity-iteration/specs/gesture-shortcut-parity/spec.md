## ADDED Requirements

### Requirement: iOS gesture behavior SHALL match reference with configurable defaults
The app SHALL provide iOS gesture behavior (single tap toggle mask, double tap play/pause and skip left/right, long-press temporary speed-up, vertical brightness) consistent with the reference implementation, using a pure-player config (e.g. skip seconds, long-press speed-up enabled) with sensible defaults and no dependency on PlaySettingModel.

#### Scenario: Double-tap skip and center play/pause match reference
- **WHEN** the user double-taps left, right, or center on the player surface on iOS
- **THEN** the player skips backward/forward by the configured seconds or toggles play/pause and shows the same Toast feedback as the reference

#### Scenario: Long-press temporary speed-up matches reference
- **WHEN** the user long-presses on the player surface on iOS and the feature is enabled
- **THEN** playback rate temporarily increases (e.g. 2x) and returns on release, with Toast and haptic feedback as in the reference

### Requirement: tvOS remote gesture behavior SHALL match reference
The app SHALL provide tvOS remote behavior (swipe/press for skip and panel show, long-press for continuous seek, select for panel) consistent with the reference implementation, using configurable skip seconds and no dependency on business models.

#### Scenario: Swipe and press skip with correct seconds
- **WHEN** the user swipes or presses left/right on the remote on tvOS
- **THEN** the player skips by the configured seconds and shows Toast consistent with the reference

#### Scenario: Long-press continuous seek and panel show
- **WHEN** the user long-presses left/right or swipes up on the remote on tvOS
- **THEN** the player enters continuous seek or shows the control panel with the same behavior as the reference

### Requirement: macOS SHALL provide keyboard and mouse behavior matching reference
The app SHALL provide macOS keyboard shortcuts (space play/pause, left/right skip, up/down playback rate, Esc exit fullscreen) and mouse-move to show controls, using configurable skip seconds and rate step, without depending on PlaySettingModel.

#### Scenario: Keyboard shortcuts control playback
- **WHEN** the user presses space, arrow keys, or Esc while the player has focus on macOS
- **THEN** the player toggles play/pause, skips, changes rate, or exits fullscreen as in the reference implementation

#### Scenario: Mouse move shows control layer
- **WHEN** the user moves the pointer over the player window on macOS
- **THEN** the control layer is shown and the auto-hide timer is reset as in the reference implementation

### Requirement: SiderView SHALL align with reference interaction and direction
The app SHALL make SiderView close on backdrop tap and call PlayerMaskModel to restore mask state; SHALL determine slide direction (trailing vs bottom) by device and orientation (e.g. iPhone portrait bottom, else trailing) consistent with the reference, while keeping only audio, video track, and playback speed panels.

#### Scenario: Tapping SiderView backdrop closes panel and restores mask
- **WHEN** the user taps the dimmed area outside the SiderView panel
- **THEN** the panel closes and PlayerMaskModel state is updated so control layer visibility is restored as in the reference

#### Scenario: SiderView slide direction by device and orientation
- **WHEN** the user opens audio, video track, or speed panel
- **THEN** the panel appears from the side or bottom according to the same rules as the reference (e.g. iPhone portrait from bottom)
