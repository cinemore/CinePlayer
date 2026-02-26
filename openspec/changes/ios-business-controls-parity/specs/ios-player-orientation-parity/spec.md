## ADDED Requirements

### Requirement: iPhone player presentation SHALL auto-enter landscape and restore portrait on exit
On iPhone, entering playback SHALL switch interface orientation to landscape and closing playback SHALL restore portrait orientation.

#### Scenario: Entering playback forces landscape on iPhone
- **WHEN** the user opens a playable source on iPhone
- **THEN** the player interface transitions to landscape orientation

#### Scenario: Closing playback restores portrait on iPhone
- **WHEN** the user closes the iPhone player
- **THEN** the interface transitions back to portrait orientation

### Requirement: Rotate control SHALL toggle portrait and landscape lock on iPhone
The iOS rotate control SHALL toggle between portrait and landscape orientation lock behavior equivalent to Cinemore.

#### Scenario: Rotate button toggles to portrait mode
- **WHEN** the player is in landscape lock and the user taps rotate
- **THEN** orientation lock switches to portrait and UI updates to portrait layout

#### Scenario: Rotate button toggles to landscape mode
- **WHEN** the player is in portrait lock and the user taps rotate
- **THEN** orientation lock switches to landscape and UI updates to landscape layout
