local _, VV = ...
local ns = VV.Nameplates

-- Item classification does not establish a quest relationship. The bundled
-- baseline supplies IDs; the live quest log supplies progress and completion.
local bundled = ns.QuestDropData
local requestedItems = {}

local function Known(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Known(value) end
end

local function Subject(text)
    text = Known(text)
    if type(text) ~= "string" then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("%d+%s*/%s*%d+", ""):gsub("%s+", " ")
        :gsub("^%s*[:%-]%s*", ""):gsub("%s*[:%-]%s*$", "")
        :match("^%s*(.-)%s*$"):lower()
end

function ns.QuestDropDatabase()
    -- The standalone provider works even when Questie's own UI is disabled.
    local library = LibQuestieDB
    if type(library) == "table" and Read(library.RequireContract, 1) == true
        and library.Quest and type(library.Quest.Get) == "function"
        and library.Item and type(library.Item.Get) == "function" then return library end
    if Questie and Questie.API and Questie.API.isReady and QuestieLoader then
        local database = Read(QuestieLoader.ImportModule, QuestieLoader, "QuestieDB")
        if type(database) == "table" and type(database.QueryQuestSingle) == "function"
            and type(database.QueryItemSingle) == "function" then return database end
    end
end

local function ItemCount(itemID)
    return Read(C_Item and C_Item.GetItemCount or GetItemCount, itemID, false)
end

local function Needed(itemID, objective, required)
    local current, target
    if objective then
        if Known(objective.finished) == true then return false end
        local nativeRequired = Known(objective.numRequired)
        current = Known(objective.numFulfilled)
        local text = Known(objective.text)
        if type(text) == "string" then
            local a, b = text:match("(%d+)%s*/%s*(%d+)")
            current, target = current or tonumber(a), tonumber(b)
        end
        if type(nativeRequired) == "number" and nativeRequired > 0 then required = nativeRequired
        elseif target then required = target end
    end
    local count = ItemCount(itemID)
    if type(count) == "number" and type(required) == "number" and required > 0 then return count < required end
    if objective then
        local finished = Known(objective.finished)
        if finished ~= nil then return finished == false end
        if type(current) == "number" and type(required) == "number" then return current < required end
    end
    return false
end

local function NativeItemObjectives(objectives)
    local items = {}
    for _, objective in ipairs(objectives or {}) do
        if Known(objective.type) == "item" then items[#items + 1] = objective end
    end
    return items
end

local function MatchObjective(itemID, description, name, objectives)
    for _, objective in ipairs(objectives) do
        -- Some client versions provide IDs; otherwise compare localized names.
        if Known(objective.itemID) == itemID or Known(objective.objectID) == itemID then return objective end
        local subject = Subject(objective.text)
        if subject ~= "" and ((name and subject == Subject(name))
            or (description and subject == Subject(description))) then return objective end
    end
end

function ns.QuestDropSources(questID, nativeObjectives, complete, database)
    local sources = {}
    if complete == true or complete == 1 then return sources end
    local objectives = NativeItemObjectives(nativeObjectives)
    local requiredItems = bundled and bundled.quests[questID]
    if requiredItems then
        for _, itemID in ipairs(requiredItems) do
            local drops = bundled.items[itemID]
            if drops then
                local name = Read(C_Item and C_Item.GetItemNameByID or GetItemInfo, itemID)
                local objective = MatchObjective(itemID, nil, name, objectives)
                -- Cardinality helps while the item cache is empty. A readable
                -- mismatched name is evidence of changed requirements, not a match.
                if not objective and not name and #requiredItems == 1 and #objectives == 1 then
                    local nativeID = Known(objectives[1].itemID) or Known(objectives[1].objectID)
                    if nativeID == nil then objective = objectives[1] end
                end
                if not objective and not name and not requestedItems[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
                    requestedItems[itemID] = true
                    pcall(C_Item.RequestLoadItemDataByID, itemID)
                end
                if objective and Needed(itemID, objective) then
                    for _, npcID in ipairs(drops) do sources[npcID] = true end
                end
            end
        end
        -- Bundled requirements take precedence over an optional provider.
        -- Unknown quests can use that provider.
        return sources
    end
    if database then
        local questRead = database.QueryQuestSingle or database.Quest.Get
        local itemRead = database.QueryItemSingle or database.Item.Get
        local definitions = Read(questRead, questID, "objectives")
        local items = type(definitions) == "table" and definitions[3]
        if type(items) == "table" then
            for _, item in ipairs(items) do
                local itemID = type(item) == "table" and Known(item[1])
                if type(itemID) == "number" and itemID > 0 then
                    local clientName = Read(C_Item and C_Item.GetItemNameByID or GetItemInfo, itemID)
                    local name = clientName or Read(itemRead, itemID, "name")
                    local objective = MatchObjective(itemID, Known(item[2]), name, objectives)
                    -- A unique item objective is unambiguous even if localized
                    -- item names are not cached yet. Never guess among several.
                    if not objective and #items == 1 and #objectives == 1 then objective = objectives[1] end
                    if not objective and not clientName and not requestedItems[itemID] and C_Item and C_Item.RequestLoadItemDataByID then
                        requestedItems[itemID] = true
                        pcall(C_Item.RequestLoadItemDataByID, itemID)
                    end
                    if objective and Needed(itemID, objective) then
                        local drops = Read(itemRead, itemID, "npcDrops")
                        if type(drops) == "table" then
                            local vendors = {}
                            local vendorList = Read(itemRead, itemID, "vendors")
                            if type(vendorList) == "table" then
                                for _, vendorID in pairs(vendorList) do
                                    vendorID = Known(vendorID)
                                    if type(vendorID) == "number" then vendors[vendorID] = true end
                                end
                            end
                            for _, npcID in pairs(drops) do
                                npcID = Known(npcID)
                                if type(npcID) == "number" and npcID > 0 and not vendors[npcID] then sources[npcID] = true end
                            end
                        end
                    end
                end
            end
        end
    end
    return sources
end
