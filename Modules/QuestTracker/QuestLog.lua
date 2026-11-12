local _, VV = ...
local addon = VV.QuestTracker
local SCALE, FONT_REDUCTION = 0.9, 1.5
local fonts = setmetatable({}, { __mode = "k" })
local headers = setmetatable({}, { __mode = "k" })
local hookedPools = setmetatable({}, { __mode = "k" })
local compact, menuInstalled

local function SizeFont(region, enabled)
    if not region then return end
    local font = fonts[region]
    if not font then
        local path, size, flags = region:GetFont()
        if not path or not size then return end
        font = { path, size, flags }
        fonts[region] = font
    end
    region:SetFont(font[1], enabled and math.max(6, font[2] - FONT_REDUCTION) or font[2], font[3])
end

local function Style(frame, isHeader, enabled)
    if frame:IsForbidden() or frame:IsProtected() then return end
    SizeFont(frame.Text, enabled)
    SizeFont(frame.Dash, enabled)
    SizeFont(frame.TagText, enabled)
    if isHeader then
        local height = headers[frame]
        if not height then height = frame:GetHeight(); headers[frame] = height end
        frame:SetHeight(enabled and height * SCALE or height)
    end
end

local function Install()
    local list = QuestScrollFrame
    if not list or not list.Contents then return end
    for _, key in ipairs({ "titleFramePool", "objectiveFramePool", "headerFramePool" }) do
        local pool = list[key]
        if pool and not hookedPools[pool] then
            local isHeader = key == "headerFramePool"
            hookedPools[pool] = true
            -- Font sizes must be in place before native code measures each
            -- newly acquired title/objective and constructs the row height.
            hooksecurefunc(pool, "Acquire", function(self)
                if InCombatLockdown() then return end
                for frame in self:EnumerateActive() do Style(frame, isHeader, compact) end
            end)
            hooksecurefunc(pool, "Release", function(_, frame)
                if not InCombatLockdown() then Style(frame, isHeader, false) end
            end)
        end
    end
    if not menuInstalled and Menu and Menu.ModifyMenu then
        menuInstalled = true
        Menu.ModifyMenu("MENU_QUEST_MAP_FRAME_SETTINGS", function(_, root)
            root:CreateCheckbox("Compact quest log", function() return addon.db and addon.db.compactLog end,
                function() addon.SetOption("compactLog", not addon.db.compactLog) end)
            root:CreateButton("Expand all zones", function() ExpandQuestHeader(0) end)
            root:CreateButton("Collapse all zones", function() CollapseQuestHeader(0) end)
        end)
    end
    return list
end

function addon.RefreshQuestLog()
    if not addon.db or InCombatLockdown() then return end
    local list = Install()
    if not list then return end
    local enabled = VV.IsModuleEnabled("questTracker") and addon.db.compactLog
    if compact == enabled then return end
    compact = enabled
    for _, key in ipairs({ "titleFramePool", "objectiveFramePool", "headerFramePool" }) do
        local pool = list[key]
        if pool then
            for frame in pool:EnumerateActive() do Style(frame, key == "headerFramePool", compact) end
        end
    end
    if list:IsShown() and QuestLogQuests_Update then
        securecallfunction(QuestLogQuests_Update)
    end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function() addon.RefreshQuestLog() end)
