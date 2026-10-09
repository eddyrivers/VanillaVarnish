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
    Label("Organize tracked quests by zone and level inside the native quest tracker.", 16, -44, "GameFontHighlightSmall")
    Check("enabled", "Enable zone grouping", -86,
        "Group tracked quests by their quest-log zone. Turning this off restores native ordering, fonts, and visibility.")
    Check("completedFirst", "Show completed quests first", -126,
        "Within each zone, show completed quests in ascending level order, followed by incomplete quests in ascending level order. Disabled by default.")
    Label("Completed quests first applies while zone grouping is enabled.\nEqual levels sort by title; unknown levels appear last in each group.",
        44, -160, "GameFontHighlightSmall")
    Button("Expand all zones", 16, -218, function() addon.SetAllZonesCollapsed(false) end)
    Button("Collapse all zones", 172, -218, function() addon.SetAllZonesCollapsed(true) end)
    Label("Click a zone heading or its white + / - button to fold or expand it.\nRight-click for zone tracking. Move and resize the tracker using Edit Mode.\nSettings save per character; tracker changes made in combat apply when combat ends.",
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
