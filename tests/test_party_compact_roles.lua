local vv = VV_TEST_NS
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local units = {"player", "party1", "party2", "party3", "party4"}
local roles = {player="HEALER", party1="DAMAGER", party2="TANK", party3="DAMAGER", party4="HEALER"}
local roleReads, sortWrites = 0, 0
function UnitGroupRolesAssigned(unit)
    assert(not Mock.combat, "Compact sorting must not read roles during combat")
    roleReads = roleReads + 1
    return roles[unit]
end
local natural = {}
for index, unit in ipairs(units) do natural[unit] = index end
natural.pet, natural.partypet1 = 6, 7
local function nativeSort(a, b) return natural[a] < natural[b] end
local function reverseSort(a, b) return natural[a] > natural[b] end
CompactPartyFrame = CreateFrame("Frame")
local compact = CompactPartyFrame
compact.flowSortFunc, compact.memberUnitFrames, compact.petUnitFrames = nativeSort, {}, {}
for index, unit in ipairs(units) do
    local member = Mock.Member(unit)
    member.parent = compact
    compact.memberUnitFrames[index] = member
end
Mock.active = {}
for index, unit in ipairs({"pet", "partypet1"}) do
    local pet = CreateFrame("Frame", nil, compact)
    pet.unit = unit
    compact.petUnitFrames[index] = pet
end
local horizontal = false
-- Model the native contract: sorting refreshes unit bindings first, then the
-- layout places member slots and pets. The addon must use that entry point.
function compact:RefreshMembers()
    local sorted = {unpack(units)}
    table.sort(sorted, self.flowSortFunc)
    local offset = 0
    for index, member in ipairs(self.memberUnitFrames) do
        member.unit = sorted[index]
        member:ClearAllPoints()
        member:SetPoint("TOPLEFT", self, "TOPLEFT", horizontal and offset or 0, horizontal and 0 or -offset)
        offset = offset + member:GetHeight()
    end
    local pets = {"pet", "partypet1"}
    table.sort(pets, self.flowSortFunc)
    for index, pet in ipairs(self.petUnitFrames) do
        pet.unit = pets[index]
        pet:SetPoint("TOPLEFT", self.memberUnitFrames[horizontal and 1 or 5], "BOTTOMLEFT", 0, -(index-1)*53)
    end
end
function compact:SetFlowSortFunction(sorter)
    assert(not Mock.combat, "Protected compact sorting changed in combat")
    sortWrites = sortWrites + 1
    self.flowSortFunc = sorter
    self:RefreshMembers()
end
compact:RefreshMembers()
EditModeManagerFrame = {UseRaidStylePartyFrames=function() return Mock.raidStyle end}
Mock.raidStyle = true
Mock.Event("PLAYER_LOGIN")
local function order(expected)
    for index, unit in ipairs(expected) do
        check(compact.memberUnitFrames[index].unit == unit, "Compact member order and targeting match " .. unit)
    end
    check(compact.petUnitFrames[1].point[2] == compact.memberUnitFrames[horizontal and 1 or 5],
        "Native pet anchors follow the member layout")
end
order(units)
check(compact.flowSortFunc == nativeSort, "Off leaves native sorting untouched")
vv.Party.SetOption("rolePin", "top")
order({"party2", "player", "party4", "party1", "party3"})
vv.Party.SetOption("rolePin", "bottom")
order({"party1", "party3", "party2", "player", "party4"})
vv.Party.SetOption("growUp", true)
order({"party1", "party3", "party2", "player", "party4"})
local writes = sortWrites
Mock.Tick(1); Mock.Event("GROUP_ROSTER_UPDATE")
check(sortWrites == writes, "Unchanged compact roles do not trigger native layout churn")
horizontal = true
compact:RefreshMembers()
vv.Party.SetOption("rolePin", "top")
order({"party2", "player", "party4", "party1", "party3"})
check(compact.memberUnitFrames[2].point[4] > 0 and compact.memberUnitFrames[2].point[5] == 0,
    "Horizontal groups retain their native layout")
check(compact.petUnitFrames[1].unit == "pet" and compact.petUnitFrames[2].unit == "partypet1",
    "Role pinning preserves native pet order")
Mock.combat = true
local reads = roleReads
roles.player, roles.party2 = "TANK", "DAMAGER"
vv.Party.SetOption("rolePin", "bottom")
Mock.Event("PLAYER_ROLES_ASSIGNED"); Mock.Tick(1)
compact:RefreshMembers()
order({"party2", "player", "party4", "party1", "party3"})
check(roleReads == reads and sortWrites == writes + 1, "Combat keeps the last safe sort without role reads or protected writes")
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
Enum = {LFGRole={Tank=1, Healer=2}}
function UnitGroupRolesAssignedEnum(unit) return unit == "party2" and 1 or unit == "player" and 2 or 3 end
Mock.Event("PLAYER_ROLES_ASSIGNED")
order({"party1", "party3", "party4", "party2", "player"})
-- Native sort changes should remain the tie-breaker, and Off must restore the
-- latest native choice rather than the one active at login.
compact:SetFlowSortFunction(reverseSort)
Mock.Event("GROUP_ROSTER_UPDATE")
order({"party4", "party3", "party1", "party2", "player"})
vv.Party.SetOption("rolePin", "off")
order({"party4", "party3", "party2", "party1", "player"})
check(compact.flowSortFunc == reverseSort, "Off restores the latest native comparator")
vv.Party.SetOption("rolePin", "top")
vv.SetModuleEnabled("party", false)
check(compact.flowSortFunc == reverseSort, "Disabling the module restores native sorting")
vv.SetModuleEnabled("party", true)
order({"party2", "player", "party4", "party3", "party1"})
Mock.raidStyle = false
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
check(compact.flowSortFunc == reverseSort, "Switching to portraits restores compact native sorting")
Mock.raidStyle = true
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
order({"party2", "player", "party4", "party3", "party1"})
Mock.combat = true
local combatSorter, combatWrites = compact.flowSortFunc, sortWrites
vv.Party.SetOption("rolePin", "off")
check(compact.flowSortFunc == combatSorter and sortWrites == combatWrites,
    "Turning pinning off in combat defers native sort restoration")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
check(compact.flowSortFunc == reverseSort, "Deferred Off restores the native comparator after combat")
vv.Party.SetOption("rolePin", "top")
-- Member slots are reused by the client when someone joins or leaves.
units = {"player", "party1", "party2"}
compact.memberUnitFrames[4]:Hide(); compact.memberUnitFrames[5]:Hide()
compact:RefreshMembers()
Mock.Event("GROUP_ROSTER_UPDATE")
check(compact.memberUnitFrames[1].unit == "party2" and compact.memberUnitFrames[2].unit == "player"
    and compact.memberUnitFrames[3].unit == "party1", "Roster reuse retains role ordering and current native unit bindings")
VV_COMPACT_ROLE_CHECKS = checks
