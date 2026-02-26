## ADDED Requirements

### Requirement: CinePlayer SHALL complete CinePlayerSDK framework integration for all target platforms
The project SHALL include CinePlayerSDK and required dependent xcframeworks, and SHALL configure link and search settings so iOS, macOS, tvOS, and visionOS targets can build without missing symbols.

#### Scenario: Build settings are configured from SDK documentation
- **WHEN** developers compare target build settings with SDK documentation and the SDK demo project
- **THEN** framework search paths, linker flags, system frameworks, and dependent libraries are present as required

#### Scenario: Multi-platform compile succeeds after SDK bootstrap
- **WHEN** the project is built for iOS, macOS, tvOS, and visionOS schemes
- **THEN** build output contains no SDK linkage errors and produces app binaries for each platform

### Requirement: Player configuration SHALL include SDK authorization key and required runtime options
The app SHALL provide `CinePlayerAuthKey` and initialize player config so CinePlayerSDK can start playback with local or remote sources.

#### Scenario: Player config initializes with valid auth key
- **WHEN** the app creates a new playback session
- **THEN** the player configuration contains the documented auth key and initializes the SDK player successfully

### Requirement: Platform capabilities SHALL match pure player runtime needs
The app SHALL enable capabilities needed for local file access and network playback, including sandbox permissions where applicable.

#### Scenario: macOS sandbox permits selected file playback
- **WHEN** a user opens a local media file through app UI on macOS
- **THEN** the app can access and play the selected file under configured sandbox entitlements
