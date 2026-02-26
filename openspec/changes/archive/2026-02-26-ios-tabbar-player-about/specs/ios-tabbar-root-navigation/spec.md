## ADDED Requirements

### Requirement: iOS Root TabBar Navigation
On iOS, the app MUST provide a native TabBar with exactly two tabs to switch between the player and the about page.

#### Scenario: User sees two tabs on iOS root
- **WHEN** the app launches on iOS
- **THEN** the root UI MUST show two tabs labeled "播放器" and "关于"
- **AND** the default selected tab MUST be "播放器"

### Requirement: Player Tab Hosts Existing Player View
The player tab MUST render the existing player root experience.

#### Scenario: Player tab displays player root
- **WHEN** the user selects the "播放器" tab
- **THEN** the app MUST render `PlayerRootView`

### Requirement: About Tab Hosts Existing About Page
The about tab MUST render the existing about content without changing macOS behavior.

#### Scenario: About tab displays about page
- **WHEN** the user selects the "关于" tab on iOS
- **THEN** the app MUST render `AboutPage`
- **AND** macOS root UI behavior MUST remain unchanged
