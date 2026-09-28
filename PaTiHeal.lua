-- PaTiHeal: a compact, manual healing aid. No automatic targeting or casting.
local addonName = ...
local DB
local rows = {}
local isTestMode = false
local clickSpellButton

local defaults = {
    point = "CENTER",
    x = 330,
    y = 0,
    locked = false,
}

local function copyDefaults()
    PaTiHealDB = PaTiHealDB or {}
    for key, value in pairs(defaults) do
        if PaTiHealDB[key] == nil then
            PaTiHealDB[key] = value
        end
    end
    DB = PaTiHealDB
end

local function isKnownSpell(spellID)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, spellID)
        return ok and known
    end
    return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(spellID) ~= nil
end

local healingSpells = {
    { id = 331, label = "Heilende Welle" },
    { id = 8004, label = "Welle der Heilung" },
    { id = 1064, label = "Kettenheilung" },
    { id = 61295, label = "Springflut" },
    { id = 73920, label = "Heilender Regen" },
}

local function getSpellInfo(spellID)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(spellID)
        if info then
            return info.name, info.iconID
        end
    elseif GetSpellInfo then
        return GetSpellInfo(spellID)
    end
end

local function getSelectedHealSpell()
    local spellID = DB and DB.clickSpellID
    if spellID and isKnownSpell(spellID) then
        return spellID
    end
end

local function getNextKnownHealSpell()
    local current = DB and DB.clickSpellID
    local firstKnown
    local foundCurrent = false
    for _, spell in ipairs(healingSpells) do
        if isKnownSpell(spell.id) then
            firstKnown = firstKnown or spell.id
            if foundCurrent then
                return spell.id
            end
            foundCurrent = spell.id == current
        end
    end
    return firstKnown
end

local function unitStatus(unit)
    if isTestMode then
        local test = {
            player = { "Du", "Schamane", 82, 100, 72, 100 },
            party1 = { "Tank", "Krieger", 48, 100, 20, 100 },
            party2 = { "Gruppe 2", "Magier", 100, 100, 90, 100 },
            party3 = { "Gruppe 3", "Priester", 15, 100, 60, 100 },
            party4 = { "Offline", "Jäger", 0, 100, 0, 100, "OFFLINE" },
        }
        return test[unit]
    end
    if not UnitExists(unit) then
        return nil
    end
    local name = UnitName(unit) or unit
    local className = UnitClass(unit) or "Unbekannt"
    if not UnitIsConnected(unit) then
        return { name, className, 0, 1, 0, 1, "OFFLINE" }
    end
    if UnitIsDeadOrGhost(unit) then
        return { name, className, 0, 1, 0, 1, "TOT" }
    end
    local health = UnitHealth(unit) or 0
    local healthMax = UnitHealthMax(unit) or 1
    local mana, manaMax = 0, 0
    local powerType = UnitPowerType(unit)
    if powerType == 0 then
        mana = UnitPower(unit, 0) or 0
        manaMax = UnitPowerMax(unit, 0) or 0
    end
    return { name, className, health, healthMax, mana, manaMax }
end

-- In this client group health and mana can be "secret values" in combat.
-- StatusBar accepts them directly, while Lua arithmetic does not.
local function setBar(bar, value, maximum)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(value)
end

local frame = CreateFrame("Frame", "PaTiHealFrame", UIParent, "BackdropTemplate")
frame:SetSize(270, 330)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
frame:SetBackdropColor(0.08, 0.11, 0.13, 0.96)
frame:SetBackdropBorderColor(0.36, 0.62, 0.72, 1)

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -11)
title:SetText("PaTiHeal")

local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
close:SetSize(24, 24)
close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -2)
close:SetScript("OnClick", function()
    frame:Hide()
end)

local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
hint:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -29, -12)
hint:SetText("Linksklick: Heilen")

local manaText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
manaText:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -34)
manaText:SetText("Dein Mana: --")

local cooldownTitle = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
cooldownTitle:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 44)
cooldownTitle:SetText("Eigene Heilzauber")

local cooldownText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
cooldownText:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 25)
cooldownText:SetWidth(242)
cooldownText:SetJustifyH("LEFT")
cooldownText:SetWordWrap(true)

local testLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
testLabel:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 25)
testLabel:SetTextColor(1, 0.82, 0)
testLabel:Hide()

clickSpellButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
clickSpellButton:SetSize(122, 20)
clickSpellButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 3)
clickSpellButton:SetText("Zauber waehlen")

