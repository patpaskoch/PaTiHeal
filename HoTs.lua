-- PaTiHeal: your HoTs and shields on party members. Adapter (aura reading) plus pure helpers
-- (tests/hots_spec.lua). Display only; PaTiAuras is never needed or read.
local _, ns = ...
local HoTs = {}
ns.HoTs = HoTs

HoTs.MAX = 3 -- icons per party frame
HoTs.POSITIONS = { "RIGHT", "BELOW" } -- right of the health bar (default) or in the bottom line

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

-- Profile of your class; test mode shows the Shaman profile for classes without one.
function HoTs.Profile(test)
    local _, classFile = UnitClass("player")
    local profiles = ns.HealProfiles or {}
    local profile = not isSecret(classFile) and profiles[classFile]
    if not profile and test then profile = profiles.SHAMAN end
    return profile or nil
end

-- Pure: the profile auras to show — switched on (db.hots[key] ~= false) and known by name to the client.
-- nameOf(spellID) -> client name or nil. Returns { { key, spellID, showCount, name } }.
function HoTs.Entries(profile, db, nameOf)
    local list = {}
    for _, def in ipairs(profile and profile.auras or {}) do
        local name = db.hots[def.key] ~= false and nameOf(def.spellID)
        if name then list[#list + 1] = { key = def.key, spellID = def.spellID, showCount = def.showCount, name = name } end
    end
    return list
end

-- Pure: match normalized auras against the entries, in entry order, at most HoTs.MAX.
-- aura: { name, spellId, icon, count, expiration, secret, timerSecret }. Secret auras never match (not guessed).
function HoTs.Match(entries, auras, now)
    local shown = {}
    for _, entry in ipairs(entries) do
        for _, aura in ipairs(auras) do
            if not aura.secret and (aura.spellId == entry.spellID or aura.name == entry.name) then
                local remaining
                if not aura.timerSecret and type(aura.expiration) == "number" and aura.expiration > 0 then
                    remaining = aura.expiration - now
                end
                shown[#shown + 1] = { entry = entry, icon = aura.icon, count = aura.count, remaining = remaining }
                break
            end
        end
        if #shown >= HoTs.MAX then break end
    end
    return shown
end

-- Pure: corner text of one icon — charges first (entries that count them), else the remaining time.
function HoTs.IconText(item, db, formatRemaining)
    if item.entry.showCount and db.showHotCharges and type(item.count) == "number" and item.count > 0 then
        return tostring(item.count)
    end
    if db.showHotTimers and item.remaining then return formatRemaining(item.remaining) end
    return nil
end

-- WoW API adapter ------------------------------------------------------------------------------

-- "HELPFUL|PLAYER" = only auras you cast (WoW decides the source). If the client ignored the PLAYER part,
-- a readable foreign source is still skipped; an unreadable source is left to the filter (not guessed).
local FILTER = "HELPFUL|PLAYER"

local function auraAt(unit, index)
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local data = C_UnitAuras.GetAuraDataByIndex(unit, index, FILTER)
        if not data then return nil end
        return data.name, data.icon, data.applications, data.expirationTime, data.sourceUnit, data.spellId
    end
    if UnitAura then
        local name, icon, count, _, _, expiration, source, _, _, spellId = UnitAura(unit, index, FILTER)
        return name, icon, count, expiration, source, spellId
    end
    return nil
end

local function plain(value)
    if isSecret(value) then return nil end
    return value
end

local function read(unit)
    local auras = {}
    for index = 1, 40 do
        local name, icon, count, expiration, source, spellId = auraAt(unit, index)
        if not isSecret(name) and name == nil then break end -- secrecy before the nil test
        local foreign = not isSecret(source) and source ~= nil and source ~= "player"
        if not foreign then
            auras[#auras + 1] = { name = plain(name), spellId = plain(spellId), icon = plain(icon), count = plain(count),
                expiration = plain(expiration), timerSecret = isSecret(expiration),
                secret = isSecret(name) and isSecret(spellId) }
        end
    end
    return auras
end

-- Your auras on `unit`, normalized. Never errors (a failed read shows no icons rather than wrong ones).
function HoTs.Read(unit)
    local ok, auras = pcall(read, unit)
    return ok and auras or {}
end

-- Test mode: per unit, entry key -> { count?, remaining? } (keys of both profiles; unused ones are ignored).
HoTs.TEST = {
    party1 = { EARTH_SHIELD = { count = 5 }, RIPTIDE = { remaining = 8 }, POWER_WORD_SHIELD = { remaining = 22 },
        RENEW = { remaining = 11 }, PRAYER_OF_MENDING = { count = 4 } },
    party3 = { RIPTIDE = { remaining = 3 }, RENEW = { remaining = 6 } },
    target = { RIPTIDE = { remaining = 9 }, RENEW = { remaining = 9 } }, -- the heal target row (test mode)
}

function HoTs.TestAuras(unit, entries, now)
    local auras = {}
    for _, entry in ipairs(entries) do
        local fake = (HoTs.TEST[unit] or {})[entry.key]
        if fake then
            auras[#auras + 1] = { name = entry.name, spellId = entry.spellID, count = fake.count,
                expiration = fake.remaining and now + fake.remaining }
        end
    end
    return auras
end
