## ADDED Requirements

### Requirement: Super-resolution sync processing SHALL avoid Task-based async bridging
The system enhancement adapter MUST execute low-latency super-resolution processing without creating a Swift `Task` from the synchronous `syncProcess(...)` path.

#### Scenario: Process a single super-resolution request successfully
- **WHEN** `syncProcess(...)` is called with a valid started super-resolution session and valid parameters
- **THEN** the adapter MUST invoke `VTFrameProcessor` processing through completion-handler based API
- **AND** the adapter MUST return the destination pixel buffer on successful completion

#### Scenario: Processing throws or completes with error
- **WHEN** `VTFrameProcessor` completes processing with an error
- **THEN** the adapter MUST log diagnostic error information
- **AND** the adapter MUST return `nil` so caller fallback behavior can run

#### Scenario: Processing exceeds timeout
- **WHEN** processing does not complete within the configured timeout window
- **THEN** the adapter MUST reset the super-resolution session
- **AND** the adapter MUST return `nil`
