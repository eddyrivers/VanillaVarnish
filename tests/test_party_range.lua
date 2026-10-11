local vv = VV_TEST_NS
local member = Mock.Member("party1")
Mock.auras.party1 = {{icon=123, auraInstanceID=1}}
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local row = assert(Mock.Row(member))
local nativeBuff = CreateFrame("Frame", nil, member)
nativeBuff.isBuff = true
nativeBuff:SetAlpha(0.8)
local nativeDebuff = CreateFrame("Frame", nil, member)
nativeDebuff.isBuff = false
local pool = {nativeBuff, nativeDebuff}
member.AuraFramePool = {EnumerateActive=function()
    local index = 0
    return function() index=index+1; return pool[index] end
end}
local checks, queries = 0, 0
local function check(value, message) assert(value, message); checks=checks+1 end
C_Spell = {IsSpellInRange=function(spell, unit)
    queries=queries+1
    check(spell == "Healing Touch", "Uses the configured friendly spell")
    return Mock.range[unit]
end}
Mock.range = {party1=false}
local ns = vv.Nameplates
member.Portrait:SetAlpha(0.6)
Mock.Tick(0.21)
check(queries == 0 and member.Portrait:GetAlpha() == 0.6 and row:GetAlpha() == 1, "No configured spell means no reads or fading")
ns.tweaksDB.friendly = "Healing Touch"
ns.SetRangeOpacity(0.5)
check(member.Portrait:GetAlpha() == 0.3 and row:GetAlpha() == 0.5, "Out-of-range portrait and custom buffs fade")
check(nativeBuff:GetAlpha() == 0.4 and nativeDebuff:GetAlpha() == 1, "Only native buffs fade; debuffs are unchanged")
check(member:GetAlpha() == 1 and member.HealthBarContainer.HealthBar:GetAlpha() == 1 and member.ManaBar:GetAlpha() == 1,
    "Secure unit button and health/mana stay unchanged")
Mock.combat = true
member.Portrait:SetAlpha(0.8)
check(member.Portrait:GetAlpha() == 0.4, "Native low-health alpha writes preserve the range factor")
Mock.Tick(0.21)
check(member.Portrait:GetAlpha() == 0.4, "Polling does not compound fading")
Mock.range.party1 = true
Mock.Tick(0.21)
check(member.Portrait:GetAlpha() == 0.8 and nativeBuff:GetAlpha() == 0.8 and row:GetAlpha() == 1,
    "Coming into range restores latest native values during combat")
Mock.range.party1 = 0
Mock.Tick(0.21)
check(row:GetAlpha() == 0.5, "Numeric out-of-range result is supported")
Mock.range.party1 = nil
Mock.Tick(0.21)
check(row:GetAlpha() == 1, "Unknown range does not fade")
Mock.range.party1 = {secret=true}
Mock.Tick(0.21)
check(row:GetAlpha() == 1, "Secret range does not fade")
C_Spell.IsSpellInRange = function() error("range read refused") end
Mock.Tick(0.21)
check(row:GetAlpha() == 1, "Refused range does not fade")
C_Spell.IsSpellInRange = function(_, unit) return Mock.range[unit] end
Mock.range.party1 = false
Mock.Tick(0.21)
vv.Party.SetOption("rangeFade", false)
check(row:GetAlpha() == 1 and member.Portrait:GetAlpha() == 0.8, "Feature off restores appearance immediately")
vv.Party.SetOption("rangeFade", true)
vv.SetModuleEnabled("party", false)
check(row:GetAlpha() == 1, "Party master off restores fading")
vv.SetModuleEnabled("party", true)
ns.SetRangeSpell("friendly", "off")
check(row:GetAlpha() == 1 and member.Portrait:GetAlpha() == 0.8, "Clearing the spell restores immediately")
ns.tweaksDB.friendly = "Healing Touch"
vv.Party.RefreshModule()
pool = {nativeDebuff}
Mock.Tick(0.21)
check(nativeBuff:GetAlpha() == 0.8, "Released native buffs restore their alpha")
member.unit = "party2"; Mock.classes.party2 = "MAGE"; Mock.range.party2 = true
Mock.Event("GROUP_ROSTER_UPDATE")
check(row:GetAlpha() == 1 and member.Portrait:GetAlpha() == 0.8, "Pooled member rebind restores previous range appearance")
member.unit = "party1"
GetCVarBool = function() return true end
vv.Party.RefreshModule()
check(row:GetAlpha() == 1 and member.Portrait:GetAlpha() == 0.8, "Raid-style frames are untouched")
GetCVarBool = function() return false end
vv.Party.RefreshModule()
Mock.active = {}
Mock.Event("GROUP_ROSTER_UPDATE")
check(row:GetAlpha() == 1 and member.Portrait:GetAlpha() == 0.8, "Inactive frames restore appearance")
VV_PARTY_RANGE_CHECKS = checks
