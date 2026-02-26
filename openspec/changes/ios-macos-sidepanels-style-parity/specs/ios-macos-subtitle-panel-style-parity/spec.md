## ADDED Requirements

### Requirement: iOS and macOS subtitle panel SHALL use segmented three-tab layout
The subtitle panel on iOS and macOS SHALL use a segmented control with three tabs: embedded subtitle, external subtitle, and subtitle adjustment.

#### Scenario: Subtitle panel shows three-tab segmented header
- **WHEN** the user opens subtitle panel
- **THEN** the panel MUST show segmented tabs for 内封字幕, 外部字幕, 字幕调整

### Requirement: External subtitle tab SHALL keep local import only
External subtitle tab MUST support local import and MUST NOT include source-based import entries.

#### Scenario: Source-based import option is absent
- **WHEN** the user opens external subtitle tab import actions
- **THEN** only local import is available and no file-source import option appears
