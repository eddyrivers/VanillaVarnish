-- The client can mark an AuraData record secret, in addition to its fields.
-- Its permitted display values still go straight to texture/text widgets.
local secretValue = setmetatable({secret = true}, {
    __sub = function() error("secret timer arithmetic") end,
    __lt = function() error("secret comparison") end,
})
local member = Mock.Member("party1")
Mock.auras.party1 = {{icon = 17, auraInstanceID = 1, applications = 1, duration = 0, expirationTime = 0}}
Mock.Event("PLAYER_LOGIN")
local icon = Mock.Icons(assert(Mock.Row(member)))[1]
assert(icon:IsShown() and icon.texture.textureValue == 17)
Mock.combat = true
Mock.auras.party1 = {{secret = true, icon = secretValue, auraInstanceID = 2,
    applications = secretValue, duration = secretValue, expirationTime = secretValue}}
Mock.Event("UNIT_AURA", "party1")
assert(icon:IsShown(), "Combat AuraData records must not be dropped solely because they are secret")
assert(icon.texture.textureValue == secretValue and icon.count.text == "3")
assert(icon.cooldown.durationObject == "native duration" and member:GetHeight() == 95)
-- A secret UNIT_AURA unit cannot be compared: refresh known party units.
Mock.auras.party1 = {{secret = true, icon = 21, auraInstanceID = 3,
    applications = 1, duration = 0, expirationTime = 0}}
Mock.Event("UNIT_AURA", secretValue)
assert(icon:IsShown() and icon.texture.textureValue == 21,
    "Secret event unit must still trigger display refresh")
-- A partial cosmetic API failure must not hide an otherwise valid icon.
icon.cooldown.Clear = function() error("cooldown clear refused") end
Mock.Event("UNIT_AURA", "party1")
assert(icon:IsShown() and icon.texture.textureValue == 21)
icon.cooldown.Clear = nil
-- Indexed fallback also supplies secret-marked AuraData records.
C_UnitAuras.GetUnitAuras = nil
C_UnitAuras.GetAuraDataByIndex = function(_, index)
    if index == 1 then return Mock.auras.party1[1] end
end
Mock.Event("UNIT_AURA", "party1")
assert(icon:IsShown() and icon.texture.textureValue == 21)
-- Still hide buffs genuinely removed during combat.
Mock.auras.party1 = {}
Mock.Event("UNIT_AURA", "party1")
assert(not icon:IsShown())

-- Forever can refuse both the bulk list and indexed reads in combat while
-- still exposing public instance IDs and per-instance display data.
local ids = {101, 102}
local auraData = {
    [101] = {icon=31, sourceUnit="party2", applications=1, duration=0, expirationTime=0},
    [102] = {icon=37, sourceUnit="player", auraInstanceID=secretValue,
        applications=secretValue, duration=secretValue, expirationTime=secretValue},
}
C_UnitAuras.GetUnitAuras = function() error("bulk aura list refused in combat") end
C_UnitAuras.GetAuraDataByIndex = function() error("indexed aura reads refused in combat") end
C_UnitAuras.GetUnitAuraInstanceIDs = function(unit, filter, limit)
    assert(unit == "party1" and filter == "HELPFUL" and limit == 40)
    return ids
end
C_UnitAuras.GetAuraDataByAuraInstanceID = function(unit, id)
    assert(unit == "party1")
    return auraData[id]
end
Mock.Event("UNIT_AURA", "party1")
local icons = Mock.Icons(Mock.Row(member))
assert(icons[1]:IsShown() and icons[1].texture.textureValue == 37 and icons[1].auraID == 102,
    "Public instance enumeration keeps current buffs visible during combat and retains player-buff priority")
assert(icons[2]:IsShown() and icons[2].texture.textureValue == 31 and icons[2].auraID == 101)
assert(icons[1].cooldown.durationObject == "native duration" and icons[1].count.text == "3",
    "Public instance IDs preserve native cooldowns and counts when metadata is restricted")
icons[1].scripts.OnEnter(icons[1])
assert(GameTooltip.id == 102, "Sorted instance buffs retain the correct tooltip")
auraData[102].icon = 41
Mock.Tick(1)
assert(icons[1]:IsShown() and icons[1].texture.textureValue == 41,
    "Periodic combat refreshes keep current instance display data")
auraData[101] = nil
Mock.Event("UNIT_AURA", "party1")
assert(icons[1]:IsShown() and icons[1].auraID == 102 and not icons[2]:IsShown(),
    "An aura expiring between instance enumeration and lookup cannot hide another buff")
auraData[101] = setmetatable({icon=31}, {__index=function() error("optional aura field refused") end})
ids = {101}
Mock.Event("UNIT_AURA", secretValue)
assert(icons[1]:IsShown() and icons[1].auraID == 101 and not icons[2]:IsShown(),
    "A buff removed during combat disappears without leaving a cached icon")
ids = {}
Mock.Event("UNIT_AURA", "party1")
assert(not icons[1]:IsShown() and member:GetHeight() == 95,
    "An authoritative empty instance list clears buffs without changing protected height")
-- A refused instance provider still falls back to permitted list data.
C_UnitAuras.GetUnitAuraInstanceIDs = function() error("instance list refused") end
C_UnitAuras.GetUnitAuras = function() return {{icon=43, auraInstanceID=103}} end
Mock.Event("UNIT_AURA", "party1")
assert(icons[1]:IsShown() and icons[1].texture.textureValue == 43 and icons[1].auraID == 103,
    "Unavailable instance enumeration cannot break a working aura-list provider")
local instanceReads = 0
C_UnitAuras.GetUnitAuraInstanceIDs = function() return {secretValue} end
C_UnitAuras.GetAuraDataByAuraInstanceID = function() instanceReads = instanceReads + 1; error("restricted ID forwarded") end
Mock.Event("UNIT_AURA", "party1")
assert(instanceReads == 0 and icons[1]:IsShown() and icons[1].auraID == 103,
    "Restricted instance IDs are never forwarded to APIs that require public arguments")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(icons[1]:IsShown(), "Buffs stay visible while leaving combat")
