local vv = VV_TEST_NS
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local top
local function bottom(frame) return top(frame) - frame:GetHeight() end
top = function(frame)
    if frame == UIParent then return 800 end
    local point = frame.point
    if not point then return 500 end
    local relative, relativePoint = point[2], point[3]
    local y = relativePoint:find("BOTTOM") and bottom(relative) or top(relative)
    if not relativePoint:find("TOP") and not relativePoint:find("BOTTOM") then y = y - relative:GetHeight() / 2 end
    y = y + (point[5] or 0)
    if point[1]:find("BOTTOM") then y = y + frame:GetHeight()
    elseif not point[1]:find("TOP") then y = y + frame:GetHeight() / 2 end
    return y
end
local create = CreateFrame
AuraContainerSortMethod = {Default=0}
CustomAuraContainerGroupDefaultOptions = {}
CreateFrame = function(kind, ...)
    local frame = create(kind, ...)
    frame.GetTop, frame.GetBottom = top, bottom
    if kind == "AuraContainer" then
        function frame:SetEnabled(value) self.enabled = value end
        function frame:SetUnit(unit) self.unit = unit end
        function frame:SetFlowLayoutAnchorPoint() end
        function frame:SetFlowLayoutMaximumLineSize(value) self.lineWidth = value end
        function frame:AddAuraGroup(_, _, options) self.options = options end
    end
    return frame
end
UIParent = CreateFrame("Frame")
UIParent:SetSize(1000, 800)
function UIParent:GetName() return "UIParent" end
local originalPool = PartyFrame.PartyMemberFramePool
PartyFrame = CreateFrame("Frame", nil, UIParent)
PartyFrame.PartyMemberFramePool = originalPool
PartyFrame.spacing, PartyFrame.bottomPadding = 10, 2
PartyFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
PartyFrame.Background = CreateFrame("Frame", nil, PartyFrame)
local dragging = false
function PartyFrame:IsEditModeDragging() return dragging end
function PartyFrame:OnDragStop() dragging = false end
local members = {}
for index = 1, 4 do
    local member = Mock.Member("party" .. index)
    member.parent, member.layoutIndex = PartyFrame, index
    member.GetTop, member.GetBottom = top, bottom
    member.ManaBar.GetTop, member.ManaBar.GetBottom = top, bottom
    member.ManaBar:SetSize(70, 8)
    member.ManaBar:SetPoint("TOPLEFT", member, "TOPLEFT", 41, -30)
    local setPoint, clear = member.SetPoint, member.ClearAllPoints
    member.SetPoint = function(self, ...)
        assert(not Mock.combat, "Protected party anchors changed during combat")
        setPoint(self, ...)
    end
    member.ClearAllPoints = function(self)
        assert(not Mock.combat, "Protected party anchors cleared during combat")
        clear(self)
    end
    members[index] = member
    Mock.auras[member.unit] = {}
    for aura = 1, 16 do Mock.auras[member.unit][aura] = {icon=aura, sourceUnit="player", auraInstanceID=aura} end
end
Mock.active = {members[4], members[2], members[1], members[3]}
function PartyFrame:Layout()
    assert(not Mock.combat, "Native layout must not be invoked in combat")
    local offset, count = 0, 0
    for index = 1, 4 do
        local member = members[index]
        local active = false
        for _, current in ipairs(Mock.active) do if member == current then active = true end end
        if active and member:IsShown() then
            member:ClearAllPoints()
            member:SetPoint("TOPLEFT", self, "TOPLEFT", 0, -offset)
            offset, count = offset + member:GetHeight() + self.spacing, count + 1
        end
    end
    self:SetHeight(count > 0 and offset - self.spacing + self.bottomPadding or 2)
end
function PartyFrame:UpdatePartyMemberBackground()
    self.Background:ClearAllPoints()
    self.Background:SetPoint("TOPLEFT", self, "TOPLEFT", -5, 6)
    self.Background:SetPoint("BOTTOMLEFT", members[4], "BOTTOMLEFT", -5, -5)
end
local nativeLayout, nativeBackground = PartyFrame.Layout, PartyFrame.UpdatePartyMemberBackground
PartyFrame:Layout()
Mock.Event("PLAYER_LOGIN")
check(vv.db.party.spacing == 4 and not vv.db.party.growUp, "Compact spacing defaults to four and downward growth")
for index, member in ipairs(members) do
    check(near(member:GetHeight(), 87), "Both buff rows use the native bar footprint without duplicated height")
    local row = Mock.Row(member)
    check(row:IsShown() and Mock.Icons(row)[16]:IsShown(), "Compact layout retains all sixteen buffs")
    check(bottom(row) >= bottom(member), "Both buff rows remain within their member's reserved area")
    if index > 1 then check(near(bottom(members[index - 1]) - top(member), 4), "Requested gaps separate adjacent member bounds") end
