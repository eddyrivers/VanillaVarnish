local vv = VV_TEST_NS
local member = Mock.Member("party3")
Mock.auras.party3 = {{icon = 12, auraInstanceID = 99, applications = 1, duration = 0, expirationTime = 0}}
Mock.Event("GROUP_ROSTER_UPDATE")
local row = assert(Mock.Row(member))
local bar = member.HealthBarContainer.HealthBar
assert(member:GetHeight() == 95 and row:IsShown())
vv.Party.SetOption("buffs", false)
assert(member:GetHeight() == 53 and not row:IsShown())
assert(bar.color[1] == RAID_CLASS_COLORS.MAGE.r)
vv.Party.SetOption("classColors", false)
assert(bar.color[1] == 0 and bar.color[2] == 1 and not bar.barTexture.desaturated)
vv.Party.SetOption("buffs", true)
assert(member:GetHeight() == 95 and row:IsShown() and bar.color[2] == 1)
vv.Party.SetOption("classColors", true)
Mock.combat = true
vv.SetModuleEnabled("party", false)
assert(not row:IsShown() and member:GetHeight() == 95)
Mock.Tick(2)
assert(not row:IsShown())
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(member:GetHeight() == 53 and bar.color[2] == 1 and not bar.barTexture.desaturated)
assert(vv.db.party.buffs and vv.db.party.classColors)
vv.Party.SetOption("buffs", false)
vv.SetModuleEnabled("party", true)
assert(member:GetHeight() == 53 and not row:IsShown() and bar.color[1] == RAID_CLASS_COLORS.MAGE.r)
-- Changes to native height while buffs are disabled become the next baseline.
member:SetHeight(61)
vv.Party.SetOption("buffs", true)
assert(member:GetHeight() == 103)
vv.Party.SetOption("buffs", false)
assert(member:GetHeight() == 61)
