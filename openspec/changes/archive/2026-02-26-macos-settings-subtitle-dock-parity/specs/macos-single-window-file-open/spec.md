## ADDED Requirements

### Requirement: macOS Dock 拖拽打开文件不得重复创建播放器窗口
When media file open is triggered from Dock icon on macOS, the app MUST process the file-open event once and MUST NOT create duplicate player windows for the same open action.

#### Scenario: Drop one media file onto Dock icon
- **WHEN** user drags a media file to the app Dock icon and drops it
- **THEN** only one player window is created or activated for that file

#### Scenario: Open event arrives through multiple framework hooks
- **WHEN** the same file-open action reaches both app lifecycle hook and delegate hook
- **THEN** deduplication logic ensures window-open side effects execute exactly once
