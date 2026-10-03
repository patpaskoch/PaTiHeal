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
Logic.SCALES = { 0.8, 0.9, 1, 1.1, 1.25, 1.5 } -- same choices as the other PaTi addons

-- 0.6.0 stored one binding as clickButton + clickModifier + clickSpellID.
local LEGACY_BINDING = {
    LeftButton = "LEFT", RightButton = "RIGHT",
    ["shift-LeftButton"] = "SHIFT_LEFT", ["shift-RightButton"] = "SHIFT_RIGHT",
    ["ctrl-LeftButton"] = "CTRL_LEFT", ["ctrl-RightButton"] = "CTRL_RIGHT",
    ["alt-LeftButton"] = "ALT_LEFT", ["alt-RightButton"] = "ALT_RIGHT",
}

-- Brings any saved table (nil, 0.6.0 or current) to the current schema. Keeps position and lock.
function Logic.Migrate(db)
    if type(db) ~= "table" then db = {} end -- nil or a broken save (string, number …): start fresh
    if type(db.schema) ~= "number" then db.schema = nil end -- broken schema: run every step (they keep values)
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
    -- Only broken entries are dropped: a binding is a spell ID, a rank a number (else the click would cast nothing
    -- or fail); every valid binding of the player stays.
    if type(db.bindings) ~= "table" then db.bindings = {} end
    if type(db.bindingRanks) ~= "table" then db.bindingRanks = {} end
    for key, id in pairs(db.bindings) do
        if type(id) ~= "number" then db.bindings[key] = nil end
    end
    for key, rank in pairs(db.bindingRanks) do
        if type(rank) ~= "number" then db.bindingRanks[key] = nil end
    end
    if db.locked == nil then db.locked = false end
    if db.collapsed == nil then db.collapsed = false end
    if db.language == nil then db.language = "auto" end
    if db.showDispels == nil then db.showDispels = true end
    -- A broken scale would make SetScale fail on login: only a sane number is kept.
    if type(db.scale) ~= "number" or db.scale < 0.5 or db.scale > 2 then db.scale = 1 end
    if db.opacity == nil then db.opacity = 0.75 end -- panel body opacity (PaTiShared window)
    -- Theme: one of the three PaTiShared themes; a typo or an old value falls back to the default look.
    if db.theme ~= "default" and db.theme ~= "woforever" and db.theme ~= "dracula" then db.theme = "default" end
    -- HoTs & shields (no schema step: only new keys with defaults, nothing renamed).
    if type(db.hots) ~= "table" then db.hots = {} end -- key -> false hides that aura
    if db.hotPosition ~= "RIGHT" and db.hotPosition ~= "BELOW" then db.hotPosition = "RIGHT" end
    if db.showHotTimers == nil then db.showHotTimers = true end
    if db.showHotCharges == nil then db.showHotCharges = true end
    return db
end

-- Settings restored by "Restore Defaults". Position, collapsed state and click bindings are kept on purpose:
-- there are no default bindings, so wiping them would only lose the player's setup (clear one with "None").
function Logic.RestoreDefaults(db)
    db.showDispels = true
    db.theme = "default"
    db.scale = 1
    db.opacity = 0.75
    db.hots = {}
    db.hotPosition = "RIGHT"
    db.showHotTimers = true
    db.showHotCharges = true
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

-- Alerts for PaTiAlerts (optional), deliberately small: one INFO alert per party member with a debuff you can
-- dispel (the same debuffs the frame shows). A state, not a decision: nothing says whom to heal or dispel first.
-- members: { { unit, name, dispels } }; name may be secret (display only, `name` field), unit is a plain token.
function Logic.DispelAlerts(members, detail, isSecret)
    local list = {}
    for _, member in ipairs(members) do
        if type(member.dispels) == "number" and member.dispels > 0 and type(member.unit) == "string" then
            local alert = { id = "dispel:" .. member.unit, priority = "INFO", kind = "DISPELLABLE", detail = detail }
            if isSecret(member.name) or member.name ~= nil then alert.name = member.name else alert.text = member.unit end
            list[#list + 1] = alert
        end
    end
    return list
end

-- "48%" for plain numbers. nil when a value is secret or unusable: the caller then hands the raw health
-- value to the widget (allowed for secret values) instead of calculating with it.
function Logic.HealthPercent(health, maximum, isSecret)
    if isSecret(health) or isSecret(maximum) then return nil end
    if type(health) ~= "number" or type(maximum) ~= "number" or maximum <= 0 then return nil end
    return ("%d%%"):format(math.floor(health / maximum * 100 + 0.5))
end

-- How many unit rows the window must be tall for: up to the last row whose unit is there, at least 1 (you). Rows
-- keep fixed slots (player, party1–4), so a gap before that row stays visible instead of a frame being cut off.
-- present[i] = true | false | nil for rows 1..total; nil = unreadable (secret): counts as present, never cut off.
function Logic.RowCount(present, total)
    local count = 1
    for index = 1, total do
        if present[index] ~= false then count = index end
    end
    return count
end

-- Heal target (owner wish 2026-10-02) -----------------------------------------------------------------------

-- What the target row's secure driver does: "show" (test mode: the example target), "hide" (collapsed) or "auto"
-- (WoW decides: a friendly, living target — TargetFrame.CONDITION).
function Logic.TargetMode(testMode, collapsed)
    if collapsed then return "hide" end
    if testMode then return "show" end
    return "auto"
end

-- Geometry of the window, all in px from the window's top. size = { top, row, gap, targetGap, bottom, header, rowX }.
-- The target row sits at the top; the player row (and the party rows chained below it) moves down by one row plus
-- targetGap while the target row is shown. rowCount = Logic.RowCount (party rows to make room for).
-- Returns { rowX, targetTop, playerTop, playerTopShifted, height, heightShifted }; collapsed: header only.
function Logic.HealLayout(size, rowCount, collapsed)
    local step = size.row + size.gap + size.targetGap
    local rowsHeight = size.top + rowCount * (size.row + size.gap) + size.bottom
    local layout = { rowX = size.rowX, targetTop = size.top, playerTop = size.top, playerTopShifted = size.top + step,
        height = rowsHeight, heightShifted = rowsHeight + step }
    if collapsed then layout.height, layout.heightShifted = size.header, size.header end
    return layout
end

-- Level text of the target: "42", "??" for a boss or unknown level (WoW reports -1 or 0), nil when unreadable
-- (secret) — then no number is shown at all instead of a guess.
function Logic.LevelText(level, isSecret)
    if isSecret(level) or type(level) ~= "number" then return nil end
    if level <= 0 then return "??" end
    return tostring(math.floor(level))
end
