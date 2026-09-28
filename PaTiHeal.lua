-- PaTiHeal: manual party frames. A click casts exactly the spell the player assigned to that click.
local _, ns = ...
local UI, L, Logic, Spells = ns.UI, ns.UI.L, ns.Logic, ns.Spells

local DB
local rows = {}
local testMode = false

local HEAL_SPELLS = {
    {331, "Heilende Welle"}, {8004, "Welle der Heilung"}, {1064, "Kettenheilung"}, {61295, "Springflut"}, {73920, "Heilender Regen"},
    {2050, "Geringes Heilen"}, {2060, "Heilen"}, {2061, "Blitzheilung"}, {2061, "Große Heilung"},
    {635, "Heiliges Licht"}, {19750, "Lichtblitz"}, {5185, "Heilende Berührung"}, {8936, "Nachwachsen"}, {774, "Verjüngung"},
}

local function say(key, ...)
    print("|cff68caffPaTiHeal:|r " .. L[key]:format(...))
end

-- WoW API adapters (spell APIs: SpellBook.lua) ---------------------------------------------------

local spellName, spellIcon = Spells.Name, Spells.Icon

local function knownSpells()
    local result, seen = {}, {}
    for _, entry in ipairs(HEAL_SPELLS) do
        if not seen[entry[1]] and Spells.IsKnown(entry[1]) then
            seen[entry[1]] = true
            result[#result + 1] = entry[1]
        end
    end
    return result
end

local function className(classFile)
    return LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile
end

local TEST_UNITS = {
    player = { nameKey = "TEST_HEALER", class = "SHAMAN", health = 82, mana = 72 },
    party1 = { nameKey = "TEST_TANK", class = "WARRIOR", health = 48, mana = 20, isTank = true },
    party2 = { nameKey = "TEST_MEMBER", class = "MAGE", health = 100, mana = 90 },
    party3 = { nameKey = "TEST_MEMBER", class = "PRIEST", health = 15, mana = 60 },
    party4 = { nameKey = "TEST_MEMBER", class = "HUNTER", health = 0, mana = 0, state = "OFFLINE" },
}

-- One unit as a plain table: name, class, health, healthMax, mana, manaMax, state, isTank.
-- Health values can be secret values: they are only handed to widgets, never calculated with.
local function unitData(unit)
    if testMode then
        local fake = TEST_UNITS[unit]
        return { name = L[fake.nameKey], class = className(fake.class), health = fake.health, healthMax = 100,
            mana = fake.mana, manaMax = 100, state = fake.state, isTank = fake.isTank }
    end
    if not UnitExists(unit) then return nil end
    local data = { name = UnitName(unit) or unit, class = UnitClass(unit) or L.UNKNOWN_CLASS,
        health = 0, healthMax = 1, mana = 0, manaMax = 1 }
    if not UnitIsConnected(unit) then data.state = "OFFLINE"; return data end
    if UnitIsDeadOrGhost(unit) then data.state = "DEAD"; return data end
    data.health, data.healthMax = UnitHealth(unit) or 0, UnitHealthMax(unit) or 1
    if UnitPowerType(unit) == 0 then data.mana, data.manaMax = UnitPower(unit, 0) or 0, UnitPowerMax(unit, 0) or 0 end
    data.isTank = UnitGroupRolesAssigned(unit) == "TANK"
    return data
end

-- Window and rows -------------------------------------------------------------------------------

-- Row: health bar (20) on top, below it the mana bar and room for aura icons (AuraWatch.ROW_ICON_AREA).
local WIDTH, ROW_WIDTH, ROW_HEIGHT, ROW_GAP = 270, 242, 42, 4
local ROWS_LEFT = (WIDTH - ROW_WIDTH) / 2
local ROWS_TOP = UI.Sizes.HeaderHeight + UI.Spacing.SM
local ROWS_HEIGHT = 5 * (ROW_HEIGHT + ROW_GAP)

local window = UI.CreateWindow("PaTiHealFrame", "PaTiHeal", WIDTH, ROWS_TOP + ROWS_HEIGHT + UI.Spacing.MD)

local function setBar(bar, value, maximum)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(value)
end

local function makeRow(index, unit)
    local row = CreateFrame("Button", "PaTiHealUnit" .. index, window, "SecureUnitButtonTemplate")
    row.unit = unit
    row.index = index
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:RegisterForClicks("AnyUp")
    row:SetAttribute("unit", unit)
    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(UI.Color("Panel"))
    local health = CreateFrame("StatusBar", nil, row)
    health:SetPoint("TOPLEFT", 3, -3)
    health:SetSize(ROW_WIDTH - 6, 20)
    health:SetStatusBarTexture(UI.WHITE)
    local name = health:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    name:SetPoint("LEFT", 6, 0)
    name:SetWidth(155)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    local status = health:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    status:SetPoint("RIGHT", -6, 0)
    local mana = CreateFrame("StatusBar", nil, row)
    mana:SetPoint("BOTTOMLEFT", 3, 5)
    mana:SetSize(ROW_WIDTH - 6 - ns.AuraWatch.ROW_ICON_AREA - UI.Spacing.SM, 10)
    mana:SetStatusBarTexture(UI.WHITE)
    mana:SetStatusBarColor(UI.Color("Mana"))
    row.health, row.mana, row.name, row.status = health, mana, name, status
    row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row:SetScript("OnEnter", function(self)
        if not testMode and UnitExists(unit) then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end
for index, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do rows[index] = makeRow(index, unit) end

local updateLayout -- defined below; aura watch asks for a relayout after settings changes
local auraWatch = ns.AuraWatch.Create({
    window = window,
    rows = rows,
    getDB = function() return DB end,
    isTestMode = function() return testMode end,
    unitData = function(unit) return unitData(unit) end,
    relayout = function() updateLayout() end,
})

local function paintRow(row, data)
    local name = data.name
    if row.unit == "player" then name = name .. " " .. L.SUFFIX_YOU
    elseif data.isTank then name = name .. " " .. L.SUFFIX_TANK end
    row.name:SetText(name .. " – " .. data.class)
    setBar(row.health, data.health, data.healthMax)
    setBar(row.mana, data.mana, data.manaMax)
    if data.state then
        row.status:SetText(L[data.state])
        row.health:SetStatusBarColor(UI.Color("Danger"))
    else
        row.status:SetText(data.health)
        row.health:SetStatusBarColor(UI.Color("Health"))
    end
end

-- Row contents only; visibility is handled by updateLayout / the unit watch.
local function refresh()
    if not DB or DB.collapsed then return end
    for _, row in ipairs(rows) do
        local data = unitData(row.unit)
        if data then paintRow(row, data) end
    end
end

-- Secure changes: only out of combat; PLAYER_REGEN_ENABLED calls this again.
-- RegisterUnitWatch shows/hides rows with their unit, also in combat (FOLLOW_UPS F2).
function updateLayout()
    if not DB or InCombatLockdown() then return end
    local unitWatch = RegisterUnitWatch ~= nil
    local rowsTop = ROWS_TOP + auraWatch:TopHeight()
    for _, row in ipairs(rows) do
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", window, "TOPLEFT", ROWS_LEFT, -rowsTop - (row.index - 1) * (ROW_HEIGHT + ROW_GAP))
        if unitWatch and not DB.collapsed and not testMode then
            RegisterUnitWatch(row)
        else
            if unitWatch then UnregisterUnitWatch(row) end
            row:SetShown(not DB.collapsed and (testMode or UnitExists(row.unit)))
        end
    end
    auraWatch:Place(ROWS_LEFT, ROWS_TOP, rowsTop + ROWS_HEIGHT, ROW_WIDTH)
    local height = rowsTop + ROWS_HEIGHT + auraWatch:BottomHeight() + UI.Spacing.MD
    window:SetHeight(DB.collapsed and UI.Sizes.HeaderHeight or height)
    if DB.collapsed then auraWatch.strip:Hide(); auraWatch.summary:Hide() end
    window:SetTestMode(testMode)
end

local function castName(id, rank)
    return Spells.IsKnown(id) and Spells.CastName(id, rank) or nil
end

local function applyBindings()
    if not DB or InCombatLockdown() then return end
    local names = Logic.SpellNames(DB.bindings, DB.bindingRanks, castName)
    local attributes = Logic.ClickAttributes(names)
    local anyBinding = next(names) ~= nil
    for _, row in ipairs(rows) do
        for _, attribute in ipairs(attributes) do row:SetAttribute(attribute.name, attribute.value) end
        row:SetEnabled(not testMode and anyBinding)
    end
end

-- Settings modal (built on first open, when DB exists) -----------------------------------------

local modal

local function spellItems(current)
    local items, listed = { { value = 0, text = "NO_SPELL" } }, {}
    local ids = knownSpells()
    if current and current ~= 0 then ids[#ids + 1] = current end -- keep an assigned spell visible after a respec
    for _, id in ipairs(ids) do
        if not listed[id] then
            listed[id] = true
            local name = spellName(id) or tostring(id)
            items[#items + 1] = { value = id, text = function() return name end, icon = spellIcon(id) }
        end
    end
    return items
end

-- Rank choices for the spell bound to `key`: highest known (default) plus every known numbered rank.
local function rankItems(key)
    local items = { { value = 0, text = "RANK_HIGHEST" } }
    local id = DB.bindings[key]
    for _, entry in ipairs(id and Spells.Ranks(id) or {}) do
        local subtext = entry.subtext
        items[#items + 1] = { value = entry.rank, text = function() return subtext end }
    end
    return items
end

local SPELL_WIDTH, RANK_WIDTH = 168, 84

-- One settings row: [spell ▾] [rank ▾]. The rank dropdown is only active if the spell has ranks.
local function bindingControls(key)
    local holder = CreateFrame("Frame", nil, modal)
    holder:SetSize(SPELL_WIDTH + UI.Spacing.SM + RANK_WIDTH, UI.Sizes.ButtonHeight)
    local changed = function()
        if InCombatLockdown() then say("APPLY_AFTER_COMBAT") end
        applyBindings()
    end
    local rank = UI.CreateDropdown(holder, RANK_WIDTH, {
        items = function() return rankItems(key) end,
        get = function() return DB.bindingRanks[key] or 0 end,
        set = function(value) DB.bindingRanks[key] = value ~= 0 and value or nil; changed() end,
        enabled = function() return DB.bindings[key] ~= nil and #Spells.Ranks(DB.bindings[key]) > 1 end,
    })
    rank:SetPoint("RIGHT")
    local spell = UI.CreateDropdown(holder, SPELL_WIDTH, {
        items = function() return spellItems(DB.bindings[key]) end,
        get = function() return DB.bindings[key] or 0 end,
        set = function(id)
            DB.bindings[key] = id ~= 0 and id or nil
            DB.bindingRanks[key] = nil -- a new spell starts at its highest rank
            rank:Refresh()
            changed()
        end,
    })
    spell:SetPoint("LEFT")
    return holder
end

local function buildSettings()
    modal = UI.CreateModal("PaTiHealSettings", function() return "PaTiHeal " .. L.SETTINGS end, 440)
    modal:AddSection("CLICK_CASTING")
    for _, binding in ipairs(Logic.BINDINGS) do modal:AddRow(binding.key, bindingControls(binding.key)) end
    modal:AddSection("GENERAL")
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 200))
    modal:AddControl(UI.CreateCheckbox(modal, "LOCK_WINDOW", {
        get = function() return window:IsLocked() end,
        set = function(locked) window:SetLocked(locked) end,
    }))
    auraWatch:BuildSettings(modal)
    modal:Finish(function()
        Logic.RestoreDefaults(DB)
        UI.SetLanguage(DB.language)
        window:SetLocked(DB.locked)
        applyBindings()
        auraWatch:Rebuild()
        updateLayout()
        auraWatch:RefreshAll()
    end)
end

local function openSettings()
    if not DB then return end
    if not modal then buildSettings() end
    modal:Show()
end

-- Actions (menu and slash commands) --------------------------------------------------------------

local function combatBlocked()
    if InCombatLockdown() then say("COMBAT_LOCKED"); return true end
    return false
end

local function toggleTestMode()
    if combatBlocked() then return end
    testMode = not testMode
    auraWatch:Rebuild()
    updateLayout()
    applyBindings()
    refresh()
    auraWatch:RefreshAll()
end

local function toggleCollapsed()
    if combatBlocked() then return end
    DB.collapsed = not DB.collapsed
    updateLayout()
    refresh()
    auraWatch:RefreshAll()
end

local function setShown(shown)
    if combatBlocked() then return end
    window:SetShown(shown)
    if not shown then say("HIDDEN_HINT") end
end

window:SetMenu(function()
    if not DB then return {} end
    local combat = InCombatLockdown()
    local combatTip = combat and "COMBAT_LOCKED" or nil
    return {
        { text = "SETTINGS", onClick = openSettings },
        { text = window:IsLocked() and "UNLOCK" or "LOCK", onClick = function() window:SetLocked(not window:IsLocked()) end },
        { text = DB.collapsed and "EXPAND" or "COLLAPSE", disabled = combat, tooltip = combatTip, onClick = toggleCollapsed },
        { text = "TEST_MODE", checked = testMode, disabled = combat, tooltip = combatTip, onClick = toggleTestMode },
        { text = "HIDE", disabled = combat, tooltip = combatTip, onClick = function() setShown(false) end },
    }
end)

local function printSpells()
    local names = {}
    for _, id in ipairs(knownSpells()) do names[#names + 1] = (spellName(id) or id) .. " (" .. id .. ")" end
    if #names == 0 then say("NO_SPELLS") else say("KNOWN_SPELLS", table.concat(names, ", ")) end
end

local function printDebug()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    print(("|cff68caffPaTiHeal Debug:|r PaTiHeal %s · PaTiShared UI %s · %s · test=%s"):format(
        tostring(getMetadata and getMetadata("PaTiHeal", "Version")), tostring(UI.VERSION),
        UI.GetLanguage(), tostring(testMode)))
    local row = rows[1]
    for _, binding in ipairs(Logic.BINDINGS) do
        local prefix = binding.modifier
        print(("  %s: id=%s rank=%s type=%s spell=%s"):format(binding.key, tostring(DB.bindings[binding.key]),
            tostring(DB.bindingRanks[binding.key] or "highest"),
            tostring(row:GetAttribute(prefix .. "type" .. binding.button)),
            tostring(row:GetAttribute(prefix .. "spell" .. binding.button))))
    end
    for _, line in ipairs(auraWatch:DebugLines()) do print("  " .. line) end
end

-- /ph auras: what this client reports for every aura profile spell ID (to confirm them in game).
local function printAuraCheck()
    print("|cff68caffPaTiHeal Auras:|r")
    for _, line in ipairs(auraWatch:VerifyLines()) do print("  " .. line) end
end

local COMMANDS = {
    settings = openSettings,
    test = toggleTestMode,
    show = function() setShown(true) end,
    hide = function() setShown(false) end,
    lock = function() window:SetLocked(true) end,
    unlock = function() window:SetLocked(false) end,
    spells = printSpells,
    auras = printAuraCheck,
    debug = printDebug,
}

SLASH_PATIHEAL1 = "/patiheal"
SLASH_PATIHEAL2 = "/ph"
SlashCmdList.PATIHEAL = function(message)
    local command = COMMANDS[(message or ""):match("^%s*(.-)%s*$"):lower()]
    if command and DB then command() else say("HELP") end
end

-- Events -----------------------------------------------------------------------------------------

local events = CreateFrame("Frame")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "GROUP_ROSTER_UPDATE", "UNIT_HEALTH", "UNIT_POWER_UPDATE",
    "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED" }) do
    events:RegisterEvent(event)
end
-- Talent/spec events differ between client generations; register the ones this client has.
for _, event in ipairs({ "PLAYER_SPECIALIZATION_CHANGED", "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED" }) do
    pcall(events.RegisterEvent, events, event)
end

-- Spells, ranks or talents changed: recheck the aura profile. Secure parts wait for the end of combat.
local function spellsChanged()
    Spells.Rescan()
    auraWatch:Rebuild()
    updateLayout()
    applyBindings()
    auraWatch:RefreshAll()
end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        PaTiHealDB = Logic.Migrate(PaTiHealDB)
        DB = PaTiHealDB
        UI.SetLanguage(DB.language)
        window:Attach(DB, 330, 0)
        spellsChanged()
    elseif not DB then
        return
    elseif event == "UNIT_AURA" then
        auraWatch:RefreshUnit(unit) -- ignores units without a party frame
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        updateLayout()
        applyBindings()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD" then
        updateLayout()
        auraWatch:RefreshAll()
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "CHARACTER_POINTS_CHANGED" then
        spellsChanged()
    elseif event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        auraWatch:RefreshUnit(unit) -- offline/dead hides the unit's aura icons
    end
    refresh()
end)
UI.OnLanguageChanged(refresh)

say("LOADED")
