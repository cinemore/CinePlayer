## ADDED Requirements

### Requirement: App SHALL support opening media files by system file association
The app SHALL declare supported video document types and imported UTIs so users can open media files by double-clicking supported files.

#### Scenario: User double-clicks a supported file in Finder
- **WHEN** the user opens a registered media file type associated with the app
- **THEN** the app launches (or activates) and routes the file URL into the playback flow

### Requirement: App SHALL route external open events through a single playback entry path
The app SHALL normalize open events from `onOpenURL`, app delegate open callbacks, and internal notifications into one player-open flow.

#### Scenario: File URL is received from any supported open entry
- **WHEN** file URL events arrive from SwiftUI scene or app delegate callbacks
- **THEN** the app forwards the URL to a single router that opens or updates the player session

### Requirement: macOS menu commands SHALL match reference open actions
The app SHALL provide File menu commands for “打开文件…” and “打开URL…”, with the same interaction behavior as the reference implementation.

#### Scenario: User selects 打开文件… from menu
- **WHEN** the user triggers the File menu “打开文件…” command
- **THEN** an open panel is shown with supported video types and the chosen file is routed into playback

#### Scenario: User selects 打开URL… from menu
- **WHEN** the user triggers the File menu “打开URL…” command
- **THEN** the app shows URL input alert and opens the entered URL with system workspace, matching reference behavior

### Requirement: macOS Dock menu SHALL expose file and URL open actions
The app SHALL provide Dock context menu actions for opening files and URLs, wired to the same handlers as top menu commands.

#### Scenario: User selects 打开文件… from Dock menu
- **WHEN** the user invokes the Dock icon context menu and selects 打开文件…
- **THEN** the app runs the same open-file flow used by the top menu command

#### Scenario: User selects 打开URL… from Dock menu
- **WHEN** the user invokes the Dock icon context menu and selects 打开URL…
- **THEN** the app runs the same open-URL flow used by the top menu command
