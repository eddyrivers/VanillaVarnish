local vv, ns = VV_TEST_NS, VV_TEST_NS.Nameplates
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local failures, checks = {}, 0
local function check(value, message)
    checks = checks + 1
    if not value then failures[#failures + 1] = message end
end
local function marker(plate, kind)
    for _, frame in ipairs(Mock.frames) do
        if frame.parent == plate.UnitFrame and frame.kind == kind then return frame end
    end
end
local first = Mock.Plate("nameplate1")
Mock.units.nameplate1, Mock.rangeResult = true, false
ns.SetRangeSpell("damage", "Moonfire")
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
Mock.Tick(0.2)
check(marker(first, "loot"):IsShown(), "Normal quest objectives still produce markers")

-- A pooled frame can be reassigned before an old removal notification arrives.
Mock.plates.nameplate2, Mock.units.nameplate2 = first, true
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate2")
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
check(first.UnitFrame:GetAlpha() == 0.5, "An old removal must not restore a recycled plate's range alpha")
Mock.Tick(0.2)
check(marker(first, "loot"):IsShown(), "An old removal must not clear a recycled plate's markers")

local forbidden = Mock.Plate("nameplate3")
forbidden.UnitFrame.forbidden = true
Mock.units.nameplate3 = true
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate3")
check(marker(forbidden, "loot") == nil, "Forbidden unit frames must not receive addon children or hooks")

local nativeTooltip = C_TooltipInfo.GetUnit
local refused = setmetatable({secret=false}, {__index=function() error("restricted tooltip record") end})
C_TooltipInfo.GetUnit = function() return refused end
check(pcall(Mock.Tick, 1), "Restricted nested tooltip data must not break nameplate updates")
C_TooltipInfo.GetUnit = nativeTooltip

local nativeInfo = C_QuestLog.GetInfo
C_QuestLog.GetInfo = function() return refused end
Mock.Event("QUEST_LOG_UPDATE")
check(pcall(Mock.Tick, 0.2), "Restricted quest records must not break nameplate updates")
C_QuestLog.GetInfo = nativeInfo
Mock.Event("PLAYER_REGEN_ENABLED")
Mock.Tick(0.2)
check(marker(first, "loot"):IsShown(), "Quest markers recover after combat without another quest-log event")
local nativeObjectives = C_QuestLog.GetQuestObjectives
C_QuestLog.GetQuestObjectives = function()
    return {{text="Wolf Pelt: 0/5", type="item", finished={secret=true}}}
end
Mock.Event("QUEST_LOG_UPDATE")
Mock.Tick(0.2)
check(not marker(first, "loot"):IsShown(), "Restricted completion flags cannot imply an unfinished objective")
C_QuestLog.GetQuestObjectives = nativeObjectives
Mock.Event("QUEST_LOG_UPDATE")
Mock.Tick(0.2)

ns.SetFeature("markers", false)
local scans = 0
local nativeEntries = C_QuestLog.GetNumQuestLogEntries
C_QuestLog.GetNumQuestLogEntries = function() scans=scans+1; return nativeEntries() end
Mock.Event("QUEST_LOG_UPDATE")
Mock.Tick(2)
check(scans == 0, "Disabled quest markers must not scan the quest log")
ns.SetFeature("markers", true)
Mock.Tick(0.2)
check(scans > 0 and marker(first, "loot"):IsShown(), "Re-enabling markers refreshes quest data")

-- Always-visible idle timers should not rebuild unchanged gradients every frame.
Mock.plates.target, Mock.units.target = first, true
ns.SetValue("visibility", "always")
Mock.Event("PLAYER_TARGET_CHANGED")
Mock.Tick(1)
local colors = 0
for _, row in ipairs(Mock.Stack(first).bars.main.fillRows) do
    hooksecurefunc(row[1], "SetGradient", function() colors=colors+1 end)
end
for _=1, 20 do Mock.Tick(0.01) end
check(colors == 0, "Idle timers must reuse their unchanged artwork")
local stack = Mock.Stack(first)
stack:Hide()
ns.Refresh()
check(colors > 0 and stack:IsShown(), "Showing a hidden timer stack invalidates cached rendering")
colors = 0
ns.SetBarValue("main", "color", "coral", 1)
check(colors > 0, "Appearance edits redraw idle timers")
colors = 0
Mock.Event("PLAYER_SWING", 2, Enum.PlayerSwingType.MainHand)
Mock.Tick(0.2)
check(colors > 0 and Mock.Stack(first).bars.main.sparkAnim:IsPlaying(), "Active swings still redraw and animate")

assert(#failures == 0, table.concat(failures, "\n"))
VV_REVIEW_NAMEPLATE_CHECKS = checks
