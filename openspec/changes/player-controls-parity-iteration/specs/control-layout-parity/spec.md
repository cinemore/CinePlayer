## ADDED Requirements

### Requirement: Player control layout SHALL match reference per platform
The app SHALL provide per-platform control panel layout (ControllerPanelViewIOS, ControllerPanelViewMacOS, ControllerPanelViewTvOS, ControllerPanelViewVision) that matches the reference implementation in button grouping, gradient background, top/bottom regions, and spacing for iPhone portrait/landscape, iPad, macOS, tvOS, and visionOS.

#### Scenario: iOS landscape control layout matches reference
- **WHEN** the user views the player in landscape on iPhone or iPad
- **THEN** the control panel shows the same top bar (close, title, button groups), bottom progress bar and button row, and gradient background as the reference implementation

#### Scenario: iOS portrait control layout matches reference
- **WHEN** the user views the player in portrait
- **THEN** the control panel uses the same portrait layout and grouping as the reference implementation

#### Scenario: macOS control panel layout matches reference
- **WHEN** the user views the player on macOS
- **THEN** the control panel structure and button placement match the reference implementation for macOS

#### Scenario: Control visibility and auto-hide timing match reference
- **WHEN** the user interacts with or leaves the player surface
- **THEN** control panels appear and hide with the same delay and animation as the reference implementation

### Requirement: PlayerControlView SHALL delegate panel content to platform ControllerPanel
The app SHALL structure PlayerControlView so that it hosts the video view, overlay layers, gesture layer, and Toast; control panel content SHALL be provided by platform-specific ControllerPanel views that use only PlayerSessionStore, VideoPlayerModel, PlayerMaskModel, and a minimal PlayerControlModel.

#### Scenario: No business types in control panel views
- **WHEN** the project is built for any target
- **THEN** ControllerPanel and PlayerControlView code does not depend on DetailPageModel, PlayerParams, or app-business APIs
