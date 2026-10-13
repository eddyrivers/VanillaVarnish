local _, VV = ...
local ns = VV.Nameplates
local combo, UI = ns.ComboPoints, ns.UI
local panel, plate
local controls = {}

function ns.RefreshComboOptions()
    if not panel then return end
    UI.RefreshControls(controls)
    plate.nextLayout = nil
    ns.DrawMenuFeaturePreview(plate)
end

function ns.RegisterComboOptions()
    if panel then return end
    if not combo.db then combo.InitDB() end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    UI.Label(panel, "Combo points", 16, -16, "GameFontNormalLarge")
    local intro = UI.Label(panel, "See your combo points along the bottom of your target's health bar.", 16, -42, "GameFontHighlightSmall")
    intro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -42)
    local viewport = CreateFrame("Frame", nil, panel)
    viewport:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -64)
    viewport:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -64)
    viewport:SetHeight(250)
    viewport:SetClipsChildren(true)
    local bg = viewport:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.025, 0.03, 0.04, 0.9)
    UI.Label(viewport, "Live preview", 12, -10, "GameFontNormal")
    UI.Label(viewport, "Follows the game's Nameplates options, with your swing timers and combo points.", 12, -30, "GameFontDisableSmall")
    plate = ns.CreateMenuFeaturePreview(viewport)
    plate:SetPoint("CENTER", viewport, "CENTER", 0, 0)
    viewport:SetScript("OnUpdate", function() ns.DrawMenuFeaturePreview(plate) end)
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", viewport, "BOTTOMLEFT", 0, -16)
    content:SetPoint("TOPRIGHT", viewport, "BOTTOMRIGHT", 0, -16)
    content:SetHeight(240)
    controls.enabled = UI.Check(content, "combo.enabled", "Show combo points", 0,
        function() return ns.tweaksDB.comboPointsEnabled end,
        function(value) ns.SetFeature("comboPointsEnabled", value) end,
        "Show five circles on your target. They fill red as you gain combo points. For rogues and druids in Cat Form.")
    local y = -40
    for _, spec in ipairs({
        {"size", "Dot size", "Size of each dot in UI units."},
        {"x", "Horizontal offset", "Positive moves right; negative moves left."},
        {"y", "Vertical offset", "Positive moves down; negative moves up. At 0, dots overlap the bottom edge halfway."},
        {"gap", "Space between dots", "Gap between dots. At 0, the dots touch."},
    }) do
        local key, limits = spec[1], combo.limits[spec[1]]
        controls[key] = UI.Slider(content, "combo." .. key, spec[2], y, limits[1], limits[2], 1, false,
            function() return combo.db[key] end, function(value) combo.SetValue(key, value) end, spec[3])
        y = y - 40
    end
    local status = UI.Label(panel, "Changes save as you go.", 16, -4, "GameFontDisableSmall")
    status:ClearAllPoints(); status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 44)
    local reset = UI.Button(panel, "Restore defaults", 144, combo.ResetSettings)
    reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 12)
    controls.reset = {button = reset, Refresh = function() end}
    ns.comboCategory = Settings.RegisterCanvasLayoutSubcategory(ns.rootCategory, panel, "Combo points")
    Settings.RegisterAddOnCategory(ns.comboCategory)
    panel:SetScript("OnShow", ns.RefreshComboOptions)
    panel:SetScript("OnHide", function() ns.StopMenuFeaturePreview(plate) end)
    combo.optionsPanel, combo.optionControls, combo.previewNameplate = panel, controls, plate
end

function ns.OpenComboOptions()
    if not ns.comboCategory then ns.RegisterOptions() end
    ns.OpenSettingsCategory(ns.comboCategory)
end
