## Context

CinePlayer currently contains a mix of Cinemore-inspired UI and local rewritten UI for player controls and side panels. This mixed approach caused visual drift (component hierarchy, border placement, spacing, typography weight, and panel composition) across iOS and macOS. The user requires strict UI parity with Cinemore code paths, while preserving pure-player product constraints (no source-switch panel, no episode list, no file-source subtitle import).

The repository boundary also matters: CinePlayer does not include several Cinemore business-layer dependencies (`Cinegomobile`, `ModelPB_File`, `SubtitleSettingModel`, `PathManager`, `ShareData`, and some routing/window infra). A direct copy without adaptation fails to compile, so parity must be achieved by porting UI structures and introducing minimal adapters only where business dependencies are unavailable.

## Goals / Non-Goals

**Goals:**
- Make iOS and macOS player control UI visually and structurally equivalent to Cinemore.
- Make iOS and macOS side panels (media info, enhancement, setting, subtitle) visually and structurally equivalent to Cinemore.
- Restore Cinemore subtitle adjustment component composition in CinePlayer.
- Enforce explicit "allowed difference" boundaries for pure-player exclusions.

**Non-Goals:**
- Do not add Cinemore cloud/business workflows (source switching, episode management, subtitle search APIs, file-source subtitle import).
- Do not introduce cross-repository runtime dependencies.
- Do not redesign tvOS/visionOS UI behavior beyond compile-safe parity maintenance.

## Decisions

### Decision 1: UI structure port-first, adapter-second
- Choice: Port Cinemore UI view structure and style code first, then add thin adapter bindings for missing data/actions.
- Rationale: Visual parity requires identical component hierarchy; parameter tuning on rewritten views is insufficient.
- Alternatives considered:
  - Keep rewritten views and adjust styling values: rejected because repeated drift has already proven this unstable.
  - Import Cinemore business modules wholesale: rejected due to repository boundary and dependency scope.

### Decision 2: Define an explicit parity adapter layer for missing dependencies
- Choice: Introduce CinePlayer-local adapter interfaces for play settings, subtitle state/actions, and optional capability gates used by Cinemore UI components.
- Rationale: Preserve Cinemore view tree while replacing unavailable business dependencies with local equivalents.
- Alternatives considered:
  - Inline conditional logic in every view: rejected due to maintenance complexity and future drift risk.

### Decision 3: Enforce product exclusions as hard UI policy, not ad-hoc removals
- Choice: Keep a centralized exclusion list for pure-player mode: no source switch, no episode list, no file-source subtitle import.
- Rationale: Prevent accidental reappearance during future parity sync.
- Alternatives considered:
  - Remove buttons manually in individual views: rejected because it is error-prone across repeated merges.

### Decision 4: Parity acceptance requires component-level verification
- Choice: Verify parity by component checklist (control groups, side panel sections, row styles, typography, border hierarchy, interaction state transitions) on iOS and macOS.
- Rationale: "Looks close" is not acceptable for this change; acceptance must be deterministic.
- Alternatives considered:
  - Rely on build-only verification: rejected because style regressions compile successfully.

## Risks / Trade-offs

- [Risk] Large UI refactor can introduce behavior regressions during state binding migration.
  -> Mitigation: Migrate panel-by-panel with focused compile checks and scenario-based manual validation after each panel.

- [Risk] Missing Cinemore dependencies can force fallback implementations that drift again.
  -> Mitigation: Restrict fallback to adapter layer only; forbid local structural rewrites in parity views.

- [Risk] Existing dirty workspace increases accidental coupling risk.
  -> Mitigation: Limit touched files to parity scope and keep OpenSpec tasks explicitly scoped.

## Migration Plan

1. Add parity adapters for settings/subtitle/control actions and capability gating.
2. Replace iOS/macOS control UI composition with Cinemore-equivalent layout blocks using adapter-backed actions.
3. Replace side panel compositions with Cinemore-equivalent view hierarchy for setting, subtitle (including adjustment), enhancement, and media info.
4. Apply pure-player exclusion policy to remove only disallowed entries while preserving visual structure.
5. Execute AGENTS-required 7-platform build matrix.
6. Run iOS/macOS component parity regression checklist and capture mismatches before completion.

## Open Questions

- Whether any Cinemore subtitle translation UI fragments should remain hidden entirely in pure-player mode or be shown as disabled placeholders.
- Whether enhancement debug-only sections should strictly follow Cinemore `#if DEBUG` gating or be adapted by runtime capability flags in CinePlayer.
