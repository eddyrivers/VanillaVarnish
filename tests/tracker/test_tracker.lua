-- Run from the addon directory with Lua 5.1.
local checks = 0
local function equal(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    checks = checks + 1
end
assert(loadfile("tests/tracker/native_ui_mock.lua"))()
local addon, combat = {}, false
local vv = VV_TEST_NS
vv.QuestTracker = addon
local inSecureCall, dirty = false, 0
InCombatLockdown = function() return combat end
issecretvalue = function() error("secret capability must not gate native grouping") end
DEFAULT_CHAT_FRAME = { AddMessage = function() end }
GameTooltip = { Hide = function() end }
SlashCmdList = {}
GetBuildInfo = function() return "1.60.1", "70235", "", 16001 end
securecallfunction = function(callback, ...)
    inSecureCall = true
    local results = { callback(...) }
    inSecureCall = false
    return unpack(results)
end
local registeredCategory, openedCategory, settingsOpens = nil, nil, 0
Settings = {
    RegisterCanvasLayoutCategory = function(panel, name)
        assert(not registeredCategory, "settings should only register once")
        registeredCategory = { panel = panel, name = name, GetID = function() return 123 end }
        return registeredCategory
    end,
    RegisterAddOnCategory = function(category) equal(category, registeredCategory, "AddOns category registered") end,
    OpenToCategory = function(id)
        assert(inSecureCall, "Settings must open through Blizzard's security boundary")
        assert(not combat, "Settings must not open during combat")
        openedCategory, settingsOpens = id, settingsOpens + 1
        registeredCategory.panel:Show()
    end,
}
hooksecurefunc = function(object, key, callback)
    local original = object[key]
    object[key] = function(...)
        local results = { original(...) }
        callback(...)
        return unpack(results)
    end
end
local menu
MenuUtil = { CreateContextMenu = function(_, generator)
    menu = { buttons = {} }
    function menu:CreateTitle(title) self.title = title end
    function menu:CreateButton(label, callback)
        local button = { callback = callback }
        function button:SetEnabled(enabled) self.enabled = enabled end
        self.buttons[#self.buttons + 1] = button
        return button
    end
    generator(nil, menu)
end }
local entries = {
    { isHeader = true, title = "Westfall" },
    { questID = 4, title = "Unknown", level = 0 },
    { questID = 3, title = "Zulu", level = 15 },
    { questID = 2, title = "Alpha", level = 15 },
    { questID = 1, title = "Low", level = 10 },
    { questID = 6, title = "Alpha", level = 15 },
    { questID = 7, title = "Untracked", level = 20 },
    { isHeader = true, title = "Elwynn Forest", isCollapsed = true },
    { questID = 5, title = "Elsewhere", level = 20 },
}
local watches = { 4, 3, 2, 1, 5, 6 }
local completed = { [2] = true, [3] = true, [4] = true, [6] = true }
local added, removed = {}, {}
C_QuestLog = {
    GetNumQuestLogEntries = function() return #entries end,
    GetInfo = function(index) return entries[index] end,
    IsComplete = function(id) return completed[id] or false end,
    GetNumQuestWatches = function() return #watches end,
    GetQuestIDForQuestWatchIndex = function(index) return watches[index] end,
    AddQuestWatch = function(id) added[#added + 1] = id; watches[#watches + 1] = id; return true end,
    RemoveQuestWatch = function(id)
        removed[#removed + 1] = id
        for index = #watches, 1, -1 do if watches[index] == id then table.remove(watches, index) end end
    end,
}
assert(loadfile("Core.lua"))("VanillaVarnish", vv)
vv.InitDB()
vv.QuestTracker = addon
vv.RegisterOptions = function() vv.rootCategory = vv.rootCategory or {} end
Settings.RegisterCanvasLayoutSubcategory = function(_, panel, name) return Settings.RegisterCanvasLayoutCategory(panel, name) end
local coreEvents = MockFrames[#MockFrames]
assert(loadfile("Modules/QuestTracker/Model.lua"))("VanillaVarnish", vv)
equal(addon.ReadMetadata()[5].zone, "Elwynn Forest", "metadata uses log category")
equal(addon.FormatQuestTitle("[15] Quest", 15), "[15] Quest", "native level preserved")
equal(addon.FormatQuestTitle("|cff00ff00[15]|r Quest", 15), "|cff00ff00[15]|r Quest", "colored level preserved")
equal(addon.FormatQuestTitle("Quest", 0), "Quest", "unknown level omitted")
local groups = addon.ReadWatchGroups()
equal(groups[1].zone, "Elwynn Forest", "zones sorted")
local ids = {}
for _, entry in ipairs(groups[2].quests) do ids[#ids + 1] = entry.id end
equal(table.concat(ids, ","), "1,2,6,3,4", "level title and ID sorting")
equal(table.concat(watches, ","), "4,3,2,1,5,6", "engine watch order unchanged")
local function order(completedFirst)
    local result = {}
    for _, entry in ipairs(addon.ReadWatchGroups(completedFirst)[2].quests) do result[#result + 1] = entry.id end
    return table.concat(result, ",")
end
equal(order(true), "2,6,3,4,1", "completed quests sort by level title ID before incomplete quests")
completed[3] = false
equal(order(true), "2,6,4,1,3", "incomplete quests retain ascending level order after completed quests")
completed[3] = true
completed[4] = false
equal(order(true), "2,6,3,1,4", "unknown incomplete level follows known incomplete levels")
completed[4] = true

local native = CreateFrame("Frame")
native.ContentsFrame = CreateFrame("Frame", nil, native)
native.headerHeight, native.fromHeaderOffsetY, native.fromBlockOffsetY = 25, -10, -10
native.blockOffsetX, native.bottomSpacing, native.availableHeight = 20, 0, 2000
native.blockTemplate, native.isCollapsed = "NativeQuestTemplate", false
local container = CreateFrame("Frame")
container.moduleSpacing = 10
function container:GetAvailableHeight() return 2000 end
function container:Update() return native:Update() end
local other = CreateFrame("Frame")
other:SetHeight(60)
function other:GetContentsHeight() return 60 end
other:SetPoint("TOP", native, "BOTTOM", 0, -10)
container.modules = { native, other }
native.parentContainer = container
ObjectiveTrackerFrame = container
QuestObjectiveTracker = native
local blocks, rendered = {}, {}
local nativeClick = function() end
native.OnBlockHeaderClick = nativeClick
function native:IsCollapsed() return self.isCollapsed end
function native:GetContentsHeight() return self.contentsHeight end
function native:MarkDirty()
    assert(inSecureCall, "MarkDirty must run through Blizzard's security boundary")
    dirty = dirty + 1
end
function native:GetExistingBlock(id) return blocks[id] end
function native:GetBlock(id)
    local block, existing = blocks[id], blocks[id] ~= nil
    if not block then
        block = CreateFrame("Frame", nil, self.ContentsFrame)
        block.id, block.lines = id, {}
        block.HeaderText = block:CreateFontString()
        block.HeaderText:SetFont("Test.ttf", 14, "OUTLINE")
        block.HeaderButton = CreateFrame("Button", nil, block)
        block.HeaderButton:SetScript("OnClick", nativeClick)
        block.ItemButton = CreateFrame("Button", nil, self.ContentsFrame)
        block.ItemButton.secure = true
        block.ProgressBar = CreateFrame("Frame", nil, self.ContentsFrame)
        block.addedRegions = { [block.ItemButton] = true, [block.ProgressBar] = true }
        block.poiButton = CreateFrame("Button", nil, block)
        block.poiButton:SetSize(24, 24)
        block.poiButton:SetPoint("TOPRIGHT", block.HeaderText, "TOPLEFT", -7, 5)
        function block:SetHeader(text)
            self.HeaderText:SetText(text)
            self.height = self.HeaderText:GetStringHeight()
        end
        function block:GetExistingLine(key) return self.lines[key] end
        function block:GetLine(key)
            if not self.lines[key] then
                self.lines[key] = { Text = self:CreateFontString(), Dash = self:CreateFontString() }
            end
            return self.lines[key]
        end
        function block:FreeLine(line) for key, current in pairs(self.lines) do if current == line then self.lines[key] = nil end end end
        function block:Free() for _, line in pairs(self.lines) do self:FreeLine(line) end end
        blocks[id] = block
    end
    return block, existing
end
function native:BeginLayout() self.firstBlock, self.lastBlock, self.contentsHeight = nil, nil, 25 end
function native:LayoutBlock(block)
    if self.contentsHeight + block.height + 10 > self.availableHeight then block:Hide(); return false end
    block.used, block.nextBlock = true, nil
    if self.lastBlock then self.lastBlock.nextBlock = block else self.firstBlock = block end
    self.lastBlock = block
    block:ClearAllPoints()
    block:SetPoint("TOP", self.ContentsFrame, "TOP", 0, -(self.contentsHeight - 25 + 10))
    block:SetHeight(block.height)
    block:Show(); block.ItemButton:Show(); block.ProgressBar:Show()
    self.contentsHeight = self.contentsHeight + block.height + 10
    return true
end
function native:EnumQuestWatchData(callback)
    for _, id in ipairs(watches) do if not callback(self, id) then return end end
end
local originalEnum = native.EnumQuestWatchData
local function render(self, id)
    local block = self:GetBlock(id)
    local metadata = addon.ReadMetadata()[id] or { title = "Quest" }
    block:SetHeader(metadata.title)
    local line = block:GetLine(1)
    line.Text:SetText("0/5 enemies")
    block.height = block.height + line.Text:GetStringHeight() + 4
    rendered[#rendered + 1] = id
    return self:LayoutBlock(block)
end
function native:Update()
    self:BeginLayout()
    self:EnumQuestWatchData(render)
    self:SetHeight(self.contentsHeight)
    return self.contentsHeight, false
end
assert(loadfile("Modules/QuestTracker/QuestTrackerOrganizer.lua"))("VanillaVarnish", vv)
assert(loadfile("Modules/QuestTracker/Settings.lua"))("VanillaVarnish", vv)
local events = MockFrames[#MockFrames]
events.callback(events, "PLAYER_LOGIN")
equal(vv.db.questTracker.completedFirst, false, "completed-first defaults off")
equal(registeredCategory.name, "Quest tracker", "settings category title")
equal(addon.optionControls.enabled:GetChecked(), true, "grouping checkbox defaults on")
equal(addon.optionControls.completedFirst:GetChecked(), false, "completed-first checkbox defaults off")
local heightUsed, truncated = container:Update()
local nativeHeight = native.contentsHeight
local originalNext = blocks[4].nextBlock
local nativeState, blockStates = {}, {}
for key, value in pairs(native) do nativeState[key] = value end
for id, block in pairs(blocks) do
    blockStates[id] = {}
    for key, value in pairs(block) do blockStates[id][key] = value end
end
RunMockTimers()
for key, value in pairs(nativeState) do equal(native[key], value, "native field unchanged: " .. key) end
for key in pairs(native) do equal(nativeState[key] ~= nil, true, "no new native field: " .. key) end
for id, state in pairs(blockStates) do
    for key, value in pairs(state) do equal(blocks[id][key], value, "block field unchanged: " .. id .. "." .. key) end
    for key in pairs(blocks[id]) do equal(state[key] ~= nil, true, "no new block field: " .. id .. "." .. key) end
end
equal(native.EnumQuestWatchData, originalEnum, "native enum function unchanged on secret client")
equal(table.concat(rendered, ","), "4,3,2,1,5,6", "native renders in its original execution order")
equal(heightUsed, nativeHeight, "native Update height return preserved")
equal(truncated, false, "native Update second return preserved")
equal(native.contentsHeight, nativeHeight, "native contents height bookkeeping unchanged")
equal(blocks[4].nextBlock, originalNext, "native linked list unchanged")
equal(native.firstBlock, blocks[4], "native first block unchanged")
equal(blocks[1].height, 26, "native block height bookkeeping unchanged")
equal(blocks[1].HeaderText:GetText(), "[10] Low", "native title receives level")
equal(blocks[1].HeaderText.size, 12, "native title font reduced")
equal(blocks[1].lines[1].Text.size, 10, "native objectives font reduced")
equal(blocks[1].HeaderButton.scripts.OnClick, nativeClick, "native click script preserved")
equal(native.OnBlockHeaderClick, nativeClick, "native context handler preserved")
equal(blocks[1].ItemButton.secure, true, "native secure item retained")
equal(blocks[1].ItemButton:IsShown(), true, "native secure item visible")
equal(container:IsShown(), true, "native objectives window stays visible")
equal(QuestTrackerOrganizerStandaloneTracker, nil, "no second tracker created")
local heads = {}
for _, frame in ipairs(MockFrames) do if frame.zone then heads[#heads + 1] = frame end end
equal(#heads, 2, "two headings integrated into native contents")
equal(heads[1].parent, native.ContentsFrame, "heading uses native contents")
equal(heads[1].Text:GetText(), "Elwynn Forest (1)", "first zone label")
equal(heads[2].Text:GetText(), "Westfall (5)", "second zone count")
equal(heads[1]:GetHeight(), 24, "heading reserves native marker height")
equal(heads[2].Icon:GetSize(), 24, "heading icon matches native marker")
local function top(frame) return select(5, frame:GetPoint(1)) end
equal(top(blocks[5]) > top(blocks[1]), true, "native blocks arranged by zone")
equal(top(blocks[1]) > top(blocks[2]), true, "native blocks arranged by level")
equal(top(blocks[2]) > top(blocks[6]), true, "native blocks arranged by ID at equal title")
equal(top(blocks[3]) > top(blocks[4]), true, "unknown level last")
-- Measure the gap from actual rendered bounds for all fold combinations;
-- expanding either neighbor may add quest content but never extra whitespace.
for mask = 0, 3 do
    for index, heading in ipairs(heads) do
        local collapsed = math.floor(mask / 2^(index - 1)) % 2 == 1
        if (vv.db.questTracker.collapsed[heading.zone] or false) ~= collapsed then
            heading.Icon.scripts.OnClick(heading.Icon, "LeftButton"); RunMockTimers()
        end
    end
    local previous = blocks[5]:IsShown() and blocks[5] or heads[1]
    equal(top(previous) - previous:GetHeight() - top(heads[2]), 10,
        "zone gap remains constant for fold combination " .. mask)
    if blocks[5]:IsShown() then
        equal(top(heads[1]) - heads[1]:GetHeight() - top(blocks[5]), 10,
            "opening a zone retains native heading-to-quest spacing")
    end
end
addon.SetAllZonesCollapsed(false); RunMockTimers()
SlashCmdList.QUESTTRACKERORGANIZER("")
equal(openedCategory, 123, "bare slash command opens settings")
local completedCheck = addon.optionControls.completedFirst
completedCheck:SetChecked(true); completedCheck.scripts.OnClick(completedCheck); RunMockTimers()
equal(vv.db.questTracker.completedFirst, true, "menu saves completed-first option")
equal(top(blocks[2]) > top(blocks[6]), true, "completed equal levels retain ID order")
equal(top(blocks[6]) > top(blocks[3]), true, "completed equal levels retain title order")
equal(top(blocks[4]) > top(blocks[1]), true, "unknown-level completed quest precedes incomplete lower-level quest")
completed[1] = true
events.callback(events, "QUEST_WATCH_UPDATE"); RunMockTimers()
equal(top(blocks[1]) > top(blocks[2]), true, "newly completed quest reorders by level on watch update")
completed[1] = false
events.callback(events, "QUEST_LOG_UPDATE"); RunMockTimers()
equal(top(blocks[4]) > top(blocks[1]), true, "quest becoming incomplete returns to incomplete group")
equal(table.concat(watches, ","), "4,3,2,1,5,6", "completed-first leaves engine watch list unchanged")
completedCheck:SetChecked(false); completedCheck.scripts.OnClick(completedCheck); RunMockTimers()
equal(top(blocks[1]) > top(blocks[2]), true, "unchecking option restores level-only order")
addon.optionsPanel:Hide()
combat = true
local opensBefore = settingsOpens
SlashCmdList.QUESTTRACKERORGANIZER("settings")
equal(settingsOpens, opensBefore, "combat settings open is deferred")
combat = false
coreEvents.callback(coreEvents, "PLAYER_REGEN_ENABLED"); events.callback(events, "PLAYER_REGEN_ENABLED")
equal(settingsOpens, opensBefore + 1, "settings open after combat ends")
RunMockTimers()
local arrangedHeight = native:GetHeight()
events.callback(events, "QUEST_LOG_UPDATE"); RunMockTimers()
equal(native:GetHeight(), arrangedHeight, "repeated refresh does not accumulate heading height")
equal(heads[2].Icon.kind, "Button", "zone icon has its own clickable hit area")
heads[2].Icon.scripts.OnClick(heads[2].Icon, "LeftButton"); RunMockTimers()
equal(heads[2].Icon.normalTexture:match("Plus$"), "Plus", "icon click folds zone and shows plus")
equal(blocks[1]:IsShown(), false, "fold hides native quest")
equal(blocks[1].ItemButton:IsShown(), false, "fold hides sibling item button")
equal(blocks[1].ProgressBar:IsShown(), false, "fold hides sibling progress bar")
equal(#watches, 6, "fold does not untrack quests")
equal(blocks[5]:IsShown(), true, "other zone remains visible")
local collapsedHeight = native:GetHeight()
container:Update()
-- Check the state at the return from Blizzard's layout, BEFORE any timer runs.
-- A next-frame correction passes eventual-state tests but visibly flashes.
equal(blocks[1]:IsShown(), false, "native rebuild keeps folded quest hidden before next frame")
equal(blocks[1].ItemButton:IsShown(), false, "native rebuild keeps folded item hidden before next frame")
equal(heads[2]:IsShown(), true, "native rebuild restores zone heading before next frame")
equal(native:GetHeight(), collapsedHeight, "native rebuild restores grouped height before next frame")
RunMockTimers()
equal(native:GetHeight(), collapsedHeight, "stale queued refresh does not change grouped height")
heads[2].Icon.scripts.OnClick(heads[2].Icon, "LeftButton"); RunMockTimers()
equal(blocks[1]:IsShown(), true, "plus icon expands zone")
equal(heads[2].Icon.normalTexture:match("Minus$"), "Minus", "expanded icon shows minus")
SlashCmdList.QUESTTRACKERORGANIZER("expand"); RunMockTimers()
equal(blocks[1].ItemButton:IsShown(), true, "expand restores native quest item")
equal(blocks[1].ProgressBar:IsShown(), true, "expand restores native progress bar")
container:Update()
equal(top(blocks[5]) > top(blocks[1]), true, "native rebuild preserves expanded ordering before next frame")
equal(heads[1]:IsShown(), true, "native rebuild preserves expanded heading before next frame")
combat = true
SlashCmdList.QUESTTRACKERORGANIZER("collapse"); RunMockTimers()
equal(blocks[1]:IsShown(), true, "combat folding deferred")
combat = false
coreEvents.callback(coreEvents, "PLAYER_REGEN_ENABLED"); events.callback(events, "PLAYER_REGEN_ENABLED"); RunMockTimers()
equal(blocks[1]:IsShown(), false, "fold applies after combat")
equal(heads[1]:IsShown(), true, "collapsed zones keep native headings")
SlashCmdList.QUESTTRACKERORGANIZER("expand"); RunMockTimers()
heads[2].Icon.scripts.OnClick(heads[2].Icon, "RightButton")
equal(menu.title, "Westfall", "native zone context menu")
equal(blocks[1]:IsShown(), true, "right click on icon does not fold zone")
menu.buttons[1].callback()
equal(table.concat(added, ","), "7", "zone track all includes untracked log quest")
combat = true
menu.buttons[2].callback()
equal(#removed, 0, "zone menu rechecks combat")
combat = false
table.remove(watches) -- return to the initial watched set
SlashCmdList.QUESTTRACKERORGANIZER("off"); RunMockTimers()
equal(native:GetHeight(), nativeHeight, "off restores native frame height")
equal(blocks[1].HeaderText:GetText(), "Low", "off restores native title")
equal(blocks[1].HeaderText.size, 14, "off restores native title font")
equal(heads[1]:IsShown(), false, "off removes headings")
equal(blocks[1]:IsShown(), true, "off restores native visibility")
equal(dirty, 1, "off requests native refresh securely")
SlashCmdList.QUESTTRACKERORGANIZER("on")
container:Update(); RunMockTimers()
equal(blocks[1].HeaderText:GetText(), "[10] Low", "grouping restores after native rebuild")
equal(native.contentsHeight, nativeHeight, "rebuild retains native height calculation")
native.availableHeight = 100
container:Update(); RunMockTimers()
equal(native:GetHeight() <= 100, true, "grouped view respects native available height")
combat = true
SlashCmdList.QUESTTRACKERORGANIZER("off")
equal(blocks[4].HeaderText.size, 12, "combat off leaves current font until combat ends")
combat = false
coreEvents.callback(coreEvents, "PLAYER_REGEN_ENABLED"); events.callback(events, "PLAYER_REGEN_ENABLED"); RunMockTimers()
equal(blocks[4].HeaderText.size, 14, "combat off restores font after combat")
equal(heads[1]:IsShown(), false, "combat off removes headings after combat")
equal(dirty, 3, "deferred off requests native refresh securely")
-- A freed/reused native block must not receive an old title on the next refresh.
SlashCmdList.QUESTTRACKERORGANIZER("on")
native.availableHeight = 2000
container:Update(); RunMockTimers()
local line = blocks[1].lines[1]
blocks[1]:Free()
equal(line.Text.size, 12, "pooled line font restored")
equal(blocks[1].HeaderText.size, 14, "pooled title font restored")
blocks[1].HeaderText:SetText("A different pooled owner")
-- A real pool release removes it from the native linked list; simulate that
-- before checking restoration on the next native rebuild.
native:BeginLayout()
equal(blocks[1].HeaderText:GetText(), "A different pooled owner", "freed block drops stale title snapshot")
-- Exercise menu actions and restored preferences after native-state checks.
local actions = {}
for _, frame in ipairs(MockFrames) do
    if frame.parent == addon.optionsPanel and frame.kind == "Button" then actions[frame.text] = frame end
end
container:Update(); RunMockTimers()
actions["Collapse all zones"].scripts.OnClick(); RunMockTimers()
equal(blocks[1]:IsShown(), false, "settings collapse action folds quests")
actions["Expand all zones"].scripts.OnClick(); RunMockTimers()
equal(blocks[1]:IsShown(), true, "settings expand action restores quests")
local enabledCheck = addon.optionControls.enabled
completedCheck:SetChecked(true); completedCheck.scripts.OnClick(completedCheck); RunMockTimers()
enabledCheck:SetChecked(false); enabledCheck.scripts.OnClick(enabledCheck); RunMockTimers()
equal(heads[1]:IsShown(), false, "settings grouping toggle removes headings")
equal(blocks[1].HeaderText:GetText(), "Low", "settings grouping toggle restores native title")
equal(completedCheck:GetChecked(), true, "completed-first preference stays saved while disabled")
SlashCmdList.QUESTTRACKERORGANIZER("on"); RunMockTimers()
equal(enabledCheck:GetChecked(), true, "slash command synchronizes settings checkbox")
equal(top(blocks[4]) > top(blocks[1]), true, "re-enabling applies saved completed-first preference")
vv.db.questTracker.enabled = false
events.callback(events, "PLAYER_LOGIN"); RunMockTimers()
equal(vv.db.questTracker.enabled, false, "saved disabled grouping survives initialization")
equal(vv.db.questTracker.completedFirst, true, "saved completed-first survives initialization")
addon.optionsPanel:Hide(); SlashCmdList.QUESTTRACKERORGANIZER("options")
equal(enabledCheck:GetChecked(), false, "settings controls refresh on reopen")
equal(completedCheck:GetChecked(), true, "settings reopen retains completed-first preference")
actions["Restore defaults"].scripts.OnClick(); RunMockTimers()
equal(vv.db.questTracker.enabled, true, "restore defaults enables grouping")
equal(vv.db.questTracker.completedFirst, false, "restore defaults disables completed-first")
equal(next(vv.db.questTracker.collapsed), nil, "restore defaults expands zones")
equal(completedCheck:GetChecked(), false, "restore defaults synchronizes checkbox")
print("PASS: " .. checks .. " native tracker checks")

-- Master switch restores native state without overwriting smaller choices.
addon.SetOption("completedFirst", true); container:Update(); RunMockTimers()
vv.SetModuleEnabled("questTracker", false); RunMockTimers()
equal(heads[1]:IsShown(), false, "module off hides headings")
equal(blocks[4].HeaderText.size, 14, "module off restores native fonts")
equal(addon.db.enabled, true, "module off preserves grouping choice")
equal(addon.db.completedFirst, true, "module off preserves ordering choice")
combat = true
vv.SetModuleEnabled("questTracker", true)
equal(heads[1]:IsShown(), false, "module enabling waits in combat")
combat = false
events.callback(events, "PLAYER_REGEN_ENABLED"); RunMockTimers()
container:Update(); RunMockTimers()
equal(heads[1]:IsShown(), true, "module re-enables after combat")
equal(blocks[4].HeaderText.size, 12, "module re-enables smaller fonts")
print("PASS: quest tracker master toggle restoration and combat deferral")
