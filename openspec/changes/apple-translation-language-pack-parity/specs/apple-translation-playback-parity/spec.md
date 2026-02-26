## ADDED Requirements

### Requirement: Player SHALL auto-check Apple language-pack availability during playback
When Apple subtitle translation mode is enabled and a runtime language pair is resolved, the player MUST check language-pack availability while playback is active.

#### Scenario: Missing language pack during playback
- **WHEN** playback is active and the current Apple translation language pair is not installed
- **THEN** the player pauses playback and presents the language-pack download dialog prefilled with the current pair

#### Scenario: Unsupported language pair
- **WHEN** playback is active and Apple reports the pair as unsupported
- **THEN** the player presents a non-downloadable compatibility message dialog for that pair

### Requirement: Player SHALL present language-pack dialog with parity sizing
The language-pack dialog MUST use a stable content container and match reference minimum sizes on macOS.

#### Scenario: Present downloadable dialog on macOS
- **WHEN** the player presents the language-pack download UI on macOS
- **THEN** the dialog content enforces a minimum size of 420x480

#### Scenario: Present unsupported dialog on macOS
- **WHEN** the player presents unsupported-language messaging on macOS
- **THEN** the dialog content enforces a minimum size of 420x280

### Requirement: Subtitle panel SHALL not expose manual language-pack management entry
The embedded subtitle panel MUST not display any language-pack download or management button.

#### Scenario: Open subtitle panel with translation enabled
- **WHEN** the user opens embedded subtitle settings and translation mode is not off
- **THEN** only translation mode controls are shown and no manual language-pack entry is visible

### Requirement: Apple translation routing SHALL not convert failures into successful source-text responses
The Apple translation route MUST propagate translation/session failures to the caller instead of returning original text as a success payload.

#### Scenario: Apple session not prepared yet
- **WHEN** Apple translation session is unavailable or not prepared
- **THEN** the translation call fails through normal error propagation and is handled by existing subtitle fallback logic
