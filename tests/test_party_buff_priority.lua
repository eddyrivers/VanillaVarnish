local vv = VV_TEST_NS
local member = Mock.Member("party1")
C_Spell = {GetSpellName=function(id) return ({[433]="Essen", [430]="Trinken", [22734]="Trinken"})[id] end}
local buffs = {}
for index = 1, 25 do buffs[index] = {icon=index, auraInstanceID=index, name="Buff " .. index, sourceUnit="party2"} end
buffs[20].name, buffs[20].spellId = "Drink", 22734
buffs[24].name, buffs[24].spellId = "Food", 1129
buffs[3].sourceUnit, buffs[22].sourceUnit = "player", "player"
Mock.auras.party1 = buffs
Mock.Event("PLAYER_LOGIN")
local row, checks = assert(Mock.Row(member)), 0
local icons = Mock.Icons(row)
local function check(value, label) assert(value, label); checks=checks+1 end
check(#icons == 16 and member:GetHeight() == 95 and row:GetHeight() == 40, "Sixteen icons fit in two reserved rows")
check(icons[1].texture.textureValue == 20 and icons[2].texture.textureValue == 24,
    "Eating and drinking beyond the display limit move ahead of other buffs")
check(icons[3].texture.textureValue == 3 and icons[4].texture.textureValue == 22 and icons[3].width == 19,
    "Player buffs follow recovery buffs, including late native entries, and retain larger size")
check(icons[5].texture.textureValue == 1 and icons[6].texture.textureValue == 2, "Remaining buffs retain native order")
check(icons[8].point[5] == 0 and icons[9].point[4] == 0 and icons[9].point[5] == -21
    and icons[16].point[5] == -21, "Eight icons per row wrap without widening the row")
for _, icon in ipairs(icons) do
    check(icon.point[4] + icon:GetWidth() <= row:GetWidth(), "Icons remain inside row width")
end
Mock.combat = true
local height = member:GetHeight()
Mock.Event("UNIT_AURA", "party1")
check(member:GetHeight() == height, "Aura changes in combat never resize the secure party frame")
C_UnitAuras.GetUnitAuras = nil
C_UnitAuras.GetAuraDataByIndex = function(_, index) return buffs[index] end
Mock.Event("UNIT_AURA", "party1")
icons[1].auraID = nil
icons[1].scripts.OnEnter(icons[1])
check(GameTooltip.index == 20, "Prioritized recovery tooltip retains original aura index")
buffs[20].name, buffs[24].name = "Well Fed", "Food Aura Test"
Mock.Event("UNIT_AURA", "party1")
check(icons[1].texture.textureValue == 3 and icons[2].texture.textureValue == 22,
    "Long-lasting food bonuses and arbitrary names are not treated as eating/drinking")
buffs[20].name = {secret=true}; buffs[20].spellId = {secret=true}
Mock.Event("UNIT_AURA", "party1")
check(icons[1].texture.textureValue == 3, "Restricted recovery metadata leaves normal priority unchanged")
-- Locale names come from the client; food ranks share the name of spell 433.
Mock.auras.party1 = {{icon=100, name="Essen"}, {icon=101, name="Other"}, {icon=102, name="Trinken", sourceUnit="player"}}
C_UnitAuras.GetUnitAuras = function(unit) return Mock.auras[unit] end
Mock.Event("UNIT_AURA", "party1")
check(icons[1].texture.textureValue == 100 and icons[2].texture.textureValue == 102,
    "Localized food/drink names are prioritized")
VV_PARTY_PRIORITY_CHECKS = checks
