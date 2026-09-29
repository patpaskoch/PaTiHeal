-- PaTiHeal HoTs & shields: profiles and the pure helpers of HoTs.lua. Run via PaTiAdmin/tools/check.sh.
local wow = require("wow_api")

local NAMES = { [974] = "Erdschild", [61295] = "Springflut", [139] = "Erneuerung", [17] = "Machtwort: Schild" }
local function nameOf(id) return NAMES[id] end

local function load(class)
    wow.install()
    _G.UnitClass = function() return class, class end
    local ns = {}
    for _, file in ipairs({ "Profiles/Shaman.lua", "Profiles/Priest.lua", "HoTs.lua" }) do wow.loadAddonFile(file, ns) end
    return ns
end

local function db(extra)
    local settings = { hots = {}, showHotTimers = true, showHotCharges = true }
    for key, value in pairs(extra or {}) do settings[key] = value end
    return settings
end

local function keys(list)
    local result = {}
    for _, item in ipairs(list) do result[#result + 1] = (item.entry or item).key end
    return result
end

describe("Heal profiles", function()
    it("Shaman: Earth Shield (charges) and Riptide, dispels with their debuff types", function()
        local profile = load("SHAMAN").HoTs.Profile(false)
        assert.equal("Shaman", profile.name)
        assert.same({ "EARTH_SHIELD", "RIPTIDE" }, keys(profile.auras))
        assert.is_true(profile.auras[1].showCount)
        assert.same({ 526, 2870, 51886 }, { profile.dispels[1].spellID, profile.dispels[2].spellID, profile.dispels[3].spellID })
        assert.same({ "Poison", "Disease", "Curse" }, profile.dispels[3].types)
    end)

    it("Priest: Renew, Power Word: Shield, Prayer of Mending; Dispel Magic removes Magic", function()
        local profile = load("PRIEST").HoTs.Profile(false)
        assert.same({ "RENEW", "POWER_WORD_SHIELD", "PRAYER_OF_MENDING" }, keys(profile.auras))
        assert.same({ "Magic" }, profile.dispels[1].types)
    end)

    it("has no profile for other classes; test mode falls back to the Shaman profile", function()
        local HoTs = load("WARRIOR").HoTs
        assert.is_nil(HoTs.Profile(false))
        assert.equal("Shaman", HoTs.Profile(true).name)
    end)
end)

describe("HoTs.Entries", function()
    it("shows switched-on auras the client knows; an unknown ID hides its entry", function()
        local HoTs = load("PRIEST").HoTs
        local entries = HoTs.Entries(HoTs.Profile(false), db(), nameOf)
        assert.same({ "RENEW", "POWER_WORD_SHIELD" }, keys(entries)) -- 33076 unknown to this "client"
        assert.same({ "POWER_WORD_SHIELD" }, keys(HoTs.Entries(HoTs.Profile(false), db({ hots = { RENEW = false } }), nameOf)))
    end)
end)

describe("HoTs.Match", function()
    local function entries()
        local HoTs = load("SHAMAN").HoTs
        return HoTs, HoTs.Entries(HoTs.Profile(false), db(), nameOf)
    end

    it("matches by spell ID or by name (other ranks) and computes the remaining time", function()
        local HoTs, list = entries()
        local shown = HoTs.Match(list, {
            { name = "Springflut", spellId = 61299, expiration = 108 },
            { name = "Erdschild", spellId = 974, count = 5, expiration = 0 },
        }, 100)
        assert.same({ "EARTH_SHIELD", "RIPTIDE" }, keys(shown)) -- entry order, not aura order
        assert.equal(5, shown[1].count)
        assert.is_nil(shown[1].remaining) -- no duration
        assert.equal(8, shown[2].remaining)
    end)

    it("never matches secret auras and ignores secret timers", function()
        local HoTs, list = entries()
        assert.same({}, HoTs.Match(list, { { secret = true } }, 100))
        local shown = HoTs.Match(list, { { name = "Springflut", timerSecret = true } }, 100)
        assert.is_nil(shown[1].remaining)
    end)
end)

describe("HoTs.IconText", function()
    local function fmt(seconds) return ("%ds"):format(seconds) end
    local shield = { entry = { showCount = true }, count = 5, remaining = 30 }
    local riptide = { entry = {}, count = 0, remaining = 8 }

    it("shows charges first, else the timer", function()
        local HoTs = load("SHAMAN").HoTs
        assert.equal("5", HoTs.IconText(shield, db(), fmt))
        assert.equal("8s", HoTs.IconText(riptide, db(), fmt))
    end)

    it("follows the timer and charges settings", function()
        local HoTs = load("SHAMAN").HoTs
        assert.equal("30s", HoTs.IconText(shield, db({ showHotCharges = false }), fmt))
        assert.is_nil(HoTs.IconText(riptide, db({ showHotTimers = false }), fmt))
    end)
end)
