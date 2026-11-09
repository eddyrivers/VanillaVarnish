local ns = NST_TEST_NS
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
ns.SetFeature("threatColorsEnabled", false)
ns.SetRangeSpell("damage", "Moonfire")

local plate = Mock.Plate("nameplate1")
local frame = plate.UnitFrame
Mock.units.nameplate1, Mock.units.target, Mock.plates.target = true, true, plate
local fighting, casting = false, false
function UnitAffectingCombat() return fighting end
function UnitIsDeadOrGhost() return false end
function UnitThreatSituation() return 3 end
function UnitThreatLeadSituation() return 0 end
function UnitCastingInfo() if casting then return "Cast", nil, nil, nil, nil, false end end
function UnitChannelInfo() end
Mock.rangeResult = false
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")

local function alpha(expected, message)
    assert(math.abs(frame:GetAlpha() - expected) < 0.00001, message)
end

for _, mode in ipairs({"tank", "damage"}) do
    ns.SetFocusOption("focusMode", mode)
    ns.SetFeature("focusEnabled", true)
    alpha(0.5, "An idle selected enemy must fade outside Moonfire range with combat focus enabled")
    fighting = true
    Mock.Tick(0.2)
    alpha(0.5, "A selected enemy in combat must still fade outside Moonfire range")
    assert(frame:GetScale() == 1, "Range fading preserves the selected enemy's full size")

    for _, verdict in ipairs({false, 0, true, 1, {secret=true}}) do
        Mock.rangeResult = verdict
        Mock.Tick(0.2)
        alpha((verdict == false or verdict == 0) and 0.5 or 1,
            "Target focus must honor readable range verdicts and ignore restricted results")
    end
    Mock.rangeResult = nil
    Mock.Tick(0.2)
    alpha(1, "Unavailable range retains the target's focus opacity")

    Mock.rangeResult = false
    Mock.Tick(0.2)
    frame:SetAlpha(0.8)
    alpha(0.4, "Native opacity writes retain the range factor without compounding it")
    Mock.Tick(0.2)
    alpha(0.4, "Repeated updates do not compound range fading")
    ns.SetFeature("rangeEnabled", false)
    alpha(1, "Disabling range fading immediately restores target focus opacity")
    ns.SetFeature("rangeEnabled", true)
    alpha(0.4, "Reenabling range fading immediately restores the range factor")

    Mock.plates.target, Mock.units.target, casting = nil, nil, true
    Mock.Event("PLAYER_TARGET_CHANGED")
    alpha(0.4, "A casting enemy outside range must also fade")
    assert(frame:GetScale() == 1, "Range fading preserves casting priority for size")
    casting = false
    ns.SetFocusOption("focusOpacity", 0.2)
    alpha(0.2, "Range fading must not brighten an already fainter background enemy")
    ns.SetRangeOpacity(0)
    alpha(0, "Zero out-of-range opacity also applies to focus plates")
    ns.SetRangeOpacity(0.5)
    ns.SetFocusOption("focusOpacity", 0.5)

    Mock.plates.target, Mock.units.target, fighting = plate, true, false
    frame:SetAlpha(1)
    Mock.Event("PLAYER_TARGET_CHANGED")
end

Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
alpha(1, "Removing the plate restores its native opacity")
