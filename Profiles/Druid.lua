-- PaTiHeal Druid profile: regular resurrection and an independent in-combat Rebirth button.
-- Revive is out of combat only. Rebirth uses a fixed secure action (never switched during combat).
local _, ns = ...
ns.HealProfiles = ns.HealProfiles or {}

ns.HealProfiles.DRUID = {
    name = "Druid",
    resurrect = 437138, -- Revive rank 1, added in WoW Forever; cast by known highest rank name.
    battleResurrect = 20484, -- Rebirth rank 1; also usable in combat, subject to cooldown/reagents.
    auras = {},
    dispels = {},
}
