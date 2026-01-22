-- GiveMeHeals Add-on
-- Click-cast healing for Restoration Shamans

local ADDON, ns = ...

-- Saved variables (defaults set in PLAYER_LOGIN after loading)
GiveMeHealsDB = GiveMeHealsDB or {}

-- Forward declarations
local UpdateTooltipAnchorVisibility

-------------------------------------------------
-- Spell Bindings
-------------------------------------------------
local BINDINGS = {
    { mouse = "Left Click",       modifier = "",      spell = "Riptide" },
    { mouse = "Left Click",       modifier = "Shift", spell = "Healing Wave" },
    { mouse = "Left Click",       modifier = "Ctrl",  spell = "Healing Surge" },
    { mouse = "Left Click",       modifier = "Alt",   spell = "Chain Heal" },
    { mouse = "Right Click",      modifier = "",      spell = "Purify Spirit" },
    { mouse = "Right Click",      modifier = "Shift", spell = "Earth Shield" },
    { mouse = "Right Click",      modifier = "Ctrl",  spell = "Unleash Life" },
    { mouse = "Middle Click",     modifier = "",      spell = "Healing Rain" },
}

-------------------------------------------------
-- Minimap Button
-------------------------------------------------
local minimapButton = CreateFrame("Button", "GiveMeHealsMinimapButton", Minimap)
minimapButton:SetSize(32, 32)
minimapButton:SetFrameStrata("MEDIUM")
minimapButton:SetFrameLevel(8)
minimapButton:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local overlay = minimapButton:CreateTexture(nil, "OVERLAY")
overlay:SetSize(53, 53)
overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
overlay:SetPoint("TOPLEFT")

local icon = minimapButton:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetTexture(135860)  -- Healing icon
icon:SetPoint("CENTER", 0, 0)

local function UpdateMinimapButtonPosition()
    local angle = math.rad(GiveMeHealsDB.minimapPos or 220)
    local radius = (Minimap:GetWidth() / 2) + 10
    local x = math.cos(angle) * radius
    local y = math.sin(angle) * radius
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

-- Dragging functionality
minimapButton:RegisterForDrag("RightButton")
minimapButton:SetScript("OnDragStart", function(self)
    self:SetScript("OnUpdate", function(self)
        local mx, my = Minimap:GetCenter()
        local cx, cy = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        cx, cy = cx / scale, cy / scale
        GiveMeHealsDB.minimapPos = math.deg(math.atan2(cy - my, cx - mx))
        UpdateMinimapButtonPosition()
    end)
end)

minimapButton:SetScript("OnDragStop", function(self)
    self:SetScript("OnUpdate", nil)
end)

-------------------------------------------------
-- Config Panel
-------------------------------------------------
local configPanel = CreateFrame("Frame", "GiveMeHealsConfigPanel", UIParent, "BackdropTemplate")
configPanel:SetSize(220, 155)
configPanel:SetPoint("CENTER")
configPanel:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 8, right = 8, top = 8, bottom = 8 }
})
configPanel:SetBackdropColor(0, 0, 0, 1)
configPanel:SetMovable(true)
configPanel:EnableMouse(true)
configPanel:RegisterForDrag("LeftButton")
configPanel:SetScript("OnDragStart", configPanel.StartMoving)
configPanel:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save panel position
    local point, _, relPoint, x, y = self:GetPoint()
    GiveMeHealsDB.configPanel = { point = point, relPoint = relPoint, x = x, y = y }
end)
configPanel:SetFrameStrata("DIALOG")
configPanel:Hide()

-- Title
local title = configPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -14)
title:SetText("|cff00aaffGiveMeHeals|r")

-- Author
local author = configPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
author:SetPoint("TOP", title, "BOTTOM", 0, -2)
author:SetText("by Xerra - Spinebreaker EU")

