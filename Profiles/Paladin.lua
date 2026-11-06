-- PaTiHeal Paladin profile: out-of-combat resurrection only for now.
-- Other class healing/dispels can be added independently when validated in the Forever client.
local _, ns = ...
ns.HealProfiles = ns.HealProfiles or {}

ns.HealProfiles.PALADIN = {
    name = "Paladin",
    resurrect = 7328, -- Redemption rank 1 (WoW Forever); highest known rank is cast by name.
    auras = {},
    dispels = {},
}
