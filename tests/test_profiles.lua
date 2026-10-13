local vv, ns = VV_TEST_NS, VV_TEST_NS.Nameplates
local checks = 0
local function check(value, label) assert(value, label); checks=checks+1 end
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
check(#vv.ProfileNames() == 0 and vv.profileControls.dropdown.parent == vv.profilesPanel, "Profiles have their own page without seeding editable profiles")
check(not vv.profileControls.load:IsEnabled() and not vv.profileControls.save:IsEnabled(), "Empty library/name disables actions")
ns.SetValue("width", 260)
ns.SetValue("x", 31)
ns.SetBarValue("main", "color", "coral", 0.65)
ns.ComboPoints.SetValue("size", 20)
ns.SetRangeSpell("friendly", "Healing Touch")
vv.Party.SetOption("classColors", false)
vv.Tooltips.SetOption("offsetX", 80)
vv.QuestTracker.SetOption("completedSort", "bottom")
vv.db.questTracker.collapsed.Westfall = true
vv.SetModuleEnabled("party", false)
check(vv.SaveProfile("  Raid setup  "), "Named snapshot can be saved")
local stored = vv.profileStore["Raid setup"].settings
check(stored.nameplates.swingTimers.width == 260 and stored.nameplates.comboPoints.size == 20
    and stored.questTracker.completedSort == "bottom" and not stored.modules.party, "Snapshot includes all module designs and switches")
check(stored.questTracker.collapsed == nil and stored.nameplates ~= vv.db.nameplates
    and stored.nameplates.swingTimers.bars.main ~= ns.db.bars.main, "Snapshots exclude personal quest folds and never alias active settings")
check(not vv.ProfileModified() and vv.profileControls.dropdown.selectionText == "Raid setup", "Saved selection and clean status synchronize")
local tables = {vv.db, vv.db.nameplates, ns.db, ns.db.bars.main, ns.ComboPoints.db, vv.db.questTracker, vv.Tooltips.db}
ns.SetValue("width", 333)
check(vv.profileControls.status:GetText():find("modified locally", 1, true), "Appearance edits immediately update the main-page profile status")
ns.SetBarValue("main", "color", "blue", 1)
ns.ComboPoints.SetValue("size", 8)
vv.Tooltips.SetOption("offsetX", -20)
vv.SetModuleEnabled("party", true)
check(stored.nameplates.swingTimers.width == 260 and stored.nameplates.swingTimers.bars.main.color == "coral"
    and stored.tooltips.offsetX == 80 and vv.ProfileModified(), "Edits remain local and mark the profile modified")
local plate = Mock.Plate("nameplate1")
Mock.plates.target, Mock.units.target, Mock.units.nameplate1 = plate, true, true
Mock.Event("PLAYER_TARGET_CHANGED")
Mock.Event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
check(vv.LoadProfile("raid SETUP"), "Case-insensitive profile lookup")
check(ns.db.width == 260 and ns.db.bars.main.color == "coral" and ns.ComboPoints.db.size == 20
    and vv.Tooltips.db.offsetX == 80 and not vv.db.modules.party and not vv.db.party.classColors, "Loading applies designs across modules")
check(vv.db == tables[1] and ns.tweaksDB == tables[2] and ns.db == tables[3]
    and ns.db.bars.main == tables[4] and ns.ComboPoints.db == tables[5] and vv.QuestTracker.db == tables[6]
    and vv.Tooltips.db == tables[7], "Existing module and nested table references remain valid")
check(Mock.Stack(plate).styleVersion == ns.styleVersion and ns.db.width == 260, "Live bars redraw loaded appearance")
check(vv.db.questTracker.collapsed.Westfall and not vv.ProfileModified(), "Quest folds remain personal and do not dirty the design")
check(vv.Tooltips.optionControls.offsetX.box:GetText() == "80", "Subpage controls refresh after loading")
Mock.lockdown = true
Mock.Event("PLAYER_REGEN_DISABLED")
check(not vv.profileControls.load:IsEnabled() and vv.SaveProfile("Combat snapshot"), "Loading is disabled in combat while saving remains available")
local loaded = vv.db.profileName
check(not vv.LoadProfile("Raid setup") and vv.db.profileName == loaded, "Combat loading cannot change active settings")
Mock.lockdown = false
Mock.Event("PLAYER_REGEN_ENABLED")
check(vv.profileControls.load:IsEnabled(), "Load re-enables when combat ends")
check(not vv.SaveProfile("") and not vv.SaveProfile("bad|name") and not vv.SaveProfile(string.rep("x", 49))
    and not vv.SaveProfile("bad\nname"), "Reject empty, markup, control-character, and overly long names")
check(vv.ProfileName(string.rep("\195\169", 48)) ~= nil, "Name length counts UTF-8 characters")
check(not vv.LoadProfile("Missing") and ns.db.width == 260, "Missing profiles leave settings unchanged")
vv.SaveProfile("Alpha")
check(table.concat(vv.ProfileNames(), ",") == "Alpha,Combat snapshot,Raid setup", "Dropdown names sort alphabetically")
ns.SetValue("width", 275)
vv.SaveProfile("RAID SETUP")
check(#vv.ProfileNames() == 3 and vv.profileStore["Raid setup"].settings.nameplates.swingTimers.width == 275,
    "Saving an existing name updates its snapshot without creating a case-only duplicate")
local oldCharacter, library = VanillaVarnishDB, VanillaVarnishProfilesDB
VanillaVarnishDB = nil
vv.db = nil
vv.selectedProfile = nil
Mock.Event("ADDON_LOADED", "VanillaVarnish")
-- These modules unregister ADDON_LOADED after initialization. Reinitialize
-- their namespace pointers to model a fresh addon process for character two.
ns.InitDB(); ns.ComboPoints.InitDB(); vv.Tooltips.InitDB()
Mock.Event("PLAYER_LOGIN")
check(VanillaVarnishProfilesDB == library and #vv.ProfileNames() == 3 and vv.db ~= oldCharacter,
    "Another character retains the account-wide library and gets independent settings")
check(ns.db.width == ns.defaults.width and vv.db.modules.party and vv.db.profileName == nil,
    "Starting another character never auto-loads or changes the first character")
vv.db.questTracker.collapsed.Durotar = true
check(vv.LoadProfile("Raid setup") and ns.db.width == 275 and vv.db.questTracker.collapsed.Durotar
    and not vv.db.questTracker.collapsed.Westfall, "Saved design loads across characters while preserving their own quest folds")
ns.SetValue("width", 300)
check(oldCharacter.nameplates.swingTimers.width == 275 and stored.nameplates.swingTimers.width == 260,
    "Changing the second character cannot modify the first character or older snapshot copies")
local ui = vv.profileControls
for _, item in ipairs(Mock.Menu(ui.dropdown)) do if item.name == "Alpha" then item.callback() end end
check(vv.selectedProfile == "Alpha" and ns.db.width == 300 and ui.name:GetText() == "Alpha", "Dropdown selection waits for Load")
ui.load.scripts.OnClick()
check(ns.db.width == 260 and vv.db.profileName == "Alpha", "Load button applies selected profile")
ui.name:SetText("New design"); ui.name.scripts.OnTextChanged()
check(ui.save:GetText() == "Save profile" and ui.save:IsEnabled(), "New name enables Save")
ui.save.scripts.OnClick()
check(vv.profileStore["New design"] and vv.db.profileName == "New design", "Save button stores current settings under specified name")
ui.name:SetText("Alpha"); ui.name.scripts.OnTextChanged()
check(ui.save:GetText() == "Update profile", "Existing names visibly identify the update action")
vv.profileStore.Bad = {version=1, settings={modules={}}}
check(not vv.LoadProfile("Bad") and vv.db.profileName == "New design", "Malformed profiles cannot partially replace settings")
local malformed = vv.Copy(vv.profileStore["New design"])
malformed.settings.nameplates = 7
vv.profileStore.Broken = malformed
vv.db.profileName = "Broken"
local ok, modified = pcall(vv.ProfileModified)
check(ok and modified, "Malformed saved sections cannot break profile status")
vv.db.profileName = "New design"
malformed.settings.nameplates = vv.Copy(vv.db.nameplates)
malformed.settings.nameplates.swingTimers = "broken"
local before = vv.Copy(vv.db)
check(not vv.LoadProfile("Broken") and vv.db.profileName == before.profileName
    and ns.db.width == before.nameplates.swingTimers.width,
    "Malformed nested profiles are rejected before changing active settings")
ns.tweaksDB.damage, ns.tweaksDB.friendly = {}, 123
ns.InitializeTweaks()
check(ns.tweaksDB.damage == nil and ns.tweaksDB.friendly == nil,
    "Invalid saved range spells are cleared before settings or range APIs use them")
VV_PROFILE_CHECKS = checks
