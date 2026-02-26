## ADDED Requirements

### Requirement: Anime4K runtime SHALL be available in pure player module
The pure player module MUST include Anime4K host runtime and shader resources required for single-frame enhancement and A/B compare output.

#### Scenario: Anime4K strategy is enabled
- **WHEN** Anime4K is active and receives video frames
- **THEN** runtime MUST process frames with selected preset/output constraints and return replacement frames compatible with player pipeline

### Requirement: System VT adapter SHALL support super-resolution and interpolation modes
The pure player module MUST include system VT enhancement adapter support for super-resolution and frame interpolation paths with source-compatible parameter semantics.

#### Scenario: System VT strategy is enabled
- **WHEN** system VT mode is active and capability checks pass
- **THEN** runtime MUST execute configured VT path and return replacement frames or frame segments for playback

### Requirement: Optical-flow interpolation adapter SHALL support temporal segment output
The pure player module MUST include optical-flow interpolation adapter that generates temporal frame segments for low-frame-rate content in supported resolution range.

#### Scenario: Optical-flow strategy is enabled
- **WHEN** optical-flow mode receives valid previous/current frame context
- **THEN** adapter MUST return `replaceMany` temporal frames aligned to source timestamps and durations
