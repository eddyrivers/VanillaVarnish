local vv = VV_TEST_NS
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
SlashCmdList.VANILLAVARNISH("groupbrowser")
local checkbox = vv.optionControls["groupBrowser.compressed"].button
local dropdown = vv.optionControls["groupBrowser.sort"].dropdown
assert(vv.groupBrowserCategory.frame:IsShown() and not checkbox:GetChecked())
assert(vv.db.groupBrowser.sort == "default" and not LFGBrowseFrame)
checkbox:SetChecked(true)
checkbox.scripts.OnClick(checkbox)
assert(vv.db.groupBrowser.compressed and not LFGBrowseFrame, "Settings can be changed before the native browser loads")

local object = Mock.Object
function object:GetNumPoints() return #self.points end
function object:GetPoint(index) return unpack(self.points[index or 1]) end
function object:GetFont() return self.font, self.fontSize, self.fontFlags end
function object:CanWordWrap() return self.wordWrap ~= false end
function object:SetDesaturated(value) self.desaturated = value end
local originalHook = hooksecurefunc
function hooksecurefunc(object, key, callback)
    if type(object) == "string" then return originalHook(_G, object, key) end
    return originalHook(object, key, callback)
end

local people = {
    [10] = {level=24, className="Hunter", classFilename="HUNTER", areaName="Stormwind City"},
    [11] = {level=29, className="Warrior", classFilename="WARRIOR"},
    [12] = {level=24, className="Druid", classFilename="DRUID", areaName="The Barrens"},
    [13] = {secret=true},
    [40] = {level=25, className="Warrior", classFilename="WARRIOR", areaName="Westfall"},
}
local roles = {
    [10] = {LEADER_ROLE_DAMAGER=true},
    [11] = {LEADER_ROLE_TANK=true, LEADER_ROLE_HEALER=true, LEADER_ROLE_DAMAGER=true},
    [12] = {LEADER_ROLE_HEALER=true, LEADER_ROLE_DAMAGER=true},
    [13] = {secret=true},
}
RAID_CLASS_COLORS = {HUNTER={}, WARRIOR={}, DRUID={}}
C_LFGList = {
    GetSearchResultInfo = function(id) return {generalPlaystyle=id == 10 and 2 or 1, numMembers=id >= 40 and 4 or 1} end,
    GetSearchResultLeaderInfo = function(id) return people[id] end,
    GetSearchResultMemberCounts = function(id) return roles[id] end,
}
function GetGeneralPlaystyleString(value) return value == 2 and "Competitive" or "Relaxed" end
LFGVanillaBrowseDividerType = {CategorySolo=1, CategoryGroup=2}
ScrollBoxListMixin = {Event={OnInitializedFrame="initialize", OnReleasedFrame="release"}}

local function Node(data, nodes)
    local node = {data=data, nodes=nodes}
    function node:GetData() return self.data end
    function node:GetNodes() return self.nodes end
    function node:SetSortComparator(compare, _, skipSort)
        if not skipSort then table.sort(self.nodes, compare) end
    end
    return node
end
local group1 = Node({resultID=40, index=2, category=2})
local group2 = Node({resultID=41, index=3, category=2})
local firstPlayer = Node({resultID=10, index=4, category=1})
local players = Node({dividerType=1}, {firstPlayer, Node({resultID=11, index=5, category=1}),
    Node({resultID=12, index=6, category=1}), Node({resultID=13, index=7, category=1})})
local groups = Node({dividerType=2}, {group1, group2})
local selfListing = Node({resultID=50, index=1})
local provider = {nodes={selfListing, groups, players}, invalidations=0}
function provider:GetChildrenNodes() return self.nodes end
function provider:Invalidate() self.invalidations = self.invalidations + 1 end
local view = {}
function view:GetTemplateExtentFromElementData(node)
    local data = node:GetData()
    return data.dividerType and 36 or data.category and 72 or 52
