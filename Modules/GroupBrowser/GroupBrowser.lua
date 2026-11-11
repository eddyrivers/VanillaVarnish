local _, VV = ...
local addon = {}
VV.GroupBrowser = addon

local RESULT_HEIGHT, HEADER_HEIGHT = 34, 20
-- The native result background starts two units below the frame's top.
local TOP_LINE_Y, SECOND_LINE_Y = -6, -19
local DISPLAY_SCALE = 0.60
local LFG_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local scrollBox, view, originalExtentCalculator, compressed, roleSortQueued
local layouts, details = {}, setmetatable({}, {__mode="k"})
local hookedHeaders = setmetatable({}, {__mode="k"})

local function Read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end

local function Field(record, key)
    if type(record) == "table" then return Read(function() return record[key] end) end
end

local function Leader(resultID, solo)
    if type(resultID) ~= "number" or (issecretvalue and issecretvalue(resultID)) then return end
    local info = Read(C_LFGList.GetSearchResultLeaderInfo, resultID)
    if not info and solo then info = Read(C_LFGList.GetSearchResultPlayerInfo, resultID, 1) end
    return info
end

local function CompactExtent(_, node)
    return node:GetData().dividerType and HEADER_HEIGHT or RESULT_HEIGHT
end

local function IsPlayersCategory(node)
    -- Forever's tree uses 1 for Players even when the Lua enum is private.
    local divider = LFGVanillaBrowseDividerType
    return node and node:GetData().dividerType == (divider and divider.CategorySolo or 1)
end

local function RegionState(row, region)
    local layout = layouts[row]
    if not layout then layout = {}; layouts[row] = layout end
    if not layout[region] then layout[region] = {} end
    return layout[region]
end

local function Remember(row, region)
    local original = RegionState(row, region)
    if not original.points then
        original.points, original.width, original.height = {}, region:GetWidth(), region:GetHeight()
        for index = 1, region:GetNumPoints() do original.points[index] = {region:GetPoint(index)} end
    end
    return original
end

local function Place(row, region, point, relativePoint, x, y)
    Remember(row, region)
    region:ClearAllPoints()
    region:SetPoint(point, row, relativePoint, x, y)
end

local function ResizeText(row, text, size)
    local original = Remember(row, text)
    if not original.font then
        original.font = {text:GetFont()}
        original.wrap = text:CanWordWrap()
    end
    local path, _, flags = unpack(original.font)
    if path then text:SetFont(path, size, flags) end
    text:SetWordWrap(false)
    text:SetHeight(size + 2)
end

local function HideArtwork(row, region)
    local original = RegionState(row, region)
    if original.alpha == nil then original.alpha = region:GetAlpha() end
    region:SetAlpha(0)
end

local function RestoreRow(row)
    local layout = layouts[row]
    if not layout then return end
    for region, original in pairs(layout) do
        if original.scale then region:SetScale(original.scale) end
        if original.font and original.font[1] then region:SetFont(unpack(original.font)) end
        if original.wrap ~= nil then region:SetWordWrap(original.wrap) end
        if original.alpha ~= nil then region:SetAlpha(original.alpha) end
        if original.points then
            region:SetSize(region == row.ActivityName and 0 or original.width, original.height)
            region:ClearAllPoints()
            for _, point in ipairs(original.points) do region:SetPoint(unpack(point, 1, 5)) end
        end
    end
    layouts[row] = nil
    local detail = details[row]
    if detail then
        detail.level:Hide()
        detail.class:Hide()
        detail.secondary:Hide()
    end
end

local function DetailRegions(row)
    if details[row] then return details[row] end
    local level = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    level:SetPoint("TOPLEFT", row, "TOPLEFT", 148, TOP_LINE_Y)
    level:SetSize(18, 13)
    level:SetTextColor(0.78, 0.78, 0.78)
    local class = row:CreateTexture(nil, "ARTWORK")
    class:SetPoint("TOPLEFT", row, "TOPLEFT", 168, TOP_LINE_Y + 1)
    class:SetSize(14, 14)
    local secondary = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    secondary:SetPoint("TOPLEFT", row, "TOPLEFT", 22, SECOND_LINE_Y)
    secondary:SetPoint("TOPRIGHT", row, "TOPRIGHT", -124, SECOND_LINE_Y)
    secondary:SetHeight(11)
    secondary:SetJustifyH("LEFT")
    secondary:SetWordWrap(false)
    secondary:SetTextColor(0.72, 0.72, 0.72)
    details[row] = {level=level, class=class, secondary=secondary}
    return details[row]
end

