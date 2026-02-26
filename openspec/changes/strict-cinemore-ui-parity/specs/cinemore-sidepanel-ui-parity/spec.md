## ADDED Requirements

### Requirement: Side panel container presentation SHALL match Cinemore behavior
Side panel containers on iOS and macOS MUST follow Cinemore-equivalent presentation behavior for direction, overlay interaction, background treatment, and transition hierarchy.

#### Scenario: Side panel opens with Cinemore-equivalent presentation
- **WHEN** the user opens any side panel
- **THEN** the panel MUST animate and render with Cinemore-equivalent container presentation rules

### Requirement: Settings panel SHALL use Cinemore play-settings composition
Settings panel UI MUST follow Cinemore play-settings component composition and styling hierarchy, while binding to CinePlayer-local settings data through adapters.

#### Scenario: Settings panel renders Cinemore play-settings hierarchy
- **WHEN** the user opens the settings panel
- **THEN** the panel MUST show Cinemore-equivalent play-settings row/group hierarchy and visual styling

### Requirement: Subtitle panel SHALL use Cinemore subtitle subview composition
Subtitle panel UI MUST be composed with Cinemore-equivalent embedded, external, and adjustment subviews and component-level styling, including subtitle adjustment controls.

#### Scenario: Subtitle panel tabs use Cinemore subview composition
- **WHEN** the user switches among 内封字幕, 外部字幕, 字幕调整 tabs
- **THEN** each tab MUST render the Cinemore-equivalent subview structure and style composition

### Requirement: External subtitle import MUST remain local-only in pure-player mode
External subtitle UI MUST keep local file import and MUST NOT expose the file-source import entry in pure-player mode.

#### Scenario: External subtitle import menu excludes file-source import
- **WHEN** the user opens external subtitle import actions
- **THEN** local import MUST be available and file-source import MUST NOT be present

### Requirement: Media info and enhancement panels SHALL match Cinemore section hierarchy
Media info and enhancement panels MUST render Cinemore-equivalent section/card hierarchy and section gating behavior for the active build mode.

#### Scenario: Media info and enhancement panels keep Cinemore hierarchy
- **WHEN** the user opens media info or enhancement panels
- **THEN** panel sections, card grouping, and gating behavior MUST match Cinemore-equivalent structure
