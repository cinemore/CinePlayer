## Why

`SystemVideoEnhancementAdapter.syncProcess(...)` currently bridges async frame processing by spawning a `Task` from a synchronous queue path and blocking with a semaphore. The crash site is inside that task closure at `VTFrameProcessor.process(parameters:)`, so we need a safer bridge that keeps the processing call in one execution model.

## What Changes

- Replace the `Task`-based async bridge in super-resolution `syncProcess(...)` with `VTFrameProcessor.process(parameters:completionHandler:)`.
- Keep existing timeout and fallback behavior so playback still degrades gracefully when processing stalls or fails.
- Preserve logging and error handling semantics for VT errors.

## Capabilities

### New Capabilities

- `system-video-enhancement-sync-processing`: Define safe synchronous bridging behavior for low-latency super-resolution processing in the system enhancement adapter.

### Modified Capabilities

- None.

## Impact

- Affected code: `CinePlayer/CinePlayer/Player/Enhancement/SystemVideoEnhancement/SystemVideoEnhancementAdapter.swift`
- Runtime impact: lower crash risk in `syncProcess(...)` call path while preserving existing fallback semantics.
