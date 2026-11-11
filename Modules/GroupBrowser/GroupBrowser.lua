local _, VV = ...
local addon = {}
VV.GroupBrowser = addon

local RESULT_HEIGHT, HEADER_HEIGHT = 28, 20
local DISPLAY_SCALE = 0.60
local LFG_ADDON = "Blizzard_GroupFinder_VanillaStyle"
local scrollBox, view, originalExtentCalculator, compressed
local layouts, details = {}, setmetatable({}, {__mode="k"})

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
    level:SetPoint("TOPLEFT", row, "TOPLEFT", 148, -2)
    level:SetSize(18, 13)
    level:SetTextColor(0.78, 0.78, 0.78)
    local class = row:CreateTexture(nil, "ARTWORK")
    class:SetPoint("TOPLEFT", row, "TOPLEFT", 168, -1)
    class:SetSize(14, 14)
    local secondary = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    secondary:SetPoint("TOPLEFT", row, "TOPLEFT", 20, -15)
    secondary:SetPoint("TOPRIGHT", row, "TOPRIGHT", -124, -15)
    secondary:SetHeight(12)
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
    if type(area) == "string" and area ~= "" then notes[#notes+1] = "Current zone: " .. area end
    detail.secondary:SetText(table.concat(notes, "   "))
    detail.secondary:SetShown(#notes > 0)
    detail.secondary:SetAlpha(delisted and 0.55 or 1)
    detail.level:SetAlpha(delisted and 0.55 or 1)

    local nameStart, nameEnd = row.PartyIcon:IsShown() and 20 or 8, 145
    Place(row, row.PartyIcon, "TOPLEFT", "TOPLEFT", 6, -2)
    row.PartyIcon:SetSize(12, 12)
    for _, icon in ipairs({row.NewPlayerFriendlyIcon, row.DiscordIcon}) do
        if icon:IsShown() then
            nameEnd = nameEnd - 13
            Place(row, icon, "TOPLEFT", "TOPLEFT", nameEnd, -2)
            icon:SetSize(12, 12)
        end
    end
    Place(row, row.Name, "TOPLEFT", "TOPLEFT", nameStart, -2)
    ResizeText(row, row.Name, 11)
    row.Name:SetWidth(nameEnd - nameStart)
    Place(row, row.ActivityName, "TOPLEFT", "TOPLEFT", 188, -2)
    row.ActivityName:SetPoint("TOPRIGHT", row, "TOPRIGHT", -124, -2)
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
    Place(row, display, "RIGHT", "TOPRIGHT", -6 / DISPLAY_SCALE, -8 / DISPLAY_SCALE)
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
    elseif row.Name and row:IsShown() then
        LayoutResult(row, Field(data, "resultID"))
    end
end

local function SortPlayers(mode)
    local provider = scrollBox:GetDataProvider()
    local divider = LFGVanillaBrowseDividerType
    if not provider or not divider or not provider.GetChildrenNodes then return end
    local changed
    for _, category in ipairs(provider:GetChildrenNodes()) do
        if category:GetData().dividerType == divider.CategorySolo then
            local nodes, keys = category:GetNodes(), {}
            for index, node in ipairs(nodes) do
                local data = node:GetData()
                local info = mode ~= "default" and Leader(Field(data, "resultID"), true)
                local level, class = Field(info, "level"), Field(info, "className")
                keys[node] = {index=Field(data, "index") or index, level=type(level) == "number" and level or -1,
                    class=type(class) == "string" and class ~= "" and class:lower() or nil}
            end
            local function Earlier(a, b)
                local left, right = keys[a], keys[b]
                if mode == "level" and left.level ~= right.level then return left.level > right.level end
                if mode == "class" and left.class ~= right.class then
                    return left.class ~= nil and (right.class == nil or left.class < right.class)
                end
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
    scrollBox:RegisterCallback(ScrollBoxListMixin.Event.OnInitializedFrame, function(_, row, node) LayoutRow(row, node) end, addon)
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
    elseif key ~= "sort" or (value ~= "default" and value ~= "level" and value ~= "class") then return false end
    VV.db.groupBrowser[key] = value
    addon.Refresh()
    if VV.RefreshOptions then VV.RefreshOptions() end
    return true
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "PLAYER_LOGIN" or name == LFG_ADDON then addon.Refresh() end
end)
