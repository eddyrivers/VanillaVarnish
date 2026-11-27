local vv = VV_TEST_NS
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
assert(vv.Nameplates ~= vv.QuestTracker and vv.Party ~= vv.Nameplates)
assert(vv.db.nameplates == vv.Nameplates.tweaksDB and vv.db.questTracker == vv.QuestTracker.db)
assert(vv.Nameplates.db == vv.db.nameplates.swingTimers)
assert(#Mock.categories == #vv.moduleOrder + 10 and Mock.categories[1].name == "VanillaVarnish")
assert(vv.QuestTracker.questLogOptionsCategory.name == "Quest log"
    and vv.QuestTracker.questLogOptionsCategory.parent == vv.rootCategory)
assert(vv.cursorRingCategory.name == "Cursor ring")
assert(vv.rootCategory.shouldSortAlphabetically)
assert(table.concat(vv.moduleOrder, ",") == "nameplates,party,questTracker,tooltips")
for index = 2, #Mock.categories do assert(Mock.categories[index].parent == vv.rootCategory) end
do
    local db = vv.db.cursorRing
    assert(not db.enabled and db.radius == 22 and db.stroke == 3 and db.r == 1 and db.g == 1 and db.b == 1)
    SlashCmdList.VANILLAVARNISH("cursor")
    assert(vv.cursorRingCategory.frame:IsShown())
    local x, y, looking = 500, 250, false
    local oldCursor, oldLooking = GetCursorPosition, IsMouselooking
    GetCursorPosition = function() return x, y end
    IsMouselooking = function() return looking end
    local createTexture = Mock.Object.CreateTexture
    local layers = {}
    Mock.Object.CreateTexture = function(self, name, layer)
        local texture = createTexture(self, name, layer)
        if self.strata == "TOOLTIP" then layers[layer] = texture end
        return texture
    end
    local oldStrata = Mock.Object.SetFrameStrata
    Mock.Object.SetFrameStrata = function(self, strata) self.strata = strata end
    local button = vv.optionControls["cursorRing.enabled"].button
    button:SetChecked(true)
    button.scripts.OnClick(button)
    local stroke = assert(layers.OVERLAY)
    local ringFrame = stroke.parent
    assert(ringFrame:IsShown() and ringFrame.mouse == false and stroke.mask)
    assert(ringFrame.points[1][4] == 500 and ringFrame.points[1][5] == 250)
    x = 680
    UIParent:SetScale(0.5)
    Mock.Tick(0.02)
    assert(ringFrame.points[1][4] == 1360 and ringFrame.points[1][5] == 500)
    looking = true
    Mock.Tick(0.02)
    assert(not stroke:IsShown() and not layers.ARTWORK:IsShown())
    looking = false
    Mock.Tick(0.02)
    assert(stroke:IsShown() and layers.ARTWORK:IsShown())
    vv.optionControls["cursorRing.radius"].slider:SetValue(40)
    vv.optionControls["cursorRing.stroke"].slider:SetValue(8)
    assert(db.radius == 40 and db.stroke == 8)
    assert(stroke:GetWidth() == 80 * 128 / 124 and stroke.mask:GetWidth() == 64 * 128 / 124)
    button:SetChecked(false)
    button.scripts.OnClick(button)
    assert(not ringFrame:IsShown() and db.radius == 40 and db.stroke == 8)
    UIParent:SetScale(1)
    GetCursorPosition, IsMouselooking = oldCursor, oldLooking
    Mock.Object.CreateTexture, Mock.Object.SetFrameStrata = createTexture, oldStrata
end
local n = vv.Nameplates
local plate = Mock.Plate("nameplate1")
Mock.plates.target, Mock.units.target, Mock.units.nameplate1 = plate, true, true
n.SetRangeSpell("damage", "Moonfire")
Mock.rangeResult = false
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
Mock.Event("PLAYER_TARGET_CHANGED")
Mock.Event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
local stack = assert(Mock.Stack(plate))
assert(plate.UnitFrame:GetAlpha() == 0.5 and stack:IsShown())
n.SetFeature("markers", false)
n.SetBarValue("offhand", "enabled", false)
local saved = vv.Copy(vv.db.nameplates)
SlashCmdList.VANILLAVARNISH("nameplates off")
assert(not stack:IsShown() and plate.UnitFrame:GetAlpha() == 1)
assert(n.tweaksDB.damage == "Moonfire" and not n.tweaksDB.markers and not n.db.bars.offhand.enabled)
Mock.Tick(1)
assert(plate.UnitFrame:GetAlpha() == 1 and not stack:IsShown())
-- Native alpha updates pass through the old post-hook while disabled.
plate.UnitFrame:SetAlpha(0.7)
assert(plate.UnitFrame:GetAlpha() == 0.7)
n.SetFeature("rangeEnabled", false)
SlashCmdList.VANILLAVARNISH("nameplates on")
assert(plate.UnitFrame:GetAlpha() == 0.7 and not n.tweaksDB.rangeEnabled and not n.tweaksDB.markers)
n.SetFeature("rangeEnabled", true)
assert(math.abs(plate.UnitFrame:GetAlpha() - 0.35) < 0.0001)
assert(n.db.width == saved.swingTimers.width and not n.db.bars.offhand.enabled)
vv.QuestTracker.SetOption("completedSort", "bottom")
vv.SetModuleEnabled("questTracker", false)
assert(vv.QuestTracker.db.completedSort == "bottom" and vv.QuestTracker.db.enabled)
vv.QuestTracker.SetOption("enabled", false)
vv.SetModuleEnabled("questTracker", true)
assert(not vv.QuestTracker.db.enabled and vv.QuestTracker.db.completedSort == "bottom")
vv.SetModuleEnabled("party", false)
vv.Party.SetOption("buffs", false)
vv.SetModuleEnabled("party", true)
assert(not vv.db.party.buffs and vv.db.party.classColors)
local openCalls = Mock.openCalls or 0
Mock.lockdown = true
SlashCmdList.VANILLAVARNISH("")
SlashCmdList.VANILLAVARNISH("tracker")
SlashCmdList.VANILLAVARNISH("party options")
assert((Mock.openCalls or 0) == openCalls)
Mock.lockdown = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(Mock.openCalls == openCalls + 1 and vv.partyPanel:IsShown())
SlashCmdList.VANILLAVARNISH("")
assert(vv.optionsPanel:IsShown())
local check = vv.optionControls.nameplates.button
check:SetChecked(false); check.scripts.OnClick(check)
assert(not vv.db.modules.nameplates and not stack:IsShown())
local db = vv.db
vv.InitDB()
assert(vv.db == db and not vv.db.modules.nameplates and not vv.db.party.buffs)
assert(vv.Tooltips.db == vv.db.tooltips and vv.db.tooltips.followMouse and not vv.db.tooltips.pauseInCombat)
SlashCmdList.VANILLAVARNISH("tooltips offset 24 -30")
SlashCmdList.VANILLAVARNISH("tooltips off")
SlashCmdList.VANILLAVARNISH("tooltips on")
assert(vv.db.tooltips.offsetX == 24 and vv.db.tooltips.offsetY == -30)
SlashCmdList.VANILLAVARNISH("tooltips")
assert(vv.Tooltips.optionsPanel:IsShown())
assert(vv.Tooltips.optionControls.instantHide == nil and vv.db.tooltips.instantHide == nil)
-- The addon owns one slash namespace, including when legacy addons are absent.
for key, value in pairs(_G) do
    if type(key) == "string" and key:match("^SLASH_") then
        assert(key == "SLASH_VANILLAVARNISH1" and value == "/vv", "Unexpected slash alias: " .. key)
    end
end
for key in pairs(SlashCmdList) do assert(key == "VANILLAVARNISH", "Unexpected slash handler: " .. key) end
SlashCmdList.VANILLAVARNISH("  NaMePlAtEs range damage Moonfire  ")
assert(n.tweaksDB.damage == "Moonfire")
SlashCmdList.VANILLAVARNISH("nameplates combo off")
assert(not n.tweaksDB.comboPointsEnabled)
SlashCmdList.VANILLAVARNISH("nameplates threat off")
assert(not n.tweaksDB.threatColorsEnabled)
SlashCmdList.VANILLAVARNISH("nameplates threat on")
assert(n.tweaksDB.threatColorsEnabled)
SlashCmdList.VANILLAVARNISH("tracker group on")
SlashCmdList.VANILLAVARNISH("tracker group off")
assert(not vv.QuestTracker.db.enabled and vv.db.modules.questTracker)
SlashCmdList.VANILLAVARNISH("tracker group on")
assert(vv.QuestTracker.db.enabled)
SlashCmdList.VANILLAVARNISH("party buffs on")
SlashCmdList.VANILLAVARNISH("party colors off")
assert(vv.db.party.buffs and not vv.db.party.classColors)
local growUp = vv.optionControls["party.growUp"].button
growUp:SetChecked(true); growUp.scripts.OnClick(growUp)
assert(vv.db.party.growUp)
local spacing = vv.optionControls["party.spacing"].box
spacing:SetText("8"); spacing.scripts.OnEnterPressed(spacing)
assert(vv.db.party.spacing == 8)
local roles = vv.optionControls["party.rolePin"].dropdown
local menu = Mock.Menu(roles)
assert(#menu == 3 and menu[1].name == "Off" and menu[2].name == "Top" and menu[3].name == "Bottom")
menu[3].callback()
assert(vv.db.party.rolePin == "bottom" and roles.selectionText == "Bottom")
local groupQuests = n.featureControls.groupQuestMarkers.button
groupQuests:SetChecked(true); groupQuests.scripts.OnClick(groupQuests)
assert(n.tweaksDB.groupQuestMarkers)
SlashCmdList.VANILLAVARNISH("nameplates groupquests off")
assert(not n.tweaksDB.groupQuestMarkers and not groupQuests:GetChecked())
local messages = #Mock.messages
SlashCmdList.VANILLAVARNISH("help")
SlashCmdList.VANILLAVARNISH("nameplates help")
SlashCmdList.VANILLAVARNISH("tracker help")
for index = messages + 1, #Mock.messages do
    local text = Mock.messages[index]
    assert(not text:find("/nt", 1, true) and not text:find("/qto", 1, true)
        and not text:find("/qlo", 1, true) and not text:find("/pt", 1, true)
        and not text:find("/vanillavarnish", 1, true), "Help advertises a removed alias")
end
local tooltipCheck = vv.Tooltips.optionControls.pauseInCombat.button
tooltipCheck:SetChecked(true); tooltipCheck.scripts.OnClick(tooltipCheck)
assert(vv.db.tooltips.pauseInCombat)
local offsetBox = vv.Tooltips.optionControls.offsetX.box
offsetBox:SetText("-45"); offsetBox.scripts.OnEnterPressed(offsetBox)
assert(vv.db.tooltips.offsetX == -45)
vv.Tooltips.ResetSettings()
assert(vv.db.modules.tooltips and vv.db.tooltips.offsetX == 34 and vv.db.tooltips.offsetY == -6 and not vv.db.tooltips.pauseInCombat)
