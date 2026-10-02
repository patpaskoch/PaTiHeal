-- PaTiHeal: the heal-target row's secure visibility (owner wish 2026-10-02). The row itself is a normal fixed
-- SecureUnitButtonTemplate with unit = "target" (made in PaTiHeal.lua, same click bindings as every row).
--
-- Why a secure state handler: the row must appear and disappear when your target changes — also in combat — and the
-- player row below it must move down by one row, the window must grow. Addon code cannot show, move or resize secure
-- frames in combat. Blizzard's own way for that is a state driver: WoW evaluates the macro condition below and runs
-- the restricted snippet, which may show/hide/anchor/resize protected frames, also in combat. Nothing here decides a
-- spell or a target: the row only becomes visible for a friendly, living target you already have.
--
-- Not yet verified in the Forever client (docs/WOW_API_COMPAT.md): RegisterStateDriver and SecureHandlerStateTemplate.
-- Without them TargetFrame.Create returns nil and PaTiHeal falls back to out-of-combat updates only.
local _, ns = ...
local TargetFrame = {}
ns.TargetFrame = TargetFrame

-- "show" for a target you can assist (friendly player or NPC) that is alive; anything else "hide".
TargetFrame.CONDITION = "[@target,help,nodead] show; hide"
TargetFrame.STATE = "healtarget"

-- Restricted snippet (runs inside WoW's secure environment): mode "show"/"hide" (test mode, collapsed) wins over
-- the driver state. Geometry comes from attributes PaTiHeal sets out of combat (TargetFrame.Configure).
local SNIPPET = [[
    local mode = self:GetAttribute("mode")
    local shown = mode == "show" or (mode == "auto" and newstate == "show")
    local target, player, window = self:GetFrameRef("target"), self:GetFrameRef("player"), self:GetFrameRef("window")
    if shown then target:Show() else target:Hide() end
    player:ClearAllPoints()
    player:SetPoint("TOPLEFT", window, "TOPLEFT", self:GetAttribute("rowx"),
        shown and self:GetAttribute("playertopshifted") or self:GetAttribute("playertop"))
    window:SetHeight(self:GetAttribute(shown and "heightshifted" or "height"))
]]

-- Creates the handler (out of combat, at load). Returns it, or nil when the client lacks the secure state driver.
function TargetFrame.Create(window, targetRow, playerRow)
    if not (RegisterStateDriver and UnregisterStateDriver) then return nil end
    local ok, driver = pcall(CreateFrame, "Frame", "PaTiHealTargetDriver", window, "SecureHandlerStateTemplate")
    if not ok or not driver or not driver.SetFrameRef then return nil end
    driver:SetFrameRef("target", targetRow)
    driver:SetFrameRef("player", playerRow)
    driver:SetFrameRef("window", window)
    driver:SetAttribute("mode", "hide")
    driver:SetAttribute("_onstate-" .. TargetFrame.STATE, SNIPPET)
    return driver
end

-- Out of combat only: geometry (Logic.HealLayout) and mode. Registers the driver for "auto", unregisters it
-- otherwise. Returns true if the target row is shown now (the driver's current state for "auto").
function TargetFrame.Configure(driver, layout, mode)
    driver:SetAttribute("rowx", layout.rowX)
    driver:SetAttribute("playertop", -layout.playerTop)
    driver:SetAttribute("playertopshifted", -layout.playerTopShifted)
    driver:SetAttribute("height", layout.height)
    driver:SetAttribute("heightshifted", layout.heightShifted)
    driver:SetAttribute("mode", mode)
    if mode == "auto" then
        RegisterStateDriver(driver, TargetFrame.STATE, TargetFrame.CONDITION)
    else
        UnregisterStateDriver(driver, TargetFrame.STATE)
    end
    return mode == "show" or (mode == "auto" and driver:GetAttribute("state-" .. TargetFrame.STATE) == "show")
end
