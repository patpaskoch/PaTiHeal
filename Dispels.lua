-- PaTiHeal: debuffs the player can dispel (WoW API adapter). Display only — PaTiHeal never dispels by itself.
local _, ns = ...
local Dispels = {}
ns.Dispels = Dispels

Dispels.MAX = 2 -- icons per party frame

-- Restricted ("secret") values must not be used; such a debuff is skipped rather than guessed.
local function isSecret(value)
    return issecretvalue ~= nil and issecretvalue(value) == true
end

local function debuffAt(unit, index)
    -- "HARMFUL|RAID" = debuffs the player can remove.
    if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local data = C_UnitAuras.GetAuraDataByIndex(unit, index, "HARMFUL|RAID")
        if not data then return nil end
        return data.name, data.icon, data.dispelName
    end
    if UnitAura then
        local name, icon, _, dispelType = UnitAura(unit, index, "HARMFUL|RAID")
        return name, icon, dispelType
    end
    return nil
end

local function read(unit)
    local list = {}
    for index = 1, 40 do
        local name, icon, dispelType = debuffAt(unit, index)
        if (not isSecret(name) and name == nil) or #list >= Dispels.MAX then break end -- secrecy before the nil test
        if not (isSecret(name) or isSecret(icon) or isSecret(dispelType)) then
            list[#list + 1] = { name = name, icon = icon, dispelType = dispelType }
        end
    end
    return list
end

-- Up to Dispels.MAX dispellable debuffs of `unit` as { name, icon, dispelType }. Never errors.
function Dispels.Read(unit)
    local ok, list = pcall(read, unit)
    if not ok then Dispels.lastError = tostring(list):sub(1, 120) end -- shown by /ph debug, nothing else
    return ok and list or {}
end

-- Border colour of a debuff type (Blizzard's own table when available).
function Dispels.Color(dispelType)
    local color = DebuffTypeColor and DebuffTypeColor[dispelType or "none"]
    return color and { color.r, color.g, color.b }
end

Dispels.TEST = { party3 = { { name = "Polymorph", icon = "Interface\\Icons\\Spell_Nature_Polymorph", dispelType = "Magic" } } }
