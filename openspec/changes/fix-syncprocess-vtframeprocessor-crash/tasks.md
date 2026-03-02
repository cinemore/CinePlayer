## 1. Root cause fix

- [x] 1.1 Replace `Task`-based bridge in `syncProcess(...)` with `VTFrameProcessor.process(parameters:completionHandler:)`
- [x] 1.2 Preserve timeout/session-reset/error-log behavior and destination-buffer success return path

## 2. Verification

- [x] 2.1 Refresh code issues for `SystemVideoEnhancementAdapter.swift` and resolve any new diagnostics
- [ ] 2.2 Build the CinePlayer scheme for all required Apple platforms (`iphoneos`, `iphonesimulator`, `appletvos`, `appletvsimulator`, `macosx`, `xros`, `xrsimulator`)
