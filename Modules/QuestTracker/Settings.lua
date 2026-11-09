local _, VV = ...
local addon = VV.QuestTracker
local panel, category, logPanel, logCategory
local controls = {}

local function Label(text, x, y, font, parent)
    parent = parent or panel
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -16, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Check(key, text, y, tip, parent)
    parent = parent or panel
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 16, y)
    Label(text, 44, y - 5, nil, parent)
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

local function Button(text, x, y, callback, parent)
    parent = parent or panel
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(144, 24)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

function addon.RefreshOptions()
    if not addon.db then return end
    for key, control in pairs(controls) do
        if key == "completedSort" then control:GenerateMenu()
        else control:SetChecked(addon.db[key]) end
    end
end

function addon.RegisterOptions()
    if category then return end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    Label("Quest tracker", 16, -16, "GameFontNormalLarge")
    Label("Keep tracked quests together by zone, with lower-level quests first.", 16, -44, "GameFontHighlightSmall")
    Check("enabled", "Enable zone grouping", -86,
        "Group quests by zone. Turn off to use the game's usual quest tracker.")
    Label("Completed quest sorting", 16, -131)
    local dropdown = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    dropdown:SetSize(240, 24)
    dropdown:SetPoint("TOPLEFT", panel, "TOPLEFT", 220, -126)
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs({{"off", "Off"}, {"top", "Completed on top"}, {"bottom", "Completed on bottom"}}) do
            local value, label = choice[1], choice[2]
            root:CreateRadio(label, function() return addon.db.completedSort == value end,
                function() addon.SetOption("completedSort", value) end)
        end
    end)
    controls.completedSort = dropdown
    Label("Applies within each zone while grouping is on. Off keeps level sorting.\nCompleted means ready for turn-in; remaining travel or delivery instructions stay in level order.",
        16, -166, "GameFontHighlightSmall")
    Button("Expand all zones", 16, -218, function() addon.SetAllZonesCollapsed(false) end)
    Button("Collapse all zones", 172, -218, function() addon.SetAllZonesCollapsed(true) end)
    Label("Click a zone heading to expand or collapse it, including in combat.\nRight-click to track or untrack the zone outside combat. Move and resize in Edit Mode.",
        16, -266, "GameFontHighlightSmall")
    Check("scrolling", "Scroll overflowing objectives", -322,
        "Use the mouse wheel or scrollbar to reach all tracked quests in the existing tracker. Keeps Blizzard's quest rows and item buttons.")
    Check("compact", "Compact view", -362,
        "Reduce quest text by 1.5 points, with slightly smaller zone buttons and tighter row spacing. Off by default.")
    Button("Restore defaults", 16, -418, addon.ResetOptions)
    VV.RegisterOptions()
    category = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, panel, "Quest tracker")
    Settings.RegisterAddOnCategory(category)
    panel:SetScript("OnShow", addon.RefreshOptions)
    addon.optionsPanel, addon.optionsCategory, addon.optionControls = panel, category, controls
    logPanel = CreateFrame("Frame", nil, UIParent)
    logPanel:Hide()
    Label("Quest log", 16, -16, "GameFontNormalLarge", logPanel)
    Label("Fit more quests in the quest log list while keeping quest details at their usual size.",
        16, -44, "GameFontHighlightSmall", logPanel)
    Check("compactLog", "Compact view", -86,
        "Reduce quest log titles, objectives, and zone headings by 1.5 points. Off by default and independent of tracker Compact view.", logPanel)
    Button("Restore defaults", 16, -146, addon.ResetQuestLogOptions, logPanel)
    logCategory = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, logPanel, "Quest log")
    Settings.RegisterAddOnCategory(logCategory)
    logPanel:SetScript("OnShow", addon.RefreshOptions)
    addon.questLogOptionsPanel, addon.questLogOptionsCategory = logPanel, logCategory
    addon.RefreshOptions()
end

function addon.OpenQuestLogOptions()
    addon.RegisterOptions()
    VV.OpenSettingsCategory(logCategory)
end

function addon.OpenOptions()
    addon.RegisterOptions()
    VV.OpenSettingsCategory(category)
end
