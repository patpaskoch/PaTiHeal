# Changelog

Format: `## [Unreleased]` / `## [x.y.z] - YYYY-MM-DD` with Added, Changed, Fixed, Removed, Known Issues.
History before this file: `git log`.

## [Unreleased]
### Added
- Themes (owner wish 2026-10-03): Settings → Window → Theme — Default (the PaTi look as before), WoForever (warm brown, gold/bronze) or Dracula (dark, purple/pink/cyan accents). Colours only; layout, secure buttons and behaviour are unchanged. Saved per character in this addon (`theme`, unknown values → Default); Restore Defaults returns to Default. PaTiSuite can switch all PaTi windows at once.
- **Heal target frame** (owner wish 2026-10-02): a fixed secure frame for your current target directly above your own
  frame (`PaTiHealTarget`, SecureUnitButtonTemplate, unit = "target"): name, level ("??" for boss/unknown, nothing
  when unreadable), health, mana, your HoTs/shields and dispellable debuffs, a small "Target" tag. The same click
  bindings as every frame (one click = exactly the assigned spell). Shown only for a friendly, living target
  (player or NPC); visibility, the shift of your frame and the window height come from WoW's secure state driver
  (`TargetFrame.lua`, `[@target,help,nodead]`), so they also follow target changes in combat. Without that driver
  (not yet confirmed in the Forever client) the frame updates only out of combat. No target: the window stays as
  compact as before; the height still follows the group (party rows now hang below your frame). Test mode shows a
  wounded NPC. The heal target never sends PaTiAlerts alerts. `/ph debug` reports the driver.
- Window settings (PaTiShared): panel opacity 30–100 % (default 75 %, the header stays opaque). The window registers
  itself for the optional PaTiSuite control panel, which shows/hides it with this addon's own rules. (Snapping to
  other PaTi windows was tried and removed again: it did not work in the client.)
- Optional PaTiAlerts report: party members with a debuff you can dispel (note), only while the dispel display is on.
  A state, not a decision. Nothing changes without PaTiAlerts; while it is installed, a collapsed window keeps scanning.
- AddOns list icon from the PaTiSuite icon set (`Media/icon.tga`, `## IconTexture`); platform images in `assets/`.
- MIT license (`LICENSE`, not part of the release zip).
- Scale setting (80–150 %); changed in combat it is applied after combat (the window holds secure rows).
- Click casting for nine combinations (left, right, middle; Shift/Ctrl/Alt + left/right), chosen per dropdown with spell icons.
- Header menu (•••): Settings, Lock/Unlock, Collapse/Expand, Test Mode, Hide.
- Settings modal with language choice (Automatic, English, Deutsch, 简体中文, 繁體中文, 한국어) and window lock; ESC closes it.
- `/ph settings`; `/ph debug` also shows the PaTiShared UI version.
- Spell rank per click binding in its own column (Click · Spell · Rank; "Highest" = always the highest known rank, as before); needs a client that lists ranks.
- Dispellable debuffs: up to two small icons per party frame, coloured by debuff type (display only; can be switched off).
- Menus and dropdowns: roomier rows with an icon or dot in front (PaTiShared 0.2.0).
- HoTs & shields on the party frames: your own (filter HELPFUL|PLAYER) Earth Shield and Riptide (Shaman) or
  Renew, Power Word: Shield and Prayer of Mending (Priest), with charges and remaining time; up to three icons,
  right of the health bar (default) or in the bottom line. Settings section "HoTs & shields": each aura on/off,
  timers, charges, position. Class profiles in `Profiles/`; spell IDs are not yet confirmed in this client.
- Click dispel: your class's dispel spells are in the click-casting list; a "Click dispel" note explains it.
  No combination is preset.
- `/ph auras` lists what the client reports for the profile's spell IDs.
- English UI texts; German translation. Chinese and Korean fall back to English except for shared menu texts.
### Changed
- Click-casting rows use PaTiShared's spell field (owner 2026-10-07: same as PaTiRota/PaTiAuras): type a spell name
  or ID + Enter, drag a spell from the spellbook, or pick it from the arrow button (your heal spells); rank as before.
