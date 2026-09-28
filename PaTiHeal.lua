-- PaTiHeal: manual group frames and an explicitly chosen click spell.
local DB
local rows = {}
local testMode = false
local settingsOpen = false
local collapsed = false

local spells = {
    {331, "Heilende Welle"}, {8004, "Welle der Heilung"}, {1064, "Kettenheilung"}, {61295, "Springflut"}, {73920, "Heilender Regen"},
    {2050, "Geringes Heilen"}, {2060, "Heilen"}, {2061, "Blitzheilung"}, {2061, "Große Heilung"},
    {635, "Heiliges Licht"}, {19750, "Lichtblitz"}, {5185, "Heilende Berührung"}, {8936, "Nachwachsen"}, {774, "Verjüngung"},
}

local function isKnownSpell(id)
    if C_SpellBook and C_SpellBook.IsSpellKnown then
        local ok, known = pcall(C_SpellBook.IsSpellKnown, id)
        return ok and known
    end
    return C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(id) ~= nil
end

local function spellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = C_Spell.GetSpellInfo(id)
        return info and info.name
    end
    return GetSpellInfo and GetSpellInfo(id)
end

local function knownSpells()
    local result, seen = {}, {}
    for _, entry in ipairs(spells) do
        if not seen[entry[1]] and isKnownSpell(entry[1]) then
            seen[entry[1]] = true
            result[#result + 1] = entry[1]
        end
    end
    return result
end

local function setBar(bar, value, maximum)
    bar:SetMinMaxValues(0, maximum)
    bar:SetValue(value)
end

local frame = CreateFrame("Frame", "PaTiHealFrame", UIParent, "BackdropTemplate")
frame:SetSize(270, 350)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetClampedToScreen(true)
frame:SetBackdrop({bgFile="Interface\\DialogFrame\\UI-DialogBox-Background", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=14, insets={left=3,right=3,top=3,bottom=3}})
frame:SetBackdropColor(0.12, 0.10, 0.08, 0.95)
frame:SetBackdropBorderColor(0.65, 0.58, 0.42, 1)

local title=frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
title:SetPoint("TOPLEFT",14,-11)
title:SetText("PaTiHeal")

local close=CreateFrame("Button",nil,frame,"UIPanelCloseButton")
close:SetSize(24,24)
close:SetPoint("TOPRIGHT",-2,-2)
close:SetScript("OnClick",function() frame:Hide() end)

local gear=CreateFrame("Button",nil,frame)
gear:SetSize(24,24)
gear:SetPoint("RIGHT",close,"LEFT",-3,0)
local gearIcon=gear:CreateTexture(nil,"ARTWORK")
gearIcon:SetAllPoints()
gearIcon:SetTexture("Interface\\Buttons\\UI-OptionsButton")
local gearActive=gear:CreateTexture(nil,"BACKGROUND")
gearActive:SetAllPoints()
gearActive:SetColorTexture(0.22,0.25,0.30,0.98)
gearActive:Hide()
gear:SetScript("OnEnter",function(self) GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetText("Klickzauber einstellen"); GameTooltip:Show() end)
gear:SetScript("OnLeave",function() GameTooltip:Hide() end)

local chevron=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
chevron:SetSize(24,24)
chevron:SetPoint("RIGHT",gear,"LEFT",-3,0)
chevron:SetText("⌄")

local settings=CreateFrame("Frame",nil,frame,"BackdropTemplate")
settings:SetPoint("TOPLEFT",10,-38)
settings:SetSize(250,58)
settings:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8", edgeFile="Interface\\Tooltips\\UI-Tooltip-Border", edgeSize=10, insets={left=2,right=2,top=2,bottom=2}})
settings:SetBackdropColor(0.12,0.14,0.17,0.98)
settings:SetBackdropBorderColor(0.42,0.46,0.52,1)
settings:Hide()
local clickHeader=settings:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
clickHeader:SetPoint("TOPLEFT",10,-9)
clickHeader:SetText("Klick")
local actionHeader=settings:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
actionHeader:SetPoint("TOPLEFT",106,-9)
actionHeader:SetText("Aktion")
local clickValue=settings:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
clickValue:SetPoint("TOPLEFT",10,-31)
clickValue:SetText("Linksklick")
local spellButton=CreateFrame("Button",nil,settings,"UIPanelButtonTemplate")
spellButton:SetSize(136,21)
spellButton:SetPoint("TOPRIGHT",-8,-27)

local testLabel=frame:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
testLabel:SetPoint("BOTTOMRIGHT",-14,12)
testLabel:SetTextColor(1,0.82,0)
testLabel:SetText("TESTMODUS – keine Zauber")
testLabel:Hide()

local function makeRow(index, unit)
    local row=CreateFrame("Button","PaTiHealUnit"..index,frame,"SecureActionButtonTemplate")
    row:SetSize(242,39)
    row:RegisterForClicks("LeftButtonUp")
    row:SetAttribute("unit",unit)
    row:SetAttribute("type1","spell")
    local background=row:CreateTexture(nil,"BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.12,0.15,0.18,0.95)
    local health=CreateFrame("StatusBar",nil,row)
    health:SetPoint("TOPLEFT",3,-3)
    health:SetSize(236,20)
    health:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    health:SetStatusBarColor(0.18,0.64,0.30,1)
    local name=health:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    name:SetPoint("LEFT",6,0)
    name:SetWidth(155)
    name:SetJustifyH("LEFT")
    name:SetTextColor(1,1,1)
    local status=health:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
    status:SetPoint("RIGHT",-6,0)
    local mana=CreateFrame("StatusBar",nil,row)
    mana:SetPoint("BOTTOMLEFT",3,3)
    mana:SetSize(236,10)
    mana:SetStatusBarTexture("Interface\\Buttons\\WHITE8X8")
    mana:SetStatusBarColor(0.16,0.42,0.9,1)
    row.health,row.mana,row.name,row.status=health,mana,name,status
    row:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square","ADD")
    row:SetScript("OnEnter",function(self) if not testMode and UnitExists(unit) then GameTooltip:SetOwner(self,"ANCHOR_RIGHT"); GameTooltip:SetUnit(unit); GameTooltip:Show() end end)
    row:SetScript("OnLeave",function() GameTooltip:Hide() end)
    return row
end
for index,unit in ipairs({"player","party1","party2","party3","party4"}) do rows[#rows+1]=makeRow(index,unit) end

local function updateLayout()
    if InCombatLockdown() then return end
    local hideRows = settingsOpen or collapsed
    settings:SetShown(settingsOpen)
    gearActive:SetShown(settingsOpen)
    chevron:SetText(collapsed and "›" or "⌄")
    if settingsOpen then frame:SetSize(270,112) elseif collapsed then frame:SetSize(270,36) else frame:SetSize(270,350) end
    for index,row in ipairs(rows) do
        if hideRows then row:Hide() else row:ClearAllPoints(); row:SetPoint("TOPLEFT",frame,"TOPLEFT",14,-55-((index-1)*43)); row:Show() end
    end
    testLabel:SetShown(testMode and not hideRows)
end

local function applyClickSpell()
    if InCombatLockdown() then return end
    local id=DB.clickSpellID
    if not (id and isKnownSpell(id)) then id=nil; DB.clickSpellID=nil end
    local castSpell=id and spellName(id)
    for _,row in ipairs(rows) do row:SetAttribute("spell",castSpell); row:SetAttribute("spell1",castSpell); row:SetAttribute("type","spell"); row:SetAttribute("type1","spell"); row:SetEnabled(not testMode and castSpell~=nil) end
    spellButton:SetText(castSpell or "Zauber auswaehlen")
end

local function selectNextSpell()
    if InCombatLockdown() then print("|cff68caffPaTiHeal:|r Zauberwahl ist im Kampf nicht moeglich."); return end
    local list=knownSpells()
    if #list==0 then print("|cff68caffPaTiHeal:|r Keine bekannten Heilzauber gefunden."); return end
    local nextID=list[1]
    for index,id in ipairs(list) do if id==DB.clickSpellID then nextID=list[index+1] or list[1]; break end end
    DB.clickSpellID=nextID
    applyClickSpell()
end
spellButton:SetScript("OnClick",selectNextSpell)
gear:SetScript("OnClick",function()
    if InCombatLockdown() then print("|cff68caffPaTiHeal:|r Einstellungen sind im Kampf gesperrt."); return end
    settingsOpen=not settingsOpen
    updateLayout()
end)

chevron:SetScript("OnClick",function()
    if InCombatLockdown() then print("|cff68caffPaTiHeal:|r Ein- und Ausklappen ist im Kampf gesperrt."); return end
    settingsOpen=false
    collapsed=not collapsed
    DB.collapsed=collapsed
    updateLayout()
end)

local function unitData(unit)
    if testMode then
        local t={player={"Du","Priester",82,100,72,100},party1={"Tank","Krieger",48,100,20,100},party2={"Gruppe 2","Magier",100,100,90,100},party3={"Gruppe 3","Priester",15,100,60,100},party4={"Offline","Jäger",0,100,0,100,"OFFLINE"}}
        return unpack(t[unit])
    end
    if not UnitExists(unit) then return nil end
    local name=UnitName(unit) or unit
    local class=UnitClass(unit) or "Unbekannt"
    if not UnitIsConnected(unit) then return name,class,0,1,0,1,"OFFLINE" end
    if UnitIsDeadOrGhost(unit) then return name,class,0,1,0,1,"TOT" end
    local mana,manaMax=0,0
    if UnitPowerType(unit)==0 then mana,manaMax=UnitPower(unit,0) or 0,UnitPowerMax(unit,0) or 0 end
    return name,class,UnitHealth(unit) or 0,UnitHealthMax(unit) or 1,mana,manaMax
end
local function refresh()
    if settingsOpen or collapsed then
        for _,row in ipairs(rows) do row:Hide() end
        testLabel:Hide()
        return
    end
    for _,row in ipairs(rows) do
        local name,class,h,hmax,m,mmax,state=unitData(row:GetAttribute("unit"))
        if not name then row:Hide() else
            row:Show(); if row:GetAttribute("unit")=="player" then name=name.." (Du)" elseif not testMode and UnitGroupRolesAssigned(row:GetAttribute("unit"))=="TANK" then name=name.." (Tank)" end
            row.name:SetText(name.." – "..class)
            setBar(row.health,h,hmax); setBar(row.mana,m,mmax)
            if state then row.status:SetText(state); row.health:SetStatusBarColor(0.45,0.12,0.12,1) else row.status:SetText(h); row.health:SetStatusBarColor(0.18,0.64,0.30,1) end
        end
    end
    testLabel:SetShown(testMode)
end

frame:SetScript("OnDragStart",function(self) if not DB.locked and not InCombatLockdown() then self:StartMoving() end end)
frame:SetScript("OnDragStop",function(self) self:StopMovingOrSizing(); local _,_,_,x,y=self:GetPoint(); DB.x=x; DB.y=y end)
local events=CreateFrame("Frame")
for _,event in ipairs({"PLAYER_LOGIN","PLAYER_ENTERING_WORLD","GROUP_ROSTER_UPDATE","UNIT_HEALTH","UNIT_POWER_UPDATE","UNIT_CONNECTION","UNIT_FLAGS","PLAYER_REGEN_ENABLED","SPELLS_CHANGED"}) do events:RegisterEvent(event) end
events:SetScript("OnEvent",function(_,event)
    if event=="PLAYER_LOGIN" then PaTiHealDB=PaTiHealDB or {}; DB=PaTiHealDB; DB.x=DB.x or 330; DB.y=DB.y or 0; DB.locked=DB.locked or false; collapsed=DB.collapsed or false; frame:ClearAllPoints(); frame:SetPoint("CENTER",UIParent,"CENTER",DB.x,DB.y); updateLayout(); applyClickSpell()
    elseif event=="PLAYER_REGEN_ENABLED" or event=="SPELLS_CHANGED" then applyClickSpell() end
    refresh()
end)
SLASH_PATIHEAL1="/patiheal"; SLASH_PATIHEAL2="/ph"
SlashCmdList.PATIHEAL=function(message)
    local command=(message or ""):match("^%s*(.-)%s*$"):lower()
    if command=="test" then if InCombatLockdown() then print("|cff68caffPaTiHeal:|r Testmodus ist im Kampf gesperrt.") else testMode=not testMode; applyClickSpell(); refresh() end
    elseif command=="show" then frame:Show()
    elseif command=="hide" then frame:Hide()
    elseif command=="lock" then DB.locked=true
    elseif command=="unlock" then DB.locked=false
    elseif command=="spells" then local list=knownSpells(); local names={}; for _,id in ipairs(list) do names[#names+1]=(spellName(id) or id).." ("..id..")" end; print("|cff68caffPaTiHeal:|r "..(#names>0 and table.concat(names,", ") or "Keine bekannten Heilzauber."))
    else print("|cff68caffPaTiHeal:|r /ph test, show, hide, lock, unlock, spells") end
end
print("|cff68caffPaTiHeal|r geladen. Zahnrad oeffnet die Klickzauber-Einstellungen.")
