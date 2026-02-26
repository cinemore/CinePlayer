## 1. Parity Adapter Foundation

- [ ] 1.1 Introduce CinePlayer parity adapter interfaces for play settings, subtitle UI state/actions, and control action routing used by Cinemore-equivalent views
- [ ] 1.2 Bind adapter implementations to existing `PlayerSessionStore`, `PlayerControlModel`, and coordinator state without adding external-repo runtime dependencies

## 2. Control Overlay Parity (iOS + macOS)

- [ ] 2.1 Replace iOS control overlay composition with Cinemore-equivalent control-group hierarchy and button cluster structure
- [ ] 2.2 Replace macOS control overlay composition with Cinemore-equivalent control-group hierarchy and button cluster structure
- [ ] 2.3 Ensure required control set is present (close, PiP, fill, rotate-mobile, seek back/forward, play/pause, audio/video track, speed) and excluded controls remain absent
- [ ] 2.4 Fix playback-state UI refresh so play/pause icon changes immediately after toggle
- [ ] 2.5 Verify iOS playback open behavior enters landscape playback orientation parity

## 3. Side Panel Parity (iOS + macOS)

- [ ] 3.1 Replace settings panel with Cinemore-equivalent play-settings composition using adapters
- [ ] 3.2 Replace subtitle panel with Cinemore-equivalent segmented subview composition (`Embedded` / `External` / `Adjustment`)
- [ ] 3.3 Port subtitle adjustment component set to Cinemore-equivalent structure and styling hierarchy
- [ ] 3.4 Replace media info panel with Cinemore-equivalent section/card hierarchy and metadata display structure
- [ ] 3.5 Replace enhancement panel with Cinemore-equivalent section hierarchy and gating behavior aligned to build/runtime constraints
- [ ] 3.6 Align side panel container presentation (overlay behavior, background treatment, animation hierarchy) with Cinemore-equivalent behavior

## 4. Pure-Player Exclusion Policy

- [ ] 4.1 Enforce a centralized exclusion policy for pure-player mode to keep "换源" and episode list entry points hidden
- [ ] 4.2 Keep external subtitle import local-only and ensure "从文件源导入" entry is not exposed

## 5. Verification

- [ ] 5.1 Execute AGENTS.md required build matrix: `iphoneos`, `iphonesimulator`, `appletvos`, `appletvsimulator`, `macosx`, `xros`, `xrsimulator`
- [ ] 5.2 Run manual iOS + macOS parity checklist for control overlay and side panel style parity against Cinemore reference
- [ ] 5.3 Record any remaining style deltas as blockers; mark change apply-ready only when no unapproved visual differences remain
