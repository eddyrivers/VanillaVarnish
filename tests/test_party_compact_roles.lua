local vv = VV_TEST_NS
local checks, writes, roleReads = 0, 0, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local roles = {player="HEALER", party1="DAMAGER", party2="TANK", party3="DAMAGER", party4="HEALER"}
function UnitGroupRolesAssigned(unit)
    assert(not Mock.combat, "Addon role reads must wait for combat to end")
    roleReads = roleReads + 1
    return roles[unit]
end
local function anchors(frame)
    frame.anchors = {}
    function frame:GetNumPoints() return #self.anchors end
    function frame:GetPoint(index) return unpack(self.anchors[index]) end
    function frame:ClearAllPoints()
        assert(not Mock.combat or Mock.nativeLayout, "Addon cleared protected anchors in combat")
        writes = writes + 1
        self.anchors = {}
    end
    function frame:SetPoint(...)
        assert(not Mock.combat or Mock.nativeLayout, "Addon moved protected anchors in combat")
        writes = writes + 1
        self.anchors[#self.anchors+1] = {...}
    end
    return frame
end
CompactPartyFrame = anchors(CreateFrame("Frame"))
local compact = CompactPartyFrame
local nativeUnits = {"player", "party1", "party2", "party3", "party4"}
compact.memberUnitFrames, compact.petUnitFrames = {}, {}
local originals = {}
for index, unit in ipairs(nativeUnits) do
    local member = anchors(Mock.Member(unit))
    member.parent = compact
    compact.memberUnitFrames[index], originals[index] = member, member
end
Mock.active = {}
for index, unit in ipairs({"pet", "partypet1"}) do
    local pet = anchors(CreateFrame("Frame", nil, compact))
    pet.unit = unit
    compact.petUnitFrames[index] = pet
end
compact.borderFrame = anchors(CreateFrame("Frame", nil, compact))
local nativeSort = function(a, b) return a < b end
compact.flowSortFunc = nativeSort
function compact:SetFlowSortFunction() error("Addon sorting taints native restricted health updates") end
local horizontal, border = false, false
local function nativeLayout(self)
    assert(Mock.nativeLayout, "Addon must not invoke native layout or unit setup")
    for index, member in ipairs(self.memberUnitFrames) do
        member:ClearAllPoints()
        if index == 1 then member:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -10)
        elseif horizontal then member:SetPoint("TOPLEFT", self.memberUnitFrames[index-1], "TOPRIGHT", 0, 0)
        else member:SetPoint("TOPLEFT", self.memberUnitFrames[index-1], "BOTTOMLEFT", 0, 0) end
    end
    self.borderFrame:ClearAllPoints()
    self.borderFrame:SetPoint("TOPLEFT", self.memberUnitFrames[1], "TOPLEFT", -2, 2)
    local last = 1
    for index, member in ipairs(self.memberUnitFrames) do if member:IsShown() then last = index end end
    self.borderFrame:SetPoint("BOTTOMRIGHT", self.memberUnitFrames[last], "BOTTOMRIGHT", 2, -3)
    for index, pet in ipairs(self.petUnitFrames) do
        pet:ClearAllPoints()
        pet:SetPoint("TOPLEFT", index > 1 and self.petUnitFrames[index-1]
            or border and self.borderFrame or self.memberUnitFrames[horizontal and 1 or last], "BOTTOMLEFT", 0, 0)
    end
end
compact.updateLayoutFunc = nativeLayout
function compact:RefreshMembers()
    assert(Mock.nativeLayout, "Addon must not invoke native member/health setup")
    for index, member in ipairs(self.memberUnitFrames) do member.unit = nativeUnits[index] end
    self:updateLayoutFunc()
end
local function refreshNative()
    Mock.nativeLayout = true
    compact:RefreshMembers()
    Mock.nativeLayout = false
end
refreshNative()
EditModeManagerFrame = {UseRaidStylePartyFrames=function() return Mock.raidStyle end}
Mock.raidStyle = true
Mock.Event("PLAYER_LOGIN")
local function position(frame, seen)
    if frame == compact then return 0, 0 end
    seen = seen or {}
    assert(not seen[frame], "Layout introduced an anchor cycle")
    seen[frame] = true
    local p = frame.anchors[1]
    local x, y = position(p[2], seen)
    if p[3]:find("RIGHT") then x = x + p[2]:GetWidth() end
    if p[3]:find("BOTTOM") then y = y - p[2]:GetHeight() end
    return x + (p[4] or 0), y + (p[5] or 0)
