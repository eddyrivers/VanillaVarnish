local ns, vv = NST_TEST_NS, VV_TEST_NS
local combo = ns.ComboPoints
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local function Row(plate)
    for _, frame in ipairs(Mock.frames) do
        if frame.parent == plate and frame.dots then return frame end
    end
end
local points = 0
local class, powerType = "ROGUE", 3
UnitClass = function() return class, class end
UnitPowerType = function() return powerType end
GetComboPoints = function(player, target)
    Check(player == "player" and target == "target", "Points use the target-bound Forever API")
    return points
end
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local target = Mock.Plate("nameplate1")
target.UnitFrame.HealthBarsContainer.healthBar = Mock.New(target.UnitFrame.HealthBarsContainer)
target.UnitFrame.CastBarsContainer = Mock.New(target.UnitFrame)
target.UnitFrame.CastBarsContainer.castBar = Mock.New(target.UnitFrame.CastBarsContainer)
target.UnitFrame.CastBarsContainer.castBar:SetFrameLevel(100)
Mock.plates.target, Mock.units.target, Mock.units.nameplate1 = target, true, true
local other = Mock.Plate("nameplate2")
Mock.plates.softenemy, Mock.units.softenemy = other, true
Mock.Event("PLAYER_TARGET_CHANGED")
local row = assert(Row(target))
Check(row:IsShown(), "Five empty circles remain visible at zero points")
for _, dot in ipairs(row.dots) do
    Check(dot:IsShown() and dot.inactive:IsShown() and not dot.active:IsShown() and not dot.icon:IsShown(),
        "Zero points use native empty artwork in every slot")
