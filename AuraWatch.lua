-- PaTiHeal: aura watch UI. Personal buffs/procs above the frames, healing auras and dispellable debuffs on
-- each frame, group buff summary below. Shows states only; the player decides and clicks.
-- Click-to-buff uses SecureActionButtonTemplate chips whose unit and spell are set out of combat only.
local _, ns = ...
local UI, L, Auras, Spells, AuraScan = ns.UI, ns.UI.L, ns.Auras, ns.Spells, ns.AuraScan

local AuraWatch = {}
ns.AuraWatch = AuraWatch

local ROW_ICONS, ROW_ICON = 4, 14
AuraWatch.ROW_ICON_AREA = ROW_ICONS * (ROW_ICON + UI.Spacing.XS)
local CHIP, MAX_CHIPS, MAX_PROCS = 20, 3, 2
AuraWatch.STRIP_HEIGHT = CHIP + UI.Spacing.SM
local LINE_HEIGHT = 16
local TICK_SECONDS = 0.2 -- timer text refresh; only while timers are visible

-- Entries --------------------------------------------------------------------------------------

local CATEGORIES = { "personal", "procs", "healing", "group" }

local function classProfile()
    local _, classFile = UnitClass("player")
    return ns.AuraProfiles and ns.AuraProfiles[classFile]
end

local function makeEntry(def, test)
    local name = Spells.Name(def.spellID) or (test and def.nameKey and L[def.nameKey]) or (test and def.key)
    if not name then return nil end -- ID unknown to this client
    local entry = setmetatable({ name = name, icon = Spells.Icon(def.spellID), ids = Spells.FamilyIDs(def.spellID),
        names = { [name] = true } }, { __index = def })
    return entry
end

-- Methods ----------------------------------------------------------------------------------------

local Watch = {}
Watch.__index = Watch

function Watch:Settings() return self.ctx.getDB().auraWatch end

