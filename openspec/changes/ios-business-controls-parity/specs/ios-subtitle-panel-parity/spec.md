## ADDED Requirements

### Requirement: iOS subtitle panel SHALL provide embedded subtitle selection and local import
The iOS subtitle panel SHALL expose embedded subtitle enable/disable and track selection, and SHALL provide local file import for external subtitles.

#### Scenario: Embedded subtitle track can be selected
- **WHEN** the subtitle panel is opened and embedded subtitle tracks exist
- **THEN** the user can enable subtitles and switch the selected embedded subtitle track

#### Scenario: Local subtitle file can be imported
- **WHEN** the user selects subtitle local import and chooses a local subtitle file
- **THEN** the file is loaded into the player as an external subtitle and becomes selectable

### Requirement: iOS subtitle external import SHALL NOT include source-based import
The subtitle panel MUST NOT expose the Cinemore "file source import" entry in this repository.

#### Scenario: Source import entry is absent
- **WHEN** the user opens subtitle external import options
- **THEN** no file-source import option is displayed