end
points = 3
Mock.Event("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
Check(row:IsShown() and row.dots[3].icon:IsShown() and row.dots[4].inactive:IsShown()
    and not row.dots[4].icon:IsShown(), "Earned points fill red while remaining circles stay empty")
local anchor = target.UnitFrame.HealthBarsContainer.healthBar
local cast = target.UnitFrame.CastBarsContainer.castBar
Check(row:GetFrameLevel() > cast:GetFrameLevel(), "Combo row draws above native cast artwork")
for _, dot in ipairs(row.dots) do
    Check(dot:GetFrameLevel() > cast:GetFrameLevel(), "Dot artwork is visible over the cast bar")
end
Check(row.points[1][2] == anchor and row.points[1][3] == "BOTTOM" and row.points[1][4] == 17 and row.points[1][5] == -24,
    "Default offsets position dots relative to the visible health bar")
Check(row.width == 76 and row.height == 12, "Default five-point row has spaced dots")
Check(row.dots[1].layers[3].atlas == "uf-roguecp-icon-red", "Use the native personal-resource red graphic")
Check(row.dots[1].layers[2].atlas == "uf-roguecp-bg", "Use its native active background")
Check(row.dots[1].inactive.atlas == "uf-roguecp-bg-dis", "Use the personal-resource display's native empty circle")
local x = row.dots[3].points[1][4]
points = 5
Mock.Event("COMBO_TARGET_CHANGED")
Check(row.dots[5].icon:IsShown() and not row.dots[5].inactive:IsShown()
    and row.dots[3].points[1][4] == x, "Point positions stay fixed as points fill")
points = 1
Mock.Event("PLAYER_TARGET_CHANGED")
Check(row.dots[2]:IsShown() and row.dots[2].inactive:IsShown() and not row.dots[2].icon:IsShown(),
    "Target changes return spent slots to empty circles")
points = 0
Mock.Event("UNIT_POWER_UPDATE", "player", "COMBO_POINTS")
Check(row:IsShown() and row.dots[1].inactive:IsShown() and not row.dots[1].icon:IsShown(),
    "Spending all points leaves the five empty circles visible")
Check(row.dots[3].points[1][4] == x, "Spending points does not move the circle row")
class = "WARRIOR"
Mock.Tick(0.11)
Check(not row:IsShown(), "Classes without combo points do not get an empty row")
class, powerType = "DRUID", 0
Mock.Event("UPDATE_SHAPESHIFT_FORM")
Check(not row:IsShown(), "Druid circles wait for Cat Form")
powerType = 3
Mock.Event("UNIT_DISPLAYPOWER", "player")
Check(row:IsShown() and row.dots[1].inactive:IsShown(), "Cat Form shows empty circles before earning points")
powerType = 1
Mock.Event("UPDATE_SHAPESHIFT_FORM")
Check(not row:IsShown(), "Leaving Cat Form hides the combo row")
class = "ROGUE"
Mock.Tick(0.11)
Mock.plates.target = other
Mock.Event("PLAYER_TARGET_CHANGED")
Check(not row:IsShown() and Row(other):IsShown(), "Only the new target shows points")
Mock.units.target = false
Mock.Event("PLAYER_TARGET_CHANGED")
Check(not Row(other):IsShown(), "Never copy target-bound points onto a soft target")
Mock.units.target, Mock.plates.target = true, target
points = 2
Mock.Event("PLAYER_TARGET_CHANGED")
ns.SetFeature("comboPointsEnabled", false)
Check(not row:IsShown(), "Feature switch hides live dots immediately")
ns.SetFeature("comboPointsEnabled", true)
Check(row:IsShown(), "Feature can be enabled without a reload")
vv.SetModuleEnabled("nameplates", false)
Check(not row:IsShown(), "Master module switch hides dots immediately")
vv.SetModuleEnabled("nameplates", true)
Check(row:IsShown(), "Master switch retains combo preferences")
Mock.lockdown = true
Check(combo.SetValue("size", 20) and combo.SetValue("x", -30) and combo.SetValue("y", 9)
    and combo.SetValue("gap", 0), "Controls work in combat")
Check(row.width == 100 and row.height == 20 and row.points[1][4] == -30 and row.points[1][5] == -9,
    "Size, offsets, and zero spacing apply live")
Check(not combo.SetValue("size", 0) and not combo.SetValue("x", {secret=true})
    and not combo.SetValue("gap", 31) and not combo.SetValue("color", "blue"), "Reject invalid settings")
Mock.lockdown = false
for _, value in ipairs({{secret=true}, -1, 6, 1.5, "3"}) do
    points = value
    Mock.Event("UNIT_POWER_FREQUENT", "player", "COMBO_POINTS")
    Check(not row:IsShown(), "Restricted or invalid counts hide old points")
end
GetComboPoints = function() error("restricted") end
Mock.Tick(0.11)
Check(not row:IsShown(), "API failure does not retain a stale count")
GetComboPoints = function() return 4 end
Mock.Tick(0.11)
Check(row:IsShown(), "Polling recovers when reads are available")
target:Hide(); Mock.Tick(0.11)
Check(not row:IsShown(), "Offscreen target hides dots")
target:Show(); target.forbidden = true; Mock.Tick(0.11)
Check(not row:IsShown(), "Forbidden plates are ignored")
target.forbidden = false; Mock.Tick(0.11)
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
Check(not row:IsShown(), "Recycled plates hide immediately")
Mock.plates.target = nil
Mock.Tick(0.11)
Check(not row:IsShown(), "Missing plate does not retain dots")

-- Both menu pages use the same sample and feature choices, independent of
-- live points, class, target, and the master module switch.
ns.OpenSwingOptions()
local swingSample = ns.optionsPreviewNameplate
ns.OpenComboOptions()
local comboSample = combo.previewNameplate
Check(combo.optionsPanel:IsShown(), "Separate combo page opens")
for _, sample in ipairs({swingSample, comboSample}) do
    Check(sample.comboRow:IsShown() and sample.comboRow.dots[5]:IsShown(), "Both previews show five sample dots")
    Check(sample.comboRow.dots[3].icon:IsShown() and sample.comboRow.dots[4].inactive:IsShown(),
        "Both previews show filled and empty circles together")
    Check(sample.swingStack:IsShown(), "Both previews show enabled swing bars")
    Check(sample.comboRow.points[1][2] == combo.HealthAnchor(sample.nativeFrame, sample.healthBar),
        "Preview uses the same visible health anchor")
    local sampleCast = sample.nativeFrame and sample.nativeFrame.CastBarsContainer.castBar or sample.castBar
    for _, dot in ipairs(sample.comboRow.dots) do
        Check(dot:GetFrameLevel() > sampleCast:GetFrameLevel(), "Both previews draw dots above cast artwork")
    end
end
ns.SetFeature("swingsEnabled", false)
for _, sample in ipairs({swingSample, comboSample}) do
    Check(not sample.swingStack:IsShown() and sample.comboRow:IsShown(), "Combo preview works with swings off")
end
ns.SetFeature("comboPointsEnabled", false)
for _, sample in ipairs({swingSample, comboSample}) do
    Check(not sample.comboRow:IsShown(), "Disabled combos disappear from both previews")
end
ns.SetFeature("swingsEnabled", true)
for _, sample in ipairs({swingSample, comboSample}) do
    Check(sample.swingStack:IsShown() and not sample.comboRow:IsShown(), "Swing preview works with combos off")
end
local toggle = ns.featureControls.comboPointsEnabled.button
toggle:SetChecked(true); toggle.scripts.OnClick(toggle)
Check(combo.optionControls.enabled.button:GetChecked(), "Main toggle updates the combo page toggle")
local size = combo.optionControls.size
size.box:SetFocus(); size.box:SetText("18"); size.box.scripts.OnEnterPressed()
Check(combo.db.size == 18 and size.slider.value == 18, "Exact value entry saves and refreshes")
combo.optionControls.x.slider:SetValue(12)
for _, sample in ipairs({swingSample, comboSample}) do
    Check(sample.comboRow.height == 18 and sample.comboRow.points[1][4] == 12,
        "Both previews update after combo controls change")
end
vv.SetModuleEnabled("nameplates", false)
ns.RefreshOptions()
Check(comboSample.comboRow:IsShown(), "Settings preview remains usable with module off")
local saved = vv.Copy(combo.db)
vv.InitDB(); combo.InitDB()
Check(combo.db.size == saved.size and combo.db.x == saved.x, "Choices survive initialization")
local swingWidth = ns.db.width
combo.ResetSettings()
Check(combo.db.size == 12 and combo.db.x == 17 and combo.db.y == 24 and combo.db.gap == 4
    and ns.tweaksDB.comboPointsEnabled and ns.db.width == swingWidth, "Reset changes only combo layout")
VV_TEST_NS.Nameplates.HandleSlash("combo off")
Check(not ns.tweaksDB.comboPointsEnabled, "Slash feature toggle works")
VV_TEST_NS.Nameplates.HandleSlash("combo")
Check(combo.optionsPanel:IsShown(), "Slash opens the combo page")
Check(not ns.preview, "Settings never enable synthetic world swings")
NST_COMBO_CHECKS = checks