local function makeRow(index, unit)
    local row = CreateFrame("Button", "PaTiHealUnit" .. index, frame, "SecureActionButtonTemplate")
    row:SetSize(242, 39)
    row:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -55 - ((index - 1) * 43))
    row:RegisterForClicks("LeftButtonUp")
    row:SetAttribute("unit", unit)
    row:SetAttribute("type1", "spell")

    local background = row:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.12, 0.15, 0.18, 0.95)
    row.background = background

    local health = CreateFrame("StatusBar", nil, row)
    health:SetPoint("TOPLEFT", row, "TOPLEFT", 3, -3)
    health:SetSize(236, 20)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:SetStatusBarColor(0.18, 0.64, 0.30, 0.9)
    row.health = health

    local mana = CreateFrame("StatusBar", nil, row)
    mana:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 3, 3)
    mana:SetSize(236, 10)
    mana:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    mana:SetStatusBarColor(0.16, 0.42, 0.90, 0.9)
    row.mana = mana

    local name = health:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    name:SetPoint("LEFT", health, "LEFT", 6, 0)
    name:SetWidth(150)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1, 1, 1)
    row.name = name

    local status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    status:SetPoint("RIGHT", row, "RIGHT", -8, 5)
    status:SetJustifyH("RIGHT")
    row.status = status

    local sub = row:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("RIGHT", row, "RIGHT", -8, -10)
    sub:SetJustifyH("RIGHT")
    row.sub = sub

    row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
    row:SetScript("OnEnter", function(self)
        if UnitExists(unit) and not isTestMode then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetUnit(unit)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    return row
end

for index, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
    rows[#rows + 1] = makeRow(index, unit)
end

local function updateRow(row)
    local data = unitStatus(row:GetAttribute("unit"))
    if not data then
        row:Hide()
        return
    end
    row:Show()
    local name, className, health, healthMax, mana, manaMax, state = unpack(data)
    if row:GetAttribute("unit") == "player" then
        name = name .. " (Du)"
    elseif not isTestMode and UnitGroupRolesAssigned(row:GetAttribute("unit")) == "TANK" then
        name = name .. " (Tank)"
    elseif isTestMode and row:GetAttribute("unit") == "party1" then
        name = name .. " (Tank)"
    end
    row.name:SetText(name .. " – " .. className)
    setBar(row.health, health, healthMax)
    setBar(row.mana, mana, manaMax)
    if state then
        row.status:SetText(state)
        row.status:SetTextColor(1, 0.24, 0.24)
        row.sub:SetText("")
        row.health:SetStatusBarColor(0.45, 0.12, 0.12, 1)
    else
        row.status:SetText(health)
        row.status:SetTextColor(1, 1, 1)
        row.sub:SetText(mana)
        row.health:SetStatusBarColor(0.18, 0.64, 0.30, 1)
    end
    if not isTestMode and UnitInRange then
        local inRange = UnitInRange(row:GetAttribute("unit"))
        if not issecretvalue or not issecretvalue(inRange) then
            row:SetAlpha(inRange == false and 0.55 or 1)
        else
            row:SetAlpha(1)
        end
    else
        row:SetAlpha(1)
    end
end

local function formatCooldown(spellID)
    local name = getSpellInfo(spellID)
    if not name then
        return nil
    end
    local startTime, duration
    if C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(spellID)
        if type(info) == "table" then
            startTime, duration = info.startTime, info.duration
        end
    elseif GetSpellCooldown then
        startTime, duration = GetSpellCooldown(spellID)
    end
    if startTime and duration and (not issecretvalue or (not issecretvalue(startTime) and not issecretvalue(duration))) then
        local remaining = math.max(0, (startTime + duration) - GetTime())
        if remaining > 0.1 then
            return string.format("%s: %.0fs", name, remaining)
        end
        return name .. ": bereit"
    end
    return name
end

local function updateDisplay()
    if not DB then
        return
    end
    for _, row in ipairs(rows) do
        updateRow(row)
    end
    local mana, manaMax = UnitPower("player", 0) or 0, UnitPowerMax("player", 0) or 0
    if isTestMode then
        mana, manaMax = 4200, 6000
    end
    manaText:SetFormattedText("Dein Mana: %s / %s", mana, manaMax)

    local cooldowns = {}
    for _, spell in ipairs(healingSpells) do
        if isKnownSpell(spell.id) then
            local text = formatCooldown(spell.id)
            if text then
                cooldowns[#cooldowns + 1] = text
            end
        end
    end
    cooldownText:SetText(#cooldowns > 0 and table.concat(cooldowns, "  |  ") or "Keine bekannten Heilzauber gefunden")
    testLabel:SetShown(isTestMode)
    if isTestMode then
        testLabel:SetText("TESTMODUS – keine Zauber")
    end
end

local function applyClickSpell()
    if InCombatLockdown() then
        return
    end
    local spellID = getSelectedHealSpell()
    for _, row in ipairs(rows) do
        row:SetAttribute("spell1", spellID)
        row:SetEnabled(not isTestMode and spellID ~= nil)
    end
    if spellID then
        local name = getSpellInfo(spellID)
        hint:SetText("Linksklick: " .. (name or "Heilzauber"))
        clickSpellButton:SetText("Zauber: " .. (name or spellID))
    else
        hint:SetText("Kein Klickzauber – unten waehlen")
        clickSpellButton:SetText("Zauber waehlen")
    end
    clickSpellButton:SetEnabled(not InCombatLockdown())
end

local function selectNextHealSpell()
    if InCombatLockdown() then
        print("|cff68caffPaTiHeal:|r Zauberwahl ist im Kampf nicht moeglich.")
        return
    end
    local spellID = getNextKnownHealSpell()
    if not spellID then
        print("|cff68caffPaTiHeal:|r Kein bekannter Heilzauber gefunden.")
        return
    end
    DB.clickSpellID = spellID
    applyClickSpell()
    updateDisplay()
end

clickSpellButton:SetScript("OnClick", selectNextHealSpell)

frame:SetScript("OnDragStart", function(self)
    if not DB.locked and not InCombatLockdown() then
        self:StartMoving()
    end
end)
frame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, _, x, y = self:GetPoint()
    DB.point, DB.x, DB.y = point, x, y
end)

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("GROUP_ROSTER_UPDATE")
events:RegisterEvent("UNIT_HEALTH")
events:RegisterEvent("UNIT_POWER_UPDATE")
events:RegisterEvent("UNIT_CONNECTION")
events:RegisterEvent("UNIT_FLAGS")
events:RegisterEvent("SPELL_UPDATE_COOLDOWN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then
        copyDefaults()
        frame:ClearAllPoints()
        frame:SetPoint(DB.point, UIParent, DB.point, DB.x, DB.y)
        applyClickSpell()
    elseif event == "PLAYER_REGEN_ENABLED" then
        applyClickSpell()
    end
    updateDisplay()
end)

SLASH_PATIHEAL1 = "/patiheal"
SLASH_PATIHEAL2 = "/ph"
SlashCmdList.PATIHEAL = function(message)
    local command = (message or ""):match("^%s*(.-)%s*$"):lower()
    if command == "test" then
        if InCombatLockdown() then
            print("|cff68caffPaTiHeal:|r Testmodus kann im Kampf nicht geaendert werden.")
            return
        end
        isTestMode = not isTestMode
        applyClickSpell()
        updateDisplay()
    elseif command == "lock" then
        DB.locked = true
        print("|cff68caffPaTiHeal:|r Fenster gesperrt.")
    elseif command == "unlock" then
        if InCombatLockdown() then
            print("|cff68caffPaTiHeal:|r Entsperren ist im Kampf nicht moeglich.")
            return
        end
        DB.locked = false
        print("|cff68caffPaTiHeal:|r Fenster entsperrt. Am Rahmen ziehen.")
    elseif command == "show" then
        frame:Show()
    elseif command == "hide" then
        frame:Hide()
    elseif command == "spells" then
        local known = {}
        for _, spell in ipairs(healingSpells) do
            if isKnownSpell(spell.id) then
                known[#known + 1] = (getSpellInfo(spell.id) or spell.label) .. " (" .. spell.id .. ")"
            end
        end
        print("|cff68caffPaTiHeal:|r Bekannte Heilzauber: " .. (#known > 0 and table.concat(known, ", ") or "keine"))
    elseif command == "spell clear" then
        if InCombatLockdown() then
            print("|cff68caffPaTiHeal:|r Zauberwahl ist im Kampf nicht moeglich.")
            return
        end
        DB.clickSpellID = nil
        applyClickSpell()
        updateDisplay()
    else
        local spellID = tonumber(command:match("^spell%s+(%d+)$"))
        if spellID then
            if InCombatLockdown() then
                print("|cff68caffPaTiHeal:|r Zauberwahl ist im Kampf nicht moeglich.")
            elseif not isKnownSpell(spellID) then
                print("|cff68caffPaTiHeal:|r Dieser Zauber ist bei diesem Charakter nicht bekannt.")
            else
                DB.clickSpellID = spellID
                applyClickSpell()
                updateDisplay()
            end
        else
            print("|cff68caffPaTiHeal:|r /ph test, /ph lock, /ph unlock, /ph show, /ph hide, /ph spells, /ph spell <ID>, /ph spell clear")
        end
    end
end

print("|cff68caffPaTiHeal|r geladen. /ph test zeigt die Vorschau.")
