local _, VV = ...
local addon = VV.QuestTracker
local tracker, db
local displayEnabled
local eventFrame = CreateFrame("Frame")
local pendingRefresh, queued = false, false
local snapshots, titles = {}, {}
local originalFonts = setmetatable({}, { __mode = "k" })
local hookedBlocks = setmetatable({}, { __mode = "k" })
local headings = {}
local moduleHeight
local ApplyLayout, Refresh

local function Print(message)
    VV.Print(message)
end

local function SizeFont(region, smaller)
    if not region then return end
    local font = originalFonts[region]
    if not font then
        local path, size, flags = region:GetFont()
        if not path or not size then return end
        font = { path, size, flags }
        originalFonts[region] = font
    end
    region:SetFont(font[1], smaller and math.max(6, font[2] - 2) or font[2], font[3])
end

local function Snapshot(frame)
    if snapshots[frame] then return end
    local points = {}
    for index = 1, frame:GetNumPoints() do points[index] = { frame:GetPoint(index) } end
    snapshots[frame] = { points = points, height = frame:GetHeight(), shown = frame:IsShown() }
end

local function RestoreLayout()
    -- Only C-backed geometry/visibility/text is restored. Never write .height,
    -- .used, .nextBlock, .contentsHeight, or any other native Lua bookkeeping.
    for frame, state in pairs(snapshots) do
        frame:ClearAllPoints()
        for _, point in ipairs(state.points) do frame:SetPoint(unpack(point)) end
        frame:SetHeight(state.height)
        frame:SetShown(state.shown)
    end
    for region, title in pairs(titles) do region:SetText(title) end
    snapshots, titles = {}, {}
    if moduleHeight then tracker:SetHeight(moduleHeight); moduleHeight = nil end
    for _, heading in ipairs(headings) do heading:Hide() end
end

local function SetZoneTracking(zone, tracked)
    if InCombatLockdown() then Print("Zone tracking changes are unavailable during combat."); return end
    local ids, watched = addon.GetZoneQuestIDs(zone), {}
    for index = 1, C_QuestLog.GetNumQuestWatches() do
        local id = C_QuestLog.GetQuestIDForQuestWatchIndex(index)
        if id then watched[id] = true end
    end
    local failed = 0
    for _, id in ipairs(ids) do
        if tracked and not watched[id] then
            if C_QuestLog.AddQuestWatch(id) == false then failed = failed + 1 end
        elseif not tracked and watched[id] then
            C_QuestLog.RemoveQuestWatch(id)
        end
    end
    Refresh()
    if failed > 0 then Print("The game could not track " .. failed .. " quest(s). Your watch limit may have been reached.") end
end

local function OpenZoneMenu(button, zone)
    GameTooltip:Hide()
    MenuUtil.CreateContextMenu(button, function(_, root)
        root:CreateTitle(zone)
        root:CreateButton("Track all zone quests", function() SetZoneTracking(zone, true) end):SetEnabled(not InCombatLockdown())
        root:CreateButton("Untrack all zone quests", function() SetZoneTracking(zone, false) end):SetEnabled(not InCombatLockdown())
    end)
end

