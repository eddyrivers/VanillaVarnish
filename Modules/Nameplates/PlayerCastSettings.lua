local _, VV = ...
local ns = VV.Nameplates
local cast, UI = ns.PlayerCastBar, ns.UI
local panel, plate, preview, nextCast
local controls = {}

local function draw()
    if not panel:IsShown() then return end
    local now = GetTime()
    ns.DrawMenuFeaturePreview(plate)
    if not preview then preview = cast.CreatePreview(plate) end
    if not preview then return end
    cast.LayoutPreview(preview, ns.MenuNameplatePreviewAnchor(plate))
    preview:SetShown(ns.tweaksDB.playerCastBarEnabled)
    if ns.tweaksDB.playerCastBarEnabled and (not nextCast or now >= nextCast) then
        preview.bar:SimulateCast({spellName="Your Healing Touch", iconTexture="Interface\\Icons\\Spell_Nature_HealingTouch", castTime=3})
        nextCast = now + 4
    end
end

function cast.RefreshOptions()
    if not panel then return end
    UI.RefreshControls(controls)
    plate.nextLayout = nil
    draw()
end

function ns.RegisterPlayerCastOptions()
    if panel then return end
    if not cast.db then cast.InitDB() end
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    UI.Label(panel, "Player cast bar", 16, -16, "GameFontNormalLarge")
    local intro = UI.Label(panel, "Your spells on your target's nameplate. Artwork and bar height follow the game's nameplate style.",
        16, -42, "GameFontHighlightSmall")
    intro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -42)
    local viewport = CreateFrame("Frame", nil, panel)
    viewport:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -74)
    viewport:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -74)
    viewport:SetHeight(240)
    viewport:SetClipsChildren(true)
    local bg = viewport:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.025, 0.03, 0.04, 0.9)
    UI.Label(viewport, "Live preview: your cast below the target's bars", 12, -10, "GameFontNormal")
    plate = ns.CreateMenuFeaturePreview(viewport)
    plate:SetPoint("TOP", viewport, "TOP", 0, -65)
    viewport:SetScript("OnUpdate", draw)
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", viewport, "BOTTOMLEFT", 0, -16)
    content:SetPoint("TOPRIGHT", viewport, "BOTTOMRIGHT", 0, -16)
    content:SetHeight(180)
    controls.enabled = UI.Check(content, "playercast.enabled", "Show player cast bar", 0,
        function() return ns.tweaksDB.playerCastBarEnabled end,
        function(value) nextCast = nil; ns.SetFeature("playerCastBarEnabled", value); cast.RefreshOptions() end,
        "Optional extra bar for your own casts and channels. Requires a visible target nameplate. Your normal player cast bar stays available.")
    local y = -40
    for _, spec in ipairs({
        {"x", "Horizontal offset", "Positive moves right; negative moves left."},
        {"y", "Vertical offset", "Distance from the bottom of the target's health bar. Positive moves down; negative moves up."},
        {"width", "Bar width", "Width of the cast progress bar in UI units. Height follows your selected nameplate style and size."},
    }) do
        local key, limits = spec[1], cast.limits[spec[1]]
        controls[key] = UI.Slider(content, "playercast." .. key, spec[2], y, limits[1], limits[2], 1, false,
            function() return cast.db[key] end, function(value) cast.SetValue(key, value) end, spec[3])
        y = y - 40
    end
    local reset = UI.Button(panel, "Restore defaults", 144, cast.Reset)
    reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 12)
    panel:SetScript("OnShow", function() nextCast = nil; cast.RefreshOptions() end)
    panel:SetScript("OnHide", function()
        ns.StopMenuFeaturePreview(plate)
        if preview then preview.bar:StopAnims(); preview:Hide() end
        nextCast = nil
    end)
    ns.playerCastCategory = Settings.RegisterCanvasLayoutSubcategory(ns.rootCategory, panel, "Player cast bar")
    Settings.RegisterAddOnCategory(ns.playerCastCategory)
    cast.optionsPanel, cast.optionControls, cast.previewNameplate = panel, controls, plate
end

function cast.OpenOptions()
    if not ns.playerCastCategory then ns.RegisterOptions() end
    ns.OpenSettingsCategory(ns.playerCastCategory)
end
