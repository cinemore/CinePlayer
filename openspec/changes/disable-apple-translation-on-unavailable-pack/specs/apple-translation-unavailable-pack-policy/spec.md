## ADDED Requirements

### Requirement: Player SHALL disable subtitle translation when Apple reports unsupported language pair
When playback language-pack checking returns `unsupported`, the player MUST immediately disable subtitle translation mode.

#### Scenario: Unsupported pair detected during playback
- **WHEN** subtitle translation mode is enabled and Apple reports the current pair as `unsupported`
- **THEN** the player sets `subtitleTranslateMode` to `off`
- **AND** logs the fallback reason with pair context
- **AND** presents unsupported messaging to the user

### Requirement: Player SHALL disable subtitle translation if language-pack dialog closes without installation
When language-pack download dialog is dismissed from a downloadable-missing state, the player MUST verify install status and close translation if still unavailable.

#### Scenario: User dismisses download dialog without completing install
- **WHEN** dialog closes for a pair whose pre-dismiss state is `canDownload`
- **AND** post-dismiss availability is not `installed`
- **THEN** the player sets `subtitleTranslateMode` to `off`
- **AND** logs the fallback reason with pair and status context

#### Scenario: User completes install before dismiss
- **WHEN** dialog closes for a pair whose pre-dismiss state is `canDownload`
- **AND** post-dismiss availability is `installed`
- **THEN** the player keeps current translation mode unchanged
- **AND** writes a debug log indicating no fallback was applied
