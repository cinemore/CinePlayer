## ADDED Requirements

### Requirement: Multi-platform build matrix SHALL pass
The CinePlayer project MUST compile successfully for `iphoneos`, `iphonesimulator`, `appletvos`, `appletvsimulator`, `macosx`, `xros`, and `xrsimulator` destinations.

#### Scenario: Execute full destination build matrix
- **WHEN** developers run the required `xcodebuild` commands for all seven destinations
- **THEN** each destination build MUST finish with `BUILD SUCCEEDED`

### Requirement: tvOS subtitle toggle styling SHALL remain deployment-compatible
Subtitle toggle controls MUST avoid style APIs that are unavailable to the current tvOS deployment target.

#### Scenario: Compile subtitle views for tvOS target
- **WHEN** `EmbeddedSubtitleView` and `ExternalSubtitleView` are compiled for tvOS and tvOS Simulator
- **THEN** compilation MUST succeed without availability errors for toggle style APIs
