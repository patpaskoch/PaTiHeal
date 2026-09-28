# AGENTS.md — PaTiHeal

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full
(independence, combat lockdown, no automation, localization, tests, Definition of Done, VALIDATION output).
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: compact party frames for a healer; the player clicks a frame, the addon casts exactly the spell the player assigned to that click.
- Files: `Logic.lua` (pure: bindings → secure attributes, SavedVariables migration; tested in `tests/logic_spec.lua`),
  `PaTiHeal.lua` (WoW adapters, rows, menu, settings, events), `Locales/` (enUS source, deDE), `Shared/` (PaTiShared, synced — never edit).
- SavedVariables: `PaTiHealDB` (per character), schema 1: point, relativePoint, x, y, locked, collapsed, language,
  bindings = { LEFT = spellID, SHIFT_RIGHT = spellID, … }. 0.6.0 keys clickSpellID/clickButton/clickModifier are migrated by `Logic.Migrate`.
  Any shape change: bump `Logic.SCHEMA`, add a migration step and a test.
- Secure / combat-sensitive: `PaTiHealUnit1..5` (SecureUnitButtonTemplate). Attributes only via `applyBindings()`,
  which writes the complete list from `Logic.ClickAttributes` out of combat. Row visibility: `RegisterUnitWatch`
  (`updateLayout()`, out of combat). Collapse/Hide/Test Mode are disabled in combat.
- Slash commands: `/ph`, `/patiheal` — settings, test, show, hide, lock, unlock, spells, debug.

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `../../PaTiAdmin/docs/TESTING.md`.
