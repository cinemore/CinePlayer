## ADDED Requirements

### Requirement: Player SHALL provide Apple subtitle translation modes in subtitle panel
The subtitle panel MUST expose translation mode options (`off`, `translated`, `bilingual`) and MUST sync the selected mode to `CinePlayerConfig.subtitleTranslateMode` during active playback.

#### Scenario: User switches translation mode in subtitle panel
- **WHEN** the user selects a different translation mode in the embedded subtitle panel
- **THEN** the player updates runtime settings and applies the selected `subtitleTranslateMode` to the active playback config

#### Scenario: Mode change takes effect on current subtitle rendering
- **WHEN** translation mode changes while a subtitle track is active
- **THEN** the player refreshes subtitle playback state so subsequent subtitle lines use the new translation mode

### Requirement: Player SHALL route subtitle translation through Apple Translation only
When translation mode requires translation, the player MUST execute subtitle translation through Apple Translation runtime, and MUST NOT call Google translation services.

#### Scenario: Apple translation is active on supported systems
- **WHEN** translation mode is `translated` or `bilingual` and an Apple translation session is available
- **THEN** the subtitle translation callback returns Apple-translated text for subtitle rendering

#### Scenario: Unsupported system gracefully falls back
- **WHEN** translation mode is enabled on a platform or OS version without Apple Translation support
- **THEN** the subtitle callback returns original text and playback continues without crash

### Requirement: TranslationSession lifecycle SHALL be hosted by SwiftUI translationTask
The app MUST host Apple `TranslationSession` inside a SwiftUI `.translationTask` view and route session work through a runtime-safe bridge.

#### Scenario: Runtime pair becomes available during playback
- **WHEN** translation runtime resolves a source/target pair and language pack is installed
- **THEN** the task host attaches `.translationTask` and forwards the session to the translation router

#### Scenario: Translation mode is disabled
- **WHEN** translation mode changes to `off`
- **THEN** the runtime detaches translation task configuration and clears pending Apple translation state
