## ADDED Requirements

### Requirement: Player SHALL provide Apple translation language-pack management entry
When translation mode requires translation, the subtitle panel MUST provide an entry point to open an Apple translation language-pack management page.

#### Scenario: Open language-pack page from subtitle panel
- **WHEN** the user taps the language-pack management entry in subtitle panel
- **THEN** the app presents a language-pack page without leaving playback context

### Requirement: Language-pack page SHALL support availability check and download trigger
On supported systems, the language-pack page MUST query language-pair availability and allow the user to trigger package download preparation.

#### Scenario: Installed language pair shows ready status
- **WHEN** the selected language pair is already installed
- **THEN** the page displays installed status and disables repeated download action

#### Scenario: User triggers package download for missing pair
- **WHEN** the selected language pair is not installed and user taps download
- **THEN** the page invokes `TranslationSession.prepareTranslation()` for that pair and reflects preparation state

### Requirement: Unsupported systems SHALL show explicit compatibility fallback
The language-pack page MUST provide a clear compatibility message on systems that do not support Apple Translation language-pack APIs.

#### Scenario: Running on unsupported OS version
- **WHEN** the language-pack page is opened on unsupported OS versions
- **THEN** the page shows compatibility guidance and does not attempt translation package APIs