end
check(near(PartyFrame:GetHeight(), 362), "Edit Mode container fits the compact four-member layout")
check(PartyFrame.spacing == 10 and PartyFrame.childLayoutDirection == nil, "Native Lua layout settings remain untouched")
local compactHeight, initialTop = PartyFrame:GetHeight(), top(PartyFrame)
for _ = 1, 4 do PartyFrame:Layout(); Mock.Tick(1) end
check(near(PartyFrame:GetHeight(), compactHeight) and near(top(PartyFrame), initialTop), "Native refreshes cannot accumulate height or move the container")
local fixedBottom = bottom(PartyFrame)
vv.Party.SetOption("growUp", true)
check(near(bottom(PartyFrame), fixedBottom), "Enabling upward growth preserves the bottom edge")
check(members[1].point[1] == "BOTTOMLEFT" and top(members[1]) < top(members[2]), "First party member fills the bottom slot")
check(near(bottom(members[2]) - top(members[1]), 4), "Upward members retain the configured gap")
Mock.active = {members[2], members[1]}
PartyFrame:Layout(); Mock.Event("GROUP_ROSTER_UPDATE")
check(near(bottom(PartyFrame), fixedBottom) and near(PartyFrame:GetHeight(), 180), "Leaving members shrink the container upward from its fixed bottom")
Mock.active = {members[4], members[2], members[1], members[3]}
PartyFrame:Layout(); Mock.Event("GROUP_ROSTER_UPDATE")
check(near(bottom(PartyFrame), fixedBottom) and near(PartyFrame:GetHeight(), 362), "Joining members grow upward without moving the bottom member")
PartyFrame:UpdatePartyMemberBackground()
check(PartyFrame.Background.point[2] == PartyFrame, "Native background updates follow the entire upward container")
vv.Party.SetOption("spacing", 0)
check(near(PartyFrame:GetHeight(), 350), "Zero extra gap retains room for all aura rows")
local function buffs(count, ownCount)
    for _, member in ipairs(members) do
        local list = {}
        for index = 1, count do
            list[index] = {icon=index, auraInstanceID=index, sourceUnit=index <= ownCount and "player" or "party2"}
        end
        Mock.auras[member.unit] = list
    end
    Mock.Event("UNIT_AURA", "party1")
end
buffs(1, 1)
check(near(PartyFrame:GetHeight(), 310) and near(bottom(PartyFrame), fixedBottom),
    "Sparse buffs shorten the party by forty units without shifting the upward anchor")
for _, member in ipairs(members) do
    check(member:GetHeight() == 77 and Mock.Row(member):GetHeight() == 30,
        "A sparse row reserves only two standard-size combat rows")
end
buffs(0, 0)
check(near(PartyFrame:GetHeight(), 310), "Empty rows retain room for buffs gained in combat")
buffs(16, 0)
for _, member in ipairs(members) do
    local row = Mock.Row(member)
    local icons = Mock.Icons(row)
    check(icons[16]:IsShown() and icons[9].point[5] == -16 and bottom(icons[16]) >= bottom(member),
        "All sixteen ordinary buffs fit the smaller reservation without overlap")
end
check(near(PartyFrame:GetHeight(), 310), "Two ordinary rows need no enlarged-row padding")
buffs(16, 8)
check(members[1]:GetHeight() == 82 and Mock.Row(members[1]):GetHeight() == 35,
    "A mixed pair of rows grows only enough to fit its enlarged first row")
buffs(1, 1)
Mock.combat = true
buffs(16, 16)
Mock.Tick(1)
check(members[1]:GetHeight() == 77 and Mock.Row(members[1]):GetHeight() == 30
    and near(PartyFrame:GetHeight(), 310), "Combat gains preserve protected member and container geometry")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
check(members[1]:GetHeight() == 87 and near(PartyFrame:GetHeight(), 350) and near(bottom(PartyFrame), fixedBottom),
    "Leaving combat expands for sixteen enlarged buffs while preserving the bottom edge")
