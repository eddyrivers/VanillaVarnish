local vv, ns = VV_TEST_NS, NST_TEST_NS
local units = {}
local restricted = {secret = true}
local threatReads = 0

function UnitCanAttack(_, unit) return units[unit] and not units[unit].friendly end
function UnitIsPlayer(unit) return units[unit] and units[unit].player == true end
function UnitIsDeadOrGhost(unit) return units[unit] and units[unit].dead == true end
function UnitAffectingCombat(unit) return units[unit] and units[unit].combat or false end
function UnitThreatSituation(_, unit)
    threatReads = threatReads + 1
    return units[unit].threat
end
function UnitThreatLeadSituation(_, unit) return units[unit].lead end
function UnitCastingInfo(unit)
    local info = units[unit]
    if info.castError then error("Cast data is unavailable") end
    if info.cast then return info.cast, nil, nil, nil, nil, false end
end
function UnitChannelInfo(unit)
    if units[unit].channel then return "Channel", nil, nil, nil, nil, false end
end

local function Add(unit, info, plate)
    units[unit] = info
    plate = plate or Mock.Plate(unit)
    Mock.units[unit], Mock.plates[unit] = true, plate
    Mock.Event("NAME_PLATE_UNIT_ADDED", unit)
    return plate.UnitFrame
end

local function Check(frame, scale, alpha, message)
    assert(math.abs(frame:GetScale() - scale) < 0.00001, message .. " (scale)")
    assert(math.abs(frame:GetAlpha() - alpha) < 0.00001, message .. " (alpha)")
end

Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
ns.SetFeature("threatColorsEnabled", false)
local one, two = "nameplate1", "nameplate2"
local secure = {combat = true, threat = 3, lead = 0}
local loose = {combat = true, threat = 1, lead = 3}
local first = Add(one, secure)
local second = Add(two, loose)
local idle = Add("nameplate3", {combat = false})
local friendly = Add("nameplate4", {combat = true, friendly = true})
local player = Add("nameplate5", {combat = true, player = true})
local dead = Add("nameplate6", {combat = true, dead = true})
first:SetScale(1.2)
first:SetAlpha(0.8)
ns.SetRangeSpell("damage", "Moonfire")
Mock.rangeResult = false
Mock.Tick(0.2)
assert(not ns.tweaksDB.focusEnabled and threatReads == 0, "Focus starts off")
Check(first, 1.2, 0.4, "Existing range fading works with focus off")

SlashCmdList.VANILLAVARNISH("nameplates focus")
assert(ns.featurePanels.focusEnabled:IsShown())
local controls = ns.featureControls
controls.focusToggle.button:SetChecked(true)
Mock.rangeResult = true
controls.focusToggle.button.scripts.OnClick(controls.focusToggle.button)
Check(first, 0.9, 0.5, "Securely held enemies shrink and use focus opacity")
Check(second, 1, 1, "Lost threat stays prominent within range")
Check(idle, 1, 1, "Idle enemies within range retain normal opacity")
Check(friendly, 1, 1, "Friendly plates keep their normal appearance")
Check(player, 1, 1, "Enemy players within range retain normal opacity")
Check(dead, 1, 1, "Dead enemies within range retain normal opacity")

Mock.plates.target, Mock.units.target = Mock.plates[one], true
Mock.Event("PLAYER_TARGET_CHANGED")
Check(first, 1.2, 1, "The selected enemy is immediately promoted")
Mock.plates.target, Mock.units.target = nil, nil
Mock.Event("PLAYER_TARGET_CHANGED")
Check(first, 0.9, 0.5, "Clearing the target demotes a securely held enemy")

secure.threat = 2
Mock.Event("UNIT_THREAT_SITUATION_UPDATE", one)
Check(first, 1.2, 1, "Shaky aggro restores normal size and full opacity")
secure.threat, secure.lead = 3, 1
Mock.Event("UNIT_THREAT_LIST_UPDATE", one)
Check(first, 1.2, 1, "A narrow lead also gets priority")
secure.lead, secure.threat = 0, restricted
Mock.Tick(0.2)
Check(first, 1.2, 1, "Restricted threat leaves the enemy prominent")

