## ADDED Requirements

### Requirement: Player SHALL provide a manual action to restart subtitle translation service
The player MUST expose a user-triggered action in subtitle translation settings to restart Apple subtitle translation service.

#### Scenario: User taps restart action while translation enabled
- **WHEN** subtitle translation mode is enabled
- **AND** user taps `重启翻译服务`
- **THEN** player triggers router-level Apple translation session restart flow
- **AND** subsequent translate requests use a newly recreated translator/session path

#### Scenario: User taps restart action while translation disabled
- **WHEN** subtitle translation mode is `off`
- **AND** user taps `重启翻译服务`
- **THEN** player does not crash or change mode
- **AND** restart request is ignored safely with diagnostic log

### Requirement: Router SHALL support explicit manual restart
Subtitle translation router MUST provide an explicit API for manual restart and execute a deterministic reset sequence.

#### Scenario: Manual restart sequence
- **WHEN** manual restart API is called while translation is enabled
- **THEN** router invalidates current Apple translator instance
- **AND** router discards cached translator box
- **AND** router toggles runtime desired pair to force `.translationTask` session recreation
