## ADDED Requirements

### Requirement: Player SHALL recreate Apple translator when translation mode is re-enabled
When subtitle translation mode transitions from disabled to enabled, the player MUST recreate Apple translator instance before serving new requests.

#### Scenario: Mode off to translated
- **WHEN** mode changes from `off` to `translated`
- **THEN** router discards previous Apple translator instance
- **AND** subsequent translation uses a newly created translator/session path

#### Scenario: Mode off to bilingual
- **WHEN** mode changes from `off` to `bilingual`
- **THEN** router discards previous Apple translator instance

#### Scenario: translated to bilingual
- **WHEN** mode changes between enabled translation modes
- **THEN** router does not force translator recreation

### Requirement: Player SHALL recover Apple session after recoverable translate errors
When Apple translation returns recoverable errors while translation mode is still enabled, the player MUST trigger one recovery cycle so subsequent requests can enter a new TranslationSession.

#### Scenario: CancellationError while mode still enabled
- **WHEN** router catches `CancellationError` from Apple translation
- **AND** current subtitle translation mode still requires translation
- **THEN** router invalidates old translator and discards translator box
- **AND** router toggles `desiredApplePair` to force `.translationTask` restart

#### Scenario: sessionUnavailable while mode still enabled
- **WHEN** router catches `sessionUnavailable`
- **AND** current subtitle translation mode still requires translation
- **THEN** router performs the same recovery cycle

#### Scenario: burst failures
- **WHEN** many subtitles fail in a short period
- **THEN** router applies recovery throttle to avoid rebuilding session for every line
