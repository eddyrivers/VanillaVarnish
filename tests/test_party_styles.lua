local vv = VV_TEST_NS
local member = Mock.Member("party1")
PartyMemberBuffTooltip = CreateFrame("Frame")
HIDE_PARTY_MEMBER_BUFF_TOOLTIP = false
local buffs = {}
for index = 1, 12 do buffs[index] = {icon=index, auraInstanceID=index, sourceUnit="party2"} end
buffs[3].sourceUnit, buffs[10].sourceUnit = "player", "player"
Mock.auras.party1 = buffs
Mock.Event("PLAYER_LOGIN")
local row = assert(Mock.Row(member))
local icons = Mock.Icons(row)
assert(HIDE_PARTY_MEMBER_BUFF_TOOLTIP and not PartyMemberBuffTooltip:IsShown(), "The native portrait-hover buff popup is suppressed")
assert(icons[1].border.color[1] == 1 and icons[2].border.color[1] == 1 and icons[3].border.color[1] ~= 1,
    "Only buffs cast by the player have a solid gold border")
assert(icons[1].texture.textureValue == 3 and icons[2].texture.textureValue == 10,
    "Player buffs must precede others, including buffs beyond the first eight")
assert(icons[1].width == 19 and icons[2].height == 19 and icons[3].width == 14)
assert(icons[2].point[4] == 21 and icons[3].point[4] == 42 and icons[4].point[4] == 58)
assert(icons[3].texture.textureValue == 1 and icons[4].texture.textureValue == 2, "Partition retains native order")
PixelUtil = {GetPixelToUIUnitFactor = function() return 0.8 end}
member.scale = 2
Mock.Event("UNIT_AURA", "party1")
assert(icons[1].texture.point[2] == -0.4 and icons[3].texture.point[2] == -1,
    "The gold border is one screen pixel at a different party frame scale")
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
for _, icon in ipairs(icons) do assert(icon.border.color[1] ~= 1, "Reused icons cannot keep another aura's gold border") end
-- Caster GUID can prove ownership without a readable unit token. The same
-- spell cast by someone else must still use the ordinary appearance.
function UnitGUID(unit) return unit == "player" and "Player-1-100" end
function C_UnitAuras.GetAuraCasterGUID(unit, id)
    assert(unit == "party1")
    if id == 3 then return "Player-1-100" end
    if id == 10 then return "Player-1-200" end
end
buffs[3].sourceUnit, buffs[10].sourceUnit = nil, nil
buffs[3].spellId, buffs[10].spellId = 1126, 1126
buffs[3].isFromPlayerOrPlayerPet, buffs[10].isFromPlayerOrPlayerPet = true, true
Mock.Event("UNIT_AURA", "party1")
assert(icons[1].texture.textureValue == 3 and icons[1].width == 19 and icons[1].border.color[1] == 1)
assert(icons[10].texture.textureValue == 10 and icons[10].width == 14 and icons[10].border.color[1] ~= 1)
C_UnitAuras.GetAuraCasterGUID = function() return {secret=true} end
Mock.Event("UNIT_AURA", "party1")
assert(icons[3].width == 14 and icons[3].border.color[1] ~= 1, "An unreadable caster never gets the player's styling")
C_UnitAuras.GetAuraCasterGUID = nil
vv.Party.SetOption("buffs", false)
assert(HIDE_PARTY_MEMBER_BUFF_TOOLTIP == false, "Disabling extra buffs restores the previous native popup setting")
HIDE_PARTY_MEMBER_BUFF_TOOLTIP = true
vv.Party.SetOption("buffs", true)
vv.SetModuleEnabled("party", false)
assert(HIDE_PARTY_MEMBER_BUFF_TOOLTIP == true, "Disabling the module preserves an already suppressed native popup")
vv.SetModuleEnabled("party", true)

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
assert(raidMember.healthBar.color[1] == RAID_CLASS_COLORS.MAGE.r,
    "Raid-style native health colors must be corrected before the setter returns")
Mock.combat = true
raidMember.healthBar:SetStatusBarColor(0, 1, 0)
assert(raidMember.healthBar.color[1] == RAID_CLASS_COLORS.MAGE.r,
    "Combat health updates cannot show an intermediate green frame")
raidMember.healthBar.barTexture:SetDesaturated(false)
assert(raidMember.healthBar.barTexture.desaturated,
    "Native texture changes must retain readable class colors immediately")
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
