local vv, addon = VV_TEST_NS, VV_TEST_NS.PoliteUI
local checks, cases = 0, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
vv.RegisterOptions, addon.RegisterOptions = function() end, function() end
vv.InitDB()
Enum.PowerType, Enum.LuaCurveType = {Mana=0, Rage=1, Energy=3}, {Step=1}

-- The simulator alone can inspect these payloads. Runtime code must treat
-- them as opaque: any arithmetic, comparison, or formatting is a test error.
local payload = setmetatable({}, {__mode="k"})
local function forbidden() error("Runtime attempted to inspect a restricted value") end
local secretMeta = {__add=forbidden, __sub=forbidden, __mul=forbidden, __div=forbidden,
    __lt=forbidden, __le=forbidden, __eq=forbidden, __tostring=forbidden}
local function opaque(value)
    local result = setmetatable({secret=true}, secretMeta)
    payload[result] = value
    return result
end
local function nativeValue(value) return issecretvalue(value) and payload[value] or value end
C_CurveUtil = {CreateCurve=function()
    local curve = {points={}}
    function curve:SetType(value) check(value == Enum.LuaCurveType.Step, "Resource opacity uses a step curve") end
    function curve:AddPoint(x, y)
        check(not issecretvalue(x) and not issecretvalue(y), "Curve points contain only public thresholds and native base alpha")
        self.points[#self.points + 1] = {x=x, y=y}
    end
    return curve
end}
local function evaluate(curve, x)
    local y = curve.points[1].y
    for _, point in ipairs(curve.points) do if x >= point.x then y = point.y end end
    return y
end
Mock.units.player = true
Mock.hp, Mock.mana, Mock.manaMax, Mock.powerType = 100, 100, 100, 1
Mock.restrictedHealth, Mock.restrictedMana = true, false
function UnitHealth(...) assert(select("#", ...) == 1); return Mock.restrictedHealth and opaque(Mock.hp) or Mock.hp end
function UnitHealthMax() return Mock.restrictedHealthMax and opaque(100) or 100 end
function UnitPower(_, kind) assert(kind == Enum.PowerType.Mana); return Mock.restrictedMana and opaque(Mock.mana) or Mock.mana end
function UnitPowerMax(_, kind) assert(kind == Enum.PowerType.Mana); return Mock.manaMax end
function UnitPowerType() return Mock.powerType end
function UnitHealthPercent(unit, predicted, curve)
    assert(unit == "player" and predicted == false)
    return opaque(evaluate(curve, Mock.hp / 100))
end
function UnitPowerPercent(unit, kind, unmodified, curve)
    assert(unit == "player" and kind == Enum.PowerType.Mana and unmodified == false)
    return opaque(evaluate(curve, Mock.mana / Mock.manaMax))
end
function UnitIsDeadOrGhost() return false end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
local player = CreateFrame("Frame", nil, UIParent)
PlayerFrame = player
function player:SetAlpha(value)
    local actual = nativeValue(value)
    assert(type(actual) == "number" and actual >= 0 and actual <= 1)
    self.alpha, self.visualAlpha = value, actual
end
player:SetAlpha(1)
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local function advance() for _ = 1, 14 do Mock.Tick(0.05) end end
local ids = {"healthFull", "manaFull", "outCombat", "noTarget"}
local function bit(mask, index) return math.floor(mask / 2 ^ (index - 1)) % 2 == 1 end
for _, form in ipairs({0, 1, 3}) do
    Mock.powerType = form
    for mask = 0, 15 do
        for _, hp in ipairs({0, 74, 75, 100}) do
            for _, mana in ipairs({0, 74, 75, 100}) do
                for combat = 0, 1 do
                    for target = 0, 1 do
                        addon.ResetSettings()
                        Mock.hp, Mock.mana, Mock.combat, Mock.units.target = hp, mana, combat == 1, target == 1
                        local signals = {hp == 100, mana == 100, combat == 0, target == 0}
                        local matches = mask > 0
                        for index, id in ipairs(ids) do
                            if bit(mask, index) then
                                addon.SetCondition("player", "fadeOut", id, true)
                                if not signals[index] then matches = false end
                            end
                        end
                        advance()
                        check(player.visualAlpha == (matches and 0 or 1),
                            string.format("Restricted health/form matrix form=%d mask=%d hp=%d mana=%d combat=%d target=%d", form, mask, hp, mana, combat, target))
                        cases = cases + 1
                    end
                end
            end
        end
    end
end
addon.ResetSettings()
Mock.hp, Mock.mana, Mock.combat, Mock.units.target, Mock.powerType = 100, 100, false, false, 1
for _, id in ipairs(ids) do addon.SetCondition("player", "fadeOut", id, true) end
advance()
check(player.visualAlpha == 0 and issecretvalue(player:GetAlpha()), "The reported bear-form combination is driven by opaque native alpha")
Mock.restrictedHealth = false
for _ = 1, 6 do
    Mock.Tick(0.05)
    check(player.visualAlpha == 0, "Lifting a health restriction does not flash a still-matching frame")
end
Mock.restrictedHealth = true
advance()
local diagnostic = addon.GetDiagnostics().player
check(diagnostic.status == "Native resource-driven visibility" and diagnostic.fadeOut.items[1].native,
    "Diagnostics describe native evaluation without inspecting its verdict")
local nativeHealthPercent = UnitHealthPercent
UnitHealthPercent = function() error("Temporarily unavailable native health display") end
advance()
check(player.visualAlpha == 1 and addon.GetDiagnostics().player.error,
    "A native API failure reveals an already-faded frame and reports the failure")
UnitHealthPercent = nativeHealthPercent
advance()
check(player.visualAlpha == 0 and not addon.GetDiagnostics().player.error, "Native API recovery resumes the rule automatically")
UnitHealthPercent = nil
advance()
check(player.visualAlpha == 1 and not addon.GetDiagnostics().player.fadeOut.items[1].native,
    "A missing native API leaves the frame readable and the condition unavailable")
UnitHealthPercent = nativeHealthPercent
advance()
local acceptedSetAlpha = player.SetAlpha
player.SetAlpha = function(self, value)
    if issecretvalue(value) then error("Simulated temporary native-alpha rejection") end
    acceptedSetAlpha(self, value)
end
advance()
check(player.visualAlpha == 1 and addon.GetDiagnostics().player.error,
    "A rejected opaque alpha falls back to readable native opacity")
player.SetAlpha = acceptedSetAlpha
advance()
check(player.visualAlpha == 0 and not addon.GetDiagnostics().player.error, "Native-alpha setter recovery resumes without reloading")
player.mouseOver = true; advance()
check(player.visualAlpha == 1 and not issecretvalue(player:GetAlpha()), "Hover reveals an opaque-alpha frame immediately")
player.mouseOver = false; advance()
check(player.visualAlpha == 0, "Leaving hover resumes native resource evaluation")
Mock.hp = 99; advance()
check(player.visualAlpha == 1, "Losing full health returns automatically through the native curve")
Mock.hp = 100; Mock.mana = 99; advance()
check(player.visualAlpha == 1, "Losing mana returns automatically in bear form")
Mock.mana = 100; advance()
player:SetAlpha(0.65)
check(player.visualAlpha == 0, "Native opacity changes remain compatible with restricted resource rules")
vv.SetModuleEnabled("politeUI", false)
check(player.visualAlpha == 0.65 and not issecretvalue(player:GetAlpha()), "Disabling restores the latest native base opacity")
vv.SetModuleEnabled("politeUI", true)
addon.ResetSettings()
player:SetAlpha(1)
Mock.restrictedHealthMax = true
addon.SetCondition("player", "fadeOut", "healthFull", true); advance()
check(player.visualAlpha == 0, "A restricted health maximum also uses native evaluation")
Mock.restrictedHealthMax = false
addon.ResetSettings()
for _, spec in ipairs({{"healthLow", 0.749, 0}, {"healthLow", 0.75, 1},
    {"healthCritical", 0.35, 0}, {"healthCritical", 0.351, 1}, {"healthFull", 0.999, 1}, {"healthFull", 1, 0}}) do
    Mock.hp = spec[2] * 100
    addon.SetCondition("player", "fadeOut", nil)
    addon.SetCondition("player", "fadeOut", spec[1], true); advance()
    check(player.visualAlpha == spec[3], "Restricted health threshold: " .. spec[1] .. " at " .. spec[2])
end
addon.ResetSettings()
Mock.restrictedHealth, Mock.restrictedMana, Mock.mana = false, true, 100
addon.SetCondition("player", "fadeOut", "manaFull", true); advance()
check(player.visualAlpha == 0, "Restricted mana alone uses the native power-percent API")
Mock.mana = 90; advance()
check(player.visualAlpha == 1, "Restricted mana loss automatically reveals")
addon.ResetSettings()
Mock.restrictedHealth, Mock.restrictedMana, Mock.hp, Mock.mana = true, true, 100, 100
addon.SetCondition("player", "fadeOut", "healthFull", true)
addon.SetCondition("player", "fadeOut", "manaFull", true); advance()
check(player.visualAlpha == 1, "Unsupported independent restricted resources leave the frame readable")
check(addon.GetDiagnostics().player.fadeOut.items[2].reason == "Two independently restricted resources cannot be combined.",
    "Independent restricted-resource limitations are explicit")
addon.ResetSettings()
Mock.restrictedMana, Mock.manaMax = false, 0
addon.SetCondition("player", "fadeOut", "manaFull", true); advance()
check(player.visualAlpha == 1 and addon.GetDiagnostics().player.fadeOut.items[1].reason == "This unit has no mana pool.",
    "A genuinely mana-less unit remains distinguishable from a shifted druid")
addon.ResetSettings()
addon.db.rules.player = {fadeOut={outCombat=true}, fadeIn={hasTarget=true}}
addon.db.rules.buffs = {fadeOut={}, fadeIn={inCombat=true}}
addon.InitDB()
check(addon.GetRule("player").fadeOut.outCombat and addon.GetRule("player").fadeIn == nil and not addon.db.rules.buffs,
    "Old beta return rules are discarded while fade-out preferences are preserved")
VV_POLITE_UI_NATIVE_RESOURCE_CHECKS, VV_POLITE_UI_NATIVE_RESOURCE_CASES = checks, cases
