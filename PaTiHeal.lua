-- PaTiHeal: manual party frames. A click casts exactly the spell the player assigned to that click.
local _, ns = ...
local UI, L, Logic, Spells, Dispels, HoTs, Settings = ns.UI, ns.UI.L, ns.Logic, ns.Spells, ns.Dispels, ns.HoTs, ns.Settings
local TargetFrame = ns.TargetFrame

local DB
local rows = {}
local testMode = false
local hotEntries = {} -- HoTs.Entries for your class profile (rebuilt on login, spells, settings, test mode)

-- Single-target heals offered for click casting (the names are only for reading this list; the UI shows the
-- client's names). Only spells cast on a unit belong here: ground-targeted spells such as Healing Rain do not
-- work as "click a frame → cast on that unit". Greater Heal is missing until its ID is confirmed in this client
-- (the old list used 2061, which is Flash Heal) — see PaTiAdmin/docs/WOW_API_COMPAT.md.
local HEAL_SPELLS = {
    {331, "Heilende Welle"}, {8004, "Welle der Heilung"}, {1064, "Kettenheilung"}, {61295, "Springflut"},
    {2050, "Geringes Heilen"}, {2060, "Heilen"}, {2061, "Blitzheilung"},
    {635, "Heiliges Licht"}, {19750, "Lichtblitz"}, {5185, "Heilende Berührung"}, {8936, "Nachwachsen"}, {774, "Verjüngung"},
}

local function say(key, ...)
    print("|cff68caffPaTiHeal:|r " .. L[key]:format(...))
end

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end

-- WoW API adapters (spells: SpellBook.lua, debuffs: Dispels.lua) ----------------------------------

local spellName = Spells.Name

local function knownSpells()
    local result, seen = {}, {}
    for _, entry in ipairs(HEAL_SPELLS) do
        if not seen[entry[1]] and Spells.IsKnown(entry[1]) then
            seen[entry[1]] = true
            result[#result + 1] = entry[1]
        end
    end
    -- Your class profile adds its HoTs/shields and dispels (click dispel = a normal binding with a dispel spell).
    local profile = HoTs.Profile(false)
    local extra = {}
    for _, def in ipairs(profile and profile.auras or {}) do extra[#extra + 1] = def.spellID end
    for _, dispel in ipairs(profile and profile.dispels or {}) do extra[#extra + 1] = dispel.spellID end
    for _, id in ipairs(extra) do
        if not seen[id] and Spells.IsKnown(id) then
            seen[id] = true
            result[#result + 1] = id
        end
    end
    return result
end

local TEST_UNITS = {
    player = { nameKey = "TEST_HEALER", class = "SHAMAN", health = 82, mana = 72 },
    party1 = { nameKey = "TEST_TANK", class = "WARRIOR", health = 48, mana = 20, isTank = true },
    party2 = { nameKey = "TEST_MEMBER", class = "MAGE", health = 100, mana = 90 },
    party3 = { nameKey = "TEST_MEMBER", class = "PRIEST", health = 15, mana = 60 },
    party4 = { nameKey = "TEST_MEMBER", class = "HUNTER", health = 0, mana = 0, state = "OFFLINE" },
    target = { nameKey = "TEST_TARGET", health = 68, mana = 0, level = 42 }, -- a wounded friendly NPC
}

-- One unit as a plain table: name, classFile, health, healthMax, mana, manaMax, state, isTank, level (target only).
-- Health values can be secret values: only Logic.HealthPercent (which checks) or widgets touch them.
local function unitData(unit)
    if testMode then
        local fake = TEST_UNITS[unit]
        return { name = L[fake.nameKey], classFile = fake.class, health = fake.health, healthMax = 100,
            mana = fake.mana, manaMax = 100, state = fake.state, isTank = fake.isTank,
            level = Logic.LevelText(fake.level, isSecret) }
    end
    if not UnitExists(unit) then return nil end
    -- The heal target may be an NPC: no class colour, no "offline" (an NPC is never connected like a player).
    local npc = unit == "target" and Logic.Flag(UnitIsPlayer(unit), isSecret) == false -- unreadable: treated as a player
    local _, classFile = UnitClass(unit)
    -- Secret check before every nil test / comparison: Logic.ValueOr and Logic.Flag (unreadable flag = no state).
    local data = { name = Logic.ValueOr(UnitName(unit), unit, isSecret), classFile = not npc and classFile or nil,
        health = 0, healthMax = 1, mana = 0, manaMax = 1 }
    if unit == "target" then data.level = Logic.LevelText(UnitLevel(unit), isSecret) end
    if not npc and Logic.Flag(UnitIsConnected(unit), isSecret) == false then data.state = "OFFLINE"; return data end
    if Logic.Flag(UnitIsDeadOrGhost(unit), isSecret) then data.state = "DEAD"; return data end
    data.health = Logic.ValueOr(UnitHealth(unit), 0, isSecret)
    data.healthMax = Logic.ValueOr(UnitHealthMax(unit), 1, isSecret)
    local powerType = UnitPowerType(unit)
    if not isSecret(powerType) and powerType == 0 then
        data.mana = Logic.ValueOr(UnitPower(unit, 0), 0, isSecret)
        data.manaMax = Logic.ValueOr(UnitPowerMax(unit, 0), 0, isSecret)
    end
    local role = UnitGroupRolesAssigned(unit)
    data.isTank = not isSecret(role) and role == "TANK"
    return data
end

-- Window and rows -------------------------------------------------------------------------------

local WIDTH, ROW_WIDTH, ROW_HEIGHT, ROW_GAP = 270, 242, 39, 4
-- Window geometry (Logic.HealLayout): rows keep fixed slots (player, party1–4); the heal target row sits above the
-- player row, TARGET_GAP apart, only while it is shown.
local TARGET_GAP = UI.Spacing.SM
local SIZE = { top = UI.Sizes.HeaderHeight + UI.Spacing.SM, row = ROW_HEIGHT, gap = ROW_GAP, targetGap = TARGET_GAP,
    bottom = UI.Spacing.MD, header = UI.Sizes.HeaderHeight, rowX = (WIDTH - ROW_WIDTH) / 2 }
local FULL_HEIGHT = Logic.HealLayout(SIZE, 5, false).height

local DISPEL_ICON = 13 -- fits between the health bar and the bottom edge of a row; judge the size in game
local HOT_ICON_RIGHT, HOT_ICON_BELOW = 20, 13 -- HoT icons: as tall as the health bar, or as the dispel icons
local TANK_MARK = 3 -- width of the tank stripe

local window = UI.CreateWindow("PaTiHealFrame", "PaTiHeal", WIDTH, FULL_HEIGHT)

local function setBar(bar, value, maximum)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(value)
end

local function makeRow(frameName, unit)
    local row = CreateFrame("Button", frameName, window, "SecureUnitButtonTemplate")
    row.unit = unit
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
    local status = health:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    status:SetPoint("RIGHT", -6, 0)
    local name = health:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
    name:SetPoint("LEFT", 6, 0)
    name:SetPoint("RIGHT", status, "LEFT", -UI.Spacing.SM, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    -- Tank: an accent stripe on the left edge — recognisable at a glance without extra text.
    local tankMark = row:CreateTexture(nil, "ARTWORK")
    tankMark:SetPoint("TOPLEFT")
    tankMark:SetPoint("BOTTOMLEFT")
    tankMark:SetWidth(TANK_MARK)
    tankMark:SetColorTexture(UI.Color("Accent"))
    tankMark:Hide()
    row.tankMark = tankMark
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
    -- Your HoTs/shields: plain icons (not secure); placed by layoutHoTs (right of the health bar or bottom line).
    row.hotIcons = {}
    for slot = 1, HoTs.MAX do
        local icon = UI.StyleAuraIcon(CreateFrame("Frame", nil, row), HOT_ICON_RIGHT)
        icon:EnableMouse(true)
        UI.SetTooltip(icon, function() return icon.tooltipLines end)
        icon:Hide()
        row.hotIcons[slot] = icon
    end
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
for index, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
    rows[index] = makeRow("PaTiHealUnit" .. index, unit)
    -- Party rows hang below the row above them: when the player row moves (heal target shown), they follow.
    if index > 1 then rows[index]:SetPoint("TOPLEFT", rows[index - 1], "BOTTOMLEFT", 0, -ROW_GAP) end
end

-- Heal target row (owner wish 2026-10-02): a fixed SecureUnitButtonTemplate with unit = "target" — the same click
-- bindings as every row (applyBindings), never another unit. Shown only for a friendly, living target
-- (TargetFrame.lua). A small "Target" tag and the level tell it apart from the player row below it.
local TARGET_TAG = 34
local targetRow = makeRow("PaTiHealTarget", "target")
targetRow:SetPoint("TOPLEFT", window, "TOPLEFT", SIZE.rowX, -SIZE.top)
targetRow:Hide()
targetRow.level = targetRow.health:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
targetRow.level:SetPoint("RIGHT", targetRow.status, "LEFT", -UI.Spacing.SM, 0)
targetRow.name:SetPoint("RIGHT", targetRow.level, "LEFT", -UI.Spacing.SM, 0)
local targetTag = targetRow:CreateFontString(nil, "OVERLAY", UI.Fonts.Muted)
targetTag:SetPoint("BOTTOMLEFT", 4, 2)
targetTag:SetWidth(TARGET_TAG - 4)
targetTag:SetJustifyH("LEFT")
targetTag:SetWordWrap(false)
UI.BindText(targetTag, "TARGET_TAG")
targetRow.mana:ClearAllPoints()
targetRow.mana:SetPoint("BOTTOMLEFT", TARGET_TAG, 3)
targetRow.manaInset = TARGET_TAG - 3
-- The player row hangs on the target row (its top while that is hidden): only secure rows anchor each other, so the
-- restricted snippet may move it in combat (TargetFrame.lua). updateLayout / the driver switch the anchor.
rows[1]:SetPoint("TOPLEFT", targetRow, "TOPLEFT", 0, 0)
local targetDriver = TargetFrame.Create(targetRow, rows[1]) -- nil: client without the secure state driver

-- Every row that is painted and click-cast: the heal target first, then you and the party.
local paintRows = { targetRow }
for _, row in ipairs(rows) do paintRows[#paintRows + 1] = row end

-- Name in class colour (class details stay in the unit tooltip), health in percent on the right.
local function paintRow(row, data)
    row.name:SetText(data.name)
    row.alertName = data.name -- for the optional PaTiAlerts report (may be secret: display only)
    local color = RAID_CLASS_COLORS and data.classFile and not isSecret(data.classFile) and RAID_CLASS_COLORS[data.classFile]
    if color then row.name:SetTextColor(color.r, color.g, color.b) else row.name:SetTextColor(UI.Color("Text")) end
    row.tankMark:SetShown(data.isTank == true)
    if row.level then row.level:SetText(data.level and L.TARGET_LEVEL:format(data.level) or "") end
    setBar(row.health, data.health, data.healthMax)
    setBar(row.mana, data.mana, data.manaMax)
    if data.state then
        row.status:SetText(L[data.state])
        row.health:SetStatusBarColor(UI.Color("Danger"))
    else
        row.status:SetText(Logic.HealthPercent(data.health, data.healthMax, isSecret) or data.health)
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
    row.dispelCount = #debuffs
end

local alertsError -- last error PaTiAlerts raised in Sync (diagnostics only)

-- PaTiAlerts is optional (AGENTS.md §3): report only if it is installed with API version 1, never depend on it.
local function alertsApi()
    local api = _G.PaTiAlertsAPI
    if type(api) == "table" and api.version == 1 and type(api.Sync) == "function" then return api end
    return nil
end

-- Members with a dispellable debuff (as shown on the frames). Test mode sends nothing; pcall so a problem in
-- PaTiAlerts never breaks PaTiHeal.
local function reportAlerts()
    local api = alertsApi()
    if not api then return end
    local members = {}
    if not testMode then
        for _, row in ipairs(rows) do
            members[#members + 1] = { unit = row.unit, name = row.alertName, dispels = row.dispelCount }
        end
    end
    local ok, err = pcall(api.Sync, "PaTiHeal", Logic.DispelAlerts(members, L.ALERT_DISPELLABLE, isSecret))
    if not ok then alertsError = tostring(err):sub(1, 120) end -- shown by /ph debug, PaTiHeal keeps running
end

-- HoTs & shields ------------------------------------------------------------------------------------

-- Places the HoT icons and sizes health/mana bars. Only as many slots are reserved as auras are switched on,
-- so the health bar keeps its full width without a profile. Plain (non-secure) child frames: fine in combat.
local DISPEL_SPACE = Dispels.MAX * (DISPEL_ICON + UI.Spacing.XS) + UI.Spacing.SM
local function layoutHoTs(row)
    local slots = math.min(#hotEntries, HoTs.MAX)
    local below = DB.hotPosition == "BELOW"
    local size = below and HOT_ICON_BELOW or HOT_ICON_RIGHT
    local space = slots > 0 and slots * (size + UI.Spacing.XS) + UI.Spacing.XS or 0
    row.health:SetWidth(ROW_WIDTH - 6 - (below and 0 or space))
    row.mana:SetWidth(ROW_WIDTH - 6 - DISPEL_SPACE - (below and space or 0) - (row.manaInset or 0))
    for slot, icon in ipairs(row.hotIcons) do
        icon:SetSize(size, size)
        icon:ClearAllPoints()
        local x = -3 - (slots - slot) * (size + UI.Spacing.XS)
        if below then icon:SetPoint("BOTTOMRIGHT", x - DISPEL_SPACE, 2) else icon:SetPoint("TOPRIGHT", x, -3) end
    end
end

local hotTicker = CreateFrame("Frame") -- redraws timer texts every 0.5 s, only while a timer is shown
hotTicker:Hide()

local function hotText(icon, now)
    local item = icon.item
    if icon.expires then item.remaining = math.max(0, icon.expires - now) end
    return HoTs.IconText(item, DB, UI.FormatRemaining)
end

local function paintHoTs(row, state)
    local now = GetTime()
    local shown = {}
    if not state and #hotEntries > 0 then
        local auras = testMode and HoTs.TestAuras(row.unit, hotEntries, now) or HoTs.Read(row.unit)
        shown = HoTs.Match(hotEntries, auras, now)
    end
    for slot, icon in ipairs(row.hotIcons) do
        local item = shown[slot]
        icon.item = item
        icon.expires = item and item.remaining and now + item.remaining or nil
        if item then
            icon:SetAura(item.icon or Spells.Icon(item.entry.spellID), "ACTIVE", hotText(icon, now))
            icon.tooltipLines = { item.entry.name }
            if icon.expires and DB.showHotTimers then hotTicker:Show() end
        end
        icon:SetShown(item ~= nil)
    end
end

local elapsedSinceTick = 0
hotTicker:SetScript("OnUpdate", function(self, elapsed)
    elapsedSinceTick = elapsedSinceTick + elapsed
    if elapsedSinceTick < 0.5 then return end
    elapsedSinceTick = 0
    local now, running = GetTime(), false
    for _, row in ipairs(paintRows) do
        for _, icon in ipairs(row.hotIcons) do
            if icon.item and icon.expires and icon:IsShown() then
                icon.auraText:SetText(hotText(icon, now) or "")
                running = running or icon.expires > now
            end
        end
    end
    if not running or not DB.showHotTimers or DB.collapsed then self:Hide() end
end)

-- Row contents only; visibility is handled by updateLayout / the unit watch.
local function refresh()
    if not DB then return end
    -- Collapsed: nothing to paint, unless PaTiAlerts shows the dispel state instead (rows stay hidden).
    if DB.collapsed and not alertsApi() then return end
    for _, row in ipairs(paintRows) do
        local data = unitData(row.unit)
        if data then paintRow(row, data); paintDispels(row, data.state); paintHoTs(row, data.state)
        else row.dispelCount = 0 end
    end
    reportAlerts()
end

-- Profile entries changed (login, spells learned, settings, test mode): rebuild and re-place; callers repaint.
local function rebuildHoTs()
    if not DB then return end
    hotEntries = HoTs.Entries(HoTs.Profile(testMode), DB, Spells.Name)
    for _, row in ipairs(paintRows) do layoutHoTs(row) end
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
    -- Only as tall as the members that are there (solo: just you). Out of combat only, like the rows: a member
    -- joining in combat appears (RegisterUnitWatch) and the window grows after combat (PLAYER_REGEN_ENABLED).
    local present = {}
    for index, row in ipairs(rows) do present[index] = testMode or Logic.Flag(UnitExists(row.unit), isSecret) end
    local layout = Logic.HealLayout(SIZE, Logic.RowCount(present, #rows), DB.collapsed)
    -- Heal target: the secure driver decides in combat (rows only); here (out of combat) the same result is applied
    -- directly, plus the window height — the snippet cannot resize the plain window (owner-observed 2026-10-03).
    local mode = Logic.TargetMode(testMode, DB.collapsed)
    if targetDriver then TargetFrame.Configure(targetDriver, TARGET_GAP, mode) end
    local shown = TargetFrame.Shown(mode, isSecret, Logic.Flag)
    targetRow:SetShown(shown)
    rows[1]:ClearAllPoints()
    if shown then
        rows[1]:SetPoint("TOPLEFT", targetRow, "BOTTOMLEFT", 0, -TARGET_GAP)
    else
        rows[1]:SetPoint("TOPLEFT", targetRow, "TOPLEFT", 0, 0)
    end
    window:SetHeight(shown and layout.heightShifted or layout.height)
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
    for _, row in ipairs(paintRows) do
        for _, attribute in ipairs(attributes) do row:SetAttribute(attribute.name, attribute.value) end
        row:SetEnabled(not testMode and anyBinding)
    end
end

-- The window holds secure rows: SetScale only out of combat, otherwise after PLAYER_REGEN_ENABLED.
local scalePending = false
local function applyScale()
    if not DB then return end
    if InCombatLockdown() then scalePending = true; return end
    scalePending = false
    window:SetScale(DB.scale)
end

-- Settings modal: Settings.lua ---------------------------------------------------------------

Settings.Init({ db = function() return DB end, window = window, applyBindings = applyBindings, refresh = refresh,
    knownSpells = knownSpells, say = say, hotsChanged = function() rebuildHoTs(); refresh() end, applyScale = applyScale })
local openSettings = Settings.Open

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
    rebuildHoTs()
    refresh()
end

local function toggleCollapsed()
    if combatBlocked() then return end
    DB.collapsed = not DB.collapsed
    updateLayout()
    refresh()
end

local function setShown(shown, quiet)
    if InCombatLockdown() then -- secure rows: the window cannot be shown/hidden in combat
        if not quiet then say("COMBAT_LOCKED") end
        return false
    end
    window:SetShown(shown)
    if not shown and not quiet then say("HIDDEN_HINT") end
    return true
end

-- Optional PaTiSuite control panel: the same rules as the commands, without chat lines (false = not possible now).
window.suiteSetShown = function(shown) return setShown(shown, true) end

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

-- The window holds secure rows: moving it is combat-locked like hide/collapse.
local function resetPosition()
    if combatBlocked() then return end
    DB.point, DB.relativePoint, DB.x, DB.y = nil, nil, nil, nil
    window:Attach(DB, 330, 0)
end

local function addonVersion()
    local getMetadata = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
    return getMetadata and getMetadata("PaTiHeal", "Version") or "?"
end

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
    local version, build, _, interface = GetBuildInfo()
    print(("  WoW %s (build %s, interface %s) · locale %s · combat %s · aura API %s"):format(tostring(version),
        tostring(build), tostring(interface), GetLocale(), InCombatLockdown() and "yes" or "no",
        (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) and "C_UnitAuras" or (UnitAura and "UnitAura" or "none")))
    print(("  last caught errors: HoTs %s · dispels %s · PaTiAlerts %s"):format(HoTs.lastError or "none",
        Dispels.lastError or "none", alertsError or "none"))
    -- Heal target: is the secure state driver there (else out-of-combat fallback), and what does it say now?
    print(("  heal target: RegisterStateDriver %s · driver %s · state %s · mode %s · row shown %s"):format(
        RegisterStateDriver and "yes" or "no", targetDriver and "yes" or "no (fallback)",
        tostring(targetDriver and targetDriver:GetAttribute("state-" .. TargetFrame.STATE)),
        tostring(targetDriver and targetDriver:GetAttribute("mode")), tostring(targetRow:IsShown())))
    local row = rows[1]
    for _, binding in ipairs(Logic.BINDINGS) do
        local prefix = binding.modifier
        print(("  %s: id=%s rank=%s type=%s spell=%s"):format(binding.key, tostring(DB.bindings[binding.key]),
            tostring(DB.bindingRanks[binding.key] or "highest"),
            tostring(row:GetAttribute(prefix .. "type" .. binding.button)),
            tostring(row:GetAttribute(prefix .. "spell" .. binding.button))))
    end
end

-- /ph auras: what this client reports for the profile's spell IDs (to confirm them in game).
local function printAuraCheck()
    local profile = HoTs.Profile(false)
    print(("|cff68caffPaTiHeal Auras:|r profile %s · aura API %s · issecretvalue %s"):format(
        profile and profile.name or "none", (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) and "C_UnitAuras"
        or (UnitAura and "UnitAura" or "none"), issecretvalue and "yes" or "no"))
    local function describe(label, id, extra)
        local name = spellName(id)
        print(("  %s id=%d: %s · known=%s%s"):format(label, id, name or "ID NOT FOUND",
            tostring(name ~= nil and Spells.IsKnown(id)), extra or ""))
    end
    for _, def in ipairs(profile and profile.auras or {}) do describe("HoT/shield " .. def.key, def.spellID) end
    for _, dispel in ipairs(profile and profile.dispels or {}) do
        describe("dispel", dispel.spellID, " · removes " .. table.concat(dispel.types, ", "))
    end
end

local COMMANDS = {
    [""] = function() setShown(not window:IsShown()) end,
    settings = openSettings,
    test = toggleTestMode,
    show = function() setShown(true) end,
    hide = function() setShown(false) end,
    lock = function() window:SetLocked(true) end,
    unlock = function() window:SetLocked(false) end,
    spells = printSpells,
    auras = printAuraCheck,
    reset = resetPosition,
    version = function() say("VERSION", addonVersion()) end,
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
    "UNIT_CONNECTION", "UNIT_FLAGS", "UNIT_AURA", "PLAYER_REGEN_ENABLED", "SPELLS_CHANGED", "PLAYER_TARGET_CHANGED" }) do
    events:RegisterEvent(event)
end
local rowByUnit = {}
for _, row in ipairs(paintRows) do rowByUnit[row.unit] = row end

events:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        PaTiHealDB = Logic.Migrate(PaTiHealDB)
        DB = PaTiHealDB
        UI.SetLanguage(DB.language)
        window:Attach(DB, 330, 0)
        applyScale() -- /reload in combat: after combat
        Spells.Rescan()
        updateLayout()
        applyBindings()
        rebuildHoTs()
    elseif not DB then
        return
    elseif event == "UNIT_AURA" or event == "UNIT_HEALTH" or event == "UNIT_POWER_UPDATE"
        or event == "UNIT_CONNECTION" or event == "UNIT_FLAGS" then
        -- Unit events repaint only that unit's frame (you, party, heal target; nameplates and raid units are ignored).
        local row = rowByUnit[unit]
        if row and (not DB.collapsed or alertsApi()) and not testMode then
            local data = unitData(unit)
            if data and event ~= "UNIT_AURA" then paintRow(row, data) end
            -- Debuffs and HoTs only change with auras or the offline/dead state: no aura scan on the
            -- health/power hot path (FOLLOW_UPS F20).
            if event ~= "UNIT_HEALTH" and event ~= "UNIT_POWER_UPDATE" then
                paintDispels(row, data and data.state)
                paintHoTs(row, data and data.state)
                if row ~= targetRow then reportAlerts() end -- the heal target never sends PaTiAlerts alerts
            end
        end
        return
    elseif event == "PLAYER_TARGET_CHANGED" then
        -- Painting is plain (fine in combat); showing/moving is the secure driver's job. Without a driver: out of combat.
        updateLayout() -- out of combat: target row, anchors and window height (returns at once in combat)
        local data = not testMode and unitData("target")
        if data and not DB.collapsed then
            paintRow(targetRow, data)
            paintDispels(targetRow, data.state)
            paintHoTs(targetRow, data.state)
        end
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        if scalePending then applyScale() end
        updateLayout()
        applyBindings()
    elseif event == "GROUP_ROSTER_UPDATE" then
        updateLayout()
    elseif event == "SPELLS_CHANGED" then
        Spells.Rescan() -- new ranks become selectable
        applyBindings()
        rebuildHoTs() -- a newly learned HoT/shield appears
    end
    refresh()
end)
UI.OnLanguageChanged(refresh)

say("LOADED")
