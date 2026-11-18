local vv, native, container = VV_TEST_NS, QuestObjectiveTracker, ObjectiveTrackerFrame
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function unexpected() error("Watched quests must not change native frames or request native actions") end

local savedMethods = {}
for _, frame in ipairs({ native, container, native.firstBlock.ItemButton }) do
    for _, name in ipairs({ "MarkDirty", "Update", "SetHeight", "SetParent", "SetPoint", "SetScript", "SetAttribute" }) do
        savedMethods[#savedMethods + 1] = {frame, name, frame[name]}
        frame[name] = unexpected
    end
end
local original = C_QuestLog
local log = vv.Copy(original)
C_QuestLog = log
local watchCount, progress, reads = 32, "1/5 phials", 0
log.GetNumQuestWatches = function() reads = reads + 1; return watchCount end
log.GetQuestIDForQuestWatchIndex = function(index) return index end
log.GetNumQuestLogEntries = function() return watchCount + 1 end
log.GetInfo = function(index)
    if index == 1 then return {isHeader = true, title = "Darkshore"} end
    return {questID = index - 1, level = index, title = "Quest " .. (index - 1)}
end
log.IsComplete = function(id) return id == 2 or id == 3 end
log.IsFailed = function(id) return id == 4 end
log.GetNextWaypointText = function(id) if id == 2 then return "Return to your contact." end end
log.GetLogIndexForQuestID = function(id) return id + 1 end
log.GetQuestObjectives = function(id)
    return {{text = id == 1 and progress or "Objective"}}
end
log.AddQuestWatch, log.RemoveQuestWatch = unexpected, unexpected
local completionText, useItem = GetQuestLogCompletionText, UseQuestLogSpecialItem
local queryItem, combatCheck, secretAuras = GetQuestLogSpecialItemInfo, InCombatLockdown, C_Secrets
GetQuestLogCompletionText = function() end
GetQuestLogSpecialItemInfo = function(index)
    if index == 2 then return "Quest item link" end
end
UseQuestLogSpecialItem = unexpected
InCombatLockdown = function() return true end
C_Secrets = {ShouldAurasBeSecret = unexpected}

local nextFrame = #MockFrames + 1
SlashCmdList.VANILLAVARNISH("tracker scroll")
local panel, viewport = MockFrames[nextFrame]
for index = nextFrame + 1, #MockFrames do
    local frame = MockFrames[index]
    if frame.template == "UIPanelScrollFrameTemplate" then viewport = frame end
end
check(panel:IsShown() and panel:GetParent() == UIParent and viewport:GetParent() == panel,
    "the view opens in combat and owns its scroll frame")
local function visible(text)
    for _, row in ipairs(viewport.child.fontStrings) do
        if row.shown and row:GetText() == text then return true end
    end
    return false
end
check(visible("Darkshore (32)") and visible("[33] Quest 32") and viewport:GetVerticalScrollRange() > 0,
    "all watches fit in the scroll child independently of Blizzard's visible rows")
check(visible(progress) and visible("Return to your contact.")
    and visible(QUEST_WATCH_QUEST_READY or "Ready for turn-in") and visible(FAILED or "Quest failed"),
    "live progress, delivery, turn-in, and failure states appear")
viewport:SetVerticalScroll(90)
progress = "2/5 phials"
local before = reads
panel.callback(panel, "QUEST_LOG_UPDATE")
panel.callback(panel, "QUEST_WATCH_UPDATE")
RunMockTimers()
check(reads == before + 1 and visible(progress) and viewport:GetVerticalScroll() == 90,
    "quest progress events redraw once and preserve the scroll position")
watchCount = 1
panel.callback(panel, "QUEST_WATCH_LIST_CHANGED")
RunMockTimers()
check(not visible("[33] Quest 32") and viewport:GetVerticalScroll() == 0,
    "shrinking the list hides stale rows and clamps the scroll position")
watchCount = 0
panel.callback(panel, "QUEST_REMOVED")
RunMockTimers()
check(visible("No tracked quests."), "empty watch list has a message")
SlashCmdList.VANILLAVARNISH("tracker scroll")
before = reads
panel.callback(panel, "QUEST_LOG_UPDATE")
RunMockTimers()
check(not panel:IsShown() and reads == before, "hidden views do not read the quest log")
SlashCmdList.VANILLAVARNISH("tracker scroll")

for _, entry in ipairs(savedMethods) do entry[1][entry[2]] = entry[3] end
C_QuestLog, InCombatLockdown, C_Secrets = original, combatCheck, secretAuras
GetQuestLogCompletionText, UseQuestLogSpecialItem = completionText, useItem
GetQuestLogSpecialItemInfo = queryItem
vv.SetModuleEnabled("questTracker", false)
check(not panel:IsShown(), "disabling the quest tracker module closes the view")
vv.SetModuleEnabled("questTracker", true)
RunMockTimers()
print("PASS: " .. checks .. " watched quest scrolling, refresh, combat, and native isolation checks")
