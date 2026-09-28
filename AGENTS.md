# AGENTS.md — PaTiHeal

**Read the suite rules first: [`../../PaTiAdmin/AGENTS.md`](../../PaTiAdmin/AGENTS.md).** They apply here in full
(independence, combat lockdown, no automation, localization, tests, Definition of Done, VALIDATION output).
Addon facts: `../../PaTiAdmin/docs/ARCHITECTURE.md` · open issues: `../../PaTiAdmin/docs/FOLLOW_UPS.md`.

## This addon
- Purpose: compact party frames for a healer; the player clicks a frame, the addon casts exactly the spell the player assigned to that click.
- SavedVariables: `PaTiHealDB` (per character): x, y, locked, collapsed, clickSpellID, clickButton, clickModifier — keep readable when changing the settings format.
- Secure / combat-sensitive: `PaTiHealUnit1..5` (SecureUnitButtonTemplate). Attributes only via `applyClickSpell()` out of combat; test mode disables the buttons.
- Slash commands: `/ph`, `/patiheal` — test, show, hide, lock, unlock, spells, debug.
- Planned: first addon to embed PaTiShared (header ••• menu, settings modal, 9 click bindings). Fix FOLLOW_UPS F1/F2 as part of that, not separately.

## Checks
`bash ../../PaTiAdmin/tools/check.sh .` before every commit. Manual WoW tests: `../../PaTiAdmin/docs/TESTING.md`.
