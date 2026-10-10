local ADDON, VV = ...
local addon = VV.Tooltips
addon.defaults = { followMouse = true, offsetX = 34, offsetY = -6,
    unitColors = true, pauseInCombat = false }
addon.limits = { offsetX = {-500, 500}, offsetY = {-500, 500} }
local driver = CreateFrame("Frame")
local hooked = setmetatable({}, { __mode = "k" })
local moved = setmetatable({}, { __mode = "k" })
local anchorQueued = setmetatable({}, { __mode = "k" })
local worldHover = setmetatable({}, { __mode = "k" })
local shownAlpha = setmetatable({}, { __mode = "k" })
local changedLines = setmetatable({}, { __mode = "k" })
local hookedHelpers = {}
local changingAnchor = false

-- Forever can return restricted values even from cosmetic tooltip APIs.
local function Known(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Known(value) end
end

local function Allowed(tooltip)
    return tooltip and (not tooltip.IsForbidden or Read(tooltip.IsForbidden, tooltip) == false)
end

local function Enabled()
    return addon.db and VV.IsModuleEnabled("tooltips")
end

local function Editing()
    local manager = EditModeManagerFrame
    return manager and Read(manager.IsEditModeActive, manager) == true
end

local function Paused()
    return addon.db.pauseInCombat and Read(InCombatLockdown) == true
end

-- Match Forever's GameTooltip_SetDefaultAnchor corner selection without
-- calling SetOwner again. That would clear content or pass a forbidden owner
-- back into addon code. The container itself belongs to Blizzard's Edit Mode.
local function AnchorInEditMode(tooltip)
    local container = GameTooltipDefaultContainer or SharedTooltipDefaultContainer
    if not container then return end
    local ok, point, _, _, x, y = pcall(container.GetPoint, container, 1)
    point, x, y = Known(point), Known(x), Known(y)
    if not ok or type(point) ~= "string" or type(x) ~= "number" or type(y) ~= "number" then return end
    if point == "TOP" or point == "BOTTOM" then
        point = point .. (x > 0 and "RIGHT" or "LEFT")
    elseif point == "LEFT" or point == "RIGHT" then
        point = (y > 0 and "TOP" or "BOTTOM") .. point
    elseif point == "CENTER" then
        point = (y > 0 and "TOP" or "BOTTOM") .. (x > 0 and "RIGHT" or "LEFT")
    end
    tooltip:SetAnchorType("ANCHOR_NONE")
    tooltip:ClearAllPoints()
    tooltip:SetPoint(point, container)
end

local function ApplyAnchor(tooltip)
    if changingAnchor or not Enabled() or not Allowed(tooltip) or Editing() then return end
    changingAnchor = true
    -- Native cursor anchoring handles movement, UI scale and edge clamping,
    -- without per-frame SetPoint calls. Clear old explicit anchors before
    -- switching families, after the native setup stack has finished.
    local ok, err = pcall(function()
        if addon.db.followMouse and not Paused() then
            tooltip:ClearAllPoints()
            tooltip:SetAnchorType("ANCHOR_CURSOR_RIGHT", addon.db.offsetX, addon.db.offsetY)
            moved[tooltip] = true
        elseif Paused() then
            AnchorInEditMode(tooltip)
            moved[tooltip] = true
        end
    end)
    changingAnchor = false
    if not ok and geterrorhandler then geterrorhandler()(err) end
end

local function QueueAnchor(tooltip)
    if changingAnchor or not Enabled() or not Allowed(tooltip) then return end
    anchorQueued[tooltip] = true
end

local function FinishAnchor(tooltip)
    if not hooked[tooltip] or not anchorQueued[tooltip] or changingAnchor then return end
    anchorQueued[tooltip] = nil
    ApplyAnchor(tooltip)
end

local function RestoreColors()
    for line, record in pairs(changedLines) do
        if Read(line.GetText, line) == record.colored then
            pcall(line.SetText, line, record.original)
        end
        changedLines[line] = nil
    end
end

local function ColorCode(color)
    color = Known(color)
    if type(color) ~= "table" then return end
    local ok, r, g, b = pcall(function()
        if color.GetRGB then return color:GetRGB() end
        return color.r, color.g, color.b
    end)
    r, g, b = Known(r), Known(g), Known(b)
    if not ok or type(r) ~= "number" or type(g) ~= "number" or type(b) ~= "number" then return end
    local function Byte(value) return math.floor(math.max(0, math.min(1, value)) * 255 + 0.5) end
    return string.format("|cff%02x%02x%02x", Byte(r), Byte(g), Byte(b))
end

local palette = { impossible = {r=1,g=0.1,b=0.1}, verydifficult = {r=1,g=0.5,b=0.25},
    difficult = {r=1,g=1,b=0}, standard = {r=0.25,g=0.75,b=0.25}, trivial = {r=0.5,g=0.5,b=0.5} }

local function Difficulty(unit, level)
    -- Match TargetFrame's creature difficulty, including dungeon units.
    -- Cosmetic fallbacks use only readable levels when native APIs fail.
    local difficulty = Read(C_PlayerInfo and C_PlayerInfo.GetContentDifficultyCreatureForPlayer, unit)
    if difficulty ~= nil then
        local code = ColorCode(Read(GetDifficultyColor, difficulty))
        if code then return code end
    end
    local playerLevel = Read(UnitLevel, "player")
    if type(playerLevel) ~= "number" or playerLevel <= 0 then return end
    local difference, key = level - playerLevel
    local gray = playerLevel <= 5 and 0
        or playerLevel <= 39 and playerLevel - math.floor(playerLevel / 10) - 5
        or playerLevel <= 59 and playerLevel - math.floor(playerLevel / 5) - 1
        or playerLevel - 9
    if difference >= 5 then key = "impossible"
    elseif difference >= 3 then key = "verydifficult"
    elseif difference >= -2 then key = "difficult"
    elseif level > gray then key = "standard"
    else key = "trivial" end
    return ColorCode(QuestDifficultyColors and QuestDifficultyColors[key] or palette[key])
end

local function LevelText(level)
    for _, template in ipairs({UNIT_LEVEL_TEMPLATE or false, TOOLTIP_UNIT_LEVEL or false}) do
        if type(template) == "string" then
            local ok, text = pcall(string.format, template, level)
            if ok then return text end
        end
    end
    return (type(LEVEL) == "string" and LEVEL or "Level") .. " " .. level
end

local function DisplayedUnit(tooltip, data)
    local function Token(fn)
        if type(fn) ~= "function" then return end
        local ok, _, unit = pcall(fn, tooltip)
        unit = Known(unit)
        if ok and type(unit) == "string" and unit ~= "" then return unit end
    end
    local unit = Token(TooltipUtil and TooltipUtil.GetDisplayedUnit) or Token(tooltip.GetUnit)
    if unit then return unit end
    -- Transient world mouseovers may not resolve through UnitTokenFromGUID.
    -- Only use mouseover when its readable GUID matches this tooltip's data.
    data = Known(data) or Read(tooltip.GetPrimaryTooltipData, tooltip)
    if type(data) ~= "table" then return end
    local ok, guid = pcall(function() return Known(data.guid) end)
    local mouseoverGUID = Read(UnitGUID, "mouseover")
    if ok and type(guid) == "string" and guid == mouseoverGUID then return "mouseover" end
end

local function RememberWorldHover(tooltip)
    local info = Read(tooltip.GetPrimaryTooltipInfo, tooltip)
    if type(info) ~= "table" then return end
    local ok, getter = pcall(function() return Known(info.getterName) end)
    if ok and type(getter) == "string" then worldHover[tooltip] = getter == "GetWorldCursor" or nil end
end

local function HideWhenHoverEnds(tooltip)
    if not Enabled() or not Allowed(tooltip) or Editing() or Read(tooltip.IsShown, tooltip) ~= true then return end
    RememberWorldHover(tooltip)
    if worldHover[tooltip] and C_TooltipInfo and type(C_TooltipInfo.GetWorldCursor) == "function" then
        -- The engine can start its own delayed fade without invoking the Lua
        -- FadeOut method. Detect departure using the native world-hover query.
        local ok, data = pcall(C_TooltipInfo.GetWorldCursor)
        if ok and not (issecretvalue and issecretvalue(data)) and data == nil then
            tooltip:Hide(); return
        end
    end
    local owner = Read(tooltip.GetOwner, tooltip)
    if owner == UIParent or owner == WorldFrame then
        local unit = DisplayedUnit(tooltip)
        if unit and Read(UnitExists, "mouseover") == false then tooltip:Hide(); return end
    elseif Allowed(owner) and Read(owner.IsMouseOver, owner) == false then
        tooltip:Hide(); return
    end
    -- Also catch engine-only fades for other hover surfaces. Compare to the
    -- tooltip's own starting alpha so a stable custom opacity is preserved.
    local alpha, initial = Read(tooltip.GetAlpha, tooltip), shownAlpha[tooltip]
    if type(alpha) == "number" and type(initial) == "number" and alpha < initial then tooltip:Hide() end
end

local function Tint(text, phrase, code)
    if type(phrase) ~= "string" or phrase == "" or not code then return text end
    local first, last = text:find(phrase, 1, true)
    if not first then return text end
    if text:sub(math.max(1, first - #code), last + 2) == code .. phrase .. "|r" then return text end
    return text:sub(1, first - 1) .. code .. phrase .. "|r" .. text:sub(last + 1)
end

local function LevelLines(tooltip, data)
    local indices = {}
    local levelType = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.UnitLevel
    data = Known(data) or Read(tooltip.GetPrimaryTooltipData, tooltip)
    if not levelType or type(data) ~= "table" then return indices end
    local lines = Read(function() return data.lines end)
    if type(lines) ~= "table" then return indices end
    pcall(function()
        for _, line in ipairs(lines) do
            if type(Known(line)) == "table" and Known(line.type) == levelType then
                local index = Known(line.lineIndex)
                if type(index) == "number" then indices[index] = true end
            end
        end
    end)
    return indices
end

local function TintLevelNumber(text, level, code)
    if not code then return text end
    -- Mask color codes without moving text offsets; a level must not match
    -- digits inside markup or a different number (19 versus 190).
    local searchable = text:gsub("|c%x%x%x%x%x%x%x%x", function(markup) return string.rep(" ", #markup) end)
    local first, last = searchable:find("%f[%d]" .. level .. "%f[%D]")
    if not first then return text end
    return text:sub(1, first - 1) .. code .. text:sub(first, last) .. "|r" .. text:sub(last + 1)
end

local function ColorUnit(tooltip, data)
    if not Enabled() or not addon.db.unitColors or not hooked[tooltip] or not Allowed(tooltip) then return end
    local unit = DisplayedUnit(tooltip, data)
    if not unit then return end
    local className, classCode, name, fullName, race
    if Read(UnitIsPlayer, unit) == true and UnitClass then
        local ok, localized, token = pcall(UnitClass, unit)
        localized, token = Known(localized), Known(token)
        if ok and type(localized) == "string" and type(token) == "string" then
            className, classCode = localized, ColorCode(RAID_CLASS_COLORS and RAID_CLASS_COLORS[token])
            race = Read(UnitRace, unit)
        end
        if classCode and UnitName then
            local nameOK, first, surname = pcall(UnitName, unit)
            first, surname = Known(first), Known(surname)
            if nameOK and type(first) == "string" and first ~= "" then
                name, fullName = first, first
                if type(surname) == "string" and surname ~= "" then
                    local separator = Constants and Constants.CharacterNameSeparatorConsts
                        and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR or " "
                    local suffix = separator .. surname
                    if first:sub(-#suffix) ~= suffix then fullName = first .. suffix end
                end
            end
        end
    end
    local level = Read(UnitLevel, unit)
    local levelText = type(level) == "number" and level > 0 and LevelText(level) or nil
    local hostile = Read(UnitCanAttack, "player", unit) == true or Read(UnitIsEnemy, "player", unit) == true
    local levelCode = hostile and levelText and Difficulty(unit, level) or nil
    local levelLines = LevelLines(tooltip, data)
    local count, tooltipName = Read(tooltip.NumLines, tooltip), Read(tooltip.GetName, tooltip)
    if type(count) ~= "number" or type(tooltipName) ~= "string" then return end
    for index = 1, count do
        local line = _G[tooltipName .. "TextLeft" .. index]
        local text = line and Read(line.GetText, line)
        if type(text) == "string" then
            local record = changedLines[line]
            if record and text == record.colored then text = record.original end
            local colored = text
            if index == 1 and name then
                colored = Tint(text, text:find(fullName, 1, true) and fullName or name, classCode)
            elseif index > 1 then
                colored = Tint(colored, levelText, levelCode)
                if colored == text and levelLines[index] and levelText then
                    colored = TintLevelNumber(colored, level, levelCode)
                end
                -- Do not color class words inside guilds, quest objectives or
                -- flavor text: only a unit's level/class detail line.
                if text == className or levelLines[index] or (levelText and text:find(levelText, 1, true))
                    or (type(race) == "string" and text == race .. " " .. (className or "")) then
                    colored = Tint(colored, className, classCode)
                end
            end
            changedLines[line] = nil
            if colored ~= text then
                local ok = pcall(line.SetText, line, colored)
                if ok then changedLines[line] = { original = text, colored = colored } end
            end
        end
    end
end

local function InstallHooks()
    -- Hover surfaces, not embedded/scanning tooltips or clicked item links.
    -- Comparison tooltips keep their native attachment to the moving item tip.
    for _, name in ipairs({"GameTooltip", "BuffFrameTooltip", "GameSmallHeaderTooltip", "GameNoHeaderTooltip"}) do
        local tooltip = _G[name]
        if Allowed(tooltip) and not hooked[tooltip] and tooltip.SetAnchorType then
            hooked[tooltip] = true
            hooksecurefunc(tooltip, "SetOwner", function(self)
                worldHover[self] = nil
                QueueAnchor(self)
            end)
            for _, method in ipairs({"SetAnchorType", "SetPoint"}) do
                -- Bag layouts set the anchor type and then SetPoint. Changing
                -- families between those calls can make the native SetPoint
                -- fail before any post-hook runs. Mark dirty until setup ends.
                hooksecurefunc(tooltip, method, QueueAnchor)
            end
            tooltip:HookScript("OnShow", function(self)
                shownAlpha[self] = Read(self.GetAlpha, self)
                RememberWorldHover(self)
                QueueAnchor(self)
                FinishAnchor(self)
            end)
            tooltip:HookScript("OnHide", function(self)
                anchorQueued[self], worldHover[self], shownAlpha[self] = nil, nil, nil
            end)
            -- Show is called again when refreshing an already visible tooltip;
            -- OnShow alone would miss that case. No next-frame timer: native
            -- placement must be corrected before this update is rendered.
            hooksecurefunc(tooltip, "Show", FinishAnchor)
            tooltip:HookScript("OnUpdate", function(self)
                HideWhenHoverEnds(self)
                if Read(self.IsShown, self) == true then FinishAnchor(self) end
            end)
            if tooltip.SetWorldCursor then
                hooksecurefunc(tooltip, "SetWorldCursor", function(self)
                    if Read(self.IsShown, self) == true then
                        worldHover[self] = true
                        FinishAnchor(self)
                    end
                end)
            end
            if tooltip.FadeOut then
                hooksecurefunc(tooltip, "FadeOut", function(self)
                    if Enabled() and Allowed(self) then self:Hide() end
                end)
            end
        end
    end
    -- These routines finish compound native anchor changes. Restore VV's
    -- placement on return, including repeated world and bag hover refreshes.
    for _, name in ipairs({"GameTooltip_SetDefaultAnchor", "SharedTooltip_SetDefaultAnchor"}) do
        if type(_G[name]) == "function" and not hookedHelpers[name] then
            hookedHelpers[name] = true
            hooksecurefunc(name, FinishAnchor)
        end
    end
    local bagHelper = "ContainerFrameItemButton_CalculateItemTooltipAnchors"
    if type(_G[bagHelper]) == "function" and not hookedHelpers[bagHelper] then
        hookedHelpers[bagHelper] = true
        hooksecurefunc(bagHelper, function(_, tooltip) FinishAnchor(tooltip) end)
    end
end

function addon.InitDB()
    if not VV.db then VV.InitDB() end
    addon.db = VV.db.tooltips
    addon.db.instantHide = nil -- Retired: enabled hover tooltips always hide immediately.
    for key, default in pairs(addon.defaults) do
        local value, limits = addon.db[key], addon.limits[key]
        if limits then
            if type(value) ~= "number" or value ~= value or value < limits[1] or value > limits[2] then addon.db[key] = default end
        elseif type(value) ~= "boolean" then addon.db[key] = default end
    end
end

function addon.RefreshModule()
    if not addon.db then addon.InitDB() end
    RestoreColors()
    InstallHooks()
    for tooltip in pairs(hooked) do
        if Allowed(tooltip) and Read(tooltip.IsShown, tooltip) == true then
            if Enabled() then
                if not addon.db.followMouse and not Paused() then
                    changingAnchor = true
                    local ok, err = pcall(AnchorInEditMode, tooltip)
                    changingAnchor = false
                    if not ok and geterrorhandler then geterrorhandler()(err) end
                else ApplyAnchor(tooltip) end
                ColorUnit(tooltip)
            elseif moved[tooltip] then
                -- Let the next native hover rebuild its original anchor/content.
                tooltip:Hide()
                moved[tooltip] = nil
            end
        end
    end
    if addon.RefreshOptions then addon.RefreshOptions() end
end

function addon.SetOption(key, value)
    if not addon.db then addon.InitDB() end
    local default, limits = addon.defaults[key], addon.limits[key]
    if default == nil then return false end
    if limits then
        if type(value) ~= "number" or value ~= value or value < limits[1] or value > limits[2] then return false end
        value = math.floor(value + 0.5)
    elseif type(value) ~= "boolean" then return false end
    addon.db[key] = value
    addon.RefreshModule()
    return true
end

function addon.ResetSettings()
    VV.db.tooltips = {}
    addon.InitDB()
    addon.RefreshModule()
end

function addon.HandleSlash(message)
    local x, y = message:match("^offset%s+(%-?%d+)%s+(%-?%d+)$")
    if x and y then
        x, y = tonumber(x), tonumber(y)
        if x >= -500 and x <= 500 and y >= -500 and y <= 500 then
            addon.SetOption("offsetX", x); addon.SetOption("offsetY", y)
            return
        end
    elseif message:lower() == "reset" then addon.ResetSettings(); return end
    VV.Print("/vv tooltips opens settings. /vv tooltips offset <x> <y> (-500 to 500); /vv tooltips reset.")
end

driver:RegisterEvent("ADDON_LOADED")
driver:RegisterEvent("PLAYER_LOGIN")
driver:RegisterEvent("PLAYER_REGEN_DISABLED")
driver:RegisterEvent("PLAYER_REGEN_ENABLED")
driver:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
driver:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" then
        if name == ADDON then addon.InitDB() end
        if addon.db then InstallHooks() end
    elseif event == "PLAYER_LOGIN" then
        addon.RefreshModule()
        if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Unit then
            TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, ColorUnit)
        end
        addon.RegisterOptions()
    elseif event == "UPDATE_MOUSEOVER_UNIT" and addon.db then
        for tooltip in pairs(hooked) do HideWhenHoverEnds(tooltip) end
    elseif addon.db then
        for tooltip in pairs(hooked) do
            if Allowed(tooltip) and Read(tooltip.IsShown, tooltip) == true then ApplyAnchor(tooltip) end
        end
    end
end)