- Heal target set apart from your group (owner wish 2026-10-03, visual only): its own subtle panel (other shade,
  outline, thin accent stripe), the "TARGET" mark in the accent colour and 12 px instead of 4 px to your own frame.
  Plain textures of the target frame itself — no new frame, no attribute, nothing new in the secure driver (only the
  value of its existing gap). Without a friendly target nothing of it remains and your frame moves up as before.
- Diagnostics (hardening 2026-10-02): errors that are caught so the addon keeps running are no longer silent — the debug command shows the last caught error per source (no chat spam, nothing saved).
- AddOns list description in English with a German translation (`## Notes-deDE`); README rewritten for players
  (features, installation, first steps, commands, known limitations).
- `/ph` alone shows/hides the window; new `/ph reset` (position, blocked in combat) and `/ph version`.
- Party frames: only the name (in class colour) and health in percent; the class is in the unit tooltip.
  Tanks get an accent stripe on the left edge instead of "(Tank)". Secret health values are shown raw, never calculated.
- Restore Defaults keeps your click bindings, ranks, position and collapsed state; it resets language, lock,
  dispel display and the HoT settings.
- Settings modal moved to `Settings.lua` (no behaviour change).
- Health, power, connection and aura events repaint only the affected frame.
- New PaTiShared look: flat dark window, TEST badge instead of the yellow test label; the window moves by its header.
- Settings are no longer shown inside the party window.
- The saved click binding of 0.6.0 is converted automatically (SavedVariables schema 2).
- A binding whose spell is currently unknown is kept and applied again when the spell is available (0.6.0 deleted it).
### Fixed
- Heal target: Lua error "RestrictedFrames.lua:478: Invalid relative frame handle" (owner, Forever client) when the
  secure driver registered or a friendly target was selected. The restricted snippet anchored your row to the PaTiHeal
  window and resized it — the window is no protected frame. Now your row hangs on the target row (its top while
  hidden, below it while shown) and the snippet only shows/hides and anchors the two secure rows. The window height
  follows out of combat (target change, end of combat); in combat the bottom row can stick out or a gap remain until
  combat ends. The out-of-combat layout uses the driver's own condition (`SecureCmdOptionParse`).
- Hardening: a broken SavedVariables save (not a table, a broken schema or scale) no longer breaks the login; only the broken value is replaced, every valid setting (also `false`) stays, and the migration is idempotent (tests/robustness_spec.lua).
- The window kept the height of five frames when solo or in a small group (owner 2026-10-02): it is now only as
  tall as the members that are there (up to the last one; a gap stays rather than cutting a frame off). Changed out
  of combat only, like the rows: a member joining in combat appears at once and the window grows after combat.
- Dispellable debuffs are no longer re-read on every health/power event of a party member (only on aura,
  connection and flag changes).
- Secret values: name, health, mana, power type and the offline/dead flags are now checked for secrecy before any
  nil test or comparison (`Logic.ValueOr`, `Logic.Flag`); the dispel scan checks the debuff name before its nil test.
- Changing the click binding left the previous binding active (stale secure attributes).
- Party rows were shown/hidden in combat (blocked action); rows now follow their unit via RegisterUnitWatch.
- The window could jump after /reload because the saved anchor was not restored.
### Removed
- Healing Rain from the click-casting list (ground-targeted, cannot be cast on a clicked unit) and the second
  2061 entry labelled Greater Heal (2061 is Flash Heal; Greater Heal returns once its ID is confirmed in this client).
- Gear, chevron and close buttons in the header (replaced by the ••• menu).
### Known Issues
- The automatic window height (2026-10-02) is not tested in game yet (PT-HEAL-057–059, 079).
- Owner-tested in game before ranks/dispels: bindings, migration, settings, language. Ranks, dispel icons, HoTs &
  shields and click dispel not yet tested in game; the HELPFUL|PLAYER filter is assumed to work in this client.
