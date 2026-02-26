# Repository Guidelines For Coding Agents

## Scope
- This file applies to this repository root only.
- Do not treat sibling repositories as part of this project unless the user explicitly asks.
- Do not write external-repo changes into this repo's `openspec/` artifacts.

## Mandatory Process
1. Start with skills
- Use `using-superpowers` first for each new user request.
- If the work is creative or changes behavior/UI/architecture, run `brainstorming` before implementation.

2. OpenSpec-first execution
- New requirement: use `openspec-propose` to create or update change artifacts.
- Implementation: use `openspec-apply-change` and execute tasks in `tasks.md`.
- Completion: use `openspec-archive-change` only after implementation and verification are done.

3. Repository boundary for OpenSpec
- `openspec/changes/*` must describe and track only changes inside this repository.
- If SDK scripts or other external repos are modified, record that outside this repo's OpenSpec.

## Build And Verification Requirements
- Before claiming success, run platform builds for:
  - `iphoneos`
  - `iphonesimulator`
  - `appletvos`
  - `appletvsimulator`
  - `macosx`
  - `xros`
  - `xrsimulator`
- Recommended command pattern:

```bash
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=tvOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=tvOS Simulator' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=macOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=visionOS' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
xcodebuild -project CinePlayer.xcodeproj -scheme CinePlayer -destination 'generic/platform=visionOS Simulator' build CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO
```

## Product Constraints
- This app is a pure player app.
- Keep player gestures and controls behavior aligned with reference parity requirements when requested.

## Change Hygiene
- Prefer focused edits and keep unrelated files untouched.
- Never revert user changes unless explicitly instructed.
- If unexpected unrelated modifications are detected during work, pause and ask user how to proceed.
