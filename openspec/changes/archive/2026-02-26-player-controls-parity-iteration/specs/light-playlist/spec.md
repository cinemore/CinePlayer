## ADDED Requirements

### Requirement: Player SHALL support a lightweight playlist model
The app SHALL provide a PlayerPlaylist (or equivalent) model that holds the current list of playable sources (e.g. [PlayerSource] or URLs) and the current index, and SHALL expose whether previous/next items exist and methods to switch to previous/next, without depending on DetailPageModel, season/episode, or business APIs.

#### Scenario: Playlist exposes current index and previous/next availability
- **WHEN** the app has a non-empty playlist and a current index
- **THEN** the model exposes hasPrevious, hasNext (or equivalent) and switch-to-previous/next so UI and gestures can drive “previous/next” behavior

#### Scenario: Playlist is independent of business metadata
- **WHEN** the project is built and playlist logic is used
- **THEN** no file in the player module depends on DetailPageModel, PlayerParams, or business watch-history/API for playlist content

### Requirement: tvOS SHALL support previous/next via playlist and remote
The app SHALL bind tvOS remote “previous/next” (e.g. pageUp/pageDown or equivalent) to the lightweight playlist so that when the user triggers previous/next and the playlist has a previous/next item, the player switches to that item; when the playlist has only one item or no previous/next, the gesture SHALL have no effect or match reference behavior.

#### Scenario: Remote previous/next changes track when playlist has multiple items
- **WHEN** the user triggers previous or next on the tvOS remote and the playlist has a previous or next item
- **THEN** the player switches to the previous or next source and playback continues from that item

#### Scenario: Remote previous/next when single item
- **WHEN** the playlist has only one item and the user triggers previous or next on tvOS
- **THEN** the player does not change source (or behavior matches the reference for single-item case)
