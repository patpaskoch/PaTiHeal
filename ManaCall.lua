-- PaTiHeal: the "Mana" button in the header (owner 2026-10-14). One click sends one line to your group ("Mana 23% –
-- I need to drink soon"); below a threshold you choose, the button lights up as a reminder. It never sends by itself
-- (AGENTS.md §8: one click = one action). A plain button (no secure template): SendChatMessage runs in its click, a
-- hardware event, like PaTiSocial. Named PaTiHealManaButton so a macro "/click PaTiHealManaButton" can bind it to a key.
local _, ns = ...
local UI, L, Logic = ns.UI, ns.UI.L, ns.Logic

local ManaCall = {}
ns.ManaCall = ManaCall

local TEST_MANA = 25 -- test mode: low enough to show the lit button
local app, button, lastSent

local function isSecret(value) return issecretvalue ~= nil and issecretvalue(value) == true end
local function flag(value) return not isSecret(value) and (value == true or value == 1) end

-- Your mana in percent, nil when unreadable or you have no mana. Power type 0 = mana (also read in druid forms).
local function manaPercent()
    if app.testMode() then return TEST_MANA end
    return Logic.ManaPercent(UnitPower("player", 0), UnitPowerMax("player", 0), isSecret)
end

local function hasMana()
    if app.testMode() then return true end
    local maximum = UnitPowerMax("player", 0)
    return isSecret(maximum) or (type(maximum) == "number" and maximum > 0) -- unreadable: keep the button
end

local function message(percent)
    if percent then return L.MANA_CALL_TEXT:format(percent) end
    return L.MANA_CALL_TEXT_LOW
end

-- Exactly one chat line per click; nothing alone, nothing twice within the cooldown, test mode only prints.
local function send()
    local db = app.db()
    if not db then return end
    local text = message(manaPercent())
    if app.testMode() then app.say("MANA_CALL_TEST", text); return end
    local channel = Logic.ManaChannel({ inGroup = IsInGroup ~= nil and flag(IsInGroup()),
        inRaid = IsInRaid ~= nil and flag(IsInRaid()) })
    if not channel then app.say("MANA_CALL_NO_GROUP"); return end
    if not Logic.ManaCallReady(GetTime(), lastSent) then return end
    if not SendChatMessage then return end
    local ok, err = pcall(SendChatMessage, text, channel)
    if ok then lastSent = GetTime() else app.say("MANA_CALL_FAILED", tostring(err)) end
end

-- callbacks = { db = function() return PaTiHealDB end, testMode = function() return testMode end, say, window }
function ManaCall.Init(callbacks)
    app = callbacks
    local header = app.window.header
    button = UI.StyleButton(CreateFrame("Button", "PaTiHealManaButton", header, "BackdropTemplate"), "MANA_BUTTON")
    button:SetHeight(UI.Sizes.HeaderHeight - 2 * UI.Spacing.XS)
    button:SetPoint("RIGHT", app.window.menuButton, "LEFT", -UI.Spacing.XS, 0)
    button:RegisterForClicks("LeftButtonUp")
    button:SetScript("OnClick", send)
    -- Lit state: a warning tint over the button background, below the label (StyleButton paints only the backdrop).
    button.low = button:CreateTexture(nil, "ARTWORK")
    button.low:SetPoint("TOPLEFT", UI.Sizes.Border, -UI.Sizes.Border)
    button.low:SetPoint("BOTTOMRIGHT", -UI.Sizes.Border, UI.Sizes.Border)
    UI.Paint(button.low, "SetColorTexture", "Warning", 0.35)
    button.low:Hide()
    UI.SetTooltip(button, function()
        local lines, percent = { L.MANA_BUTTON_TIP }, manaPercent()
        if percent then lines[#lines + 1] = L.MANA_BUTTON_NOW:format(percent) end
        lines[#lines + 1] = L.MANA_BUTTON_MACRO
        return lines
    end)
    button:Hide()
end

-- Shows/hides the button and lights it below the threshold. Cheap: called on your own power changes and refresh.
function ManaCall.Update()
    local db = app and app.db()
    if not button or not db then return end
    local shown = db.showManaButton and hasMana()
    button:SetShown(shown)
    button.low:SetShown(shown and Logic.ManaLow(manaPercent(), db.manaWarn))
end

-- /ph debug
function ManaCall.Describe()
    return ("mana call: button %s · percent %s · warn below %s · last sent %s"):format(
        tostring(button and button:IsShown()), tostring(app and manaPercent()),
        tostring(app and app.db() and app.db().manaWarn), tostring(lastSent))
end