-- Recomputes which entries are shown (login, spells learned, settings changed, test mode toggled).
function Watch:Rebuild()
    local test = self.ctx.isTestMode()
    local profile = test and AuraScan.TEST_PROFILE or classProfile()
    local settings = self:Settings()
    self.profile = profile
    for _, category in ipairs(CATEGORIES) do
        local list = {}
        for _, def in ipairs(profile and profile[category] or {}) do
            local known = test or category == "procs" or Spells.IsKnown(def.spellID)
            if known and (test or Auras.IsWatched(settings, def)) then
                local entry = makeEntry(def, test)
                if entry then list[#list + 1] = entry end
            end
        end
        self.entries[category] = list
    end
    self.pending = true -- chip attributes and layout follow in Place(), out of combat
end

function Watch:HasStrip()
    return #self.entries.personal + #self.entries.procs > 0
end

function Watch:TopHeight() return self:HasStrip() and AuraWatch.STRIP_HEIGHT or 0 end

function Watch:ShowsSummary()
    return #self.entries.group > 0 and (self.ctx.isTestMode() or (IsInGroup ~= nil and IsInGroup()))
end

function Watch:BottomHeight()
    if not self:ShowsSummary() then return 0 end
    return UI.Spacing.SM + (#self.entries.group + 1) * LINE_HEIGHT
end

-- Out of combat only (called from PaTiHeal's updateLayout): positions, visibility, secure attributes.
function Watch:Place(left, top, bottom, width)
    local test = self.ctx.isTestMode()
    self.strip:ClearAllPoints()
    self.strip:SetPoint("TOPLEFT", self.ctx.window, "TOPLEFT", left, -top)
    self.strip:SetSize(width, CHIP)
    self.strip:SetShown(self:HasStrip())
    for index, chip in ipairs(self.chips) do
        local entry = self.entries.personal[index]
        local clickable = entry ~= nil and entry.clickable and not test
        chip.entry = entry
        chip:SetAttribute("unit", entry and "player" or nil)
        chip:SetAttribute("type1", clickable and "spell" or nil)
        chip:SetAttribute("spell1", clickable and Spells.CastName(entry.spellID) or nil)
        chip:SetEnabled(clickable)
        chip:SetShown(entry ~= nil)
    end
    self.summary:ClearAllPoints()
    self.summary:SetPoint("TOPLEFT", self.ctx.window, "TOPLEFT", left, -bottom - UI.Spacing.SM)
    self.summary:SetSize(width, self:BottomHeight())
    self.summary:SetShown(self:ShowsSummary())
    self.pending = false
end

local function statusText(state) return L["STATUS_" .. state] end

local function lines(...)
    local list = {}
    for index = 1, select("#", ...) do
        local line = select(index, ...)
        if line then list[#list + 1] = line end
    end
    return list
end

function Watch:Detail(entry, result, target)
    local clickLine
    if entry.clickable and not self.ctx.isTestMode() then clickLine = L.TIP_CLICK:format(entry.name) end
    return lines(entry.name,
        L.TIP_STATUS:format(statusText(result.state)),
        result.remaining and L.TIP_REMAINING:format(UI.FormatRemaining(result.remaining)) or nil,
        result.count and result.count > 0 and L.TIP_CHARGES:format(result.count) or nil,
        target and L.TIP_TARGET:format(target) or nil,
        clickLine)
end

-- Plain-table auras of a unit: real ones, or the fake test set.
function Watch:ReadUnit(unit, unitState)
    if self.ctx.isTestMode() then return AuraScan.TestAuras(unit, self.entries, GetTime()) end
    if unitState then return {}, {} end
    local dispels = self:Settings().showDispels and AuraScan.Read(unit, "HARMFUL|RAID") or {}
    return AuraScan.Read(unit, "HELPFUL"), dispels
end

local function paintIcon(frame, texture, result, text, border)
    frame.result = result
    frame.expiration = result.remaining and GetTime() + result.remaining or nil
    frame:SetAura(texture, result.state, text, border)
end

function Watch:PaintRow(row, info)
    local settings, slot = self:Settings(), 0
    local function add(texture, result, text, tooltip, border)
        if slot >= ROW_ICONS then return end
        slot = slot + 1
        local icon = self.rowIcons[row][slot]
        icon.entry, icon.tooltipLines = nil, tooltip
        paintIcon(icon, texture, result, text, border)
        icon:Show()
    end
    if info and not info.unitState then
        for _, debuff in ipairs(info.dispels) do
            if slot < 2 then
                local color = DebuffTypeColor and DebuffTypeColor[debuff.dispelType or "none"]
                add(debuff.icon, { state = "ACTIVE" }, nil, lines(debuff.name, debuff.dispelType),
                    color and { color.r, color.g, color.b })
            end
        end
        for _, entry in ipairs(self.entries.healing) do
            local result = Auras.Evaluate(entry, info.helpful, GetTime(), settings)
            if result.state == "ACTIVE" or result.state == "EXPIRING" then
                add(result.icon or entry.icon, result, Auras.IconText(entry, result, settings, UI.FormatRemaining),
                    self:Detail(entry, result, info.name))
                self.rowIcons[row][slot].entry = entry
            end
        end
    end
    for index = slot + 1, ROW_ICONS do self.rowIcons[row][index]:Hide() end
end

function Watch:PaintPersonal(info)
    local settings, now = self:Settings(), GetTime()
    local helpful = info and not info.unitState and info.helpful or {}
    for index, chip in ipairs(self.chips) do
        local entry = self.entries.personal[index]
        if entry then -- visuals only: allowed in combat
            local result = Auras.Evaluate(entry, helpful, now, settings)
            paintIcon(chip, result.icon or entry.icon, result, Auras.IconText(entry, result, settings, UI.FormatRemaining))
        end
        chip.tooltipLines = entry and self:Detail(entry, chip.result)
    end
    for index, frame in ipairs(self.procFrames) do
        local entry = self.entries.procs[index]
        local result = entry and Auras.Evaluate(entry, helpful, now, settings)
        local active = result and (result.state == "ACTIVE" or result.state == "EXPIRING")
        frame.entry = entry
        if active then
            paintIcon(frame, result.icon or entry.icon, result, Auras.IconText(entry, result, settings, UI.FormatRemaining))
            frame.tooltipLines = self:Detail(entry, result)
        end
        frame:SetShown(active == true)
    end
end

function Watch:PaintSummary()
    local settings = self:Settings()
    for index, line in ipairs(self.summaryLines) do
        local entry = self.entries.group[index]
        line:SetShown(entry ~= nil and self:ShowsSummary())
        if entry then
            local members = {}
            for _, row in ipairs(self.ctx.rows) do
                local info = self.cache[row.unit]
                if info then
                    members[#members + 1] = { name = info.name, unitState = info.unitState,
                        result = Auras.Evaluate(entry, info.helpful, GetTime(), settings) }
                end
            end
            local summary = Auras.Summarize(members)
            line.icon:SetTexture(entry.icon)
            line.name:SetText(entry.name)
            line.count:SetText(("%d / %d"):format(summary.have, summary.total))
            local incomplete = #summary.missing > 0 and settings.showMissing
            line.count:SetTextColor(UI.Color(incomplete and "Warning" or "Text"))
            line.tooltipLines = #summary.missing > 0
                and lines(entry.name, L.TIP_MISSING_ON:format(table.concat(summary.missing, ", ")))
                or lines(entry.name, L.TIP_ALL_BUFFED)
        end
    end
end

-- Event entry points (combat-safe: no secure changes here) ----------------------------------------

function Watch:RefreshUnit(unit)
    local row = self.rowsByUnit[unit]
    if not row then return end
    local data = self.ctx.getDB() and self:Settings().enabled and self.ctx.unitData(unit)
    local info
    if data then
        local helpful, dispels = self:ReadUnit(unit, data.state)
        info = { name = data.name, unitState = data.state, helpful = helpful, dispels = dispels }
    end
    self.cache[unit] = info
    self:PaintRow(row, info)
    if unit == "player" then self:PaintPersonal(info) end
    self:PaintSummary()
    self:UpdateTicker()
end

function Watch:RefreshAll()
    for _, row in ipairs(self.ctx.rows) do self:RefreshUnit(row.unit) end
end

-- Timer texts and the expiring border tick only while something with a timer is visible.
function Watch:UpdateTicker()
    local settings = self:Settings()
    local any = false
    for _, frame in ipairs(self.timerFrames) do
        if frame:IsVisible() and frame.expiration then any = true; break end
    end
    self.ticker:SetShown(any and (settings.showTimers or settings.showExpiring))
end

function Watch:Tick()
    local now, settings = GetTime(), self:Settings()
    for _, frame in ipairs(self.timerFrames) do
        if frame.expiration and frame:IsVisible() then
            local remaining = frame.expiration - now
            local entry = frame.entry
            local result = { state = frame.result and frame.result.state or "ACTIVE", remaining = remaining,
                count = frame.result and frame.result.count }
            if entry and entry.expiring and settings.showExpiring and remaining < Auras.EXPIRING_SECONDS then
                result.state = "EXPIRING"
            end
            if not (entry and entry.showCount and settings.showCharges and result.count and result.count > 0) then
                frame.auraText:SetText(settings.showTimers and remaining > 0 and UI.FormatRemaining(remaining) or "")
            end
            if result.state == "EXPIRING" then frame.auraBorder:SetColorTexture(UI.Color("Warning")) end
        end
    end
end

-- Construction ---------------------------------------------------------------------------------

local function tooltipFrom(frame) return function() return frame.tooltipLines end end

-- ctx: { window, rows, getDB(), isTestMode(), unitData(unit), relayout() }
function AuraWatch.Create(ctx)
    local watch = setmetatable({ ctx = ctx, cache = {}, rowsByUnit = {}, rowIcons = {}, timerFrames = {},
        entries = { personal = {}, procs = {}, healing = {}, group = {} }, pending = true }, Watch)

    watch.strip = CreateFrame("Frame", nil, ctx.window)
    watch.chips, watch.procFrames = {}, {}
    for index = 1, MAX_CHIPS do
        local chip = CreateFrame("Button", "PaTiHealAuraChip" .. index, watch.strip, "SecureActionButtonTemplate")
        UI.StyleAuraIcon(chip, CHIP)
        chip:RegisterForClicks("AnyUp", "AnyDown") -- same as PaTiGroup's working secure buttons
        chip:SetPoint("LEFT", (index - 1) * (CHIP + UI.Spacing.SM), 0)
        chip:Hide()
        UI.SetTooltip(chip, tooltipFrom(chip))
        watch.chips[index] = chip
        watch.timerFrames[#watch.timerFrames + 1] = chip
    end
    for index = 1, MAX_PROCS do
        local frame = CreateFrame("Frame", nil, watch.strip)
        UI.StyleAuraIcon(frame, CHIP)
        frame:SetPoint("RIGHT", -(index - 1) * (CHIP + UI.Spacing.SM), 0)
        frame:EnableMouse(true)
        frame:Hide()
        UI.SetTooltip(frame, tooltipFrom(frame))
        watch.procFrames[index] = frame
        watch.timerFrames[#watch.timerFrames + 1] = frame
    end

    for _, row in ipairs(ctx.rows) do
        watch.rowsByUnit[row.unit] = row
        watch.rowIcons[row] = {}
        for index = 1, ROW_ICONS do
            local icon = CreateFrame("Frame", nil, row)
            UI.StyleAuraIcon(icon, ROW_ICON)
            icon:SetPoint("BOTTOMRIGHT", -3 - (index - 1) * (ROW_ICON + UI.Spacing.XS), 3)
            icon:EnableMouse(true)
            icon:Hide()
            UI.SetTooltip(icon, tooltipFrom(icon))
            watch.rowIcons[row][index] = icon
            watch.timerFrames[#watch.timerFrames + 1] = icon
        end
    end

    watch.summary = CreateFrame("Frame", nil, ctx.window)
    local header = watch.summary:CreateFontString(nil, "OVERLAY", UI.Fonts.Label)
    header:SetPoint("TOPLEFT")
    header:SetTextColor(UI.Color("TextMuted"))
    UI.BindText(header, function() return string.upper(L.GROUP_BUFFS) end)
    watch.summaryLines = {}
    for index = 1, 3 do
        local line = CreateFrame("Frame", nil, watch.summary)
        line:SetSize(200, LINE_HEIGHT)
        line:SetPoint("TOPLEFT", 0, -index * LINE_HEIGHT)
        line:EnableMouse(true)
        line.icon = line:CreateTexture(nil, "ARTWORK")
        line.icon:SetSize(LINE_HEIGHT - 2, LINE_HEIGHT - 2)
        line.icon:SetPoint("LEFT")
        line.name = line:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
        line.name:SetPoint("LEFT", line.icon, "RIGHT", UI.Spacing.SM, 0)
        line.count = line:CreateFontString(nil, "OVERLAY", UI.Fonts.Text)
        line.count:SetPoint("RIGHT")
        UI.SetTooltip(line, tooltipFrom(line))
        line:Hide()
        watch.summaryLines[index] = line
    end

    watch.ticker = CreateFrame("Frame", nil, UIParent)
    watch.ticker:Hide()
    local elapsed = 0
    watch.ticker:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        if elapsed >= TICK_SECONDS then elapsed = 0; watch:Tick() end
    end)
    return watch
end

-- Settings section ------------------------------------------------------------------------------

function Watch:BuildSettings(modal)
    local changed = function() self:Rebuild(); self.ctx.relayout(); self:RefreshAll() end
    local function box(label, get, set)
        return UI.CreateCheckbox(modal, label, { get = get, set = function(value) set(value); changed() end })
    end
    local labels = { enabled = "AURA_ENABLED", showTimers = "SHOW_TIMERS", showCharges = "SHOW_CHARGES",
        showMissing = "HIGHLIGHT_MISSING", showExpiring = "HIGHLIGHT_EXPIRING", showDispels = "SHOW_DISPELS" }
    local function option(key)
        return box(labels[key], function() return self:Settings()[key] end, function(value) self:Settings()[key] = value end)
    end
    modal:AddSection("AURA_WATCH")
    modal:AddControls(option("enabled"))
    local profile = classProfile()
    local defs = {}
    for _, category in ipairs(CATEGORIES) do
        for _, def in ipairs(profile and profile[category] or {}) do defs[#defs + 1] = def end
    end
    for index = 1, #defs, 2 do
        local controls = {}
        for offset = 0, 1 do
            local def = defs[index + offset]
            if def then
                controls[offset + 1] = box(function() return Spells.Name(def.spellID) or def.key end,
                    function() return self:Settings().watch[def.key] ~= false end,
                    function(value) self:Settings().watch[def.key] = value end)
            end
        end
        modal:AddControls(controls[1], controls[2])
    end
    modal:AddLabel("AURA_DISPLAY")
    modal:AddControls(option("showTimers"), option("showCharges"))
    modal:AddControls(option("showMissing"), option("showExpiring"))
    modal:AddControls(option("showDispels"))
end

-- Diagnostics -----------------------------------------------------------------------------------

function Watch:DebugLines()
    local settings, clickable = self:Settings(), 0
    for _, entry in ipairs(self.entries.personal) do if entry.clickable then clickable = clickable + 1 end end
    return {
        ("Aura Watch: %s · profile: %s"):format(settings.enabled and "enabled" or "disabled",
            self.profile and self.profile.name or "none"),
        ("Tracked: personal %d · procs %d · healing %d · group %d · clickable %d · pending secure changes: %s"):format(
            #self.entries.personal, #self.entries.procs, #self.entries.healing, #self.entries.group, clickable,
            self.pending and "yes" or "no"),
        ("Aura API: %s · issecretvalue: %s"):format(
            AuraScan.ApiName(),
            issecretvalue and "yes" or "no"),
    }
end

-- /ph auras: what the client says about every profile spell ID (to confirm the IDs in game).
function Watch:VerifyLines()
    local result = {}
    local profile = classProfile()
    if not profile then return { "No aura profile for this class." } end
    for _, category in ipairs(CATEGORIES) do
        for _, def in ipairs(profile[category]) do
            local name = Spells.Name(def.spellID)
            local ranks = #Spells.Ranks(def.spellID)
            result[#result + 1] = ("%s %s id=%d: %s · known=%s · ranks=%d"):format(category, def.key, def.spellID,
                name or "ID NOT FOUND", tostring(name ~= nil and Spells.IsKnown(def.spellID)), ranks)
        end
    end
    return result
end
