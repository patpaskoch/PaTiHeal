# AGENTS.md — PaTiHeal

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full
(independence, combat lockdown, no automation, localization, tests, Definition of Done, VALIDATION output).
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: compact party frames for a healer; the player clicks a frame, the addon casts exactly the spell the player assigned to that click.
- Files: `Logic.lua` (pure: bindings → secure attributes, SavedVariables migration; tested in `tests/logic_spec.lua`),
  `SpellBook.lua` (spell/spellbook adapter, ranks), `Dispels.lua` (dispellable debuffs adapter),
  `Profiles/<Class>.lua` (data: HoTs/shields + dispel spells), `TargetFrame.lua` (heal-target secure driver), `HoTs.lua` (own-aura adapter + pure matching; tested in
  `tests/hots_spec.lua`), `Settings.lua` (settings modal), `PaTiHeal.lua` (rows, menu, commands, events), `Locales/` (enUS source, deDE), `Shared/` (PaTiShared, synced — never edit).
- SavedVariables: `PaTiHealDB` (per character), schema 2: point, relativePoint, x, y, locked, collapsed, language,
  showDispels, bindings = { LEFT = spellID, … }, bindingRanks = { LEFT = rank } (missing = highest),
  hots = { KEY = false } (hidden auras), hotPosition RIGHT|BELOW, showHotTimers, showHotCharges, scale (SetScale only out
  of combat, pending until PLAYER_REGEN_ENABLED). 0.6.0 keys clickSpellID/clickButton/clickModifier are migrated by `Logic.Migrate`.
  Any shape change: bump `Logic.SCHEMA`, add a migration step and a test.
- Heal target: `PaTiHealTarget` (SecureUnitButtonTemplate, unit = "target", same attributes as every row) above the
  player row; `TargetFrame.lua` = SecureHandlerStateTemplate `PaTiHealTargetDriver` with
  `RegisterStateDriver("[@target,help,nodead] show; hide")` — its restricted snippet only shows/hides the target row
  and anchors `PaTiHealUnit1` to it (top while hidden, below while shown; party rows hang below), also in combat.
  Never reference the PaTiHeal window from the snippet: it is no protected frame ("Invalid relative frame handle",
  owner 2026-10-03). The window height follows out of combat (`Logic.HealLayout`, `TargetFrame.Shown` =
  `SecureCmdOptionParse` of the same condition). Mode `Logic.TargetMode`. Without the driver: out of combat only.
- Secure / combat-sensitive: `PaTiHealUnit1..5` (SecureUnitButtonTemplate). Attributes only via `applyBindings()`,
  which writes the complete list from `Logic.ClickAttributes` out of combat. Row visibility: `RegisterUnitWatch`;
  window height = rows up to the last present member (`Logic.RowCount`)
  (`updateLayout()`, out of combat). Collapse/Hide/Test Mode are disabled in combat.
- Healer auras (own HoTs/shields on members, dispellable debuffs) are part of PaTiHeal. General aura/buff/proc watching
  lives in PaTiAuras. The two never depend on each other; duplicated spell data is accepted on purpose.
- Secret values: every unit/aura value is checked with `isSecret` before a nil test or comparison (`Logic.ValueOr`, `Logic.Flag`).
- Slash commands: `/ph`, `/patiheal` — alone = show/hide, settings, test, show, hide, lock, unlock, reset, spells, auras, debug, version.

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `../../PaTiAdmin/docs/TESTING.md`.

## PaTiAlerts (optional)
Reports its current alerts with `PaTiAlertsAPI.Sync("PaTiHeal", list)` after every normal refresh — only if the API
exists with version 1, always inside `pcall` (PaTiAdmin/AGENTS.md §3). The list is built by a pure, tested function.
Without PaTiAlerts nothing may change. Never make PaTiAlerts a dependency.