local previousPoint, previousHeight = members[1].point, PartyFrame:GetHeight()
Mock.combat = true
vv.Party.SetOption("spacing", 12)
vv.Party.SetOption("growUp", false)
Mock.Tick(2)
check(members[1].point == previousPoint and PartyFrame:GetHeight() == previousHeight, "Layout preferences save during combat without changing secure geometry")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
check(members[1].point[1] == "TOPLEFT" and near(PartyFrame:GetHeight(), 386), "Pending gap and growth apply after combat")
check(near(top(PartyFrame), initialTop), "Downward growth restores the original top anchor")
vv.Party.SetOption("growUp", true)
PartyFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 200, -200)
local movedBottom = bottom(PartyFrame)
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
check(near(bottom(PartyFrame), movedBottom), "Moving the party in Edit Mode becomes the new bottom anchor")
vv.SetModuleEnabled("party", false)
check(PartyFrame.point[1] == "TOPLEFT" and PartyFrame.point[4] == 200, "Disabling restores the latest native Edit Mode anchor")
check(members[1]:GetHeight() == 53 and members[2].point[5] == -63, "Disabling restores native heights and spacing")
members[1]:SetPoint("TOPLEFT", PartyFrame, "TOPLEFT", 9, -9)
local disabledPoint = members[1].point
vv.Party.RefreshModule()
check(members[1].point == disabledPoint, "Disabled party layout cannot overwrite another addon's anchors")
PartyFrame:Layout()
vv.SetModuleEnabled("party", true)
Mock.raidStyle = true
EditModeManagerFrame = {UseRaidStylePartyFrames=function() return Mock.raidStyle end}
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
check(members[1]:GetHeight() == 53 and members[2].point[5] == -63, "Raid-style selection restores portrait geometry")
Mock.raidStyle = false
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
check(members[1]:GetHeight() == 87 and members[1].point[1] == "BOTTOMLEFT", "Portrait selection resumes saved compact upward layout")
check(not vv.Party.SetOption("spacing", -1) and not vv.Party.SetOption("spacing", 41)
    and not vv.Party.SetOption("spacing", 0/0) and not vv.Party.SetOption("growUp", "yes"), "Invalid layout values are rejected")
vv.Party.HandleSlash("spacing 6")
vv.Party.HandleSlash("grow down")
check(vv.db.party.spacing == 6 and not vv.db.party.growUp, "Slash commands configure spacing and direction")
vv.Party.SetOption("buffs", false)
members[1].PetFrame:SetSize(64, 23)
members[1].PetFrame:SetPoint("TOPLEFT", members[1], "TOPLEFT", 23, -43)
members[1].PetFrame.GetTop, members[1].PetFrame.GetBottom = top, bottom
members[1].PetFrame:Show()
Mock.Event("UNIT_PET", "party1")
check(near(bottom(members[1]) - top(members[2]), 22), "Native pet clearance is added only where it is needed")
vv.Party.SetOption("growUp", true)
check(bottom(members[1].PetFrame) >= bottom(PartyFrame), "Upward growth keeps a bottom member's pet inside the container")
vv.Party.SetOption("buffs", true)
PartyFrame.scale = 1.8
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
check(near(members[1]:GetHeight(), 87), "Scaling the entire party does not duplicate aura height")
local scaledBottom = bottom(PartyFrame)
buffs(1, 1)
check(near(members[1]:GetHeight(), 77) and near(bottom(PartyFrame), scaledBottom),
    "Scaled parties also reclaim sparse buff space without moving the saved bottom edge")
vv.Party.SetOption("growUp", false)
check(near(members[1]:GetHeight(), 77) and members[1].point[1] == "TOPLEFT",
    "Sparse buff space also compresses in downward-growing parties")
buffs(16, 16)
vv.Party.SetOption("growUp", true)
local roles = {party1="DAMAGER", party2="HEALER", party3="TANK", party4="DAMAGER"}
function UnitGroupRolesAssigned(unit) return roles[unit] end
local function order(expected)
    local physical = {unpack(members)}
    table.sort(physical, function(a,b) return top(a) > top(b) end)
    for index, value in ipairs(expected) do
        check(physical[index] == members[value], "Role pinning preserves the expected physical order")
    end
    for index, member in ipairs(members) do
        check(member.unit == "party" .. index and member.layoutIndex == index, "Role pinning preserves native unit bindings")
    end
