local vv, addon = VV_TEST_NS, VV_TEST_NS.QuestTracker
local checks, combat = 0, false
local function check(value, label) checks = checks + 1; assert(value, label) end
InCombatLockdown = function() return combat end
QuestScrollFrame = CreateFrame("ScrollFrame")
local list = QuestScrollFrame
list:SetSize(304, 200)
list.Contents = CreateFrame("Frame", nil, list)
list:SetScrollChild(list.Contents)
local nativeClick = function() end
local function pool(size)
    local pool = { active = {}, inactive = {} }
    function pool:EnumerateActive() return pairs(self.active) end
    function pool:Acquire()
        local frame = table.remove(self.inactive)
        if not frame then
            frame = CreateFrame("Button", nil, list.Contents)
            frame.Text = frame:CreateFontString()
            frame.Text:SetFont("LogFont.ttf", size, "")
            frame:SetHeight(22)
            frame:SetScript("OnClick", nativeClick)
        end
        self.active[frame] = true
        frame:Show()
        return frame
    end
    function pool:Release(frame)
        self.active[frame] = nil
        frame:Hide(); frame:ClearAllPoints()
        self.inactive[#self.inactive + 1] = frame
    end
    function pool:ReleaseAll()
        local frames = {}
        for frame in self:EnumerateActive() do frames[#frames + 1] = frame end
        for _, frame in ipairs(frames) do self:Release(frame) end
    end
    return pool
end
list.titleFramePool, list.objectiveFramePool, list.headerFramePool = pool(16), pool(12), pool(16)
local title, objective, header
QuestLogQuests_Update = function()
    list.titleFramePool:ReleaseAll(); list.objectiveFramePool:ReleaseAll(); list.headerFramePool:ReleaseAll()
    header = list.headerFramePool:Acquire()
    header.Text:SetText("Elwynn Forest")
    local height = header:GetHeight()
    for index = 1, 10 do
        title = list.titleFramePool:Acquire()
        title.Text:SetText("Quest " .. index)
        objective = list.objectiveFramePool:Acquire()
        objective.Text:SetText("0/5 enemies")
        objective:SetHeight(objective.Text:GetStringHeight())
        title:SetHeight(title.Text:GetStringHeight() + objective:GetHeight() + 14)
        height = height + title:GetHeight()
    end
    list.Contents:SetHeight(height)
end
local menuModifiers = {}
Menu = { ModifyMenu = function(tag, callback) menuModifiers[tag] = callback end }
QuestLogQuests_Update()
local normalHeight = list.Contents:GetHeight()
assert(loadfile("Modules/QuestTracker/QuestLog.lua"))("VanillaVarnish", vv)
local events = MockFrames[#MockFrames]
events.callback(events, "PLAYER_LOGIN")
check(not addon.db.compactLog and title.Text.size == 16, "compact quest log defaults off")
check(addon.questLogOptionsCategory.name == "Quest log"
    and addon.optionControls.compactLog:GetParent() == addon.questLogOptionsPanel
    and addon.optionControls.compactLog:GetParent() ~= addon.optionsPanel,
    "quest log compact view has its own settings page")
SlashCmdList.VANILLAVARNISH("questlog")
check(addon.questLogOptionsPanel:IsShown(), "questlog slash command opens the dedicated page")
local root = {}
function root:CreateCheckbox(label, selected, callback) self.label, self.selected, self.callback = label, selected, callback end
menuModifiers.MENU_QUEST_MAP_FRAME_SETTINGS(nil, root)
check(root.label == "Compact quest log" and not root.selected(), "native quest log settings contains compact checkbox")
root.callback()
check(addon.db.compactLog and addon.optionControls.compactLog:GetChecked(), "native menu synchronizes saved choice and addon settings")
check(title.Text.size == 14.5 and objective.Text.size == 10.5 and header.Text.size == 14.5,
    "native titles and objectives use a gentle 1.5-point reduction")
check(header:GetHeight() == 22 * 0.9 and list.Contents:GetHeight() < normalHeight, "compact log headers and quest rows fit more entries")
check(title:GetScript("OnClick") == nativeClick and list:GetWidth() == 304, "native clicks and quest log width are preserved")
check(not addon.db.compact, "log compact choice is independent of tracker compact choice")
local compactHeight = list.Contents:GetHeight()
QuestLogQuests_Update(); QuestLogQuests_Update()
check(list.Contents:GetHeight() == compactHeight, "pooled log rows never progressively shrink")
list.titleFramePool:Release(title)
check(title.Text.size == 16, "released log titles restore native fonts")
QuestLogQuests_Update()
combat = true
root.callback()
check(not addon.db.compactLog and title.Text.size == 14.5, "compact log change waits during combat")
combat = false; events.callback(events, "PLAYER_REGEN_ENABLED")
check(title.Text.size == 16 and header:GetHeight() == 22 and list.Contents:GetHeight() == normalHeight,
    "combat end restores fonts, header heights, and native scroll extent")
addon.SetOption("compactLog", true)
vv.SetModuleEnabled("questTracker", false)
check(title.Text.size == 16 and addon.db.compactLog, "module off restores log while preserving preference")
vv.SetModuleEnabled("questTracker", true)
check(title.Text.size == 14.5, "module re-enable restores compact log")
addon.ResetOptions()
check(title.Text.size == 14.5 and addon.db.compactLog, "tracker defaults preserve separate quest log preferences")
addon.SetOption("compact", true)
addon.ResetQuestLogOptions()
check(title.Text.size == 16 and not root.selected(), "restore defaults synchronizes native quest log menu")
check(addon.db.compact, "quest log defaults preserve tracker preferences")
print("PASS: " .. checks .. " compact quest log native menu, measured heights, pooling, combat, and restoration checks")
