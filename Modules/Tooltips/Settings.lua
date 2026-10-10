local _, VV = ...
local addon = VV.Tooltips
local panel, category
local controls = {}

function addon.RefreshOptions()
    if panel then VV.Nameplates.UI.RefreshControls(controls) end
end

function addon.RegisterOptions()
    if panel then return end
    if not addon.db then addon.InitDB() end
    VV.RegisterOptions()
    local UI = VV.Nameplates.UI
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    UI.Label(panel, "Tooltips", 16, -16, "GameFontNormalLarge")
    local intro = UI.Label(panel, "Keep hover information beside your mouse and make units easier to recognize.",
        16, -44, "GameFontHighlightSmall")
    intro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -44)
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -86)
    content:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -86)
    content:SetHeight(320)
    for index, spec in ipairs({
        {"followMouse", "Follow the mouse", "Move hover tooltips for units, spells, items, auras, and other controls beside the cursor."},
        {"unitColors", "Color unit names, classes, and levels", "Use class colors for player names and class text, and Classic difficulty colors for hostile levels. Restricted information keeps Blizzard's colors."},
        {"instantHide", "Hide instantly when hovering ends", "Skip the normal fade when you move off a unit or another hover target."},
        {"pauseInCombat", "Pause mouse following in combat", "Use the tooltip position saved in Blizzard's Edit Mode throughout combat. Mouse following resumes when combat ends. Off by default."},
    }) do
        local key = spec[1]
        controls[key] = UI.Check(content, "tooltips." .. key, spec[2], -(index - 1) * 40,
            function() return addon.db[key] end, function(value) addon.SetOption(key, value) end, spec[3])
    end
    for index, spec in ipairs({
        {"offsetX", "Horizontal offset", "Positive moves right; negative moves left. UI units relative to the cursor anchor."},
        {"offsetY", "Vertical offset", "Positive moves up; negative moves down. UI units relative to the cursor anchor."},
    }) do
        local key, limits = spec[1], addon.limits[spec[1]]
        controls[key] = UI.Slider(content, "tooltips." .. key, spec[2], -184 - (index - 1) * 44,
            limits[1], limits[2], 1, false, function() return addon.db[key] end,
            function(value) addon.SetOption(key, value) end, spec[3])
    end
    UI.Label(panel, "Enable the Tooltips module on the VanillaVarnish page.\nOffsets apply while following the mouse. Combat pause uses your Edit Mode position.",
        16, -368, "GameFontHighlightSmall")
    local reset = UI.Button(panel, "Restore defaults", 144, addon.ResetSettings)
    reset:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -428)
    category = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, panel, "Tooltips")
    Settings.RegisterAddOnCategory(category)
    panel:SetScript("OnShow", addon.RefreshOptions)
    addon.optionsPanel, addon.optionsCategory, addon.optionControls = panel, category, controls
    addon.RefreshOptions()
end

function addon.OpenOptions()
    addon.RegisterOptions()
    VV.OpenSettingsCategory(category)
end
