-- PaTiHeal profile: Shaman. Only what matters on a party frame: your HoTs/shields on members and your dispels.
-- Self buffs and procs (Water Shield, Tidal Waves) belong to PaTiAuras, not here.
-- spellID = base/rank-1 ID; other ranks match by the name the client returns for it. An ID the client does
-- not know hides its entry. Status: IDs from classic/WotLK data, NOT yet confirmed in the Interface 16001
-- client — `/ph auras` lists what the client reports (PaTiAdmin/docs/WOW_API_COMPAT.md).
local _, ns = ...
ns.HealProfiles = ns.HealProfiles or {}

ns.HealProfiles.SHAMAN = {
    name = "Shaman",
    auras = {
        { key = "EARTH_SHIELD", spellID = 974, showCount = true }, -- charges
        { key = "RIPTIDE", spellID = 61295 },
    },
    -- Offered in the click-casting spell list (click dispel). `types` = what the spell removes, for /ph auras.
    -- Which debuffs are shown is decided by WoW's own filter (HARMFUL|RAID), not by this list.
    dispels = {
        { spellID = 526, types = { "Poison", "Disease" } },           -- Cure Toxins / Cure Poison
        { spellID = 2870, types = { "Disease" } },                    -- Cure Disease (classic)
        { spellID = 51886, types = { "Poison", "Disease", "Curse" } }, -- Cleanse Spirit
    },
}