-- Healing tooltip checkbox
local tooltipCheckbox = CreateFrame("CheckButton", "GiveMeHealsTooltipCheckbox", configPanel, "UICheckButtonTemplate")
tooltipCheckbox:SetPoint("TOPLEFT", configPanel, "TOPLEFT", 14, -50)
tooltipCheckbox.text = tooltipCheckbox:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
tooltipCheckbox.text:SetPoint("LEFT", tooltipCheckbox, "RIGHT", 2, 0)
tooltipCheckbox.text:SetText("Show healing tooltip")
tooltipCheckbox:SetScript("OnClick", function(self)
    GiveMeHealsDB.showTooltip = self:GetChecked()
end)

-- Move tooltip button (toggles between "Move General Tooltip" and "Set Anchor")
local moveTooltipButton = CreateFrame("Button", "GiveMeHealsMoveTooltipButton", configPanel, "UIPanelButtonTemplate")
moveTooltipButton:SetSize(150, 22)
moveTooltipButton:SetPoint("TOPLEFT", tooltipCheckbox, "BOTTOMLEFT", 2, -6)
moveTooltipButton:SetText("Move General Tooltip")
moveTooltipButton:SetScript("OnClick", function(self)
    if GiveMeHealsTooltipAnchor:IsShown() then
        GiveMeHealsTooltipAnchor:Hide()
        self:SetText("Move General Tooltip")
        print("|cff00aaffGiveMeHeals|r: Tooltip position saved.")
    else
        GiveMeHealsTooltipAnchor:Show()
        self:SetText("Set Anchor")
        print("|cff00aaffGiveMeHeals|r: Drag the blue anchor to position your tooltip.")
    end
end)

-- Close button
local closeButton = CreateFrame("Button", nil, configPanel, "UIPanelButtonTemplate")
closeButton:SetSize(70, 22)
closeButton:SetPoint("BOTTOM", 0, 14)
closeButton:SetText("Close")
closeButton:SetScript("OnClick", function()
    configPanel:Hide()
end)

-------------------------------------------------
-- Game Tooltip Anchor
-------------------------------------------------
local tooltipAnchor = CreateFrame("Frame", "GiveMeHealsTooltipAnchor", UIParent, "BackdropTemplate")
tooltipAnchor:SetSize(120, 30)
tooltipAnchor:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -100, 100)
tooltipAnchor:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
tooltipAnchor:SetBackdropColor(0, 0.5, 1, 0.8)
tooltipAnchor:SetBackdropBorderColor(0, 0.7, 1, 1)
tooltipAnchor:SetMovable(true)
tooltipAnchor:EnableMouse(true)
tooltipAnchor:RegisterForDrag("LeftButton")
tooltipAnchor:SetFrameStrata("TOOLTIP")
tooltipAnchor:Hide()

local anchorText = tooltipAnchor:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
anchorText:SetPoint("CENTER")
anchorText:SetText("Tooltip Anchor")

tooltipAnchor:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)

tooltipAnchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    -- Save position
    local point, _, relPoint, x, y = self:GetPoint()
    GiveMeHealsDB.tooltipAnchor = { point = point, relPoint = relPoint, x = x, y = y }
end)

tooltipAnchor:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine("Tooltip Anchor", 0, 0.67, 1)
    GameTooltip:AddLine("Drag to move", 1, 1, 1)
    GameTooltip:Show()
end)

tooltipAnchor:SetScript("OnLeave", function()
    GameTooltip:Hide()
end)

-- Hook GameTooltip to use our anchor position (only hook once)
local tooltipHooked = false
local function ApplyTooltipAnchor()
    if tooltipHooked then return end
    tooltipHooked = true

    hooksecurefunc("GameTooltip_SetDefaultAnchor", function(tooltip, parent)
        -- Always use saved anchor position if one exists
        if GiveMeHealsDB.tooltipAnchor then
            tooltip:ClearAllPoints()
            tooltip:SetPoint("BOTTOMRIGHT", GiveMeHealsTooltipAnchor, "TOPRIGHT", 0, 5)
        end
    end)
end

