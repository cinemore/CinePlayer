## ADDED Requirements

### Requirement: Player SHALL log Apple translation failures with actionable context
Apple translation failures MUST be logged with enough context to distinguish request-level and session-level failures.

#### Scenario: Request-level translation failure
- **WHEN** router translation request fails for an active Apple pair
- **THEN** logs include source/target language identifiers and error summary

#### Scenario: Session preparation failure
- **WHEN** TranslationSession preparation fails
- **THEN** logs include pair context and preparation error summary

### Requirement: Mode switches between translated and bilingual SHALL NOT force pair task identity changes
Switching between translation-enabled modes MUST keep language-pair task identity stable for the same pair.

#### Scenario: Bilingual to translated with same pair
- **WHEN** mode changes from `bilingual` to `translated` and pair is unchanged
- **THEN** pair task identity remains unchanged and existing session stays reusable
