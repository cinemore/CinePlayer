## ADDED Requirements

### Requirement: Launch page SHALL use a single full-window canvas
When no media source is active, the player launch page SHALL render as a single unified canvas without split top/bottom regions.

#### Scenario: Open page renders unified layout
- **WHEN** the app is on `PlayerOpenView` with no current media source
- **THEN** the view is presented as one full-window canvas
- **THEN** no visual split-divider structure is shown

### Requirement: Launch page SHALL use CinePlayer icon branding
The launch page SHALL display `CinePlayerIcon` in the top branding area with visual treatment aligned to the About page icon usage.

#### Scenario: Branding area loads app icon
- **WHEN** the launch page appears
- **THEN** `CinePlayerIcon` is visible in the branding area
- **THEN** the icon presentation matches the app's established About-page branding style

### Requirement: Launch page SHALL provide essential open actions only
The launch page SHALL provide an enclosed URL input field, a `播放` action, and a `播放文件` action as the only primary media-open controls.

#### Scenario: User opens media by URL
- **WHEN** the user enters a valid URL and taps `播放`
- **THEN** the app resolves the URL and opens media playback

#### Scenario: User opens media by file picker
- **WHEN** the user taps `播放文件` and chooses a video file
- **THEN** the app opens playback with the selected file

#### Scenario: URL input remains single-line
- **WHEN** the launch page renders
- **THEN** the URL input is displayed as a single-line enclosed field
- **THEN** the control is compact and does not render as a multiline panel

#### Scenario: Action buttons keep equal visual width
- **WHEN** the launch page renders on platforms that show both `播放` and `播放文件`
- **THEN** both action buttons are presented with equal width
- **THEN** both controls appear as one aligned action group below the URL input

### Requirement: Launch page SHALL support full-window drag-and-drop opening
The launch page SHALL accept dropped video files from any window region and open playback with the dropped file.

#### Scenario: Drop file on any area
- **WHEN** the user drags and drops a supported video file anywhere in the launch window
- **THEN** the app accepts the drop
- **THEN** playback opens for the dropped file

### Requirement: Launch page SHALL show macOS-only bottom guidance hint
The launch page SHALL show a fixed bottom-centered drag-and-drop guidance hint on macOS only, and SHALL NOT display dynamic status feedback text.

#### Scenario: macOS guidance is visible
- **WHEN** the launch page appears on macOS
- **THEN** a bottom-centered fixed guidance text is shown
- **THEN** the text does not change after play, file pick, or file drop actions

#### Scenario: Non-macOS platforms hide guidance text
- **WHEN** the launch page appears on iOS, tvOS, or visionOS families
- **THEN** no bottom drag-and-drop guidance text is shown
