local _, VV = ...
local addon = VV.QuestTracker

-- Read the engine watch list without invoking native renderers/cache builders.
function addon.ReadWatchGroups(completedSort)
    local metadata, watches = addon.ReadMetadata(), {}
    for index = 1, C_QuestLog.GetNumQuestWatches() do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if id then
            local questID = id
            watches[#watches + 1] = { quest = {
                title = metadata[id] and metadata[id].title or "",
                GetID = function() return questID end,
            } }
        end
    end
    return addon.BuildGroups(watches, metadata, completedSort)
end

function addon.FormatQuestTitle(title, level)
    -- The Forever client (or another addon) may already supply the level.
    local plain = title:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    if plain:match("^%s*%[%d+%+?%]") then return title end
    level = tonumber(level)
    if not level or level <= 0 then return title end
    return "[" .. level .. "] " .. title
end

-- Keep grouping independent of tracker frames so it can be exercised without WoW.
function addon.BuildGroups(watches, metadata, completedSort)
    local groups, byZone = {}, {}
    local function GetGroup(zone)
        local group = byZone[zone]
        if not group then
            group = { zone = zone, quests = {} }
            byZone[zone] = group
            groups[#groups + 1] = group
        end
        return group
    end
    for _, watch in ipairs(watches) do
        local id = watch.quest:GetID()
        local info = metadata[id] or {}
        local zone = info.zone or "Other Quests"
        local group = GetGroup(zone)
        group.quests[#group.quests + 1] = {
            quest = watch.quest,
            id = id,
            level = tonumber(info.level) or 0,
            title = info.title or watch.quest.title or "",
            completed = info.completed == true,
        }
    end
    table.sort(groups, function(a, b) return a.zone < b.zone end)
    for _, group in ipairs(groups) do
        table.sort(group.quests, function(a, b)
            if a.completed ~= b.completed then
                if completedSort == "top" then return a.completed end
                if completedSort == "bottom" then return not a.completed end
            end
            -- Unknown/scaling levels follow quests with a known level.
            local al = a.level > 0 and a.level or math.huge
            local bl = b.level > 0 and b.level or math.huge
            if al ~= bl then return al < bl end
            if a.title ~= b.title then return a.title < b.title end
            return a.id < b.id
        end)
    end
    return groups
end

function addon.GetZoneQuestIDs(zone)
    local ids = {}
    for id, info in pairs(addon.ReadMetadata()) do
        if info.zone == zone then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

function addon.ReadMetadata()
    local metadata = {}
    local zone = "Other Quests"
    for index = 1, C_QuestLog.GetNumQuestLogEntries() do
        local info = C_QuestLog.GetInfo(index)
        if info then
            if info.isHeader then
                zone = info.title or "Other Quests"
            elseif info.questID and info.questID > 0 then
                metadata[info.questID] = {
                    zone = zone, level = info.level, title = info.title,
                    completed = C_QuestLog.IsComplete(info.questID),
                }
            end
        end
    end
    return metadata
end
