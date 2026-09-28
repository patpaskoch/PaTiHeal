# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.
History before this file: `git log`.

## [Unreleased]
### Added
- Click casting for nine combinations (left, right, middle; Shift/Ctrl/Alt + left/right), chosen per dropdown with spell icons.
- Header menu (•••): Settings, Lock/Unlock, Collapse/Expand, Test Mode, Hide.
- Settings modal with language choice (Automatic, English, Deutsch, 简体中文, 繁體中文, 한국어) and window lock; ESC closes it.
- `/ph settings`; `/ph debug` also shows the PaTiShared UI version.
- Spell rank per click binding in its own column (Click · Spell · Rank; "Highest" = always the highest known rank, as before); needs a client that lists ranks.
- Dispellable debuffs: up to two small icons per party frame, coloured by debuff type (display only; can be switched off).
- Menus and dropdowns: roomier rows with an icon or dot in front (PaTiShared 0.2.0).
- English UI texts; German translation. Chinese and Korean fall back to English except for shared menu texts.
### Changed
- Party frames: only the name (in class colour) and health in percent; the class is in the unit tooltip.
  Tanks get an accent stripe on the left edge instead of "(Tank)". Secret health values are shown raw, never calculated.
- Restore Defaults keeps your click bindings and ranks (there are no default bindings); it resets language, lock and dispel display.
- Health, power, connection and aura events repaint only the affected frame.
- New PaTiShared look: flat dark window, TEST badge instead of the yellow test label; the window moves by its header.
- Settings are no longer shown inside the party window.
- The saved click binding of 0.6.0 is converted automatically (SavedVariables schema 2).
- A binding whose spell is currently unknown is kept and applied again when the spell is available (0.6.0 deleted it).
### Fixed
- Changing the click binding left the previous binding active (stale secure attributes).
- Party rows were shown/hidden in combat (blocked action); rows now follow their unit via RegisterUnitWatch.
- The window could jump after /reload because the saved anchor was not restored.
### Removed
- Healing Rain from the click-casting list (ground-targeted, cannot be cast on a clicked unit) and the second
  2061 entry labelled Greater Heal (2061 is Flash Heal; Greater Heal returns once its ID is confirmed in this client).
- Gear, chevron and close buttons in the header (replaced by the ••• menu).
### Known Issues
- Owner-tested in game before ranks/dispels: bindings, migration, settings, language. Ranks and dispel icons not yet tested in game.
