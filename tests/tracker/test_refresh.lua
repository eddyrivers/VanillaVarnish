-- Native quest events rebuild the rows. Addon events and settings must
-- only arrange the result, even while an item quest is entering the tracker.
local vv, native, container = VV_TEST_NS, QuestObjectiveTracker, ObjectiveTrackerFrame
local addon, events = vv.QuestTracker
for _, frame in ipairs(MockFrames) do
    if frame.events and frame.events.QUEST_WATCH_LIST_CHANGED then events = frame; break end
end
assert(events, "quest tracker event listener is installed")
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function count()
    local total, block = 0, native.firstBlock
    while block do total, block = total + 1, block.nextBlock end
    return total
end

container:SetCollapsed(false)
local originalCount = C_QuestLog.GetNumQuestWatches
C_QuestLog.GetNumQuestWatches = function() return 0 end
native:Update(); RunMockTimers()
check(count() == 0, "native tracker can start with an empty watch list")
C_QuestLog.GetNumQuestWatches = originalCount

events.callback(events, "QUEST_ACCEPTED")
events.callback(events, "QUEST_LOG_UPDATE")
RunMockTimers()
check(count() == 0, "addon quest events do not trigger a rebuild before the item watch arrives")

local itemInfo, logIndexForQuest = GetQuestLogSpecialItemInfo, C_QuestLog.GetLogIndexForQuestID
C_QuestLog.GetLogIndexForQuestID = function(id) return id end
GetQuestLogSpecialItemInfo = function(index) if index == 1 then return "quest item link" end end
-- The game can run a captured container callback that bypasses its Update
-- post-hook. The module's Update post-hook still arranges the rebuilt rows.
C_Timer.After(0, function() native:Update() end)
events.callback(events, "QUEST_WATCH_LIST_CHANGED")
RunMockTimers()
local block = native:GetExistingBlock(1)
check(count() == originalCount() and block.ItemButton:IsShown(), "the native update supplies the item row and button")
local heading
for _, frame in ipairs(MockFrames) do if frame.zone == "Westfall" then heading = frame; break end end
check(heading and heading:IsShown(), "item quests keep grouped headings")
local itemClick = block.ItemButton:GetScript("OnClick")
addon.SetAllZonesCollapsed(true); RunMockTimers()
check(not block.ItemButton:IsShown(), "grouping can still fold the item row")
addon.SetAllZonesCollapsed(false); RunMockTimers()
check(block.ItemButton:IsShown() and block.ItemButton:GetScript("OnClick") == itemClick,
    "expanding restores the same native item button and click handler")
addon.SetOption("compact", true); RunMockTimers()
check(heading:IsShown() and block.HeaderText.size == 10.5, "compact view still works with item quests")
addon.SetOption("compact", false); RunMockTimers()

local originalCombat = InCombatLockdown
InCombatLockdown = function() return true end
events.callback(events, "QUEST_LOG_UPDATE"); RunMockTimers()
InCombatLockdown = originalCombat
events.callback(events, "PLAYER_REGEN_ENABLED"); RunMockTimers()
GetQuestLogSpecialItemInfo, C_QuestLog.GetLogIndexForQuestID = itemInfo, logIndexForQuest
container:Update(); RunMockTimers()
print("PASS: " .. checks .. " native quest refresh, item grouping, folding, and compact view checks")
