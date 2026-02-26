## ADDED Requirements

### Requirement: Player SHALL show network and loading feedback equivalent to reference
The app SHALL extend PlayerToast types to include network states (connecting, retrying, switching URL, error, stable) and SHALL bind CinePlayer SDK callbacks (onNetworkStatusChanged, onNetworkError, onBufferingStatusChanged) to display Toast and loading/error overlays with the same information level and visual style as the reference implementation, without using Cinemore network or business error codes.

#### Scenario: Network status changes show appropriate Toast
- **WHEN** the player reports connecting, retrying, switching URL, or stable via SDK callbacks
- **THEN** the app shows the corresponding Toast (e.g. "正在连接...", "重试中 (n/m)", "切换线路", "连接稳定") with the same style as the reference

#### Scenario: Network or playback error shows clear message
- **WHEN** the player reports a network or playback error via SDK callbacks
- **THEN** the app shows an error Toast or overlay with a message that suggests next steps (e.g. retry or check network), consistent with the reference

#### Scenario: Initial loading shows overlay with progress and text
- **WHEN** the player is initializing or buffering before ready
- **THEN** the app shows a semi-transparent overlay with progress indicator and status text (e.g. "初始化中...", "正在连接...") in the same style as the reference

### Requirement: Toast and overlay styling SHALL match reference
The app SHALL use the same glass-style modifier, padding, and typography for Toast and loading/error overlays as the reference implementation, and SHALL not include business-only copy (e.g. "会员专享") in any message.

#### Scenario: Toast visual style matches reference
- **WHEN** any Toast is displayed (skip, rate, brightness, progress, network, error)
- **THEN** the capsule/rounded style, padding, and font treatment match the reference implementation
