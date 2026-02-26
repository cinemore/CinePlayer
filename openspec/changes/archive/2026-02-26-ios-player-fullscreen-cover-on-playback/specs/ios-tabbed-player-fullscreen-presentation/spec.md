## ADDED Requirements

### Requirement: iOS playback SHALL be presented in full-screen cover from tabbed player entry
When the app is running on iOS with tabbed navigation enabled, starting playback from the player tab MUST present the player UI in a full-screen cover so the tab bar is not visible over playback controls.

#### Scenario: Start playback from player tab
- **WHEN** the user is on the iOS player tab and opens a media source that sets an active playback source
- **THEN** the app presents the playback UI in a `fullScreenCover`
- **THEN** the tab bar is not visible while playback is presented

### Requirement: iOS playback full-screen presentation SHALL dismiss back to tab entry state
The full-screen playback presentation MUST dismiss automatically when playback is closed and return the user to the existing player tab entry UI.

#### Scenario: Close active playback
- **WHEN** the user closes playback and the active playback source is cleared
- **THEN** the full-screen cover is dismissed
- **THEN** the player tab shows the existing open/import entry UI

### Requirement: Non-iOS behavior SHALL remain unchanged
The full-screen cover behavior introduced by this change MUST be limited to iOS and MUST NOT change existing navigation behavior on other platforms.

#### Scenario: Launch on macOS
- **WHEN** the app runs on macOS and playback starts
- **THEN** the app keeps its existing macOS navigation and presentation behavior without iOS tab cover logic
