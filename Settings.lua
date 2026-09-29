-- PaTiHeal: settings modal (built on first open, when the DB exists). Moved out of PaTiHeal.lua (FOLLOW_UPS F13).
-- PaTiHeal.lua hands over what the modal needs via Settings.Init; nothing here runs before the first open.
local _, ns = ...
local UI, L, Logic, Spells, HoTs = ns.UI, ns.UI.L, ns.Logic, ns.Spells, ns.HoTs

local Settings = {}
ns.Settings = Settings

local DB, window, applyBindings, refresh, knownSpells, say, hotsChanged, applyScale
local spellName, spellIcon = Spells.Name, Spells.Icon

-- app = { db = function() return PaTiHealDB end, window, applyBindings, refresh, knownSpells, say, hotsChanged }
local app
function Settings.Init(callbacks) app = callbacks end

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
    -- Click dispel is an ordinary binding: the dispel spells are in the spell list, no combination is preset.
    modal:AddNote("CLICK_DISPEL_TITLE", nil, "CLICK_DISPEL_TEXT", 2)

    -- HoTs & shields of your class profile (names from the client; unknown IDs are simply not listed).
    modal:AddSection("HOTS_SHIELDS")
    local profile, boxes = HoTs.Profile(false), {}
    for _, def in ipairs(profile and profile.auras or {}) do
        local name = Spells.Name(def.spellID)
        if name then
            boxes[#boxes + 1] = UI.CreateCheckbox(modal, function() return name end, {
                get = function() return DB.hots[def.key] ~= false end,
                set = function(value) DB.hots[def.key] = value; hotsChanged() end,
            })
        end
    end
    if #boxes == 0 then modal:AddLabel("NO_HEAL_PROFILE") end
    for index = 1, #boxes, 2 do modal:AddControls(boxes[index], boxes[index + 1]) end
    local function hotBox(label, key)
        return UI.CreateCheckbox(modal, label, {
            get = function() return DB[key] end,
            set = function(value) DB[key] = value; hotsChanged() end,
        })
    end
    modal:AddControls(hotBox("SHOW_HOT_TIMERS", "showHotTimers"), hotBox("SHOW_HOT_CHARGES", "showHotCharges"))
    local positions = {}
    for _, position in ipairs(HoTs.POSITIONS) do positions[#positions + 1] = { value = position, text = "HOT_POSITION_" .. position } end
    modal:AddRow("HOT_POSITION", UI.CreateDropdown(modal, 200, {
        items = function() return positions end,
        get = function() return DB.hotPosition end,
        set = function(position) DB.hotPosition = position; hotsChanged() end,
    }))

    modal:AddSection("GENERAL")
    modal:AddRow("LANGUAGE", UI.CreateLanguageDropdown(modal, DB, 200))
    local scales = {}
    for _, scale in ipairs(Logic.SCALES) do
        scales[#scales + 1] = { value = scale, text = function() return ("%d %%"):format(scale * 100 + 0.5) end }
    end
    modal:AddRow("SCALE", UI.CreateDropdown(modal, 200, {
        items = function() return scales end,
        get = function() return DB.scale end,
        set = function(scale)
            DB.scale = scale
            if InCombatLockdown() then say("SCALE_AFTER_COMBAT") end
            applyScale()
        end,
    }))
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
        applyScale()
        applyBindings()
        hotsChanged()
    end)
end

function Settings.Open()
    DB = app.db()
    if not DB then return end
    window, applyBindings, refresh, knownSpells, say = app.window, app.applyBindings, app.refresh, app.knownSpells, app.say
    hotsChanged, applyScale = app.hotsChanged, app.applyScale
    if not modal then buildSettings() end
    modal:Show()
end
