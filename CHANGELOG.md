# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.
History before this file: `git log`.

## [Unreleased]
### Added
- Click casting for nine combinations (left, right, middle; Shift/Ctrl/Alt + left/right), chosen per dropdown with spell icons.
- Header menu (•••): Settings, Lock/Unlock, Collapse/Expand, Test Mode, Hide.
- Settings modal with language choice (Automatic, English, Deutsch, 简体中文, 繁體中文, 한국어) and window lock; ESC closes it.
- `/ph settings`; `/ph debug` also shows the PaTiShared UI version.
- English UI texts; German translation. Chinese and Korean fall back to English except for shared menu texts.
### Changed
- New PaTiShared look: flat dark window, TEST badge instead of the yellow test label; the window moves by its header.
- Settings are no longer shown inside the party window.
- The saved click binding of 0.6.0 is converted automatically (SavedVariables schema 1).
- A binding whose spell is currently unknown is kept and applied again when the spell is available (0.6.0 deleted it).
### Fixed
- Changing the click binding left the previous binding active (stale secure attributes).
- Party rows were shown/hidden in combat (blocked action); rows now follow their unit via RegisterUnitWatch.
- The window could jump after /reload because the saved anchor was not restored.
### Removed
- Gear, chevron and close buttons in the header (replaced by the ••• menu).
### Known Issues
- Not yet tested in game (secure click casting, combat behaviour, visuals, Chinese/Korean fonts).