end
local function order(expected)
    local physical = {}
    for index, frame in ipairs(compact.memberUnitFrames) do
        check(frame == originals[index] and frame.unit == nativeUnits[index], "Native frame table and unit bindings remain untouched")
        if frame:IsShown() then physical[#physical+1] = frame end
        position(frame)
    end
    table.sort(physical, function(a,b)
        local ax, ay = position(a)
        local bx, by = position(b)
        return horizontal and ax < bx or not horizontal and ay > by
    end)
    for index, unit in ipairs(expected) do check(physical[index].unit == unit, "Physical role order matches " .. unit) end
    check(compact.flowSortFunc == nativeSort, "Native comparator must never be replaced")
    local first, last = physical[1], physical[#physical]
    check(compact.borderFrame.anchors[1][2] == first and compact.borderFrame.anchors[2][2] == last,
        "Both border anchors follow physical member edges")
    check(compact.petUnitFrames[1].anchors[1][2] == (border and compact.borderFrame or horizontal and first or last),
        "Pets stay below the physical member block")
    for _, pet in ipairs(compact.petUnitFrames) do position(pet) end
end
order(nativeUnits)
vv.Party.SetOption("rolePin", "top")
order({"party2", "player", "party4", "party1", "party3"})
vv.Party.SetOption("rolePin", "bottom")
order({"party1", "party3", "party2", "player", "party4"})
vv.Party.SetOption("growUp", true)
order({"party1", "party3", "party2", "player", "party4"})
local previousWrites = writes
Mock.Tick(1); Mock.Event("GROUP_ROSTER_UPDATE")
check(writes == previousWrites, "Unchanged role layouts do not rewrite anchors on the periodic refresh")
refreshNative()
order({"party1", "party3", "party2", "player", "party4"})
horizontal, border = true, true
refreshNative()
vv.Party.SetOption("rolePin", "top")
order({"party2", "player", "party4", "party1", "party3"})
Mock.combat = true
local beforeCombat, reads = writes, roleReads
roles.player, roles.party2 = "TANK", "DAMAGER"
vv.Party.SetOption("rolePin", "bottom")
Mock.Event("PLAYER_ROLES_ASSIGNED"); Mock.Tick(1)
order({"party2", "player", "party4", "party1", "party3"})
check(writes == beforeCombat and roleReads == reads, "Combat defers all addon role reads and protected layout changes")
-- A secure native refresh may reset anchors in combat. The addon must neither
-- intervene nor mistake those fresh native positions for an old pinned layout.
refreshNative()
order(nativeUnits)
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
order({"party1", "party2", "party3", "player", "party4"})
roles.party3 = "TANK"
Mock.Event("ROLE_CHANGED_INFORM")
order({"party1", "party2", "player", "party3", "party4"})
roles.player, roles.party4 = {secret=true}, {secret=true}
Mock.Event("PLAYER_ROLES_ASSIGNED")
order({"player", "party1", "party2", "party4", "party3"})
UnitGroupRolesAssigned = nil
Enum = {LFGRole={Tank=1,Healer=2}}
function UnitGroupRolesAssignedEnum(unit) return unit == "party2" and 1 or unit == "player" and 2 or 3 end
Mock.Event("PLAYER_ROLES_ASSIGNED")
order({"party1", "party3", "party4", "party2", "player"})
vv.Party.SetOption("rolePin", "off")
order(nativeUnits)
-- Layout changes made while pinning is off become the new restoration baseline.
horizontal, border = false, false
refreshNative()
vv.Party.SetOption("rolePin", "top")
order({"party2", "player", "party1", "party3", "party4"})
vv.SetModuleEnabled("party", false)
order(nativeUnits)
vv.SetModuleEnabled("party", true)
order({"party2", "player", "party1", "party3", "party4"})
Mock.raidStyle = false
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
order(nativeUnits)
Mock.raidStyle = true
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
order({"party2", "player", "party1", "party3", "party4"})
Mock.combat = true
vv.Party.SetOption("rolePin", "off")
order({"party2", "player", "party1", "party3", "party4"})
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
order(nativeUnits)
vv.Party.SetOption("rolePin", "top")
-- Native slot reuse and hidden slots keep their original chained anchors.
nativeUnits = {"player", "party2", "party1", "party3", "party4"}
compact.memberUnitFrames[4]:Hide(); compact.memberUnitFrames[5]:Hide()
refreshNative()
Mock.Event("GROUP_ROSTER_UPDATE")
order({"party2", "player", "party1"})
vv.Party.SetOption("rolePin", "off")
order({"player", "party2", "party1"})

-- Role lookups can disagree or become unavailable while a remote member zones.
-- Use the native enum first and remember roles by identity, not by frame/slot.
local guids = {player="healer", party1="damage", party2="tank"}
function UnitGUID(unit)
    check(not Mock.combat, "Identity reads also wait until combat ends")
    return guids[unit]
end
local enumRoles = {player=2, party1=3, party2=1}
Enum.LFGRole.Damage = 3
function UnitGroupRolesAssignedEnum(unit) return enumRoles[unit] end
roles = {player="HEALER", party1="DAMAGER", party2="DAMAGER"}
function UnitGroupRolesAssigned(unit) return roles[unit] end
vv.Party.SetOption("rolePin", "top")
order({"party2", "player", "party1"})
Mock.Event("UNIT_AURA", "party2"); Mock.Tick(1)
order({"party2", "player", "party1"})
enumRoles.party2, roles.party2 = 0, "NONE"
Mock.Event("UNIT_CONNECTION", "party2"); Mock.Tick(1)
order({"party2", "player", "party1"})
Mock.Event("GROUP_ROSTER_UPDATE")
refreshNative()
order({"party2", "player", "party1"})
enumRoles.party2, roles.party2 = nil, nil
Mock.Event("PLAYER_ENTERING_WORLD"); Mock.Tick(1)
order({"party2", "player", "party1"})
local enumReader = UnitGroupRolesAssignedEnum
function UnitGroupRolesAssignedEnum(unit)
    if unit == "party2" then error("role temporarily unavailable") end
    return enumReader(unit)
end
Mock.Tick(1)
order({"party2", "player", "party1"})
UnitGroupRolesAssignedEnum = enumReader
enumRoles.party2, roles.party2 = {secret=true}, {secret=true}
Mock.Tick(1)
order({"party2", "player", "party1"})
enumRoles.party2, roles.party2 = 3, "TANK"
Mock.Event("PLAYER_ROLES_ASSIGNED")
order({"player", "party2", "party1"})
enumRoles.party2, roles.party2 = 1, "TANK"
Mock.Event("ROLE_CHANGED_INFORM")
-- Party slots can swap without losing the remembered role of either identity.
guids.party1, guids.party2 = guids.party2, guids.party1
enumRoles.party1, roles.party1, enumRoles.party2, roles.party2 = 0, "NONE", 0, "NONE"
Mock.Event("GROUP_ROSTER_UPDATE")
order({"party1", "player", "party2"})
-- A replacement must not inherit the tank role from the recycled unit token.
guids.party1 = "replacement"
Mock.Event("GROUP_ROSTER_UPDATE")
order({"player", "party2", "party1"})
guids.party1 = "tank"
Mock.Event("GROUP_ROSTER_UPDATE")
order({"player", "party2", "party1"})
-- Restricted identity is never a cache key, and missing identity is not a slot fallback.
enumRoles.party1, roles.party1 = 1, "TANK"
Mock.Event("PLAYER_ROLES_ASSIGNED")
guids.party1, enumRoles.party1, roles.party1 = {secret=true}, 0, "NONE"
Mock.Tick(1)
order({"player", "party2", "party1"})
guids.party1 = nil
Mock.Tick(1)
order({"player", "party2", "party1"})
-- A real role change during combat applies on leaving combat.
guids.party1, enumRoles.party1, roles.party1 = "tank", 1, "TANK"
Mock.Event("PLAYER_ROLES_ASSIGNED")
Mock.combat = true
enumRoles.party1, roles.party1 = 3, "DAMAGER"
Mock.Event("GROUP_ROSTER_UPDATE"); Mock.Event("PLAYER_ROLES_ASSIGNED"); Mock.Tick(1)
order({"party1", "player", "party2"})
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
order({"player", "party2", "party1"})
VV_COMPACT_ROLE_CHECKS = checks
