## ADDED Requirements

### Requirement: iOS control panel SHALL match Cinemore business layout structure
The app SHALL provide iOS portrait and landscape control panel layouts that follow the Cinemore iOS structure for top area, bottom area, gradient background, and button grouping order.

#### Scenario: Landscape layout uses Cinemore-equivalent regions and grouping
- **WHEN** iOS player is in landscape
- **THEN** the control panel shows title row, top action row, progress row, and bottom control row with Cinemore-equivalent spacing and grouping

#### Scenario: Portrait layout uses Cinemore-equivalent regions and grouping
- **WHEN** iOS player is in portrait
- **THEN** the control panel shows title row, top action row, secondary action row, and bottom stacked controls with Cinemore-equivalent spacing and grouping

### Requirement: iOS business buttons SHALL include required controls and exclude removed controls
The iOS control panel SHALL include close, PiP, scale-fill toggle, rotate, skip backward, play/pause, skip forward, audio tracks, video tracks, playback speed, subtitle, settings, enhancement, and media info entry points; it MUST NOT include source-switch and playlist entry points.

#### Scenario: Required buttons are present in control panel
- **WHEN** the user opens the iOS control panel
- **THEN** all required button entry points are visible and can be tapped

#### Scenario: Excluded buttons are not present
- **WHEN** the user opens the iOS control panel
- **THEN** source-switch and playlist buttons are not rendered