local function UpdateTooltipAnchorPosition()
    if GiveMeHealsDB.tooltipAnchor then
        tooltipAnchor:ClearAllPoints()
        tooltipAnchor:SetPoint(
            GiveMeHealsDB.tooltipAnchor.point,
            UIParent,
            GiveMeHealsDB.tooltipAnchor.relPoint,
            GiveMeHealsDB.tooltipAnchor.x,
            GiveMeHealsDB.tooltipAnchor.y
        )
    end
end

local function UpdateConfigPanelPosition()
    if GiveMeHealsDB.configPanel then
        configPanel:ClearAllPoints()
        configPanel:SetPoint(
            GiveMeHealsDB.configPanel.point,
            UIParent,
            GiveMeHealsDB.configPanel.relPoint,
            GiveMeHealsDB.configPanel.x,
            GiveMeHealsDB.configPanel.y
        )
    end
end

UpdateTooltipAnchorVisibility = function()
    -- Anchor is only shown via the "Move Anchor" button, not automatically
    tooltipAnchor:Hide()
end

-- Minimap button click handler
minimapButton:RegisterForClicks("LeftButtonUp")
minimapButton:SetScript("OnClick", function(self, button)
    if button == "LeftButton" then
        if configPanel:IsShown() then
            configPanel:Hide()
        else
            configPanel:Show()
        end
    end
end)

minimapButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("GiveMeHeals")
    GameTooltip:AddLine("|cffffffffLeft-click|r to open bindings", 0.8, 0.8, 0.8)
    GameTooltip:AddLine("|cffffffffRight-drag|r to move", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end)

minimapButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
end)

-------------------------------------------------
-- Class/Spec Checks
-------------------------------------------------
local function IsShaman()
    local _, class = UnitClass("player")
    return class == "SHAMAN"
end

local function IsRestorationSpec()
    local specIndex = GetSpecialization()
    if not specIndex then return false end
    local specID = GetSpecializationInfo(specIndex)
    return specID == 264  -- Restoration Shaman spec ID
end

-------------------------------------------------
-- Healing Tooltip Frame
-------------------------------------------------
local healingTooltip = CreateFrame("Frame", "GiveMeHealsTooltip", UIParent, "BackdropTemplate")
healingTooltip:SetSize(180, 170)
healingTooltip:SetFrameStrata("TOOLTIP")
healingTooltip:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
})
healingTooltip:SetBackdropColor(0, 0, 0, 0.9)
healingTooltip:SetBackdropBorderColor(0.6, 0.6, 0.6, 1)
healingTooltip:Hide()

local tooltipTitle = healingTooltip:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
tooltipTitle:SetPoint("TOP", 0, -8)
tooltipTitle:SetText("|cff00aaffGiveMeHeals|r")

local yPos = -24
for _, binding in ipairs(BINDINGS) do
    local line = healingTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    line:SetPoint("TOPLEFT", healingTooltip, "TOPLEFT", 10, yPos)
    local modText = binding.modifier ~= "" and (binding.modifier .. "+") or ""
    line:SetText("|cff00ff00" .. modText .. binding.mouse .. "|r")

    local spellText = healingTooltip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    spellText:SetPoint("TOPRIGHT", healingTooltip, "TOPRIGHT", -10, yPos)
    spellText:SetText(binding.spell)

    yPos = yPos - 16
end

local currentHoverFrame = nil
local hideTooltipTimer = nil

local function ShowHealingTooltip(frame)
    if not GiveMeHealsDB.showTooltip then return end
    -- Cancel any pending hide
    if hideTooltipTimer then
        hideTooltipTimer:Cancel()
        hideTooltipTimer = nil
    end
    currentHoverFrame = frame
    healingTooltip:ClearAllPoints()
    healingTooltip:SetPoint("BOTTOM", frame, "TOP", 0, 5)
    healingTooltip:Show()
end

local function HideHealingTooltip(frame)
    if currentHoverFrame == frame then
        -- Use a small delay to allow moving between parent/child frames
        if hideTooltipTimer then
            hideTooltipTimer:Cancel()
        end
        hideTooltipTimer = C_Timer.NewTimer(0.1, function()
            healingTooltip:Hide()
            currentHoverFrame = nil
            hideTooltipTimer = nil
        end)
    end
