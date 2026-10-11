local vv, ns = VV_TEST_NS, NST_TEST_NS
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message or ("Threat color check " .. checks .. " failed"))
end

local info = {combat=true, player=false, dead=false, tapped=false, attackable=true, status=3, tanking=true}
local role, tankAura = "TANK", false
function UnitGroupRolesAssigned(unit) assert(unit == "player"); return role end
function UnitHasEffectivelyTankAura(unit) assert(unit == "player"); return tankAura end
local nativeTank = PlayerUtil and PlayerUtil.IsPlayerEffectivelyTank
PlayerUtil = PlayerUtil or {}
PlayerUtil.IsPlayerEffectivelyTank = nativeTank or function()
    return tankAura or role == "TANK"
end
function UnitCanAttack(_, unit) return info.attackable end
function UnitIsPlayer(unit) return info.player end
function UnitIsDeadOrGhost(unit) return info.dead end
function UnitIsTapDenied(unit) return info.tapped end
function UnitAffectingCombat(unit) return unit == "player" and Mock.combat or info.combat end
function UnitThreatSituation(_, unit) return info.status end
function UnitDetailedThreatSituation(_, unit) return info.tanking, info.status end

local function Bar(frame, color)
    local bar = Mock.New(frame)
    bar.rgb, bar.writes = color or {0.8, 0.1, 0.1, 0.75}, 0
    function bar:GetStatusBarColor() return unpack(self.rgb) end
    function bar:SetStatusBarColor(r, g, b, a)
        self.rgb, self.writes = {r, g, b, a}, self.writes + 1
    end
    function bar:SetValue() error("Threat coloring must not rewrite health") end
    function bar:GetValue() error("Threat coloring must not read health") end
    return bar
end
local function IsBlue(bar)
    return bar.rgb[1] == 0.25 and bar.rgb[2] == 0.65 and bar.rgb[3] == 1
end
local function ColorIs(bar, color)
    for index = 1, 4 do Check(bar.rgb[index] == color[index], "Restore the most recent native color and alpha") end
end
local function ThreatEvent() Mock.Event("UNIT_THREAT_SITUATION_UPDATE", "nameplate1") end

Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
Check(ns.tweaksDB.threatColorsEnabled == true, "Threat coloring starts enabled")
local plate = Mock.Plate("nameplate1")
local frame = plate.UnitFrame
local bar = Bar(frame)
frame.HealthBarsContainer.healthBar = bar
Mock.units.nameplate1 = true
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
Check(IsBlue(bar) and bar.rgb[4] == 0.75, "Tanks holding aggro are blue without changing alpha")
local native = {0.85, 0.12, 0.08, 0.6}
bar:SetStatusBarColor(unpack(native))
Check(IsBlue(bar) and bar.rgb[4] == native[4], "Native health updates cannot overwrite the blue tint")
info.tanking, info.status = false, 1
ThreatEvent(); ColorIs(bar, native)
info.tanking, info.status = true, 2
Mock.Event("UNIT_THREAT_LIST_UPDATE", "nameplate1")
Check(IsBlue(bar), "An insecure tank still has aggro")
info.tanking, info.status = false, 0
ThreatEvent(); ColorIs(bar, native)

-- Damage dealers and healers get the inverse rule; their own aggro is unsafe.
for _, assigned in ipairs({"DAMAGER", "HEALER"}) do
    role = assigned
    Mock.Event("PLAYER_ROLES_ASSIGNED")
    Check(IsBlue(bar), "Non-tanks without aggro are blue")
    info.tanking, info.status = true, 3
    ThreatEvent(); ColorIs(bar, native)
    info.tanking, info.status = false, 1
    ThreatEvent(); Check(IsBlue(bar), "Gaining threat still counts as not holding aggro")
end
role, tankAura = "DAMAGER", true
Mock.Event("UPDATE_SHAPESHIFT_FORM")
ColorIs(bar, native)
info.tanking, info.status = true, 3
ThreatEvent(); Check(IsBlue(bar), "A tank aura activates tank mode independently of the assigned role")
role, tankAura = "TANK", false

-- Prefer actual tanking even if a stale or restricted status disagrees.
info.tanking, info.status = false, 3
ThreatEvent(); ColorIs(bar, native)
UnitDetailedThreatSituation = nil
for _, status in ipairs({0, 1, 2, 3}) do
    info.status = status
    ThreatEvent(); Check(IsBlue(bar) == (status >= 2), "Threat status is a fallback when detailed tanking is unavailable")
