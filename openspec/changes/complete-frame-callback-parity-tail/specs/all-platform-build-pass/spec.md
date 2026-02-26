## MODIFIED Requirements

### Requirement: Multi-platform build matrix SHALL pass
The CinePlayer project MUST compile successfully for `iphoneos`, `iphonesimulator`, `appletvos`, `appletvsimulator`, `macosx`, `xros`, and `xrsimulator` destinations after completing frame-callback parity tail migration.

#### Scenario: Execute full destination build matrix
- **WHEN** developers run the required `xcodebuild` commands for all seven destinations
- **THEN** each destination build MUST finish with `BUILD SUCCEEDED`
