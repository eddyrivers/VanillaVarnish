local ADDON, VV = ...
local ns = VV.Nameplates
ns = ns or {}
local db
local active = {}
local frames = setmetatable({}, { __mode = "k" })
local questTooltips
local objectives = {}
local activeQuests = {}
local neededDrops = {}
local dropDatabase
local questDirty = true
local elapsed = 0
local RemoveUnit
local textures = "Interface\\AddOns\\VanillaVarnish\\Media\\"
local focusDefaults = { focusEnabled = false, focusMode = "tank", focusScale = 0.75, focusOpacity = 0.5 }

-- Forever can restrict unit data in combat. Unknown results never cause fading.
local function Known(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Known(value) end
end

local function RecordField(record, key) return record[key] end

local function Field(record, key)
    if type(record) ~= "table" then return end
    local ok, value = pcall(RecordField, record, key)
    if ok and not (issecretvalue and issecretvalue(value)) then return value, true end
end

local function Records(list)
    if type(list) ~= "table" then return {} end
    -- Restricted nested records/lists can refuse indexing even when the
    -- top-level API succeeded. Unknown quest data contributes no markers.
    return SafeCall(function()
        local result = {}
        for _, record in ipairs(list) do
            if type(Known(record)) == "table" then result[#result + 1] = record end
        end
        return result
    end) or {}
end

local function Print(message)
    print("|cff80cfffVanillaVarnish:|r " .. message:gsub("|", "||"))
end

local function Normalize(text)
    if type(text) ~= "string" then return "" end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("%s+", " "):match("^%s*(.-)%s*$"):lower()
end

local function RefreshObjectives()
    objectives = {}
    activeQuests, neededDrops = {}, {}
    dropDatabase = ns.QuestDropDatabase and ns.QuestDropDatabase()
    local function AddDrops(questID, questObjectives, complete)
        if not ns.QuestDropSources then return end
        local drops = SafeCall(ns.QuestDropSources, questID, questObjectives, complete, dropDatabase) or {}
        for npcID in pairs(drops) do neededDrops[npcID] = true end
    end
    local function AddObjective(text, kind, finished)
        text, kind, finished = Known(text), Known(kind), Known(finished)
        if type(text) == "string" and not finished then
            local marker = kind == "item" and "loot" or kind == "monster" and "kill" or "other"
            objectives[Normalize(text)] = marker
            local subject = Normalize(text):gsub("%d+%s*/%s*%d+", ""):gsub("%d+%%", "")
                :gsub("^%s*[:%-]%s*", ""):gsub("%s*[:%-]%s*$", "")
            objectives[Normalize(subject)] = marker
        end
    end
    if C_QuestLog and C_QuestLog.GetInfo and C_QuestLog.GetQuestObjectives then
        local count = SafeCall(C_QuestLog.GetNumQuestLogEntries)
        for index = 1, type(count) == "number" and count or 0 do
            local info = SafeCall(C_QuestLog.GetInfo, index)
            local questID = Field(info, "questID")
            if type(questID) == "number" and questID > 0 and Field(info, "isHeader") ~= true then
                activeQuests[questID] = true
                local questObjectives = Records(SafeCall(C_QuestLog.GetQuestObjectives, questID))
                for _, objective in ipairs(questObjectives) do
                    local finished, readable = Field(objective, "finished")
                    if readable then AddObjective(Field(objective, "text"), Field(objective, "type"), finished) end
                end
                AddDrops(questID, questObjectives, Field(info, "isComplete"))
            end
        end
        return
    end
    if not GetNumQuestLogEntries or not GetQuestLogTitle then return end
    for index = 1, GetNumQuestLogEntries() do
        local _, _, _, header, _, complete, _, _, questID = GetQuestLogTitle(index)
        if not header and questID then activeQuests[questID] = true end
        if not header and complete ~= 1 and complete ~= true then
            local questObjectives = {}
            for objectiveIndex = 1, GetNumQuestLeaderBoards(index) do
                local text, kind, finished = GetQuestLogLeaderBoard(objectiveIndex, index)
                AddObjective(text, kind, finished)
                questObjectives[#questObjectives + 1] = {text = text, type = kind, finished = finished}
            end
            AddDrops(questID, questObjectives, complete)
        end
    end
end

local function NPCID(unit)
    local guid = SafeCall(UnitGUID, unit)
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("^Creature%-%d+%-%d+%-%d+%-%d+%-(%d+)")
        or guid:match("^Vehicle%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

local function QuestieKinds(unit)
    if not (Questie and Questie.API and Questie.API.isReady and QuestieLoader) then return nil end
    if not questTooltips then
        local ok, module = pcall(QuestieLoader.ImportModule, QuestieLoader, "QuestieTooltips")
        if ok then questTooltips = module end
    end
    local npcID = NPCID(unit)
    local lookup = questTooltips and questTooltips.lookupByKey
    local entries = lookup and npcID and lookup["m_" .. npcID]
    if not entries then return nil end
    local kinds = {}
    for _, entry in pairs(entries) do
        local objective = entry.objective
        if objective and activeQuests[entry.questId] then
            if objective.Update then pcall(objective.Update, objective) end
            if not objective.Completed and (not objective.Needed or not objective.Collected
                or objective.Collected < objective.Needed) then
                local icon = objective.Icon
                local kind = (objective.Type == "item" or (icon and (icon == Questie.ICON_TYPE_LOOT
                    or icon == Questie.ICON_TYPE_OBJECT))) and "loot"
                    or (objective.Type == "monster" or (icon and icon == Questie.ICON_TYPE_SLAY)) and "kill"
                    or "other"
                local reviewed = ns.QuestDropData and ns.QuestDropData.reviewed[entry.questId]
                if kind ~= "loot" or not reviewed then kinds[kind] = true end
            end
        end
    end
    return kinds
end

local function PlayerNames(unit)
    local ok, name, surname = pcall(UnitName, unit or "player")
    if not ok then return end
    name, surname = Known(name), Known(surname)
    if type(name) ~= "string" or name == "" then return end
    local fullName = name
    if type(surname) == "string" and surname ~= "" then
        local separator = Field(Field(Constants, "CharacterNameSeparatorConsts"), "CHARACTERNAME_SURNAME_SEPARATOR")
        if type(separator) ~= "string" then separator = " " end
        local suffix = separator .. surname
        if name:sub(-#suffix) ~= suffix then fullName = name .. suffix end
    end
    return Normalize(name), Normalize(fullName)
end

local function ObjectiveSubject(text)
    return Normalize(Normalize(text):gsub("%d+%s*/%s*%d+", ""):gsub("%d+%%", "")
        :gsub("^%s*[:%-]%s*", ""):gsub("%s*[:%-]%s*$", ""))
end

local function GroupNames()
    local names = {}
    if not db.groupQuestMarkers then return names end
    local raid = SafeCall(IsInRaid) == true
    local count = SafeCall(GetNumGroupMembers)
    count = type(count) == "number" and math.min(count, raid and 40 or 4) or (raid and 0 or 4)
    for index = 1, count do
        local token = (raid and "raid" or "party") .. index
        if SafeCall(UnitExists, token) == true then
            local name, fullName = PlayerNames(token)
            if name then names[name] = true end
            if fullName then names[fullName] = true end
        end
    end
    return names
end

local function NativeKinds(unit)
    local kinds = {}
    if not (C_TooltipInfo and C_TooltipInfo.GetUnit) then return kinds end
    local info = SafeCall(C_TooltipInfo.GetUnit, unit)
    local lines = Field(info, "lines")
    if type(lines) ~= "table" then return kinds end
    local lineTypes = Enum and Enum.TooltipDataLineType
    local ownObjectives = true
    local groupObjectives = false
    local groupNames = GroupNames()
    local questObjectives = {}
    local npcName = Normalize(SafeCall(UnitName, unit))
    local slainText = SafeCall(string.format, QUEST_MONSTERS_KILLED or "%s slain: %d/%d", npcName, 0, 1)
    local slainSubject = ObjectiveSubject(slainText)
    local playerName, playerFullName = PlayerNames()
    for _, line in ipairs(Records(lines)) do
        local lineType = Field(line, "type")
        local text = Field(line, "leftText")
        if lineTypes and lineType == lineTypes.QuestTitle then
            ownObjectives = true
            groupObjectives, questObjectives = false, {}
            local questID = Field(line, "questID")
            if db.groupQuestMarkers and type(questID) == "number" then
                for _, objective in ipairs(Records(SafeCall(C_QuestLog and C_QuestLog.GetQuestObjectives, questID))) do
                    local kind = Field(objective, "type")
                    if kind == "item" or kind == "monster" then
                        questObjectives[ObjectiveSubject(Field(objective, "text"))] = kind == "item" and "loot" or "kill"
                    end
                end
            end
        elseif lineTypes and lineType == lineTypes.QuestPlayer then
            -- Forever's player line may include a surname even when UnitName's
            -- first return does not. Compare complete names, never prefixes.
            local name = Normalize(text)
            ownObjectives = playerName ~= nil and (name == playerName or name == playerFullName)
            groupObjectives = not ownObjectives and groupNames[name] == true
        elseif groupObjectives and lineTypes and lineType == lineTypes.QuestObjective and type(text) == "string" then
            local current, needed = text:match("(%d+)%s*/%s*(%d+)")
            if current and tonumber(current) < tonumber(needed) then
                local subject = ObjectiveSubject(text)
                -- Native quest metadata is preferred. For tooltip-only group
                -- quests, counted NPC names mean kills; other counted needs
                -- on this hostile creature identify quest loot.
                local kind = questObjectives[subject] or objectives[subject]
                    or (npcName ~= "" and (subject == npcName or subject == slainSubject) and "kill" or "loot")
                if kind == "loot" or kind == "kill" then kinds[kind] = true end
            end
        elseif ownObjectives and type(text) == "string" then
            local kind = objectives[Normalize(text)]
            if not kind then
                local subject = Normalize(text):gsub("%d+%s*/%s*%d+", ""):gsub("%d+%%", "")
                    :gsub("^%s*[:%-]%s*", ""):gsub("%s*[:%-]%s*$", "")
                local current, needed = text:match("(%d+)%s*/%s*(%d+)")
                if not current or tonumber(current) < tonumber(needed) then
                    kind = objectives[Normalize(subject)]
                end
            end
            if kind then kinds[kind] = true end
        end
    end
    return kinds
end

local function GetKinds(unit)
    if SafeCall(UnitIsPlayer, unit) or SafeCall(UnitCanAttack, "player", unit) ~= true then return {} end
    local kinds = NativeKinds(unit)
    local npcID = NPCID(unit)
    if npcID and neededDrops[npcID] then kinds.loot = true end
    if not db.questieFallback then return kinds end
    -- Optional fallback for NPC drop relationships missing from native tooltips.
    local ok, fallback = pcall(QuestieKinds, unit)
    if ok and fallback then
        for kind, needed in pairs(fallback) do if needed then kinds[kind] = true end end
    end
    return kinds
end

local function CreateMarker(parent, kind)
    local marker = CreateFrame("Frame", nil, parent)
    marker:SetSize(16, 16)
    local shadow = marker:CreateTexture(nil, "ARTWORK", nil, 0)
    shadow:SetSize(16, 16)
    shadow:SetPoint("CENTER", 1, -1)
    shadow:SetTexture(textures .. kind .. ".tga")
    shadow:SetVertexColor(0, 0, 0, 1)
    local icon = marker:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetAllPoints()
    icon:SetTexture(textures .. kind .. ".tga")
    icon:SetVertexColor(1, 1, 1, 1)
    marker:Hide()
    marker.icon, marker.shadow, marker.kind = icon, shadow, kind
    return marker
end

local function ApplyAlpha(state)
    if type(state.baseAlpha) ~= "number" then return end
    local desired = state.focusAlpha or state.baseAlpha * (state.faded and db.rangeOpacity or 1)
    local current = SafeCall(state.frame.GetAlpha, state.frame)
    if type(current) == "number" and current ~= desired then
        state.settingAlpha = true
        pcall(state.frame.SetAlpha, state.frame, desired)
        state.settingAlpha = false
    end
end

local function ApplyScale(state)
    if not state.baseScale then return end
    local frame = state.frame
    if SafeCall(frame.IsForbidden, frame) ~= false then return end
    local current = SafeCall(frame.GetScale, frame)
    if type(current) ~= "number" then return end
    local desired = state.baseScale * (state.focusScale or 1)
    state.scaleDeferred = nil
    if current == desired then return end
    if InCombatLockdown() and SafeCall(frame.IsProtected, frame) ~= false then
        state.scaleDeferred = true
        return
    end
    state.settingScale = true
    pcall(frame.SetScale, frame, desired)
    state.settingScale = false
end

local function SetFocusScale(state, factor)
    local frame = state.frame
    if factor and not state.watchingScale then
        state.baseScale = SafeCall(frame.GetScale, frame)
        if type(state.baseScale) ~= "number" then state.baseScale = nil; return end
        state.watchingScale = true
        hooksecurefunc(frame, "SetScale", function(_, scale)
            if state.settingScale then return end
            scale = Known(scale)
            state.baseScale = type(scale) == "number" and scale or nil
            if state.unit and state.focusScale then ApplyScale(state) end
        end)
    end
    state.focusScale = factor
    ApplyScale(state)
end

local function StateFor(plate)
    if SafeCall(plate.IsForbidden, plate) ~= false then return nil end
    local frame = plate.UnitFrame
    if not frame or SafeCall(frame.IsForbidden, frame) ~= false then return nil end
    local state = frames[frame]
    if not state then
        state = { frame = frame, baseAlpha = SafeCall(frame.GetAlpha, frame), markers = {} }
        for _, kind in ipairs({"loot", "kill", "other"}) do
            state.markers[kind] = CreateMarker(frame, kind)
        end
        frames[frame] = state
        hooksecurefunc(frame, "SetAlpha", function(_, alpha)
            if state.settingAlpha then return end
            alpha = Known(alpha)
            state.baseAlpha = type(alpha) == "number" and alpha or nil
            if state.unit and (state.focusAlpha or state.faded) then ApplyAlpha(state) end
        end)
    end
    return state
end

local function UpdateMarkers(state)
    local kinds = VV.IsModuleEnabled("nameplates") and db.markers and GetKinds(state.unit) or {}
    local name = state.frame.name or state.frame.nameText or state.frame.Name
    local anchor = name or state.frame.healthBar or state.frame
    local point, offset = "LEFT", -4
    if name and name.GetStringWidth then
        -- The name FontString can span the entire bar even for a short name.
        -- Position beside the rendered text rather than the FontString's box.
        local width = SafeCall(name.GetWidth, name)
        local textWidth = SafeCall(name.GetStringWidth, name)
        if type(textWidth) == "number" then
            if type(width) == "number" and width > 0 then textWidth = math.min(textWidth, width) end
            local justify = SafeCall(name.GetJustifyH, name)
            if justify == "RIGHT" then
                point, offset = "RIGHT", -textWidth - 4
            elseif justify ~= "LEFT" then
                point, offset = "CENTER", -textWidth / 2 - 4
            end
        end
    end
    local previous
    for _, kind in ipairs({"loot", "kill", "other"}) do
        local marker = state.markers[kind]
        local pixel = PixelUtil and PixelUtil.GetPixelToUIUnitFactor
            and PixelUtil.GetPixelToUIUnitFactor() / marker:GetEffectiveScale() or 1
        if kind == "loot" then
            -- Keep the top edge; lift the bag's bottom by one screen pixel.
            marker.icon:ClearAllPoints()
            marker.icon:SetPoint("TOPLEFT", marker, "TOPLEFT", 0, 0)
            marker.icon:SetPoint("BOTTOMRIGHT", marker, "BOTTOMRIGHT", 0, pixel)
            marker.shadow:ClearAllPoints()
            marker.shadow:SetPoint("TOPLEFT", marker.icon, "TOPLEFT", pixel, -pixel)
            marker.shadow:SetPoint("BOTTOMRIGHT", marker.icon, "BOTTOMRIGHT", pixel, -pixel)
        end
        local gap = 4
        if previous and previous.kind == "loot" and kind == "kill" then
            -- The 16-unit artwork has 2 units of left padding on the bag and
            -- 1.5 of right padding on the dagger. Keep visible edges 6 screen
            -- pixels apart, including on enlarged target nameplates.
            gap = 6 * pixel - 3.5
        end
        marker:ClearAllPoints()
        marker:SetPoint("RIGHT", previous or anchor, previous and "LEFT" or point,
            previous and -gap or offset, 0)
        marker:SetShown(kinds[kind] == true)
        if kinds[kind] then previous = marker end
    end
end

local function SpellInRange(spell, unit)
    if not spell then return nil end
    local result = SafeCall(C_Spell and C_Spell.IsSpellInRange, spell, unit)
    if result == nil and IsSpellInRange then result = SafeCall(IsSpellInRange, spell, unit) end
    if result == false or result == 0 then return false end
    if result == true or result == 1 then return true end
    return nil
end
ns.SpellInRange = SpellInRange

local function IsOutOfRange(unit)
    if not db.rangeEnabled then return false end
    local spell
    if SafeCall(UnitCanAttack, "player", unit) then
        spell = db.damage
    elseif SafeCall(UnitCanAssist, "player", unit) then
        spell = db.friendly
    end
    return SpellInRange(spell, unit) == false
end

local function Casting(api, unit)
    if not api then return nil end
    -- Both spell APIs return a public tradeskill flag only while a spell is active.
    -- The spell name and other details can be restricted.
    local ok, name, _, _, _, _, tradeskill = pcall(api, unit)
    if not ok then return nil end
    if type(Known(tradeskill)) == "boolean" then return true end
    if issecretvalue and issecretvalue(name) then return nil end
    return name ~= nil
end

local function FocusTarget()
    if not db.focusEnabled then return end
    local plate = SafeCall(C_NamePlate.GetNamePlateForUnit, "target")
    if plate and SafeCall(plate.IsForbidden, plate) == false then return plate.UnitFrame end
end

local function FocusAppearance(state, target)
    if not db.focusEnabled then return end
    local unit = state.unit
    if SafeCall(UnitCanAttack, "player", unit) ~= true or SafeCall(UnitIsPlayer, unit) ~= false
        or SafeCall(UnitIsDeadOrGhost, unit) ~= false then return end
    if state.frame == target then return 1 end
    if SafeCall(UnitAffectingCombat, unit) ~= true then return end

    local casting, channeling = Casting(UnitCastingInfo, unit), Casting(UnitChannelInfo, unit)
    -- Unavailable cast or threat data keeps potentially important enemies prominent.
    if casting ~= false or channeling ~= false then return 1 end
    if db.focusMode == "tank" then
        if SafeCall(UnitThreatSituation, "player", unit) ~= 3 then return 1 end
        if UnitThreatLeadSituation and SafeCall(UnitThreatLeadSituation, "player", unit) ~= 0 then return 1 end
    end
    return db.focusOpacity, db.focusScale < 1 and db.focusScale or nil
end

local function UpdateAppearance(state, target)
    if SafeCall(state.frame.IsForbidden, state.frame) ~= false then return end
    local alpha, scale = FocusAppearance(state, target)
    state.focusAlpha = alpha
    state.faded = alpha == nil and IsOutOfRange(state.unit)
    SetFocusScale(state, scale)
    ApplyAlpha(state)
end

local function UpdateAppearances()
    local target = FocusTarget()
    for _, state in pairs(active) do UpdateAppearance(state, target) end
end

local function AddUnit(unit)
    if type(unit) ~= "string" or not VV.IsModuleEnabled("nameplates") then return end
    local plate = SafeCall(C_NamePlate.GetNamePlateForUnit, unit)
    local state = plate and StateFor(plate)
    if active[unit] and active[unit] ~= state then RemoveUnit(unit) end
    if not state then return end
    if state.unit and state.unit ~= unit then RemoveUnit(state.unit) end
    state.unit = unit
    active[unit] = state
    UpdateAppearance(state, FocusTarget())
    UpdateMarkers(state)
end

RemoveUnit = function(unit)
    local state = active[unit]
    if not state then return end
    state.unit = nil
    state.faded, state.focusAlpha = nil, nil
    if SafeCall(state.frame.IsForbidden, state.frame) == false then
        SetFocusScale(state, nil)
        ApplyAlpha(state)
    else
        state.focusScale = nil
    end
    for _, marker in pairs(state.markers) do marker:Hide() end
    active[unit] = nil
end

local function SpellName(value)
    local info = SafeCall(C_Spell and C_Spell.GetSpellInfo, tonumber(value) or value)
    if info then return info.name, info.spellID, info.maxRange end
    if GetSpellInfo then
        local name, _, _, _, _, maxRange, id = GetSpellInfo(tonumber(value) or value)
        return name, id, maxRange
    end
end

local function SetSpell(kind, input)
    input = input:match("^%s*(.-)%s*$"):gsub('^"(.*)"$', "%1")
    if input == "" then
        Print(kind .. " range spell: " .. (db[kind] or "off"))
        return
    end
    if input:lower() == "off" or input:lower() == "clear" then
        db[kind] = nil
        Print(kind .. " range fading disabled.")
    else
        local name, id = SpellName(input)
        if not name then Print("Unknown spell. Use its full name, spell ID, or shift-click a spell link.") return end
        local harmful = SafeCall(C_Spell and C_Spell.IsSpellHarmful or IsHarmfulSpell, id or name)
        local helpful = SafeCall(C_Spell and C_Spell.IsSpellHelpful or IsHelpfulSpell, id or name)
        if (kind == "damage" and harmful == false) or (kind == "friendly" and helpful == false) then
            Print(name .. " is not a " .. (kind == "damage" and "harmful" or "friendly") .. " spell.") return
        end
        -- Melee spells report maxRange=0: the range API still checks their
        -- native combat reach. Spell metadata is not a range verdict.
        if SafeCall(C_Spell and C_Spell.IsSpellPassive or IsPassiveSpell, id or name) == true then
            Print(name .. " is passive. Choose a targeted spell.") return
        end
        db[kind] = name
        Print(string.format("%s range spell set to %s. Out-of-range opacity: %g%%.", kind, name, db.rangeOpacity * 100))
    end
    UpdateAppearances()
    if VV.Party.RefreshModule then VV.Party.RefreshModule() end
    if ns.RefreshFeatureOptions then ns.RefreshFeatureOptions() end
    if VV.RefreshProfileStatus then VV.RefreshProfileStatus() end
end

function ns.RefreshTweaks()
    questDirty = true
    UpdateAppearances()
    for _, state in pairs(active) do UpdateMarkers(state) end
    if ns.RefreshThreatColors then ns.RefreshThreatColors() end
    if ns.RefreshFeatureOptions then ns.RefreshFeatureOptions() end
end

function ns.SetFeature(key, value)
    if not db or type(value) ~= "boolean" then return false end
    if key == "focusEnabled" then return ns.SetFocusOption(key, value) end
    if key ~= "rangeEnabled" and key ~= "markers" and key ~= "swingsEnabled"
        and key ~= "comboPointsEnabled" and key ~= "questieFallback" and key ~= "groupQuestMarkers"
        and key ~= "threatColorsEnabled" then return false end
    db[key] = value
    ns.RefreshTweaks()
    if ns.Refresh then ns.Refresh() end
    if ns.RefreshComboPoints then ns.RefreshComboPoints() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    if VV.RefreshProfileStatus then VV.RefreshProfileStatus() end
    return true
end

function ns.SetRangeOpacity(value)
    value = Known(value)
    if not db or type(value) ~= "number" or value ~= value or value < 0 or value > 1 then return false end
    db.rangeOpacity = value
    ns.RefreshTweaks()
    if VV.Party.RefreshModule then VV.Party.RefreshModule() end
    if VV.RefreshProfileStatus then VV.RefreshProfileStatus() end
    return true
end

local function ValidFocusOption(key, value)
    value = Known(value)
    if key == "focusEnabled" then return type(value) == "boolean" end
    if key == "focusMode" then return value == "tank" or value == "damage" end
    local minimum = key == "focusScale" and 0.25 or 0
    return type(value) == "number" and value >= minimum and value <= 1
end

function ns.NormalizeFocusSettings(settings)
    for key, default in pairs(focusDefaults) do
        if not ValidFocusOption(key, settings[key]) then settings[key] = default end
    end
end

function ns.SetFocusOption(key, value)
    if not db or focusDefaults[key] == nil or not ValidFocusOption(key, value) then return false end
    db[key] = value
    UpdateAppearances()
    if ns.RefreshFeatureOptions then ns.RefreshFeatureOptions() end
    if VV.RefreshProfileStatus then VV.RefreshProfileStatus() end
    return true
end

ns.SetRangeSpell = SetSpell

local function Status()
    Print("Damage: " .. (db.damage or "off") .. "; friendly: " .. (db.friendly or "off")
        .. "; range check: " .. (db.rangeEnabled and "on" or "off")
        .. "; quest icons: " .. (db.markers and "on" or "off")
        .. "; swing timers: " .. (db.swingsEnabled and "on" or "off")
        .. "; combo points: " .. (db.comboPointsEnabled and "on" or "off")
        .. "; threat colors: " .. (db.threatColorsEnabled and "on" or "off") .. ".")
    Print(string.format("Out-of-range opacity: %g%% of normal.", db.rangeOpacity * 100))
    Print(string.format("Combat focus: %s (%s, %g%% size, %g%% opacity).", db.focusEnabled and "on" or "off",
        db.focusMode == "tank" and "Tank" or "Damage / Healer", db.focusScale * 100, db.focusOpacity * 100))
end

local function Slash(message)
    if not db then return end
    message = message:gsub("|c%x%x%x%x%x%x%x%x|Hspell:(%d+).-|h.-|h|r", "%1")
        :gsub("|Hspell:(%d+).-|h.-|h", "%1")
    local command, rest = message:match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "rangecheck" then command = "range" end
    if command == "" or command == "options" or command == "config" then
        if ns.OpenOptions then ns.OpenOptions() end
        return
    end
    local feature = ({range = "rangeEnabled", quests = "markers", questicons = "markers",
        markers = "markers", swings = "swingsEnabled", swing = "swingsEnabled",
        combo = "comboPointsEnabled", combos = "comboPointsEnabled",
        threat = "threatColorsEnabled", aggro = "threatColorsEnabled", focus = "focusEnabled"})[command]
    local mode = rest:lower()
    if feature and (mode == "on" or mode == "off" or mode == "toggle") then
        ns.SetFeature(feature, mode == "on" or mode == "toggle" and not db[feature])
        Status(); return
    end
    if feature and (mode == "" or mode == "options") then
        if ns.OpenOptions then ns.OpenOptions(feature) end
        return
    end
    if command == "swings" or command == "swing" then
        if ns.Slash then ns.Slash(rest) end
        return
    end
    if command == "range" then
        local kind, spell = rest:match("^(%S*)%s*(.-)$")
        kind = kind:lower()
        if kind == "damage" or kind == "friendly" then SetSpell(kind, spell) return end
        if kind == "opacity" then
            local percent = tonumber(spell)
            if percent and ns.SetRangeOpacity(percent / 100) then
                Print(string.format("Out-of-range opacity: %g%% of normal.", db.rangeOpacity * 100))
            else Print("Use /vv nameplates range opacity <0-100 percent>.") end
            return
        end
    elseif command == "dmgrange" then SetSpell("damage", rest) return
    elseif command == "friendlyrange" or command == "healrange" then SetSpell("friendly", rest) return
    elseif command == "status" then
        Status()
        if ns.SwingStatus then ns.SwingStatus() end
        return
    elseif command == "questie" and (rest:lower() == "on" or rest:lower() == "off") then
        ns.SetFeature("questieFallback", rest:lower() == "on")
        Print("Extra Questie quest information " .. rest:lower() .. ".")
    elseif command == "groupquests" and (rest:lower() == "on" or rest:lower() == "off") then
        ns.SetFeature("groupQuestMarkers", rest:lower() == "on")
        Print("Group quest markers " .. rest:lower() .. ".")
        return
    elseif command == "debug" then
        Status()
        Print("Quest sources: native tooltip, bundled item drops, " .. (ns.QuestDropDatabase and ns.QuestDropDatabase()
            and "optional drop database available" or "optional drop database unavailable")
            .. "; optional Questie tooltip fallback " .. (db.questieFallback and "on" or "off") .. ".")
        local damage, friendly = SpellInRange(db.damage, "target"), SpellInRange(db.friendly, "target")
        Print("Target range: damage=" .. tostring(damage) .. ", friendly=" .. tostring(friendly) .. " (nil means unavailable).")
        return
    end
    if command ~= "help" and not feature and command ~= "questie" and command ~= "groupquests" and ns.Slash then
        ns.Slash(message)
        return
    end
    Print("/vv nameplates opens settings. Add range, quests, swings, combo, or focus to open a feature page.")
    Print("/vv nameplates range on or off; /vv nameplates quests on or off.")
    Print("/vv nameplates swings on or off; /vv nameplates combo on or off.")
    Print("/vv nameplates range damage Moonfire — set enemy range spell")
    Print("/vv nameplates range friendly Healing Touch — set friendly range spell")
    Print("/vv nameplates range opacity 50 — choose out-of-range opacity from 0 to 100 percent.")
    Print("Use off to disable either; spell IDs and spell links also work.")
    Print("/vv nameplates markers on or off; /vv nameplates questie on or off.")
    Print("/vv nameplates groupquests on or off includes your group's loot and kill objectives.")
    Print("/vv nameplates status; /vv nameplates debug. Settings save per character.")
    Print("/vv nameplates threat on or off — toggle role-aware threat colors.")
    Print("/vv nameplates focus on or off — toggle combat focus.")
    if ns.SwingHelp then ns.SwingHelp() end
end

ns.HandleSlash = Slash
ns.TweaksSlash = Slash

function ns.InitializeTweaks()
    if not VV.db then VV.InitDB() end
    db = VV.db.nameplates
    if type(db.markers) ~= "boolean" then db.markers = true end
    if type(db.rangeEnabled) ~= "boolean" then db.rangeEnabled = true end
    if type(db.swingsEnabled) ~= "boolean" then db.swingsEnabled = true end
    if type(db.comboPointsEnabled) ~= "boolean" then db.comboPointsEnabled = true end
    if type(db.threatColorsEnabled) ~= "boolean" then db.threatColorsEnabled = true end
    if type(db.questieFallback) ~= "boolean" then db.questieFallback = false end
    if type(db.groupQuestMarkers) ~= "boolean" then db.groupQuestMarkers = false end
    local opacity = Known(db.rangeOpacity)
    if type(opacity) ~= "number" or opacity ~= opacity or opacity < 0 or opacity > 1 then db.rangeOpacity = 0.5 end
    ns.NormalizeFocusSettings(db)
    ns.tweaksDB = db
    for _, key in ipairs({"damage", "friendly"}) do
        if type(db[key]) ~= "string" or db[key] == "" then db[key] = nil end
    end
end

local events = CreateFrame("Frame")
local focusUnitEvents = {
    UNIT_FLAGS = true, UNIT_THREAT_LIST_UPDATE = true, UNIT_THREAT_SITUATION_UPDATE = true,
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_CHANNEL_START = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_STOP = true,
}
for event in pairs(focusUnitEvents) do events:RegisterEvent(event) end
for _, event in ipairs({"ADDON_LOADED", "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "PLAYER_REGEN_ENABLED", "QUEST_LOG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_DATA_LOAD_RESULT", "SPELLS_CHANGED", "UNIT_FACTION", "GROUP_ROSTER_UPDATE", "PLAYER_TARGET_CHANGED"}) do
    events:RegisterEvent(event)
end
events:SetScript("OnEvent", function(_, event, arg)
    arg = Known(arg)
    if event == "ADDON_LOADED" then
        if arg ~= ADDON then return end
        ns.InitializeTweaks()
    elseif not db then return
    elseif event == "NAME_PLATE_UNIT_ADDED" then AddUnit(arg)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then RemoveUnit(arg)
    elseif event == "PLAYER_ENTERING_WORLD" then
        for unit in pairs(active) do RemoveUnit(unit) end
        -- GetNamePlates is not reliable on every Forever build; also scan unit tokens.
        for i = 1, 80 do
            local unit = "nameplate" .. i
            if SafeCall(UnitExists, unit) then AddUnit(unit) end
        end
        questDirty = true
    elseif event == "UNIT_FACTION" then
        if active[arg] then UpdateAppearance(active[arg], FocusTarget()); UpdateMarkers(active[arg]) end
    elseif event == "PLAYER_TARGET_CHANGED" then
        if db.focusEnabled then UpdateAppearances() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        if db.focusEnabled then UpdateAppearances() end
        for _, state in pairs(frames) do
            if state.scaleDeferred then ApplyScale(state) end
        end
        questDirty = true
    elseif focusUnitEvents[event] then
        if db.focusEnabled and active[arg] then UpdateAppearance(active[arg], FocusTarget()) end
    else questDirty = true end
end)

local questElapsed = 0
events:SetScript("OnUpdate", function(_, delta)
    if not db or not VV.IsModuleEnabled("nameplates") or not next(active) then return end
    elapsed = elapsed + delta
    questElapsed = questElapsed + delta
    if elapsed < 0.2 then return end
    elapsed = 0
    local updateQuests = db.markers and (questDirty or questElapsed >= 1)
    if updateQuests then
        if questDirty or (ns.QuestDropDatabase and ns.QuestDropDatabase() ~= dropDatabase) then RefreshObjectives() end
        questDirty = false
        questElapsed = 0
    end
    local target = FocusTarget()
    for _, state in pairs(active) do
        UpdateAppearance(state, target)
        if updateQuests then UpdateMarkers(state) end
    end
end)

function ns.RefreshModule()
    if not db then return end
    if ns.RefreshSwingWeapons then ns.RefreshSwingWeapons() end
    if VV.IsModuleEnabled("nameplates") then
        for i = 1, 80 do
            local unit = "nameplate" .. i
            if SafeCall(UnitExists, unit) then AddUnit(unit) end
        end
    else
        for unit in pairs(active) do RemoveUnit(unit) end
    end
    ns.RefreshTweaks()
    if ns.Refresh then ns.Refresh() end
    if ns.RefreshComboPoints then ns.RefreshComboPoints() end
end
