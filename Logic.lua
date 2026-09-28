-- PaTiHeal: pure logic without WoW API calls (unit-tested in tests/logic_spec.lua).
local _, ns = ...
local Logic = {}
ns.Logic = Logic

-- The click combinations offered in the settings, in display order. `key` is the DB key and the L key.
Logic.BINDINGS = {
    { key = "LEFT", modifier = "", button = 1 },
    { key = "RIGHT", modifier = "", button = 2 },
    { key = "MIDDLE", modifier = "", button = 3 },
    { key = "SHIFT_LEFT", modifier = "shift-", button = 1 },
    { key = "SHIFT_RIGHT", modifier = "shift-", button = 2 },
    { key = "CTRL_LEFT", modifier = "ctrl-", button = 1 },
    { key = "CTRL_RIGHT", modifier = "ctrl-", button = 2 },
    { key = "ALT_LEFT", modifier = "alt-", button = 1 },
    { key = "ALT_RIGHT", modifier = "alt-", button = 2 },
}

-- Attributes written by PaTiHeal <= 0.6.0 that are not part of BINDINGS.
local LEGACY_ATTRIBUTES = { "type", "spell", "shift-spell", "ctrl-spell", "alt-spell" }

-- bindings: DB.bindings (key -> spellID); ranks: DB.bindingRanks (key -> rank, nil = highest known).
-- resolve(spellID, rank) -> castable spell name ("Name" or "Name(Rank 3)") or nil.
-- Returns key -> spell name for the bindings that can be cast right now.
function Logic.SpellNames(bindings, ranks, resolve)
    local names = {}
    for _, binding in ipairs(Logic.BINDINGS) do
        local id = bindings[binding.key]
        if id then names[binding.key] = resolve(id, ranks[binding.key]) end
    end
    return names
end

-- Every secure attribute PaTiHeal owns, as an ordered list of { name, value }. Unassigned
-- combinations get value nil, so an earlier assignment can never keep casting (FOLLOW_UPS F1).
function Logic.ClickAttributes(names)
    local attributes = {}
    for _, name in ipairs(LEGACY_ATTRIBUTES) do attributes[#attributes + 1] = { name = name } end
    for _, binding in ipairs(Logic.BINDINGS) do
        local spell = names[binding.key]
        local suffix = binding.modifier .. "%s" .. binding.button
        attributes[#attributes + 1] = { name = suffix:format("type"), value = spell and "spell" or nil }
        attributes[#attributes + 1] = { name = suffix:format("spell"), value = spell }
    end
    return attributes
end

Logic.SCHEMA = 2

-- 0.6.0 stored one binding as clickButton + clickModifier + clickSpellID.
local LEGACY_BINDING = {
    LeftButton = "LEFT", RightButton = "RIGHT",
    ["shift-LeftButton"] = "SHIFT_LEFT", ["shift-RightButton"] = "SHIFT_RIGHT",
    ["ctrl-LeftButton"] = "CTRL_LEFT", ["ctrl-RightButton"] = "CTRL_RIGHT",
    ["alt-LeftButton"] = "ALT_LEFT", ["alt-RightButton"] = "ALT_RIGHT",
}

-- Brings any saved table (nil, 0.6.0 or current) to the current schema. Keeps position and lock.
function Logic.Migrate(db)
    db = db or {}
    if (db.schema or 0) < 1 then
        db.bindings = db.bindings or {}
        if db.clickSpellID then
            local key = LEGACY_BINDING[(db.clickModifier or "") .. (db.clickButton or "LeftButton")]
            if key and db.bindings[key] == nil then db.bindings[key] = db.clickSpellID end
        end
        db.clickSpellID, db.clickButton, db.clickModifier = nil, nil, nil
        db.schema = 1
    end
    if db.schema < 2 then
        -- 2: chosen spell ranks per binding (empty = highest rank, the 0.6 behaviour).
        db.bindingRanks = db.bindingRanks or {}
        db.schema = 2
    end
    if db.bindings == nil then db.bindings = {} end
    if db.bindingRanks == nil then db.bindingRanks = {} end
    if db.locked == nil then db.locked = false end
    if db.collapsed == nil then db.collapsed = false end
    if db.language == nil then db.language = "auto" end
    if db.showDispels == nil then db.showDispels = true end
    return db
end

-- Settings restored by "Restore Defaults". Position and click bindings are kept on purpose: there are no
-- default bindings, so wiping them would only lose the player's setup (clear one binding with "None").
function Logic.RestoreDefaults(db)
    db.showDispels = true
    db.locked = false
    db.language = "auto"
    return db
end

-- Secret-value rule (AGENTS.md §8): check readability FIRST, compare or test only afterwards.
-- isSecret is injected (issecretvalue in WoW), so these stay pure and testable.

-- value for a widget: a secret value unchanged (widgets may show it), nil replaced by fallback.
-- Replaces `value or fallback`, which would test a secret value.
function Logic.ValueOr(value, fallback, isSecret)
    if isSecret(value) then return value end
    if value == nil then return fallback end
    return value
end

-- A yes/no API flag: true for true or 1 (older client APIs return 1/nil), false for anything else, nil when secret.
function Logic.Flag(value, isSecret)
    if isSecret(value) then return nil end
    return value == true or value == 1
end

-- "48%" for plain numbers. nil when a value is secret or unusable: the caller then hands the raw health
-- value to the widget (allowed for secret values) instead of calculating with it.
function Logic.HealthPercent(health, maximum, isSecret)
    if isSecret(health) or isSecret(maximum) then return nil end
    if type(health) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return nil end
    return ("%d%%"):format(math.floor(health / maximum * 100 + 0.5))
end
