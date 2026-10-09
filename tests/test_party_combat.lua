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
assert(icon.cooldown.durationObject == "native duration" and member:GetHeight() == 74)
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
