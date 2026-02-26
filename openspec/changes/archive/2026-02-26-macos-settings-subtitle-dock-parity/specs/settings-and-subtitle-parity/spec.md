## ADDED Requirements

### Requirement: macOS 播放设置需与 Cinemore 平台行为一致
The macOS play setting panel MUST only expose left-click backward and right-click forward step selectors, and MUST NOT expose long-press speed controls, subtitle-setting rows, or placeholder prompt copy.

#### Scenario: Open play settings on macOS
- **WHEN** user opens the play settings panel on macOS
- **THEN** the panel shows exactly two selector rows for backward/forward step seconds
- **AND** the panel does not show long-press speed controls
- **AND** the panel does not show subtitle-setting rows or non-functional prompt text

### Requirement: 字幕面板结构与样式需与 Cinemore 一致
The subtitle panel on iOS and macOS MUST follow Cinemore section structure and row style for embedded subtitles, external subtitles, and subtitle adjustment entry.

#### Scenario: Open subtitle panel on iOS or macOS
- **WHEN** user opens the subtitle panel
- **THEN** the panel presents sections for embedded subtitles, external subtitles, and subtitle adjustment with Cinemore-matching hierarchy and visual style

### Requirement: 字幕调整必须可操作
Subtitle adjustment MUST be an actionable feature that lets user adjust subtitle timing offset in the panel flow.

#### Scenario: Adjust subtitle offset
- **WHEN** user enters subtitle adjustment and changes offset
- **THEN** the new offset is applied to subtitle rendering timing without requiring unrelated panel refresh actions