end
vv.Party.SetOption("growUp", false)
vv.Party.SetOption("rolePin", "top"); order({3,2,1,4})
vv.Party.SetOption("rolePin", "bottom"); order({1,4,3,2})
vv.Party.SetOption("growUp", true); order({4,1,3,2})
vv.Party.SetOption("rolePin", "top"); order({3,2,4,1})
vv.Party.SetOption("rolePin", "off"); order({4,3,2,1})
Mock.combat = true
vv.Party.SetOption("rolePin", "bottom"); order({4,3,2,1})
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED"); order({4,1,3,2})
roles.party4 = "TANK"
Mock.Event("PLAYER_ROLES_ASSIGNED"); order({1,4,3,2})
roles.party2 = {secret=true}
Mock.Event("ROLE_CHANGED_INFORM"); order({2,1,4,3})
roles.party4 = "NONE"
UnitGroupRolesAssigned = nil
Mock.Event("PLAYER_ROLES_ASSIGNED"); order({4,3,2,1})
Enum = {LFGRole={Tank=1,Healer=2,Damage=3}}
function UnitGroupRolesAssignedEnum(unit) return unit == "party3" and 1 or unit == "party2" and 2 or 3 end
Mock.Event("PLAYER_ROLES_ASSIGNED"); order({4,1,3,2})
check(not vv.Party.SetOption("rolePin", true) and not vv.Party.SetOption("rolePin", "left"), "Invalid role modes are rejected")
vv.Party.HandleSlash("roles top")
check(vv.db.party.rolePin == "top", "Role pinning is accessible from slash commands")

-- Portrait layouts share the native assigned-role lookup and zoning memory.
local guids = {party1="damage1", party2="healer", party3="tank", party4="damage4"}
function UnitGUID(unit) return guids[unit] end
Enum.LFGRole.Damage = 3
local enumRoles = {party1=3, party2=2, party3=1, party4=3}
function UnitGroupRolesAssignedEnum(unit) return enumRoles[unit] end
function UnitGroupRolesAssigned(unit) return roles[unit] end
roles.party3 = "DAMAGER"
Mock.Event("UNIT_AURA", "party3"); Mock.Tick(1); order({3,2,4,1})
enumRoles.party3, roles.party3 = 0, "NONE"
Mock.Event("UNIT_CONNECTION", "party3"); Mock.Tick(1); order({3,2,4,1})
Mock.Event("GROUP_ROSTER_UPDATE"); order({3,2,4,1})
enumRoles.party3, roles.party3 = 3, "DAMAGER"
Mock.Event("PLAYER_ROLES_ASSIGNED"); order({2,4,3,1})
enumRoles.party3, roles.party3 = 1, "TANK"
Mock.Event("ROLE_CHANGED_INFORM"); order({3,2,4,1})

local editing = true
function EditModeManagerFrame:IsEditModeActive() return editing end
local editX, editY, editScale = 123.4567, -209.8765, 1.3
PartyFrame.scale = editScale
function PartyFrame:GetScale() return self.scale end
PartyFrame:ClearAllPoints()
PartyFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", editX, editY)
PartyFrame:Layout()
check(PartyFrame.point[1] == "TOPLEFT" and PartyFrame.point[4] == editX,
    "Upward growth leaves Blizzard's dragged anchor alone during Edit Mode")
dragging = true
local dragHeight, memberPoint = PartyFrame:GetHeight(), members[1].point
local dragRow = Mock.Row(members[1])
local rowPoint, iconPoint = dragRow.point, Mock.Icons(dragRow)[1].point
vv.Party.SetOption("spacing", 8)
Mock.Event("UNIT_AURA", "party1")
Mock.Event("GROUP_ROSTER_UPDATE")
Mock.Tick(2)
PartyFrame:UpdatePartyMemberBackground()
check(PartyFrame:GetHeight() == dragHeight and members[1].point == memberPoint
    and dragRow.point == rowPoint and Mock.Icons(dragRow)[1].point == iconPoint,
    "Settings, roster, aura, and periodic updates leave the dragged layout alone")
check(PartyFrame.Background.point[2] == members[4], "The background hook leaves native anchors alone during the drag")
PartyFrame:OnDragStop()
local afterDrag = assert(Mock.pending, "Reflow should be queued after native drag stop")
Mock.pending = nil
afterDrag()
check(near(PartyFrame:GetHeight(), dragHeight + 6) and PartyFrame.point[4] == editX,
    "Spacing updates after the drag without moving the saved Edit Mode anchor")
local savedHeight = PartyFrame:GetHeight()
Mock.EditModeEvent("EditMode.SavedLayouts")
editing = false