local menu = Mock.Menu(controls.focusMode.dropdown)
menu[2].callback()
assert(ns.tweaksDB.focusMode == "damage")
Check(second, 0.75, 0.5, "Damage and healer mode ignores aggro")
local reads = threatReads
secure.cast = restricted
Mock.Event("UNIT_SPELLCAST_START", one)
Check(first, 1.2, 1, "A cast with a restricted spell name is still prominent")
secure.cast, secure.channel = nil, true
Mock.Event("UNIT_SPELLCAST_CHANNEL_START", one)
Check(first, 1.2, 1, "Channels get cast priority")
secure.channel = nil
Mock.Event("UNIT_SPELLCAST_INTERRUPTED", one)
Check(first, 0.9, 0.5, "Interrupting restores the background appearance")
secure.castError = true
Mock.Tick(0.2)
Check(first, 1.2, 1, "An unreadable cast status fails open")
secure.castError = nil
Mock.Tick(0.2)
Check(first, 0.9, 0.5, "The appearance recovers when cast status becomes readable")
assert(threatReads == reads, "Damage and healer mode skips threat reads")

controls.focusScale.slider:SetValue(0.6)
controls.focusOpacity.slider:SetValue(0.3)
first:SetAlpha(0.64)
first:SetScale(1.5)
Check(first, 0.9, 0.3, "Native writes update the baseline while focus is active")
assert(not ns.SetFocusOption("focusScale", 0) and not ns.SetFocusOption("focusOpacity", 2))
assert(vv.SaveProfile("Combat design"))
Mock.rangeResult = false
SlashCmdList.VANILLAVARNISH("nameplates focus off")
Check(first, 1.5, 0.32, "Disabling focus restores native scale and range fading")
assert(vv.ProfileModified() and vv.LoadProfile("Combat design") and not vv.ProfileModified())
Check(first, 0.9, 0.3, "Profiles restore the switch, mode, size, and opacity")

local reused = Add("nameplate7", {combat = true}, Mock.plates[one])
Mock.Event("NAME_PLATE_UNIT_REMOVED", one)
Check(reused, 0.9, 0.3, "Late removal of an old token cannot reset a reused frame")
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate7")
Check(reused, 1.5, 0.64, "Removing a plate restores the latest native appearance")
SlashCmdList.VANILLAVARNISH("nameplates off")
Check(second, 1, 1, "Disabling the module restores the original appearance")

local old = vv.profileStore["Combat design"].settings.nameplates
old.focusEnabled, old.focusMode, old.focusScale, old.focusOpacity = nil, nil, nil, nil
assert(vv.LoadProfile("Combat design") and not vv.ProfileModified())
assert(not ns.tweaksDB.focusEnabled and ns.tweaksDB.focusMode == "tank"
    and ns.tweaksDB.focusScale == 0.75 and ns.tweaksDB.focusOpacity == 0.5)

local protected = Mock.Plate("nameplate8")
local protectedFrame = protected.UnitFrame
protectedFrame.protected = true
local nativeSetScale = protectedFrame.SetScale
local blockedScaleWrites = 0
function protectedFrame:SetScale(value)
    if InCombatLockdown() then blockedScaleWrites = blockedScaleWrites + 1; return end
    nativeSetScale(self, value)
end
Add("nameplate8", {combat = true}, protected)
ns.SetFocusOption("focusMode", "damage")
Mock.lockdown = true
ns.SetFeature("focusEnabled", true)
Check(protectedFrame, 1, 0.5, "Protected scale is deferred while opacity still updates")
Mock.lockdown = false
Mock.Event("PLAYER_REGEN_ENABLED")
Check(protectedFrame, 0.75, 0.5, "Deferred scale can apply outside lockdown")
Mock.lockdown = true
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate8")
Check(protectedFrame, 0.75, 1, "Removing the unit defers protected scale restoration")
Mock.lockdown = false
Mock.Event("PLAYER_REGEN_ENABLED")
Check(protectedFrame, 1, 1, "Removing a protected unit still restores its scale after combat")
assert(blockedScaleWrites == 0, "Combat focus never attempts a protected resize")