local function LayoutResult(row, resultID)
    local info = resultID and Read(C_LFGList.GetSearchResultInfo, resultID)
    local leader = Leader(resultID, Field(info, "numMembers") == 1)
    local level, class, area = Field(leader, "level"), Field(leader, "classFilename"), Field(leader, "areaName")
    local playstyle = Field(info, "generalPlaystyle")
    local style = playstyle and Read(GetGeneralPlaystyleString, playstyle)
    local delisted = Field(row, "isDelisted") == true
    local detail = DetailRegions(row)

    local hasLevel = type(level) == "number" and level > 0
    detail.level:SetText(hasLevel and level or "")
    detail.level:SetShown(hasLevel)
    local hasClass = type(class) == "string" and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class] ~= nil
    if hasClass then detail.class:SetAtlas("groupfinder-icon-class-" .. class:lower(), false) end
    detail.class:SetDesaturated(delisted)
    detail.class:SetShown(hasClass == true)

    local notes = {}
    if type(style) == "string" and style ~= "" then notes[#notes+1] = "|cff94cc87" .. style .. "|r" end
    if type(area) == "string" and area ~= "" then notes[#notes+1] = "Zone: " .. area end
    detail.secondary:SetText(table.concat(notes, "   "))
    detail.secondary:SetShown(#notes > 0)
    detail.secondary:SetAlpha(delisted and 0.55 or 1)
    detail.level:SetAlpha(delisted and 0.55 or 1)

    local nameStart, nameEnd = row.PartyIcon:IsShown() and 22 or 10, 145
    Place(row, row.PartyIcon, "TOPLEFT", "TOPLEFT", 8, TOP_LINE_Y)
    row.PartyIcon:SetSize(12, 12)
    for _, icon in ipairs({row.NewPlayerFriendlyIcon, row.DiscordIcon}) do
        if icon:IsShown() then
            nameEnd = nameEnd - 13
            Place(row, icon, "TOPLEFT", "TOPLEFT", nameEnd, TOP_LINE_Y)
            icon:SetSize(12, 12)
        end
    end
    Place(row, row.Name, "TOPLEFT", "TOPLEFT", nameStart, TOP_LINE_Y)
    ResizeText(row, row.Name, 11)
    row.Name:SetWidth(nameEnd - nameStart)
    Place(row, row.ActivityName, "TOPLEFT", "TOPLEFT", 188, TOP_LINE_Y)
    row.ActivityName:SetPoint("TOPRIGHT", row, "TOPRIGHT", -124, TOP_LINE_Y)
    ResizeText(row, row.ActivityName, 11)
    row.ActivityName:SetWidth(0)
    HideArtwork(row, row.Level)
    HideArtwork(row, row.ClassIcon)
    if row.PlaystyleLabel then HideArtwork(row, row.PlaystyleLabel) end

    -- Keep the native role display and delist button with their own data and handlers.
    local display = row.DataDisplay
    local original = Remember(row, display)
    original.scale = original.scale or display:GetScale()
    display:SetScale(DISPLAY_SCALE)
    Place(row, display, "RIGHT", "RIGHT", -6 / DISPLAY_SCALE, -1 / DISPLAY_SCALE)
    if display.Solo then HideArtwork(row, display.Solo.RolesText) end
end

local function LayoutRow(row, node)
    if not compressed then return end
    local data = node:GetData()
    if data.dividerType then
        Place(row, row.CategoryLabel, "LEFT", "LEFT", 12, 0)
        ResizeText(row, row.CategoryLabel, 11)
        Place(row, row.ExpandIcon, "RIGHT", "RIGHT", -12, 0)
        Place(row, row.CollapseIcon, "RIGHT", "RIGHT", -12, 0)
        Place(row, row.ResultBG, "TOPLEFT", "TOPLEFT", 3, -1)
        row.ResultBG:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -3, 0)
        Remember(row, row.Highlight)
        row.Highlight:ClearAllPoints()
        row.Highlight:SetPoint("TOPLEFT", row.ResultBG, "TOPLEFT")
        row.Highlight:SetPoint("BOTTOMRIGHT", row.ResultBG, "BOTTOMRIGHT")
    elseif row.Name and row:IsShown() then
        LayoutResult(row, Field(data, "resultID"))
    end
end

local function PrepareRow(row, node)
    if IsPlayersCategory(node) and not hookedHeaders[row] and MenuUtil and MenuUtil.CreateContextMenu then
        hookedHeaders[row] = true
        -- The native button handles left-click collapse. Pooled headers can later represent Groups.
        row:HookScript("OnMouseUp", function(self, button)
            if button == "RightButton" and self:IsMouseOver() and self.GetElementData
                and IsPlayersCategory(self:GetElementData()) then
                MenuUtil.CreateContextMenu(self, function(_, menu)
                    menu:CreateTitle("Sort players by")
                    VV.AddGroupBrowserSortOptions(menu)
                end)
            end
        end)
    end
    LayoutRow(row, node)
end

local function RolePriority(resultID)
    -- Use the same solo listing data Blizzard uses for the visible role icons.
    if not resultID then return 4 end
    local player = Read(C_LFGList.GetSearchResultPlayerInfo, resultID, 1)
    local roles = Field(player, "lfgRoles")
        or Field(Read(C_LFGList.GetSearchResultLeaderInfo, resultID), "lfgRoles")
    if Field(roles, "tank") == true then return 1 end
    if Field(roles, "healer") == true then return 2 end
    if Field(roles, "dps") == true then return 3 end
    return 4
end

local function SortPlayers(mode)
    local provider = scrollBox:GetDataProvider()
    if not provider or not provider.GetChildrenNodes then return end
    local changed
    for _, category in ipairs(provider:GetChildrenNodes()) do
        if IsPlayersCategory(category) then
            local nodes, keys = category:GetNodes(), {}
            for index, node in ipairs(nodes) do
                local data = node:GetData()
                local resultID = Field(data, "resultID")
                local info = (mode == "level" or mode == "class") and Leader(resultID, true)
                local level, class = Field(info, "level"), Field(info, "className")
                keys[node] = {index=Field(data, "index") or index, level=type(level) == "number" and level or -1,
                    class=type(class) == "string" and class ~= "" and class:lower() or nil,
                    role=mode == "role" and RolePriority(resultID) or nil}
            end
            local function Earlier(a, b)
                local left, right = keys[a], keys[b]
                if mode == "level" and left.level ~= right.level then return left.level > right.level end
                if mode == "class" and left.class ~= right.class then
                    return left.class ~= nil and (right.class == nil or left.class < right.class)
                end
                if mode == "role" and left.role ~= right.role then return left.role < right.role end
                return left.index < right.index
            end
            for index = 2, #nodes do
                if Earlier(nodes[index], nodes[index-1]) then
                    category:SetSortComparator(Earlier, false, false)
                    category:SetSortComparator(nil, false, true)
                    changed = true
                    break
                end
            end
        end
    end
    -- Sorting preserves node identity. Invalidate the flattened order once.
    if changed then provider:Invalidate() end
end

local function Install()
    if scrollBox then return true end
    local browse = LFGBrowseFrame
    local box = browse and browse.ScrollBox
    local list = box and box.GetView and box:GetView()
    if not list or not list.SetElementExtentCalculator or not ScrollBoxListMixin or not C_LFGList then return end
    scrollBox, view, compressed = box, list, false
    originalExtentCalculator = view:GetElementExtentCalculator()
    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row, node) PrepareRow(row, node) end, addon)
    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnReleasedFrame, function(_, row) RestoreRow(row) end, addon)
    if type(LFGBrowseSearchEntry_Update) == "function" then
        hooksecurefunc("LFGBrowseSearchEntry_Update", function(row)
            local resultID = compressed and layouts[row] and Field(row, "resultID")
            if resultID and row:IsShown() then LayoutResult(row, resultID) end
        end)
    end
    hooksecurefunc(browse, "UpdateResults", function()
        local mode = VV.db.groupBrowser.sort
        if mode ~= "default" then SortPlayers(mode) end
    end)
    scrollBox:ForEachFrame(PrepareRow)
    return true
