-- PaTiHeal: manual party frames. A click casts exactly the spell the player assigned to that click.
local _, ns = ...
local UI, L, Logic, Spells, Dispels = ns.UI, ns.UI.L, ns.Logic, ns.Spells, ns.Dispels

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

-- WoW API adapters (spells: SpellBook.lua, debuffs: Dispels.lua) ----------------------------------

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

local WIDTH, ROW_WIDTH, ROW_HEIGHT, ROW_GAP = 270, 242, 39, 4
local ROWS_TOP = UI.Sizes.HeaderHeight + UI.Spacing.SM
local FULL_HEIGHT = ROWS_TOP + 5 * (ROW_HEIGHT + ROW_GAP) + UI.Spacing.MD

local DISPEL_ICON = 13 -- fits between the health bar and the bottom edge of a row

local window = UI.CreateWindow("PaTiHealFrame", "PaTiHeal", WIDTH, FULL_HEIGHT)

local function setBar(bar, value, maximum)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(value)
end

local function makeRow(index, unit)
    local row = CreateFrame("Button", "PaTiHealUnit" .. index, window, "SecureUnitButtonTemplate")
    row.unit = unit
    row:SetSize(ROW_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", (WIDTH - ROW_WIDTH) / 2, -ROWS_TOP - (index - 1) * (ROW_HEIGHT + ROW_GAP))
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
    mana:SetPoint("BOTTOMLEFT", 3, 3)
    mana:SetSize(ROW_WIDTH - 6 - Dispels.MAX * (DISPEL_ICON + UI.Spacing.XS) - UI.Spacing.SM, 10)
    mana:SetStatusBarTexture(UI.WHITE)
    mana:SetStatusBarColor(UI.Color("Mana"))
    row.health, row.mana, row.name, row.status = health, mana, name, status
    -- Dispellable debuffs: small plain icons (not secure), bottom right next to the mana bar.
    row.dispelIcons = {}
    for slot = 1, Dispels.MAX do
        local icon = UI.StyleAuraIcon(CreateFrame("Frame", nil, row), DISPEL_ICON)
        icon:SetPoint("BOTTOMRIGHT", -3 - (slot - 1) * (DISPEL_ICON + UI.Spacing.XS), 2)
        icon:EnableMouse(true)
        UI.SetTooltip(icon, function() return icon.tooltipLines end)
        icon:Hide()
        row.dispelIcons[slot] = icon
    end
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

-- Offline/dead members show no debuff icons (their state is the important information).
local function paintDispels(row, state)
    local debuffs = {}
    if DB.showDispels and not state then
        debuffs = testMode and (Dispels.TEST[row.unit] or {}) or Dispels.Read(row.unit)
    end
    for slot, icon in ipairs(row.dispelIcons) do
        local debuff = debuffs[slot]
        if debuff then
            icon:SetAura(debuff.icon, "ACTIVE", nil, Dispels.Color(debuff.dispelType))
            icon.tooltipLines = { debuff.name, debuff.dispelType }
        end
        icon:SetShown(debuff ~= nil)
    end
end

-- Row contents only; visibility is handled by updateLayout / the unit watch.
local function refresh()
    if not DB or DB.collapsed then return end
    for _, row in ipairs(rows) do
        local data = unitData(row.unit)
        if data then paintRow(row, data); paintDispels(row, data.state) end
    end
end

-- Secure changes: only out of combat; PLAYER_REGEN_ENABLED calls this again.
-- RegisterUnitWatch shows/hides rows with their unit, also in combat (FOLLOW_UPS F2).
local function updateLayout()
    if not DB or InCombatLockdown() then return end
    local watch = RegisterUnitWatch ~= nil
    for _, row in ipairs(rows) do
        if watch and not DB.collapsed and not testMode then
            RegisterUnitWatch(row)
        else
            if watch then UnregisterUnitWatch(row) end
            row:SetShown(not DB.collapsed and (testMode or UnitExists(row.unit)))
        end
    end
    window:SetHeight(DB.collapsed and UI.Sizes.HeaderHeight or FULL_HEIGHT)
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

-- One settings row: [spell ▾] [rank ▾]. The rank dropdown is only active if the spell has several ranks.
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

-- Column titles above the binding rows: Click | Spell | Rank (aligned with bindingControls).
local function columnHeaders()
    local holder = CreateFrame("Frame", nil, modal)
    holder:SetSize(SPELL_WIDTH + UI.Spacing.SM + RANK_WIDTH, 14)
    for _, column in ipairs({ { "COLUMN_SPELL", 0 }, { "COLUMN_RANK", SPELL_WIDTH + UI.Spacing.SM } }) do
        local title = holder:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
        title:SetPoint("LEFT", column[2] + UI.Spacing.MD, 0)
        UI.BindText(title, column[1])
    end
    return holder
end

local function buildSettings()
    modal = UI.CreateModal("PaTiHealSettings", function() return "PaTiHeal " .. L.SETTINGS end, 440)
    modal:AddSection("CLICK_CASTING")
    modal:AddRow("COLUMN_CLICK", columnHeaders()):SetTextColor(UI.Color("TextMuted"))
    for _, binding in ipairs(Logic.BINDINGS) do modal:AddRow(binding.key, bindingControls(binding.key)) end
    modal:AddSection("GENERAL")
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 200))
    modal:AddControls(UI.CreateCheckbox(modal, "LOCK_WINDOW", {
        get = function() return window:IsLocked() end,
        set = function(locked) window:SetLocked(locked) end,
    }), UI.CreateCheckbox(modal, "SHOW_DISPELS", {
        get = function() return DB.showDispels end,
        set = function(show) DB.showDispels = show; refresh() end,
    }))
    modal:Finish(function()
        Logic.RestoreDefaults(DB)
        UI.SetLanguage(DB.language)
        window:SetLocked(DB.locked)
        applyBindings()
        refresh()
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
    updateLayout()
    applyBindings()
    refresh()
end

local function toggleCollapsed()
    if combatBlocked() then return end
    DB.collapsed = not DB.collapsed
    updateLayout()
    refresh()
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
end

local COMMANDS = {
    settings = openSettings,
    test = toggleTestMode,
    show = function() setShown(true) end,
    hide = function() setShown(false) end,
    lock = function() window:SetLocked(true) end,
    unlock = function() window:SetLocked(false) end,
    spells = printSpells,
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
local rowByUnit = {}
for _, row in ipairs(rows) do rowByUnit[row.unit] = row end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        PaTiHealDB = Logic.Migrate(PaTiHealDB)
        DB = PaTiHealDB
        UI.SetLanguage(DB.language)
        window:Attach(DB, 330, 0)
        Spells.Rescan()
        updateLayout()
        applyBindings()
    elseif not DB then
        return
    elseif event == "UNIT_AURA" then
        -- Only the debuff icons of that one frame can change; no full redraw.
        local row = rowByUnit[unit]
        if row and not DB.collapsed and not testMode then
            local data = unitData(unit)
            paintDispels(row, data and data.state)
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        updateLayout()
        applyBindings()
    elseif event == "GROUP_ROSTER_UPDATE" then
        updateLayout()
    elseif event == "SPELLS_CHANGED" then
        Spells.Rescan() -- new ranks become selectable
        applyBindings()
    end
    refresh()
end)
UI.OnLanguageChanged(refresh)

say("LOADED")
