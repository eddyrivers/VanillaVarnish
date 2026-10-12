local vv = VV_TEST_NS
local member = Mock.Member("party1")
local buffs = {}
for index = 1, 12 do buffs[index] = {icon=index, auraInstanceID=index, sourceUnit="party2"} end
buffs[3].sourceUnit, buffs[10].sourceUnit = "player", "player"
Mock.auras.party1 = buffs
Mock.Event("PLAYER_LOGIN")
local row = assert(Mock.Row(member))
local icons = Mock.Icons(row)
assert(icons[1].texture.textureValue == 3 and icons[2].texture.textureValue == 10,
    "Player buffs must precede others, including buffs beyond the first eight")
assert(icons[1].width == 19 and icons[2].height == 19 and icons[3].width == 14)
assert(icons[2].point[4] == 21 and icons[3].point[4] == 42 and icons[4].point[4] == 58)
assert(icons[3].texture.textureValue == 1 and icons[4].texture.textureValue == 2, "Partition retains native order")
-- Indexed tooltips retain the original index after sorting.
C_UnitAuras.GetUnitAuras = nil
C_UnitAuras.GetAuraDataByIndex = function(_, index) return buffs[index] end
Mock.Event("UNIT_AURA", "party1")
icons[2].auraID = nil
icons[2].scripts.OnEnter(icons[2])
assert(GameTooltip.index == 10, "Sorted tooltips use the source aura index")
C_UnitAuras.GetUnitAuras = function(unit, filter)
    if filter == "HARMFUL|RAID" then return Mock.dispellable[unit] or {} end
    return Mock.auras[unit] or {}
end
Mock.dispellable = {party1={}}
-- Secret ownership is neither compared nor sorted to the front.
buffs[3].sourceUnit = {secret=true}
buffs[10].sourceUnit = "party2"
Mock.Event("UNIT_AURA", "party1")
assert(icons[1].width == 14 and icons[3].texture.textureValue == 3)

local native = {}
member.AuraFramePool = {EnumerateActive=function()
    local index = 0
    return function() index=index+1; return native[index] end
end}
for index, kind in ipairs({"Curse", "Poison", "Magic", "Disease"}) do
    local icon = CreateFrame("Frame", nil, member)
    icon:SetSize(14, 14)
    icon:SetPoint("TOPLEFT", member, "TOPRIGHT", (index-1)*16, 0)
    icon.auraInstanceID, icon.isBuff, icon.layoutIndex = 100+index, false, index
    icon.DebuffBorder = icon:CreateTexture()
    native[index] = icon
    Mock.dispellable.party1[index] = {auraInstanceID=100+index, dispelName=kind}
end
native[1].isBuff = nil -- Native Setup forwards a nil showBuffs flag for debuffs.
Mock.Event("UNIT_AURA", "party1")
local expected = {{0.6, 0, 1}, {0, 0.6, 0}, {0.2, 0.6, 1}, {0.6, 0.4, 0}}
for index, icon in ipairs(native) do
    assert(icon.width == 28 and icon.height == 28, "Player-dispellable native debuffs are doubled")
    for channel = 1, 3 do assert(icon.DebuffBorder.color[channel] == expected[index][channel]) end
    if index > 1 then assert(icon.point[2] == native[index-1] and icon.point[4] == 2, "Enlarged debuffs do not overlap") end
end
Mock.dispellable.party1[2] = nil
Mock.Event("UNIT_AURA", "party1")
assert(native[2].width == 14 and native[1].width == 28, "Only currently dispellable auras are enlarged")
vv.Party.SetOption("buffs", false)
for index, icon in ipairs(native) do
    assert(icon.width == 14 and icon.point[2] == member and icon.point[4] == (index-1)*16,
        "Disabling restores native aura geometry")
end
vv.Party.SetOption("buffs", true)

local compact = CreateFrame("Frame")
CompactPartyFrame = compact
local raidMember = Mock.Member("party2")
Mock.active[#Mock.active] = nil
raidMember.healthBar = raidMember.HealthBarContainer.HealthBar
raidMember.HealthBarContainer = nil
compact.memberUnitFrames = {raidMember}
EditModeManagerFrame = {UseRaidStylePartyFrames=function() return Mock.raidStyle end}
Mock.raidStyle = true
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
assert(not row:IsShown() and member:GetHeight() == 53, "Raid-style selection hides the extra row and restores portrait spacing")
assert(Mock.Row(raidMember) == nil and raidMember:GetHeight() == 53, "Compact frames never get addon aura rows or extra height")
assert(raidMember.healthBar.color[1] == RAID_CLASS_COLORS.MAGE.r, "Raid-style party bars use class colors")
raidMember.healthBar:SetStatusBarColor(0, 1, 0)
Mock.combat = true
Mock.Tick(0.2)
assert(raidMember.healthBar.color[1] == RAID_CLASS_COLORS.MAGE.r, "Native compact resets are recolored during combat")
vv.Party.SetOption("classColors", false)
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(raidMember.healthBar.color[1] == 0 and raidMember.healthBar.color[2] == 1, "Compact colors restore when disabled")
Mock.raidStyle = false
compact:Hide()
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
assert(row:IsShown() and member:GetHeight() == 95, "Switching back restores portrait buffs")
-- Frame discovery in combat needs no aura widgets or secure unit mutations.
local newcomer = Mock.Member("party3")
Mock.active[#Mock.active] = nil
newcomer.healthBar = newcomer.HealthBarContainer.HealthBar
newcomer.HealthBarContainer = nil
compact.memberUnitFrames[2] = newcomer
Mock.raidStyle, Mock.combat = true, true
vv.Party.SetOption("classColors", true)
assert(newcomer.healthBar.color[1] == RAID_CLASS_COLORS.MAGE.r and Mock.Row(newcomer) == nil)
assert(not row:IsShown() and member:GetHeight() == 95, "Combat switch hides rows immediately while protected spacing waits")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(member:GetHeight() == 53)