-- Edit Mode stores offsets at scale 1 and rounds them on disk. Reloading
-- restores those offsets divided by the frame scale, with the live roster.
local loadedX, loadedY = 160.5 / editScale, -272.8 / editScale
local function reloadParty()
    local reloaded = CreateFrame("Frame", nil, UIParent)
    reloaded.PartyMemberFramePool = originalPool
    reloaded.spacing, reloaded.bottomPadding = 10, 2
    reloaded.Layout, reloaded.UpdatePartyMemberBackground = nativeLayout, nativeBackground
    reloaded.scale, reloaded.GetScale = editScale, PartyFrame.GetScale
    reloaded:SetPoint("TOPLEFT", UIParent, "TOPLEFT", loadedX, loadedY)
    PartyFrame = reloaded
    for _, member in ipairs(members) do member.parent = reloaded end
    Mock.active = {members[1], members[2]}
    PartyFrame:Layout()
    Mock.Event("PLAYER_LOGIN")
    return PartyFrame.point[1] == "BOTTOMLEFT" and PartyFrame.point[4] == loadedX
        and near(bottom(PartyFrame), top(UIParent) + loadedY - savedHeight)
end
check(reloadParty(), "Reloading with rounded offsets and a different roster keeps the saved bottom position")
vv.db.partyGrowthAnchor = {key = ("TOPLEFT:UIParent:TOPLEFT:%.4f:%.4f"):format(editX, editY), height = savedHeight}
check(reloadParty(), "An existing saved bottom position survives migration across Edit Mode rounding")

-- Edit Mode wraps the ordinary anchor methods with shared snap/dirty-state
-- writes. Cosmetic growth must use its C-backed base methods instead.
local party = PartyFrame
party.SetPointBase, party.ClearAllPointsBase = party.SetPoint, party.ClearAllPoints
local snapTarget = {snappedFrames={[party]=true}}
party.snappedToFrame = snapTarget
local anchorWrites = 0
function party:SetPoint(...)
    self:SetPointBase(...)
    anchorWrites = anchorWrites + 1
    EditModeManagerFrame.editModeSystemAnchorDirty = true
    self.snappedToFrame = snapTarget
    snapTarget.snappedFrames[self] = true
end
function party:ClearAllPoints()
    self:ClearAllPointsBase()
    anchorWrites = anchorWrites + 1
    snapTarget.snappedFrames[self] = nil
    self.snappedToFrame = nil
end
local function cleanEditState(label)
    check(anchorWrites == 0 and EditModeManagerFrame.editModeSystemAnchorDirty == nil
        and party.snappedToFrame == snapTarget and snapTarget.snappedFrames[party], label)
end
vv.Party.SetOption("growUp", false)
check(party.point[1] == "TOPLEFT", "Downward growth restores the saved native anchor")
cleanEditState("Restoring the anchor preserves native Edit Mode snap and dirty state")
vv.Party.SetOption("growUp", true)
check(party.point[1] == "BOTTOMLEFT", "Upward growth still applies its visual anchor")
cleanEditState("Upward growth does not write shared Edit Mode state")
vv.SetModuleEnabled("party", false)
check(party.point[1] == "TOPLEFT", "Disabling party tweaks restores its native anchor")
cleanEditState("Disabling party tweaks leaves native Edit Mode bookkeeping untouched")
vv.SetModuleEnabled("party", true)
cleanEditState("Re-enabling party tweaks leaves native Edit Mode bookkeeping untouched")

-- Native dragging/saving continues to use the wrappers. Once it settles,
-- exit and periodic addon refreshes must not re-dirty shared native state.
editing = true
party:ClearAllPoints()
party:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 140, -220)
check(anchorWrites == 2 and EditModeManagerFrame.editModeSystemAnchorDirty,
    "Native Edit Mode movement retains its original anchor methods")
Mock.EditModeEvent("EditMode.SavedLayouts")
editing = false
anchorWrites, EditModeManagerFrame.editModeSystemAnchorDirty = 0, nil
Mock.EditModeEvent("EditMode.Exit")
Mock.Event("EDIT_MODE_LAYOUTS_UPDATED")
Mock.Tick(2)
check(party.point[1] == "BOTTOMLEFT", "Leaving Edit Mode restores upward growth at the new position")
cleanEditState("Edit Mode exit, layout events, and polling preserve native snap and dirty state")
NST_PARTY_LAYOUT_CHECKS = checks
