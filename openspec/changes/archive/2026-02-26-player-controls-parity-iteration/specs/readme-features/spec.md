## ADDED Requirements

### Requirement: README SHALL reflect current player features and platforms
The project SHALL maintain README-zh.md (or the primary README for the repo) so that it describes the current pure-player feature set and supported platforms, including playback controls, gesture/shortcut behavior, supported platforms (iOS, macOS, tvOS, visionOS), and how to build/run, without describing removed or out-of-scope business features.

#### Scenario: Feature list matches implemented capabilities
- **WHEN** a reader opens the README
- **THEN** the documented features (e.g. controls, gestures, PiP, keyboard shortcuts, multi-platform) align with what is implemented in the current change and do not claim unimplemented or excluded capabilities

#### Scenario: Build and run instructions are accurate
- **WHEN** a developer follows the README build/run instructions
- **THEN** they can build and run the app for the documented platforms (e.g. using AGENTS.md-recommended xcodebuild destinations or Xcode scheme) without missing steps

### Requirement: README update SHALL be part of this change
The update to README-zh.md (or primary README) for the above SHALL be completed as part of the player-controls-parity-iteration change, so that after implementation the document reflects the post-iteration state.

#### Scenario: README updated after parity iteration tasks complete
- **WHEN** all implementation tasks for this change are done
- **THEN** README-zh.md has been updated to include the new or aligned features (layout, gestures, Toast, system capabilities, light playlist, etc.) and any revised build/usage notes
