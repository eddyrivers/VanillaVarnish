local ns = NST_TEST_NS
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function Near(a, b) return math.abs(a - b) < 0.00001 end

Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
ns.OpenSwingOptions()
local plate = ns.optionsPreviewNameplate
Check(plate and plate.castBar:IsShown(), "Menu includes a synthetic cast without targeting a mob")
Check(plate.name.parent == plate.healthBar and plate.level.parent == plate.healthBar,
    "Health artwork cannot cover the sample name and level")
Check(ns.optionsPreview.anchor == plate, "Swing preview anchors to the health container")
Check(not ns.preview and ns.anchorUnit == nil, "Menu casting does not enable world preview or change targeting")

-- Expected Blizzard dimensions at Medium; widths exclude the clickable inset.
local styles = {
    {0, 206, 20, 10, "LEFT", "TOPLEFT"}, -- Modern
    {1, 206, 10, 10, "BOTTOMLEFT", "TOPLEFT"}, -- Thin
    {2, 206, 20, 16, "LEFT", "LEFT"}, -- Block
    {3, 206, 20, 10, "BOTTOMLEFT", "TOPLEFT"}, -- Health Focus
    {4, 206, 10, 16, "BOTTOMLEFT", "LEFT"}, -- Cast Focus
    {5, 206, 10, 10, "BOTTOMLEFT", "TOPLEFT"}, -- Legacy
    {6, 128, 10, 10, "BOTTOM", "CENTER"}, -- Classic
}
for _, style in ipairs(styles) do
    Mock.cvars.nameplateStyle, Mock.cvars.nameplateSize = tostring(style[1]), "2"
    Mock.Tick(0.11)
    Check(Near(plate:GetWidth(), style[2]) and Near(plate.height, style[3]), "Health geometry follows selected style")
    Check(Near(plate.castBar.height, style[4]), "Cast height follows selected style")
    Check(plate.name.points[1][1] == style[5] and plate.castBar.icon.points[1][1] == style[6],
        "Name and spell placement follow selected style")
    Check(plate.healthBar.border:IsShown() == (style[1] == 6) and plate.castBar.border:IsShown() == (style[1] == 6),
        "Classic borders are restored and removed when changing styles")
    Check(plate.level:IsShown() == (style[1] == 6), "Classic level display follows style")
    Check(ns.optionsPreview.anchor == plate and ns.optionsPreview.offset >= ns.db.y,
        "Cast clearance preserves the live health anchor and configured minimum offset")
end
for _, style in ipairs({0, 4, 6}) do
    for size, scale in ipairs({0.8, 1, 1.25, 1.4, 1.6}) do
        Mock.cvars.nameplateStyle, Mock.cvars.nameplateSize = tostring(style), tostring(size)
        Mock.Tick(0.11)
        local horizontal = size == 1 and style ~= 6 and 0.75 or scale
        Check(Near(plate.width, (style == 6 and 128 or 206) * horizontal), "Selected size scales health and cast widths")
        Check(Near(plate.height, (style == 0 and 20 or 10) * scale), "Selected size scales health height")
        Check(Near(plate.castBar.height, (style == 4 and 16 or 10) * scale), "Selected size scales cast height")
    end
end

-- Client globals take priority, including future geometry changes and custom
-- base width. They are read even when no live nameplate has ever been created.
Mock.cvars.nameplateStyle, Mock.cvars.nameplateSize = "4", "2"
NamePlateSetupOptions = {healthBarHeight = 13, castBarHeight = 23, insetWidth = 9,
    castBarToHealthBarSpacing = 5, healthBarToNameAboveSpacing = 3,
    healthBarFontHeight = 14, castBarFontHeight = 12, castIconHeight = 18,
    unitNameAnchorStyle = 2, spellNameInsideCastBar = true,
    horizontalScale = 1.1, verticalScale = 1.2, useClassicHealthBar = false, useClassicCastBar = false}
C_NamePlate.GetNamePlateSize = function() return 240, 80 end
Mock.Tick(0.11)
Check(plate.width == 222 and plate.height == 13 and plate.castBar.height == 23, "Client setup and base width override fallbacks")
Check(plate.castBar.points[1][5] == -5 and plate.name.points[1][5] == 3, "Client bar and name spacing")
Check(plate.name.fontSize == 14 and plate.castBar.text.fontSize == 12 and plate.castBar.icon.height == 18,
    "Client font and icon sizes")
local initialFill = plate.castBar.fill.width
Mock.Tick(0.11)
Check(plate.castBar.fill.width ~= initialFill, "Menu cast animates synthetically")
Check(NamePlateSetupOptions.healthBarHeight == 13 and NamePlateSetupOptions.castBarHeight == 23,
    "Preview does not mutate Blizzard setup options")

ns.optionsPanel:Hide()
NamePlateSetupOptions.healthBarHeight, NamePlateSetupOptions.castBarHeight = 18, 12
Mock.Tick(1)
ns.OpenSwingOptions()
Check(plate.height == 18 and plate.castBar.height == 12, "Reopening refreshes changes made while the menu was hidden")

-- Missing, invalid, secret, or failing read APIs still leave a usable preview.
NamePlateSetupOptions = {healthBarHeight = {secret = true}, castBarHeight = -1}
C_NamePlate.GetNamePlateSize = function() error("not available") end
Mock.cvars.nameplateStyle, Mock.cvars.nameplateSize = "invalid", {secret = true}
Mock.Tick(0.11)
Check(plate.width == 206 and plate.height == 20 and plate.castBar.height == 10, "Invalid settings use safe default geometry")
Check(not ns.preview and ns.anchorUnit == nil, "Synthetic preview remains isolated from world timers")
NST_PREVIEW_CHECKS = checks
