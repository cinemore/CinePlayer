## ADDED Requirements

### Requirement: iOS and macOS media info card SHALL use Cinemore-style grouped track cards
The media info panel on iOS and macOS SHALL present grouped sections for available media tracks (video/audio/subtitle/cover when available) using card-style blocks and a consistent close affordance.

#### Scenario: Track groups are shown with card blocks
- **WHEN** the user opens media info from player controls
- **THEN** the panel MUST render grouped track sections with card-like per-track detail blocks

#### Scenario: Media info closes via explicit action and mask tap
- **WHEN** the user taps close or background mask
- **THEN** the media info panel MUST dismiss and control mask behavior remains consistent
