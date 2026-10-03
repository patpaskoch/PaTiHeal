-- PaTiHeal: the heal-target row's secure visibility (owner wish 2026-10-02). The row itself is a normal fixed
-- SecureUnitButtonTemplate with unit = "target" (made in PaTiHeal.lua, same click bindings as every row).
--
-- Why a secure state handler: the row must appear and disappear when your target changes — also in combat — and the
-- player row below it (party rows hang below the player row) must move down by one row. Addon code cannot show or
-- move secure frames in combat. Blizzard's own way for that is a state driver: WoW evaluates the macro condition below
-- and runs the restricted snippet, which may show/hide and anchor protected frames, also in combat. Nothing here
-- decides a spell or a target: the row only becomes visible for a friendly, living target you already have.
--
-- Owner-observed 2026-10-03 (Forever client): the first version anchored the player row to the PaTiHeal window and
-- resized it from the snippet → "RestrictedFrames.lua:478: Invalid relative frame handle" (the window is a plain
-- frame, not a protected one). Now the snippet only touches the two secure rows: the player row is anchored to the
-- target row (its top while hidden, below it while shown). The window height follows out of combat (PaTiHeal.lua).
local _, ns = ...
local TargetFrame = {}
ns.TargetFrame = TargetFrame

-- "show" for a target you can assist (friendly player or NPC) that is alive; anything else "hide".
TargetFrame.CONDITION = "[@target,help,nodead] show; hide"
TargetFrame.STATE = "healtarget"

-- Restricted snippet: mode "show"/"hide" (test mode, collapsed) wins over the driver state. Only the target row and
-- the player row are touched — both are secure buttons, valid frame handles in the restricted environment.
local SNIPPET = [[
    local mode = self:GetAttribute("mode")
    local shown = mode == "show" or (mode == "auto" and newstate == "show")
    local target, player = self:GetFrameRef("target"), self:GetFrameRef("player")
    if shown then target:Show() else target:Hide() end
    player:ClearAllPoints()
    if shown then
        player:SetPoint("TOPLEFT", target, "BOTTOMLEFT", 0, -self:GetAttribute("gap"))
    else
        player:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    end
]]

-- Creates the handler (out of combat, at load). Returns it, or nil when the client lacks the secure state driver.
function TargetFrame.Create(targetRow, playerRow)
    if not (RegisterStateDriver and UnregisterStateDriver) then return nil end
    local ok, driver = pcall(CreateFrame, "Frame", "PaTiHealTargetDriver", UIParent, "SecureHandlerStateTemplate")
    if not ok or not driver or not driver.SetFrameRef then return nil end
    driver:SetFrameRef("target", targetRow)
    driver:SetFrameRef("player", playerRow)
    driver:SetAttribute("mode", "hide")
    driver:SetAttribute("_onstate-" .. TargetFrame.STATE, SNIPPET)
    return driver
end

-- Out of combat only: the gap and the mode. Registers the driver for "auto", unregisters it otherwise.
function TargetFrame.Configure(driver, gap, mode)
    driver:SetAttribute("gap", gap)
    driver:SetAttribute("mode", mode)
    if mode == "auto" then
        RegisterStateDriver(driver, TargetFrame.STATE, TargetFrame.CONDITION)
    else
        UnregisterStateDriver(driver, TargetFrame.STATE)
    end
end

-- Out of combat: would the row be shown now? The same macro condition as the driver (SecureCmdOptionParse), so the
-- Lua layout and the snippet always agree; without that API the readable unit flags decide.
function TargetFrame.Shown(mode, isSecret, Flag)
    if mode ~= "auto" then return mode == "show" end
    if SecureCmdOptionParse then return SecureCmdOptionParse(TargetFrame.CONDITION) == "show" end
    return Flag(UnitExists("target"), isSecret) == true and Flag(UnitCanAssist("player", "target"), isSecret) == true
        and Flag(UnitIsDead("target"), isSecret) == false
end
