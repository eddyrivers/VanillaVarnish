local _, VV = ...
local addon = VV.QuestTracker
local panel, category, pendingOpen
local controls = {}

local function Label(text, x, y, font)
    local label = panel:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    label:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Check(key, text, y, tip)
    local check = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
    Label(text, 44, y - 5)
    check:SetScript("OnClick", function(self) addon.SetOption(key, self:GetChecked()) end)
    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(text)
        GameTooltip:AddLine(tip, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)
    controls[key] = check
end

local function Button(text, x, y, callback)
    local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    button:SetSize(144, 24)
    button:SetPoint("TOPLEFT", panel, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

function addon.RefreshOptions()
    if not addon.db then return end
    for key, check in pairs(controls) do check:SetChecked(addon.db[key]) end
end

function addon.RegisterOptions()
    if category then return end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    Label("Quest tracker", 16, -16, "GameFontNormalLarge")
    Label("Keep tracked quests together by zone, with lower-level quests first.", 16, -44, "GameFontHighlightSmall")
    Check("enabled", "Enable zone grouping", -86,
        "Group quests by zone. Turn off to use the game's usual quest tracker.")
    Check("completedFirst", "Show completed quests first", -126,
        "Move completed quests to the top of each zone. Requires zone grouping.")
    Label("Completed quests first applies while zone grouping is on.",
        44, -160, "GameFontHighlightSmall")
    Button("Expand all zones", 16, -218, function() addon.SetAllZonesCollapsed(false) end)
    Button("Collapse all zones", 172, -218, function() addon.SetAllZonesCollapsed(true) end)
    Label("Click a zone heading to expand or collapse it. Right-click to track or untrack the zone.\nMove and resize the tracker in Edit Mode. Changes made in combat apply when combat ends.",
        16, -266, "GameFontHighlightSmall")
    Button("Restore defaults", 16, -338, addon.ResetOptions)
    VV.RegisterOptions()
    category = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, panel, "Quest tracker")
    Settings.RegisterAddOnCategory(category)
    panel:SetScript("OnShow", addon.RefreshOptions)
    addon.optionsPanel, addon.optionsCategory, addon.optionControls = panel, category, controls
    addon.RefreshOptions()
end

function addon.OpenOptions()
    addon.RegisterOptions()
    VV.OpenSettingsCategory(category)
end
