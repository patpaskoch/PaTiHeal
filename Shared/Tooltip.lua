-- PaTiShared: one-line tooltips.
local _, ns = ...
local UI = ns.UI or {}
ns.UI = UI

-- text: L key, literal or function (see UI.Text); nil = no tooltip. Can be changed later.
function UI.SetTooltip(frame, text)
    frame.patiTooltip = text
    if frame.patiTooltipHooked then return end
    frame.patiTooltipHooked = true
    frame:HookScript("OnEnter", function(self)
        local value = UI.Text(self.patiTooltip)
        if not value or value == "" then return end
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText(value, 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    frame:HookScript("OnLeave", function(self)
        if GameTooltip:IsOwned(self) then GameTooltip:Hide() end
    end)
end
