## ADDED Requirements

### Requirement: iOS and macOS enhancement panel SHALL use Cinemore grouped-form style
The enhancement panel on iOS and macOS SHALL use a grouped-form layout with explicit enhancement sections and status messaging consistent with Cinemore style.

#### Scenario: Enhancement panel renders grouped sections
- **WHEN** the user opens enhancement panel
- **THEN** the panel MUST present grouped enhancement sections with section title and descriptive footer text

### Requirement: Enhancement panel MUST NOT include scale-fill toggle entry
The enhancement panel MUST NOT present a scale-fill toggle control.

#### Scenario: Scale-fill control is absent in enhancement panel
- **WHEN** the user opens enhancement panel
- **THEN** no "画面填充" option is rendered inside the enhancement panel
