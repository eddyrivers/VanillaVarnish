local ns = NST_TEST_NS
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local originalInfo, originalHarmful = C_Spell.GetSpellInfo, C_Spell.IsSpellHarmful
C_Spell.GetSpellInfo = function(value)
    if value == "Sinister Strike" or value == 1752 then return {name="Sinister Strike", spellID=1752, maxRange=0} end
    if value == "Passive" then return {name="Passive", spellID=999, maxRange=0} end
    return originalInfo(value)
end
C_Spell.IsSpellHarmful = function(id) return id == 1752 or id == 999 or originalHarmful(id) end
C_Spell.IsSpellPassive = function(id) return id == 999 end
local plate = Mock.Plate("nameplate1")
Mock.plates.target, Mock.units.target = plate, true
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
ns.SetRangeSpell("damage", "Sinister Strike")
assert(ns.tweaksDB.damage == "Sinister Strike", "Zero maxRange must accept a targeted melee ability")
local queried
C_Spell.IsSpellInRange = function(spell, unit)
    queried = {spell, unit}
    return Mock.rangeResult
end
for _, case in ipairs({{false, 0.5}, {true, 1}, {0, 0.5}, {1, 1}, {{secret=true}, 1}}) do
    Mock.rangeResult = case[1]
    Mock.Tick(0.2)
    assert(plate.UnitFrame:GetAlpha() == case[2], "Melee fading must follow native spell reach verdicts")
    assert(queried[1] == "Sinister Strike" and queried[2] == "nameplate1")
end
Mock.rangeResult = nil
Mock.Tick(0.2)
assert(plate.UnitFrame:GetAlpha() == 1, "Unavailable melee reach must retain normal opacity")
IsSpellInRange = function(spell) assert(spell == "Sinister Strike"); return 0 end
Mock.Tick(0.2)
assert(plate.UnitFrame:GetAlpha() == 0.5, "Legacy spell-range API can supply the melee reach verdict")
ns.SetRangeSpell("damage", "1752")
assert(ns.tweaksDB.damage == "Sinister Strike", "Melee spell IDs work too")
ns.SetRangeSpell("damage", "Passive")
assert(ns.tweaksDB.damage == "Sinister Strike", "Passive spells cannot replace the selected range ability")
