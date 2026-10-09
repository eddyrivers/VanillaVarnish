local vv = VV_TEST_NS
local member = Mock.Member("party1")
local bar = member.HealthBarContainer.HealthBar
local texture = bar.barTexture
local nativeCalls, valueCalls = 0, 0
-- Model the dangerous part of UpdateMember: it touches unit binding/health
-- state. The cosmetic feature must never invoke it, through any call wrapper.
member.UpdateMember = function() nativeCalls = nativeCalls + 1 end
securecallfunction = function(fn, ...) return fn(...) end
local protected = setmetatable({secret=true}, {
    __lt=function() error("secret health comparison") end,
    __sub=function() error("secret health arithmetic") end,
})
bar.currValue, bar.unit, bar.lockColor = protected, "party1", true
bar.SetValue = function() valueCalls = valueCalls + 1 end
local nativeUpdate = function() end
local nativeValueChanged = function() end
bar.scripts.OnUpdate, bar.scripts.OnValueChanged = nativeUpdate, nativeValueChanged
bar.color = {0.1, 0.9, 0.2, 0.7}
local originalColor = bar.color
Mock.auras.party1 = {{icon=17, auraInstanceID=1, applications=1, duration=0, expirationTime=0}}
Mock.Event("PLAYER_LOGIN")
local row = assert(Mock.Row(member))
local icon = Mock.Icons(row)[1]
assert(icon:IsShown())
for _ = 1, 10 do
    vv.Party.SetOption("classColors", false)
    assert(bar.color[1] == originalColor[1] and bar.color[4] == originalColor[4])
    assert(texture.desaturated == false)
    vv.Party.SetOption("classColors", true)
    assert(bar.color[1] == RAID_CLASS_COLORS.MAGE.r and texture.desaturated)
end
assert(nativeCalls == 0, "Color toggles must never call native UpdateMember")
assert(valueCalls == 0 and bar.currValue == protected, "Color toggles preserve native health state")
assert(bar.unit == "party1" and bar.lockColor == true)
assert(bar.scripts.OnUpdate == nativeUpdate and bar.scripts.OnValueChanged == nativeValueChanged)

-- Snapshot display values may be secret; pass them to the native setters
-- without comparing, branching, or doing arithmetic on their values.
vv.Party.SetOption("classColors", false)
bar.color = {protected, protected, protected, protected}
texture.IsDesaturated = function() return protected end
vv.Party.SetOption("classColors", true)
vv.Party.SetOption("classColors", false)
assert(bar.color[1] == protected and bar.color[4] == protected and texture.desaturated == protected)
texture.IsDesaturated = nil
bar.color, texture.desaturated = originalColor, false

-- In-combat toggles keep the existing deferral policy; regeneration restores
-- visuals without changing health data or stopping party aura updates.
vv.Party.SetOption("classColors", true)
Mock.combat = true
vv.Party.SetOption("classColors", false)
Mock.auras.party1[1].icon = 25
Mock.Event("UNIT_AURA", "party1")
assert(icon:IsShown() and icon.texture.textureValue == 25)
assert(bar.color[1] == RAID_CLASS_COLORS.MAGE.r)
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(bar.color[1] == originalColor[1] and not texture.desaturated)
assert(nativeCalls == 0 and valueCalls == 0 and bar.currValue == protected)

vv.Party.SetOption("classColors", true)
vv.SetModuleEnabled("party", false)
assert(bar.color[1] == originalColor[1] and not row:IsShown())
vv.SetModuleEnabled("party", true)
assert(row:IsShown() and bar.color[1] == RAID_CLASS_COLORS.MAGE.r)
Mock.active = {}
Mock.Event("GROUP_ROSTER_UPDATE")
assert(bar.color[1] == originalColor[1] and not row:IsShown())
assert(nativeCalls == 0 and valueCalls == 0 and bar.currValue == protected,
    "Module toggles and pooled-frame cleanup preserve native health updates")
