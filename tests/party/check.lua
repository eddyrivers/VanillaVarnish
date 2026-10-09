local member = Mock.Member("party1")
Mock.auras.party1 = {{icon = 123, auraInstanceID = 1, applications = 2, duration = 10, expirationTime = 100}}
Mock.Event("PLAYER_LOGIN")
local row = assert(Mock.Row(member))
local icons = Mock.Icons(row)
assert(member:GetHeight() == 74 and Mock.layouts == 1)
assert(member.HealthBarContainer.HealthBar.color[1] == RAID_CLASS_COLORS.MAGE.r)
assert(member.HealthBarContainer.HealthBar.barTexture.desaturated == true)
assert(row.point[1] == "TOPLEFT" and row.point[2] == member.ManaBar and row.point[3] == "BOTTOMLEFT")
assert(row.point[4] == 4 and row.point[5] == -7 and #icons == 8 and icons[1]:IsVisible())
assert(icons[1].texture.textureValue == 123 and icons[1].count.text == 2)
assert(icons[1].cooldown.cooldownValue[1] == 90)
assert(icons[1].clicks == false and not icons[2]:IsShown())
icons[1].scripts.OnEnter(icons[1])
assert(GameTooltip.shown and GameTooltip.id == 1)

-- Secret display fields go to widgets; secret timers are never subtracted.
local protected = setmetatable({secret = true}, {__sub = function() error("secret arithmetic") end})
Mock.auras.party1 = {{icon = protected, auraInstanceID = 2, applications = protected,
    duration = protected, expirationTime = protected}}
Mock.combat = true
Mock.Event("UNIT_AURA", "party1")
assert(icons[1].texture.textureValue == protected and icons[1].count.text == "3")
assert(icons[1].cooldown.durationObject == "native duration")
assert(GameTooltip.id == 2)
assert(member:GetHeight() == 74)

-- Native resets are recolored; a new member's protected layout waits.
member.HealthBarContainer.HealthBar:SetStatusBarColor(0, 1, 0)
local second = Mock.Member("party2")
Mock.Tick(1)
assert(member.HealthBarContainer.HealthBar.color[1] == RAID_CLASS_COLORS.MAGE.r)
assert(Mock.Row(second) == nil)
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(Mock.Row(second) and second:GetHeight() == 74)
local frameCount = #Mock.frames
Mock.Tick(1)
assert(#Mock.frames == frameCount and member:GetHeight() == 74)

-- A pooled frame is rebound without stale buffs/class colors.
Mock.classes.party1 = "WARRIOR"
Mock.auras.party1 = {}
Mock.Event("GROUP_ROSTER_UPDATE")
assert(member.HealthBarContainer.HealthBar.color[1] == RAID_CLASS_COLORS.WARRIOR.r)
assert(not icons[1]:IsShown() and not GameTooltip.shown)
member.PetFrame:Show()
Mock.Event("UNIT_PET", "party1")
assert(row.point[2] == member.ManaBar and row.point[4] == 4 and row.point[5] == -7)
member:Hide()
Mock.Tick(1)
assert(not row:IsShown())
member:Show()
Mock.active = {second}
Mock.Event("GROUP_ROSTER_UPDATE")
assert(not row:IsShown())

-- Fall back to the index API when the list API is unavailable.
C_UnitAuras.GetUnitAuras = nil
function C_UnitAuras.GetAuraDataByIndex(unit, index)
    if index == 1 then return {icon = 77, auraInstanceID = protected, applications = 1, duration = 0, expirationTime = 0} end
end
Mock.Event("UNIT_AURA", "party2")
local secondIcon = Mock.Icons(Mock.Row(second))[1]
assert(secondIcon:IsShown() and secondIcon.count.text == "")
assert(secondIcon.cooldown.cooldownValue == nil)
secondIcon.scripts.OnEnter(secondIcon)
assert(GameTooltip.index == 1)

-- A refused read clears previous buffs and exposes an actionable diagnostic.
function C_UnitAuras.GetAuraDataByIndex() error("aura access refused") end
Mock.Event("UNIT_AURA", "party2")
assert(not secondIcon:IsShown())
SlashCmdList.PARTYTWEAKS()
assert(Mock.message:find("aura access refused", 1, true))
