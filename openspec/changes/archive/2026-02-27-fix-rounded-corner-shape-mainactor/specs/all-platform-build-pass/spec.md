## ADDED Requirements

### Requirement: Shared rounded-corner shape utility SHALL compile under Swift concurrency isolation
Shared UI shape utilities MUST avoid actor-isolated API access from nonisolated `Shape` requirement contexts so that strict Swift concurrency checks do not break platform builds.

#### Scenario: Build macOS with strict concurrency enabled
- **WHEN** `RoundedCornerShape` is compiled for the `macosx` destination under Swift 6 strict concurrency settings
- **THEN** compilation MUST succeed without main-actor isolation errors from rounded-corner path generation code