local function Heading(index, group, sample)
    local heading = headings[index]
    if not heading then
        -- Addon-owned headings are children of the existing native contents
        -- frame, but never enter Blizzard's block pools or linked lists.
        heading = CreateFrame("Button", nil, tracker.ContentsFrame)
        heading.Text = heading:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        heading.Text:SetPoint("TOPLEFT")
        heading.Text:SetJustifyH("LEFT")
        heading.Text:SetTextColor(1, 1, 1)
        heading.Icon = CreateFrame("Button", nil, heading)
        heading.Icon:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        heading.Icon:SetHighlightTexture("Interface\\AddOns\\VanillaVarnish\\Textures\\Circle", "ADD")
        heading:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local function OnClick(self, button)
            if button == "RightButton" then OpenZoneMenu(self, heading.zone); return end
            if button ~= "LeftButton" then return end
            db.collapsed[heading.zone] = not db.collapsed[heading.zone] or nil
            Refresh()
        end
        local function OnEnter(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(heading.zone)
            GameTooltip:AddLine("Click to fold this zone. Right-click for zone tracking.", 1, 1, 1)
            GameTooltip:Show()
        end
        for _, button in ipairs({ heading, heading.Icon }) do
            button:SetScript("OnClick", OnClick)
            button:SetScript("OnEnter", OnEnter)
            button:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        headings[index] = heading
    end
    heading.zone = group.zone
    heading:SetWidth(tracker.ContentsFrame:GetWidth() - tracker.blockOffsetX)
    heading.Text:SetWidth(heading:GetWidth())
    local font = sample and originalFonts[sample.HeaderText]
    if font then heading.Text:SetFont(unpack(font)) end
    heading.Text:SetText(group.zone .. " (" .. #group.quests .. ")")
    local marker = sample and sample.poiButton
    local width, height = 20, 20
    local point, relativePoint, x, y = "TOPRIGHT", "TOPLEFT", -7, 5
    if marker then
        width, height = marker:GetSize()
        local p, relative, rp, px, py = marker:GetPoint(1)
        if relative == sample.HeaderText then point, relativePoint, x, y = p, rp, px, py end
    end
    heading.Icon:SetSize(width, height)
    heading.Icon:ClearAllPoints()
    heading.Icon:SetPoint(point, heading.Text, relativePoint, x, y)
    heading.Icon:SetNormalTexture("Interface\\AddOns\\VanillaVarnish\\Textures\\" .. (db.collapsed[group.zone] and "Plus" or "Minus"))
    heading:SetHeight(math.max(height, heading.Text:GetStringHeight()))
    return heading
end

local function SetBlockVisible(block, visible)
    Snapshot(block)
    block:SetShown(visible)
    -- Native item buttons, timers, and progress bars may be siblings, not
    -- children of their quest block. Fold and restore these with the block.
    for region in pairs(block.addedRegions or {}) do
        Snapshot(region)
        region:SetShown(visible and snapshots[region].shown)
    end
end

ApplyLayout = function()
    queued = false
    if not tracker or not db then return end
    if InCombatLockdown() then pendingRefresh = true; return end
    RestoreLayout()
    pendingRefresh = false
    if not VV.IsModuleEnabled("questTracker") or not db.enabled or not tracker:IsShown() or tracker:IsCollapsed() then return end

    local groups = addon.ReadWatchGroups(db.completedSort)
    addon.groups = groups
    local watched, blocks, special = {}, {}, {}
    for _, group in ipairs(groups) do
        for _, entry in ipairs(group.quests) do watched[entry.id] = true end
    end
    -- Traverse the native list without sorting or changing it. Only blocks
    -- Blizzard rendered participate; cached/autocomplete blocks are retained.
    local block = tracker.firstBlock
    while block do
        if watched[block.id] and not block.cached then blocks[block.id] = block
        else special[#special + 1] = block end
        block = block.nextBlock
    end
    moduleHeight = tracker:GetHeight()
    local budget = tracker.availableHeight
    local container = tracker.parentContainer
    if container and container.modules then
        local others, count = 0, 0
        for _, module in ipairs(container.modules) do
            if module ~= tracker then
                local height = module:GetContentsHeight()
                if height > 0 then others, count = others + height, count + 1 end
            end
        end
        budget = math.min(budget, container:GetAvailableHeight() - others - count * container.moduleSpacing)
    end
    local y = tracker.headerHeight or 0
    local gap = -(tracker.fromBlockOffsetY or -10)
    local firstGap = -(tracker.fromHeaderOffsetY or -10)
    local count = 0
    local function Place(frame, height)
        local offset = count == 0 and firstGap or gap
        if y + offset + height > budget then return false end
        Snapshot(frame)
        frame:ClearAllPoints()
        frame:SetPoint("TOP", tracker.ContentsFrame, "TOP", 0, -(y - (tracker.headerHeight or 0) + offset))
        frame:SetPoint("LEFT", tracker.ContentsFrame, "LEFT", frame.offsetX or tracker.blockOffsetX, 0)
        if not frame.fixedWidth then frame:SetPoint("RIGHT", tracker.ContentsFrame, "RIGHT", 0, 0) end
        frame:SetHeight(height)
        frame:Show()
        y, count = y + offset + height, count + 1
        return true
    end
    for _, block in ipairs(special) do
        if not Place(block, block:GetHeight()) then SetBlockVisible(block, false) end
    end
    local headingIndex, full = 0, false
    for _, group in ipairs(groups) do
        local sample
        for _, entry in ipairs(group.quests) do sample = blocks[entry.id]; if sample then break end end
        if sample then
            headingIndex = headingIndex + 1
            local heading = Heading(headingIndex, group, sample)
            local collapsed = db.collapsed[group.zone]
            -- Use the same native gap after every zone's last visible row,
            -- whether that row is a collapsed heading or an expanded quest.
            if full or not Place(heading, heading:GetHeight()) then full = true; heading:Hide() end
            for _, entry in ipairs(group.quests) do
                local questBlock = blocks[entry.id]
                if questBlock then
                    local height = questBlock:GetHeight()
                    local region = questBlock.HeaderText
                    if region then
                        titles[region] = region:GetText()
                        local oldHeight = region:GetStringHeight()
                        region:SetText(addon.FormatQuestTitle(titles[region], entry.level))
                        height = height + region:GetStringHeight() - oldHeight
                    end
                    local visible = not collapsed and not full
                    if visible and not Place(questBlock, height) then full = true; visible = false end
                    SetBlockVisible(questBlock, visible)
                end
            end
        end
    end
    -- Frame height is C-backed; native .contentsHeight and return values stay
    -- unchanged. Following native modules already anchor to this frame's bottom.
    tracker:SetHeight(y + (tracker.bottomSpacing or 0))
end

Refresh = function(immediate)
    if not tracker then return end
    if InCombatLockdown() then pendingRefresh = true; return end
    local enabled = VV.IsModuleEnabled("questTracker") and db.enabled
    if displayEnabled ~= enabled then
        displayEnabled = enabled
        for region in pairs(originalFonts) do SizeFont(region, displayEnabled) end
        -- Do not write shared dirty flags from addon execution. The native
        -- callable handles its own state through Blizzard's security boundary.
        securecallfunction(tracker.MarkDirty, tracker)
    end
    -- Native post-hooks finish before the game can draw this frame. Apply here
    -- so restoring/rebuilding native blocks never leaves an ungrouped frame on
    -- screen. Event-only requests can still coalesce behind the native update.
    if immediate then ApplyLayout(); return end
    if queued then return end
    queued = true
    C_Timer.After(0, function() if queued then ApplyLayout() end end)
end

local function TryInstall()
    if tracker then return true end
    if not VV.IsModuleEnabled("questTracker") then return true end
    if InCombatLockdown() then pendingRefresh = true; return false end
    local module = QuestObjectiveTracker
    if not module or not module.ContentsFrame or type(module.BeginLayout) ~= "function"
        or type(module.Update) ~= "function" or type(module.GetExistingBlock) ~= "function" then return false end
    tracker = module
    hooksecurefunc(module, "BeginLayout", function()
        if InCombatLockdown() then pendingRefresh = true; return end
        RestoreLayout()
    end)
    hooksecurefunc(module, "Update", function() Refresh(true) end)
    if module.parentContainer then
        hooksecurefunc(module.parentContainer, "Update", function() Refresh(true) end)
    end
    hooksecurefunc(module, "GetBlock", function(self, id, template)
        if type(id) ~= "number" or (template and template ~= self.blockTemplate) then return end
        local block = self:GetExistingBlock(id, template)
        if not block then return end
        SizeFont(block.HeaderText, displayEnabled)
        if hookedBlocks[block] then return end
        hookedBlocks[block] = true
        hooksecurefunc(block, "GetLine", function(self, key)
            local line = self:GetExistingLine(key)
            if line then SizeFont(line.Text, displayEnabled); SizeFont(line.Dash, displayEnabled) end
        end)
        hooksecurefunc(block, "FreeLine", function(_, line) SizeFont(line.Text, false); SizeFont(line.Dash, false) end)
        hooksecurefunc(block, "Free", function(self)
            SizeFont(self.HeaderText, false)
            -- A freed frame can be acquired by another module before the next
            -- quest layout. Never restore stale geometry/text onto that owner.
            snapshots[self] = nil
            titles[self.HeaderText] = nil
            for region in pairs(self.addedRegions or {}) do snapshots[region] = nil end
        end)
    end)
    Refresh()
    return true
end

local function Initialize()
    if not VV.db then VV.InitDB() end
    db = VV.db.questTracker
    if db.enabled == nil then db.enabled = true end
    if type(db.collapsed) ~= "table" then db.collapsed = {} end
    displayEnabled = VV.IsModuleEnabled("questTracker") and db.enabled
    db.position = nil -- Remove the retired separate panel's saved position.
    addon.db = db
    addon.RegisterOptions()
end

function addon.SetOption(key, value)
    if key == "completedSort" then
        if value ~= "off" and value ~= "top" and value ~= "bottom" then return false end
    elseif key == "enabled" then
        value = not not value
    else return false end
    db[key] = value
    addon.RefreshOptions()
    Refresh()
    return true
end

function addon.SetAllZonesCollapsed(collapsed)
    if collapsed then
        for _, group in ipairs(addon.ReadWatchGroups()) do db.collapsed[group.zone] = true end
    else
        db.collapsed = {}
    end
    Refresh()
end

function addon.ResetOptions()
    db.enabled, db.completedSort, db.collapsed = true, "off", {}
    addon.RefreshOptions()
    Refresh()
end

addon.Print = Print

for _, event in ipairs({ "PLAYER_LOGIN", "ADDON_LOADED", "PLAYER_ENTERING_WORLD", "PLAYER_REGEN_ENABLED",
    "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_WATCH_LIST_CHANGED" }) do eventFrame:RegisterEvent(event) end
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" then Initialize() end
    if not db then return end
    if not TryInstall() then
        if event == "PLAYER_LOGIN" then Print("Waiting for the native quest tracker. /qto status shows diagnostics.") end
        return
    end
    Refresh()
end)

local function Slash(message)
    if not db then Initialize() end
    TryInstall()
    local command = (message or ""):lower():match("^%s*(.-)%s*$")
    if command == "" or command == "options" or command == "settings" then
        addon.OpenOptions()
    elseif command == "on" or command == "off" then
        addon.SetOption("enabled", command == "on")
        Print(db.enabled and "Native zone grouping enabled." or "Native quest ordering restored.")
    elseif command == "expand" then
        addon.SetAllZonesCollapsed(false)
    elseif command == "collapse" then
        addon.SetAllZonesCollapsed(true)
    elseif command == "status" then
        local version, build, _, interface = GetBuildInfo()
        Print("Client " .. version .. " / build " .. build .. " / interface " .. interface .. ".")
        Print("Grouping " .. (db.enabled and "on" or "off") .. "; native tracker " .. (tracker and "connected" or "unavailable") .. ".")
        local label = ({off = "off", top = "completed on top", bottom = "completed on bottom"})[db.completedSort]
        Print("Completed quest sorting: " .. label .. ".")
    else
        Print("/qto opens settings. /qto on | off | expand | collapse | status | help. Click a native zone heading to fold it.")
    end
end

addon.HandleSlash = Slash
if not VV.IsLegacyLoaded("QuestTrackerOrganizer") then
    SLASH_QUESTTRACKERORGANIZER1 = "/qto"
    SLASH_QUESTTRACKERORGANIZER2 = "/qlo"
    SlashCmdList.QUESTTRACKERORGANIZER = Slash
end
function addon.RefreshModule()
    if not db then return end
    TryInstall()
    Refresh(true)
end
