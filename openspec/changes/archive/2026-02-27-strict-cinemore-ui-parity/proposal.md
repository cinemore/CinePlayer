## Why

Current iOS and macOS player UI in CinePlayer does not fully match Cinemore's actual player UI code path, which causes visible style and layout drift in control bars and side panels. This parity gap has blocked acceptance and must be corrected now with strict component-level alignment.

## What Changes

- Replace rewritten player UI surfaces with Cinemore-equivalent component structure for iOS and macOS player control UI.
- Replace rewritten side panel surfaces with Cinemore-equivalent component structure for media info, enhancement, setting, and subtitle panels.
- Restore Cinemore subtitle adjustment UI composition (including component hierarchy and styling tokens) in CinePlayer.
- Enforce style parity rules so visual differences are treated as regressions unless explicitly approved.
- Keep product scope constraints already requested for pure-player mode:
  - remove "换源" and episode list entry points from control/sider UI
  - remove external subtitle import option "从文件源导入"
  - keep required business controls: close, PiP, fill mode, rotate (mobile), seek back/forward, play/pause, audio track, video track, playback speed

## Capabilities

### New Capabilities
- `cinemore-control-ui-parity`: Define strict parity requirements for iOS and macOS control overlays, button groups, spacing, typography, and interaction states using Cinemore as the UI source of truth.
- `cinemore-sidepanel-ui-parity`: Define strict parity requirements for side panel container presentation and for media info, enhancement, setting, and subtitle panel structure/styling, including subtitle adjustment composition.

### Modified Capabilities
- None.

## Impact

- Affected code:
  - `CinePlayer/Player/Views/PlayerControlView.swift`
  - `CinePlayer/Player/Components/ControllerPanelViewIOS.swift`
  - `CinePlayer/Player/Components/ControllerPanelViewMacOS.swift`
  - `CinePlayer/Player/SiderView/*`
  - `CinePlayer/Player/Components/PlayerMediaInfoCardView.swift`
  - subtitle-related UI components introduced for parity
- Dependencies:
  - requires UI adapter bindings from CinePlayer models to Cinemore-style view structure
  - requires keeping current pure-player business removals while preserving visual parity
- Risk:
  - medium; large UI refactor across iOS and macOS with high regression sensitivity on spacing/styling