end
function view:GetElementExtentCalculator() return self.calculator end
function view:SetElementExtentCalculator(calculator) self.calculator = calculator end
local callbacks, rows = {}, {}
local scrollBox = {updates=0}
function scrollBox:RegisterCallback(event, callback, owner) callbacks[event] = function(...) callback(owner, ...) end end
function scrollBox:GetView() return view end
function scrollBox:GetDataProvider() return self.provider end
function scrollBox:ForEachFrame(callback) for row, node in pairs(rows) do callback(row, node) end end
function scrollBox:FullUpdate() self.updates = self.updates + 1 end
function scrollBox:ReinitializeFrames()
    self:ForEachFrame(function(row, node)
        if node:GetData().resultID then LFGBrowseSearchEntry_Update(row) end
        callbacks.initialize(row, node)
    end)
end

local function MakeResult()
    local row = Mock.New(UIParent)
    row:SetSize(429, 72)
    row.labels, row.artwork = {}, {}
    function row:CreateFontString(...)
        local label = object.CreateFontString(self, ...)
        self.labels[#self.labels+1] = label
        return label
    end
    function row:CreateTexture(...)
        local texture = object.CreateTexture(self, ...)
        self.artwork[#self.artwork+1] = texture
        return texture
    end
    for _, key in ipairs({"Name", "ActivityName", "Level", "PlaystyleLabel"}) do
        row[key] = row:CreateFontString()
        row[key]:SetFont("Native.ttf", 15, "")
    end
    for _, key in ipairs({"PartyIcon", "ClassIcon", "NewPlayerFriendlyIcon", "DiscordIcon"}) do
        row[key] = row:CreateTexture()
        row[key]:SetSize(24, 24)
    end
    row.ActivityName:SetPoint("TOPLEFT", row.Name, "BOTTOMLEFT", 0, -2)
    row.DataDisplay = Mock.New(row)
    row.DataDisplay:SetSize(200, 32)
    row.DataDisplay.Solo = {RolesText=Mock.New(row.DataDisplay)}
    row.DataDisplay:SetPoint("RIGHT", row, "RIGHT", -2, -1)
    row.DataDisplay.DelistButton = Mock.New(row.DataDisplay)
    row.DataDisplay.DelistButton:SetScript("OnClick", function() row.delisted = true end)
    row:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then scrollBox.selected = rows[self]
        elseif button == "RightButton" then self.contextResult = self.resultID end
    end)
    row:SetScript("OnEnter", function(self) self.tooltipResult = self.resultID end)
    return row
end

function LFGBrowseSearchEntry_Update(row)
    row.PartyIcon:SetShown(row.resultID >= 40)
    row.Name:ClearAllPoints()
    row.Name:SetPoint("TOPLEFT", row.PartyIcon, row.resultID >= 40 and "TOPRIGHT" or "TOPLEFT", 0, -2)
    row.Name:SetWidth(220)
    row.Name:SetText("Character " .. row.resultID)
    row.ActivityName:SetText("Stormwind Stockades")
    row.DiscordIcon:Hide()
    row.NewPlayerFriendlyIcon:Hide()
end

LFGBrowseFrame = {ScrollBox=scrollBox}
function LFGBrowseFrame:UpdateResults() scrollBox.provider = provider end
Mock.Event("ADDON_LOADED", "Blizzard_GroupFinder_VanillaStyle")
assert(scrollBox.updates == 0 and view.calculator, "The view can attach before the first search")
LFGBrowseFrame:UpdateResults()
local function Show(row, node)
    rows[row], row.resultID = node, node:GetData().resultID
    row:SetHeight(view.calculator and view.calculator(1, node) or view:GetTemplateExtentFromElementData(node))
    if row.resultID then LFGBrowseSearchEntry_Update(row) end
    callbacks.initialize(row, node)
end
local solo, group = MakeResult(), MakeResult()
local nativeClick, nativeHover, nativeDelist = solo.scripts.OnClick, solo.scripts.OnEnter, group.DataDisplay.DelistButton.scripts.OnClick
Show(solo, firstPlayer)
Show(group, group1)
local header = Mock.New(UIParent)
header.CategoryLabel = header:CreateFontString()
header.CategoryLabel:SetFont("Native.ttf", 15, "")
header.ExpandIcon, header.CollapseIcon, header.ResultBG = header:CreateTexture(), header:CreateTexture(), header:CreateTexture()
Show(header, players)
local available = 535 - 112 - 40 - view.calculator(1, selfListing) - 2 * header:GetHeight()
assert(math.floor(available / solo:GetHeight()) >= 10 and solo:GetHeight() == 30 and header:GetHeight() == 20)
assert(solo.Name.fontSize == 11 and solo.Name:GetWidth() == 135 and solo.ActivityName:GetText() == "Stormwind Stockades")
for _, row in ipairs({solo, group}) do
    local nameTop = select(5, row.Name:GetPoint())
    local notes = row.labels[6]
    local notesTop = select(5, notes:GetPoint())
    assert(-nameTop - 2 == 2 and row:GetHeight() + notesTop - notes:GetHeight() == 2,
        "Both lines sit two units inside the native background")
    assert(nameTop - row.Name:GetHeight() == notesTop, "Text bounds meet without overlapping")
end
assert(solo.labels[5]:GetText() == 24 and solo.artwork[5].atlas == "groupfinder-icon-class-hunter")
assert(group.labels[5]:GetText() == 25 and group.artwork[5].atlas == "groupfinder-icon-class-warrior")
assert(solo.labels[6]:GetText():find("Competitive|r   Current zone: Stormwind City", 1, true))
assert(group.DataDisplay:GetScale() == 0.6 and solo.DataDisplay.Solo.RolesText:GetAlpha() == 0)
solo.scripts.OnClick(solo, "LeftButton")
solo.scripts.OnClick(solo, "RightButton")
solo.scripts.OnEnter(solo)
group.DataDisplay.DelistButton.scripts.OnClick()
assert(scrollBox.selected == firstPlayer and solo.contextResult == 10 and solo.tooltipResult == 10 and group.delisted)

local function PlayerOrder()
    local ids = {}
    for _, node in ipairs(players:GetNodes()) do ids[#ids+1] = node:GetData().resultID end
    return table.concat(ids, ",")
end
local sortMenu = Mock.Menu(dropdown)
sortMenu[2].callback()
assert(PlayerOrder() == "11,10,12,13" and dropdown.selectionText == "Level (highest first)")
sortMenu[3].callback()
assert(PlayerOrder() == "12,10,11,13" and scrollBox.selected == firstPlayer)
assert(provider.nodes[1] == selfListing and provider.nodes[2] == groups and groups.nodes[1] == group1 and groups.nodes[2] == group2)
players.nodes[1], players.nodes[2] = players.nodes[2], players.nodes[1]
LFGBrowseFrame:UpdateResults()
assert(PlayerOrder() == "12,10,11,13", "Sorting applies again when Blizzard updates the results")
sortMenu[4].callback()
assert(PlayerOrder() == "11,12,10,13" and dropdown.selectionText == "Role (tank, healer, DPS)",
    "Role sorting prefers the highest listed role and puts unknown roles last")
assert(scrollBox.selected == firstPlayer and provider.nodes[1] == selfListing and groups.nodes[1] == group1,
    "Role sorting keeps the selection, own listing, and group order")
sortMenu[1].callback()
assert(PlayerOrder() == "10,11,12,13" and provider.invalidations == 5)

local levelLabel, secondaryLabel = solo.labels[5], solo.labels[6]
people[10] = people[11]
LFGBrowseSearchEntry_Update(solo)
assert(levelLabel:GetText() == 29 and not secondaryLabel:GetText():find("Current zone", 1, true) and solo.Name:GetWidth() == 135)
callbacks.release(solo)
assert(not levelLabel:IsShown() and not secondaryLabel:IsShown() and solo.Name.fontSize == 15 and solo.Level:GetAlpha() == 1)
Show(solo, players.nodes[4])
assert(not levelLabel:IsShown() and not solo.artwork[5]:IsShown() and not secondaryLabel:GetText():find("Current zone", 1, true))
assert(solo.labels[5] == levelLabel, "Recycled native buttons reuse their compact artwork")

checkbox:SetChecked(false)
checkbox.scripts.OnClick(checkbox)
assert(not view.calculator and solo:GetHeight() == 72 and header:GetHeight() == 36)
assert(solo.Name.fontSize == 15 and solo.Name:GetWidth() == 220 and group.DataDisplay:GetScale() == 1)
assert(solo.scripts.OnClick == nativeClick and solo.scripts.OnEnter == nativeHover
    and group.DataDisplay.DelistButton.scripts.OnClick == nativeDelist)