end
role, info.status = "DAMAGER", nil
Mock.Event("PLAYER_ROLES_ASSIGNED")
Check(IsBlue(bar), "A readable missing threat entry on a fighting NPC means the non-tank has no aggro")
info.combat = false
Mock.Event("UNIT_FLAGS", "nameplate1"); ColorIs(bar, native)
info.combat, info.status = true, 0
ThreatEvent(); Check(IsBlue(bar))

-- Preserve friendly, player, dead, tapped, and restricted unit displays.
for field, value in pairs({attackable=false, player=true, dead=true, tapped=true}) do
    local original = info[field]
    info[field] = value
    Mock.Event("UNIT_FACTION", "nameplate1"); ColorIs(bar, native)
    info[field] = original
    ThreatEvent(); Check(IsBlue(bar))
end
local secret = {secret=true}
for _, field in ipairs({attackable, "attackable", "player", "combat", "dead", "tapped", "status"}) do
    local original = info[field]
    info[field] = secret
    ThreatEvent(); ColorIs(bar, native)
    info[field] = original
    ThreatEvent(); Check(IsBlue(bar), "A restricted result does not break later updates")
end
local threatGetter = UnitThreatSituation
UnitThreatSituation = function() error("restricted threat getter") end
ThreatEvent(); ColorIs(bar, native)
UnitThreatSituation = threatGetter
ThreatEvent(); Check(IsBlue(bar))
local tankGetter = PlayerUtil.IsPlayerEffectivelyTank
PlayerUtil.IsPlayerEffectivelyTank = function() return secret end
role, tankAura = secret, secret
Mock.Event("UPDATE_SHAPESHIFT_FORM"); ColorIs(bar, native)
PlayerUtil.IsPlayerEffectivelyTank = tankGetter
role, tankAura = "DAMAGER", false
Mock.Event("PLAYER_ROLES_ASSIGNED"); Check(IsBlue(bar))

-- Native color channels may be restricted display values: store and restore
-- them directly without comparisons, arithmetic, or native health refreshes.
bar:SetStatusBarColor(secret, secret, secret, secret)
Check(IsBlue(bar) and bar.rgb[4] == secret)
ns.SetFeature("threatColorsEnabled", false)
for index = 1, 4 do Check(bar.rgb[index] == secret) end
bar:SetStatusBarColor(unpack(native))
ns.SetFeature("threatColorsEnabled", true)
Check(IsBlue(bar))
vv.SetModuleEnabled("nameplates", false); ColorIs(bar, native)
vv.SetModuleEnabled("nameplates", true); Check(IsBlue(bar))
SlashCmdList.VANILLAVARNISH("nameplates threat off"); ColorIs(bar, native)
Check(ns.tweaksDB.threatColorsEnabled == false)
vv.InitDB(); ns.InitializeTweaks()
Check(ns.tweaksDB.threatColorsEnabled == false, "Keep a saved disabled preference")
VV_TEST_NS.Nameplates.HandleSlash("aggro on"); Check(IsBlue(bar))
local toggle = ns.featureControls.threatColorsEnabled.button
toggle:SetChecked(false); toggle.scripts.OnClick(toggle); ColorIs(bar, native)
toggle:SetChecked(true); toggle.scripts.OnClick(toggle); Check(IsBlue(bar))

-- Removed/pooled plates and changed bar objects must not retain VV's color.
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate1"); ColorIs(bar, native)
local pooled = {0.2, 0.8, 0.2, 0.9}
bar:SetStatusBarColor(unpack(pooled)); ColorIs(bar, pooled)
info.status, role = 3, "TANK"
Mock.plates.nameplate2, Mock.units.nameplate2 = plate, true
Mock.units.nameplate1, Mock.plates.nameplate1 = nil, nil
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate2"); Check(IsBlue(bar))
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate1"); Check(IsBlue(bar), "A stale removal cannot reset a reused bar")
local replacement = Bar(frame, native)
frame.HealthBarsContainer.healthBar = replacement
Mock.Event("UNIT_THREAT_LIST_UPDATE", "nameplate2")
ColorIs(bar, pooled); Check(IsBlue(replacement))
vv.conflicts.nameplates = "NameplateTweaks"
ns.RefreshThreatColors(); ColorIs(replacement, native)
vv.conflicts.nameplates = nil
ns.RefreshThreatColors(); Check(IsBlue(replacement))
frame.forbidden = true
ns.RefreshThreatColors(); ColorIs(replacement, native)
frame.forbidden = false
ns.RefreshThreatColors(); Check(IsBlue(replacement))
info.combat = false
Mock.Event("PLAYER_REGEN_ENABLED"); ColorIs(replacement, native)

NST_THREAT_CHECKS = checks