end

local function SetupClickCasting(frame)
    if not frame or frame.GiveMeHealsSetup then return end

    local unit = frame:GetAttribute("unit") or frame.unit
    if not unit then return end

    -- Set click-cast attributes
    frame:SetAttribute("type1", "spell")  -- Left click
    frame:SetAttribute("spell1", "Riptide")

    frame:SetAttribute("shift-type1", "spell")
    frame:SetAttribute("shift-spell1", "Healing Wave")

    frame:SetAttribute("ctrl-type1", "spell")
    frame:SetAttribute("ctrl-spell1", "Healing Surge")

    frame:SetAttribute("alt-type1", "spell")
    frame:SetAttribute("alt-spell1", "Chain Heal")

    frame:SetAttribute("type2", "spell")  -- Right click
    frame:SetAttribute("spell2", "Purify Spirit")

    frame:SetAttribute("shift-type2", "spell")
    frame:SetAttribute("shift-spell2", "Earth Shield")

    frame:SetAttribute("ctrl-type2", "spell")
    frame:SetAttribute("ctrl-spell2", "Unleash Life")

    frame:SetAttribute("type3", "spell")  -- Middle click
    frame:SetAttribute("spell3", "Healing Rain")

    -- Show healing tooltip on hover
    frame:HookScript("OnEnter", function(self)
        ShowHealingTooltip(self)
    end)

    frame:HookScript("OnLeave", function(self)
        HideHealingTooltip(self)
    end)

    frame.GiveMeHealsSetup = true
end

local function HookCompactUnitFrames()
    -- Hook into CompactUnitFrame creation
    hooksecurefunc("CompactUnitFrame_SetUpFrame", function(frame, ...)
        if IsShaman() then
            SetupClickCasting(frame)
        end
    end)

    -- Setup existing frames
    if CompactRaidFrameContainer then
        CompactRaidFrameContainer:ApplyToFrames("all", function(frame)
            if IsShaman() then
                SetupClickCasting(frame)
            end
        end)
    end
end

local function HookPartyFrames()
    for i = 1, 4 do
        local frame = _G["PartyMemberFrame" .. i]
        if frame and IsShaman() then
            SetupClickCasting(frame)
        end
    end
end

local function HookPlayerAndTargetFrames()
    -- Player frame for self-healing
    if PlayerFrame then
        SetupClickCasting(PlayerFrame)
    end
    -- Target frame for healing friendly targets
    if TargetFrame then
        SetupClickCasting(TargetFrame)
    end
    -- Focus frame
    if FocusFrame then
        SetupClickCasting(FocusFrame)
    end
end

-------------------------------------------------
-- Initialization
-------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        -- Set defaults if not present
        if GiveMeHealsDB.minimapPos == nil then
            GiveMeHealsDB.minimapPos = 220
        end
        if GiveMeHealsDB.showTooltip == nil then
            GiveMeHealsDB.showTooltip = true
        end

        -- Update checkbox to match saved settings
        tooltipCheckbox:SetChecked(GiveMeHealsDB.showTooltip)

        UpdateMinimapButtonPosition()
        UpdateConfigPanelPosition()
        UpdateTooltipAnchorPosition()
        UpdateTooltipAnchorVisibility()
        ApplyTooltipAnchor()

        if not IsShaman() then
            print("|cff00aaffGiveMeHeals|r: |cffff5555You are not a Shaman.|r This addon is designed for Restoration Shamans.")
            return
        end

        if not IsRestorationSpec() then
            print("|cff00aaffGiveMeHeals|r: |cffffff00You are not in Restoration spec.|r This addon works best as Restoration.")
        end

        HookCompactUnitFrames()
        HookPartyFrames()
        HookPlayerAndTargetFrames()

        print("|cff00aaffGiveMeHeals|r: Click-cast healing enabled. Click the minimap button for settings.")

    elseif event == "GROUP_ROSTER_UPDATE" then
        if IsShaman() then
            HookPartyFrames()
        end
    end
end)
