local member = Mock.Member("party1")
Mock.auras.party1 = {{icon=17, auraInstanceID=1, applications=1, duration=0, expirationTime=0}}
Mock.Event("PLAYER_LOGIN")
local row = assert(Mock.Row(member))
local icon = Mock.Icons(row)[1]
assert(icon:IsShown() and icon.texture.textureValue == 17)
Mock.combat = true

-- The original implementation discarded a secret-marked list even when its
-- permitted display records were accessible and the index API was unavailable.
Mock.auras.party1 = {secret=true, {secret=true, icon=25, auraInstanceID=2, applications=1, duration=0, expirationTime=0}}
C_UnitAuras.GetAuraDataByIndex = function() error("index read refused") end
Mock.Event("UNIT_AURA", "party1")
assert(icon:IsShown() and icon.texture.textureValue == 25, "Permitted records in restricted aura lists still render")

-- Optional field access can fail independently of the texture field. Such a
-- failure must not hide an otherwise renderable icon or leave stale metadata.
Mock.auras.party1 = {{icon=31}}
setmetatable(Mock.auras.party1[1], {__index=function() error("optional aura metadata refused") end})
Mock.Event("UNIT_AURA", "party1")
assert(icon:IsShown() and icon.texture.textureValue == 31, "Optional metadata failure cannot hide the buff texture")
assert(icon.auraID == nil and icon.count.text == "" and icon.cooldown.cooldownValue == nil)

-- If numeric indexing into the list is actually refused, the independent
-- indexed API can still provide permitted display data.
Mock.auras.party1 = setmetatable({}, {__index=function() error("list indexing refused") end})
C_UnitAuras.GetAuraDataByIndex = function(unit, index, filter)
    assert(unit == "party1" and filter == "HELPFUL")
    if index == 1 then return {icon=37, auraInstanceID=3, applications=1, duration=0, expirationTime=0} end
end
Mock.Event("UNIT_AURA", "party1")
assert(icon:IsShown() and icon.texture.textureValue == 37, "Refused list indexing falls back to indexed aura reads")
icon.scripts.OnEnter(icon)
assert(GameTooltip.unit == "party1" and GameTooltip.id == 3)
icon.scripts.OnLeave(icon)

-- Mocks cannot prohibit Lua boolean tests; marking literal false as secret
-- verifies the secrecy check and distinguishes unknown from readable hidden.
local originalSecret = issecretvalue
local visibilityProbes = 0
member.IsVisible = function() return false end
issecretvalue = function(value)
    if value == false then visibilityProbes = visibilityProbes + 1; return true end
    return originalSecret(value)
end
Mock.Event("UNIT_AURA", "party1")
Mock.Tick(1)
issecretvalue = originalSecret
assert(visibilityProbes >= 2 and icon:IsShown() and row:IsShown(), "Secret false visibility cannot clear the row")
Mock.Event("UNIT_AURA", "party1")
assert(not row:IsShown() and not icon:IsShown(), "Readable hidden frames still clear their buff row")
member.IsVisible = nil

-- Genuine combat removal still clears the icons, including restricted lists.
Mock.auras.party1 = {secret=true}
Mock.Event("UNIT_AURA", "party1")
assert(not icon:IsShown(), "Restricted empty lists still remove expired buffs")

-- Status identifies the blocking stage without printing secret aura data.
local messages = {}
print = function(value) messages[#messages+1] = value end
VV_TEST_NS.Party.HandleSlash("status")
assert(table.concat(messages, "\n"):find("party1: no buffs returned; source: list", 1, true))
Mock.auras.party1 = {{icon=41, auraInstanceID=4, applications=1, duration=0, expirationTime=0}}
icon.texture.SetTexture = function() error("texture setter refused") end
Mock.Event("UNIT_AURA", "party1")
assert(not icon:IsShown(), "Refused required texture hides the failed icon")
messages = {}
VV_TEST_NS.Party.HandleSlash("status")
local status = table.concat(messages, "\n")
assert(status:find("party1: buff rendering refused; source: list", 1, true))
assert(status:find("texture setter refused", 1, true))
icon.texture.SetTexture = nil
Mock.auras.party1 = setmetatable({}, {__index=function() error("list indexing refused") end})
C_UnitAuras.GetAuraDataByIndex = function() error("index read refused") end
Mock.Event("UNIT_AURA", "party1")
messages = {}
VV_TEST_NS.Party.HandleSlash("status")
assert(table.concat(messages, "\n"):find("party1: aura read refused; source: index", 1, true))
