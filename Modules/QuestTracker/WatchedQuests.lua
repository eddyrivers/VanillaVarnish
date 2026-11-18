local _, VV = ...
local addon = VV.QuestTracker
local panel, viewport, content
local rows, refreshQueued = {}, false
local WIDTH, HEIGHT = 364, 430

local function ReadObjectives(questID)
    if C_QuestLog.IsFailed(questID) then return {{text = FAILED or "Quest failed"}} end
    if C_QuestLog.IsComplete(questID) then
        local logIndex = C_QuestLog.GetLogIndexForQuestID(questID)
        local info = logIndex and logIndex > 0 and C_QuestLog.GetInfo(logIndex)
        if info and info.isAutoComplete then
            return {{text = QUEST_WATCH_QUEST_COMPLETE or "Quest complete", finished = true}}
        end
        local instruction = info and GetQuestLogCompletionText(logIndex)
            or C_QuestLog.GetNextWaypointText(questID)
        return {{text = instruction or QUEST_WATCH_QUEST_READY or "Ready for turn-in", finished = not instruction}}
    end
    return C_QuestLog.GetQuestObjectives(questID) or {}
end

local function Render()
    local offset = viewport:GetVerticalScroll()
    local count, y = 0, 4
    local function Line(text, font, indent, gap)
        count = count + 1
        local row = rows[count]
        if not row then
            row = content:CreateFontString(nil, "OVERLAY")
            row:SetJustifyH("LEFT")
            row:SetWordWrap(true)
            rows[count] = row
        end
        row:SetFontObject(font)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", indent, -y)
        row:SetWidth(content:GetWidth() - indent - 6)
        row:SetText(text)
        row:Show()
        y = y + row:GetStringHeight() + gap
    end

    local groups = addon.ReadWatchGroups(VV.db.questTracker.completedSort)
    for _, group in ipairs(groups) do
        Line(group.zone .. " (" .. #group.quests .. ")", GameFontNormal, 2, 6)
        for _, quest in ipairs(group.quests) do
            Line(addon.FormatQuestTitle(quest.title, quest.level), GameFontHighlight, 10, 3)
            for _, objective in ipairs(ReadObjectives(quest.id)) do
                if objective.text and objective.text ~= "" then
                    local font = objective.finished and GameFontDisableSmall or GameFontHighlightSmall
                    Line(objective.text, font, 20, 3)
                end
            end
            y = y + 7
        end
        y = y + 5
    end
    if #groups == 0 then Line("No tracked quests.", GameFontHighlight, 2, 4) end
    for index = count + 1, #rows do rows[index]:Hide() end
    content:SetHeight(y)
    viewport:UpdateScrollChildRect()
    viewport:SetVerticalScroll(math.min(offset, viewport:GetVerticalScrollRange()))
end

function addon.RefreshWatchedQuests()
    if not panel or not panel:IsShown() then return end
    if not VV.IsModuleEnabled("questTracker") then panel:Hide(); return end
    if refreshQueued then return end
    refreshQueued = true
    C_Timer.After(0, function()
        refreshQueued = false
        if panel:IsShown() then Render() end
    end)
end

local function CreatePanel()
    -- Keep the entire view under UIParent. It has no native tracker hooks,
    -- protected controls, or code that requests a Blizzard layout.
    panel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    panel:Hide()
    panel:SetSize(WIDTH, HEIGHT)
    panel:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    panel:SetFrameStrata("DIALOG")
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:EnableMouse(true)
    panel:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 16,
        insets = {left = 4, right = 4, top = 4, bottom = 4},
    })
    panel:SetBackdropColor(0.065, 0.055, 0.04, 0.97)

    local header = CreateFrame("Button", nil, panel)
    header:SetPoint("TOPLEFT", panel, "TOPLEFT", 12, -8)
    header:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -38, -8)
    header:SetHeight(23)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() panel:StartMoving() end)
    header:SetScript("OnDragStop", function() panel:StopMovingOrSizing() end)
    local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("LEFT")
    title:SetText("Watched quests")
    local close = CreateFrame("Button", nil, panel, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -4)
    close:SetScript("OnClick", function() panel:Hide() end)

    viewport = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    viewport:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -40)
    viewport:SetSize(WIDTH - 46, HEIGHT - 77)
    content = CreateFrame("Frame", nil, viewport)
    content:SetSize(WIDTH - 46, 1)
    viewport:SetScrollChild(content)
    local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 14, 14)
    hint:SetText("Use quest items from Blizzard's tracker or your bags.")

    for _, event in ipairs({
        "PLAYER_ENTERING_WORLD", "QUEST_LOG_UPDATE", "QUEST_WATCH_LIST_CHANGED",
        "QUEST_WATCH_UPDATE", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_TURNED_IN",
    }) do panel:RegisterEvent(event) end
    panel:SetScript("OnEvent", addon.RefreshWatchedQuests)
    panel:SetScript("OnShow", Render)
    panel:SetScript("OnHide", function() panel:StopMovingOrSizing() end)
end

function addon.ToggleWatchedQuests()
    if not VV.IsModuleEnabled("questTracker") then
        VV.Print("Enable the Quest tracker module to open Watched quests.")
        return
    end
    if not panel then CreatePanel() end
    panel:SetShown(not panel:IsShown())
end