end

function addon.Refresh()
    if not VV.db or not Install() then return end
    local settings = VV.db.groupBrowser
    if compressed ~= settings.compressed then
        compressed = settings.compressed
        view:SetElementExtentCalculator(compressed and CompactExtent or originalExtentCalculator)
        scrollBox:ForEachFrame(function(row, node)
            if compressed then
                row:SetHeight(CompactExtent(nil, node))
                LayoutRow(row, node)
            else
                RestoreRow(row)
                local height = originalExtentCalculator and originalExtentCalculator(row:GetOrderIndex(), node)
                    or view:GetTemplateExtentFromElementData(node)
                row:SetHeight(height)
            end
        end)
        if scrollBox:GetDataProvider() then
            scrollBox:FullUpdate(true)
            if not compressed then scrollBox:ReinitializeFrames() end
        end
    end
    SortPlayers(settings.sort)
end

function addon.SetOption(key, value)
    if key == "compressed" then
        if type(value) ~= "boolean" then return false end
    elseif key ~= "sort" or (value ~= "default" and value ~= "level" and value ~= "class" and value ~= "role") then return false end
    VV.db.groupBrowser[key] = value
    addon.Refresh()
    if VV.RefreshOptions then VV.RefreshOptions() end
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("LFG_LIST_SEARCH_RESULT_UPDATED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or (event == "ADDON_LOADED" and name == LFG_ADDON) then
        addon.Refresh()
    elseif event == "LFG_LIST_SEARCH_RESULT_UPDATED" and scrollBox and VV.db.groupBrowser.sort == "role" and not roleSortQueued then
        -- Let Blizzard finish updating the result before moving its row.
        roleSortQueued = true
        C_Timer.After(0, function()
            roleSortQueued = false
            if VV.db.groupBrowser.sort == "role" then SortPlayers("role") end
        end)
    end
end)
