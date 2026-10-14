local vv = VV_TEST_NS
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
assert(vv.Nameplates ~= vv.QuestTracker and vv.Party ~= vv.Nameplates)
assert(vv.db.nameplates == vv.Nameplates.tweaksDB and vv.db.questTracker == vv.QuestTracker.db)
assert(vv.Nameplates.db == vv.db.nameplates.swingTimers)
assert(#Mock.categories == 11 and Mock.categories[1].name == "VanillaVarnish")
assert(vv.rootCategory.shouldSortAlphabetically)
assert(table.concat(vv.moduleOrder, ",") == "nameplates,party,questTracker,tooltips,politeUI")
for index = 2, #Mock.categories do assert(Mock.categories[index].parent == vv.rootCategory) end
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
