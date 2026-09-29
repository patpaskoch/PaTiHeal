-- PaTiHeal profile: Priest. Only what matters on a party frame: your HoTs/shields on members and your dispels.
-- Inner Fire and the group buffs belong to PaTiAuras, not here.
-- Status: IDs from classic/WotLK data, NOT yet confirmed in the Interface 16001 client — check with `/ph auras`.
local _, ns = ...
ns.HealProfiles = ns.HealProfiles or {}

ns.HealProfiles.PRIEST = {
    name = "Priest",
    auras = {
        { key = "RENEW", spellID = 139 },
        { key = "POWER_WORD_SHIELD", spellID = 17 },
        { key = "PRAYER_OF_MENDING", spellID = 33076, showCount = true }, -- charges; hidden if the client lacks it
    },
    dispels = {
        { spellID = 527, types = { "Magic" } },   -- Dispel Magic
        { spellID = 528, types = { "Disease" } }, -- Cure Disease
        { spellID = 552, types = { "Disease" } }, -- Abolish Disease
    },
}
