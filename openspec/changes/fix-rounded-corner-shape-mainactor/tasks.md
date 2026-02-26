## 1. Rounded Corner Shape Concurrency Fix

- [x] 1.1 Refactor macOS `RoundedCornerShape.path(in:)` to use SwiftUI-native rounded path construction instead of AppKit `cgPath` bridging.
- [x] 1.2 Remove unused AppKit bridge code/imports that are no longer needed after the refactor.

## 2. Verification

- [x] 2.1 Rebuild `macosx` destination and confirm the `RoundedCornerShape.swift:24` actor-isolation error is gone.
- [x] 2.2 Run the required multi-platform build matrix (`iphoneos`, `iphonesimulator`, `appletvos`, `appletvsimulator`, `macosx`, `xros`, `xrsimulator`) and confirm successful builds.
