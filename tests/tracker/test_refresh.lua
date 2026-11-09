-- Quest changes can arrive after the native tracker has rendered an empty
-- watch list. A cosmetic relayout alone cannot recreate those missing blocks.
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
local originalCount, originalMarkDirty = C_QuestLog.GetNumQuestWatches, native.MarkDirty
local originalCombat, requests = InCombatLockdown, 0
function native:MarkDirty()
    originalMarkDirty(self) -- Also asserts that requests cross the secure boundary.
    requests = requests + 1
    C_Timer.After(0, function() container:Update() end)
end
local function emptyThenChange(event)
    C_QuestLog.GetNumQuestWatches = function() return 0 end
    container:Update(); RunMockTimers()
    check(count() == 0, "native pass reproduces an empty tracker")
    C_QuestLog.GetNumQuestWatches = originalCount
    events.callback(events, event)
end
emptyThenChange("QUEST_ACCEPTED")
events.callback(events, "QUEST_LOG_UPDATE")
events.callback(events, "QUEST_WATCH_LIST_CHANGED")
RunMockTimers()
check(requests == 1, "quest-change burst requests one fresh native quest pass")
RunMockTimers()
check(count() == originalCount() and native.firstBlock:IsShown(), "watched quests return without a reload")
for _, event in ipairs({"QUEST_TURNED_IN", "QUEST_REMOVED", "QUEST_WATCH_UPDATE", "PLAYER_ENTERING_WORLD"}) do
    check(events.events[event], "refresh event is registered: " .. event)
    local before = requests
    emptyThenChange(event); RunMockTimers(); RunMockTimers()
    check(requests == before + 1 and count() == originalCount(), "fresh native rows recover after " .. event)
end
local before = requests
InCombatLockdown = function() return true end
events.callback(events, "QUEST_LOG_UPDATE"); RunMockTimers()
check(requests == before, "native refresh request waits during combat")
InCombatLockdown = originalCombat
events.callback(events, "PLAYER_REGEN_ENABLED"); RunMockTimers(); RunMockTimers()
check(requests == before + 1, "pending quest refresh runs after combat")
vv.SetModuleEnabled("questTracker", false); RunMockTimers(); RunMockTimers()
before = requests
events.callback(events, "QUEST_LOG_UPDATE"); RunMockTimers(); RunMockTimers()
check(requests == before, "disabled module leaves native quest events alone")
vv.SetModuleEnabled("questTracker", true); RunMockTimers(); RunMockTimers()
before = requests
addon.RefreshModule(); container:Update(); RunMockTimers(); RunMockTimers()
check(requests == before, "native posthooks do not request another native update")
native.MarkDirty = originalMarkDirty
container:Update(); RunMockTimers()
print("PASS: " .. checks .. " quest-change refresh, missing-row recovery, coalescing, combat, and module checks")
