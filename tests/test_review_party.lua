local vv = VV_TEST_NS
local member = Mock.Member("party1")
Mock.auras.party1 = {{icon=17, auraInstanceID=1}}
Mock.Event("PLAYER_LOGIN")
local bar = member.HealthBarContainer.HealthBar
local texture = bar.barTexture
local failures, checks = {}, 0
local function check(value, message)
    checks=checks+1
    if not value then failures[#failures+1]=message end
end
bar:SetStatusBarColor(0.7, 0.2, 0.1, 0.4)
texture:SetDesaturated(true)
Mock.Tick(0.2)
vv.Party.SetOption("classColors", false)
check(bar.color[1] == 0.7 and bar.color[4] == 0.4 and texture.desaturated == true,
    "Color toggles must restore the latest native color and desaturation")

local timers, reads = 0, 0
local callbacks = {}
C_Timer.After = function(_, fn) timers=timers+1; callbacks[#callbacks+1]=fn end
local nativeAuras = C_UnitAuras.GetUnitAuras
C_UnitAuras.GetUnitAuras = function(...) reads=reads+1; return nativeAuras(...) end
Mock.Event("UNIT_AURA", "target")
Mock.Event("UNIT_AURA", "player")
check(timers == 0 and reads == 0, "Unrelated aura events must not schedule party work")
callbacks, timers = {}, 0
for _=1, 10 do Mock.Event("GROUP_ROSTER_UPDATE") end
check(timers == 1, "Party event bursts must coalesce into one deferred refresh")
for _, fn in ipairs(callbacks) do fn() end
callbacks, timers = {}, 0
Mock.auras.party1[1].icon=25
Mock.Event("UNIT_AURA", "party1")
check(Mock.Icons(Mock.Row(member))[1].texture.textureValue == 25,
    "Relevant party aura events must still refresh immediately")
check(timers == 1, "Relevant aura events still schedule a refresh after native updates")
for _, fn in ipairs(callbacks) do fn() end

local icon = CreateFrame("Frame", nil, member)
icon:SetSize(14, 14)
icon:SetPoint("TOPLEFT", member, "TOPRIGHT", 0, 0)
icon.auraInstanceID, icon.isBuff, icon.layoutIndex = 100, false, 1
icon.DebuffBorder = icon:CreateTexture()
member.AuraFramePool = {EnumerateActive=function()
    local yielded=false
    return function() if not yielded then yielded=true; return icon end end
end}
Mock.dispellable = {party1={{auraInstanceID=100, dispelName="Magic"}}}
vv.Party.RefreshModule()
check(icon.width == 28, "Dispellable debuffs still enlarge")
-- Blizzard's pool reset hides and clears anchors, but does not reset size.
icon:Hide()
check(icon.point[2] == member, "Hidden aura frames restore native anchors before later redecoration")
icon:ClearAllPoints()
check(icon.width == 14, "Released aura frames must shed addon sizing before reuse")
icon.isBuff, icon.auraInstanceID = true, 101
icon:SetPoint("TOPLEFT", member, "TOPLEFT", 9, -3)
icon:Show()
vv.Party.SetOption("buffs", false)
check(icon.point[3] == "TOPLEFT" and icon.point[4] == 9,
    "Disabling buffs must not restore a previous debuff's anchors onto a recycled buff")
assert(#failures == 0, table.concat(failures, "\n"))
VV_REVIEW_PARTY_CHECKS = checks
