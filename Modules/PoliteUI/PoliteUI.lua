local _, VV = ...
local addon = VV.PoliteUI
local driver = CreateFrame("Frame")
local ready, elapsed, discoveryElapsed = false, 0, 0
local records, hidden, history, pulses = {}, {}, {}, {}
local evaluations, overrides = {}, {}
local EMPTY_RULE = {fadeOut={}, fadeIn={}}
local lastChat, cache, dirty = 0, {}, false
local FADE_TIME, EVENT_HOLD = 0.5, 3

-- Unknown or restricted data must never satisfy a condition, including a
-- negative condition such as "no debuffs" or "not casting".
local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
local function number(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end
local function truth(value)
    if value == true or value == 1 then return true end
    if value == false or value == 0 then return false end
end
local function invert(value)
    if value ~= nil then return not value end
end
local function exists(unit) return truth(read(UnitExists, unit)) end
local function casting()
    if not UnitCastingInfo or not UnitChannelInfo then return end
    local castOK, cast = pcall(UnitCastingInfo, "player")
    local channelOK, channel = pcall(UnitChannelInfo, "player")
    if not castOK or not channelOK or (issecretvalue and (issecretvalue(cast) or issecretvalue(channel))) then return end
    return cast ~= nil or channel ~= nil
end
local function typing()
    local known = false
    for index = 1, (NUM_CHAT_WINDOWS or 10) do
        local box = _G["ChatFrame" .. index .. "EditBox"]
        if box then
            local focused = truth(read(box.HasFocus, box))
            if focused then return true end
            if focused ~= nil then known = true end
        end
    end
    if known then return false end
end
local function resource(unit, kind)
    local key = unit .. "." .. kind
    if cache[key] then return unpack(cache[key]) end
    if exists(unit) ~= true then return end
    if kind == "mana" and read(UnitPowerType, unit) ~= 0 then return end
    local current, maximum
    if kind == "health" then
        -- An omitted optional argument is different from an explicit nil in
        -- the client's generated API bindings. HealthMax takes only the unit.
        current, maximum = read(UnitHealth, unit), read(UnitHealthMax, unit)
    else
        current, maximum = read(UnitPower, unit, 0), read(UnitPowerMax, unit, 0)
    end
    if not number(current) or not number(maximum) or maximum <= 0 then return end
    local guid = read(UnitGUID, unit)
    local previous, now = history[key], GetTime()
    local rising = previous and previous.guid == guid and previous.maximum == maximum and previous.rising or 0
    if previous and previous.guid == guid and previous.maximum == maximum then
        if current > previous.current then rising = now + EVENT_HOLD
        elseif current < previous.current then rising = 0 end
    end
    history[key] = {current=current, maximum=maximum, guid=guid, rising=rising}
    cache[key] = {current / maximum, rising > now}
    return unpack(cache[key])
end
local function auraCount(filter)
    local key = "auras." .. filter
    if cache[key] then return unpack(cache[key]) end
    local count, expiring = 0, false
    for index = 1, 40 do
        local aura, expiration
        if C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
            local ok, result = pcall(C_UnitAuras.GetAuraDataByIndex, "player", index, filter)
            if not ok or (issecretvalue and issecretvalue(result)) then return end
            if result == nil then break end
            if type(result) ~= "table" then return end
            aura = read(function() return result.name end)
            expiration = read(function() return result.expirationTime end)
            if type(aura) ~= "string" then return end
        else
            local fn = filter == "HELPFUL" and UnitBuff or UnitDebuff
            if not fn then return end
            local ok, name, _, _, _, _, _, ending = pcall(fn, "player", index)
            if not ok or (issecretvalue and issecretvalue(name)) then return end
            if name == nil then break end
            if type(name) ~= "string" then return end
            aura = name
            if not (issecretvalue and issecretvalue(ending)) then expiration = ending end
        end
        count = count + 1
        if number(expiration) and expiration > 0 and expiration - GetTime() <= 30 then expiring = true end
    end
    cache[key] = {count, expiring}
    return count, expiring
end
local function trackedQuests()
    if not C_QuestLog then return end
    local count = read(C_QuestLog.GetNumQuestWatches)
    if not number(count) then return end
    local complete = false
    for index = 1, count do
        local id = read(C_QuestLog.GetQuestIDForQuestWatchIndex, index)
        if number(id) and truth(read(C_QuestLog.IsComplete, id)) == true then complete = true end
    end
    return count, complete
end
local function groupState(spec, condition)
    local found = false
    for index = 1, spec.key == "raid" and 40 or 4 do
        local unit = (spec.key == "raid" and "raid" or "party") .. index
        local present = exists(unit)
        if present == nil then return end
        if present then
            found = true
            local connected = truth(read(UnitIsConnected, unit))
            local dead = truth(read(UnitIsDeadOrGhost, unit))
            if condition == "memberUnavailable" then
                if connected == false or dead == true then return true end
            elseif condition == "memberInjured" then
                -- One offline/dead member must not mask another member who
                -- can still be healed. Only the all-full predicates need
                -- every member to be available.
                if connected == true and dead == false then
                    local ratio = resource(unit, "health")
                    if ratio and ratio < 1 then return true end
                end
            elseif connected ~= true or dead ~= false then return false
            elseif condition == "groupManaFull" then
                local powerType = read(UnitPowerType, unit)
                if powerType == nil then return end
                if powerType == 0 then
                    local ratio = resource(unit, "mana")
                    if not ratio or ratio < 1 then return false end
                end
            else
                local ratio = resource(unit, "health")
                if not ratio then return end
                if condition == "groupHealthFull" and ratio < 1 then return false end
            end
        end
    end
    return found and (condition == "groupHealthFull" or condition == "groupManaFull")
end

addon.conditions = {}
addon.common, addon.returns = {}, {}
local function condition(id, label, test, list)
    addon.conditions[id] = {id=id, label=label, test=test}
    if list then list[#list + 1] = id end
end
condition("outCombat", "When not in combat", function() return invert(truth(read(UnitAffectingCombat, "player"))) end, addon.common)
condition("inCombat", "When in combat", function() return truth(read(UnitAffectingCombat, "player")) end, addon.common)
condition("noTarget", "When I have no target", function() return invert(exists("target")) end, addon.common)
condition("hasTarget", "When I target a character or NPC", function() return exists("target") end, addon.common)
condition("moving", "When I am moving", function() local v = read(GetUnitSpeed, "player"); if number(v) then return v > 0 end end, addon.common)
condition("stationary", "When I am standing still", function() local v = read(GetUnitSpeed, "player"); if number(v) then return v == 0 end end, addon.common)
condition("mounted", "When mounted", function() return truth(read(IsMounted)) end, addon.common)
condition("onFoot", "When not mounted", function() return invert(truth(read(IsMounted))) end, addon.common)
condition("resting", "When resting", function() return truth(read(IsResting)) end, addon.common)
condition("casting", "While casting or channeling", casting, addon.common)
condition("notCasting", "When not casting or channeling", function() return invert(casting()) end, addon.common)
condition("alive", "When alive", function() return invert(truth(read(UnitIsDeadOrGhost, "player"))) end, addon.common)
condition("dead", "When dead or a ghost", function() return truth(read(UnitIsDeadOrGhost, "player")) end, addon.common)
for _, item in ipairs({
    {"enterCombat", "When I enter combat"}, {"leaveCombat", "When I leave combat"},
    {"startCast", "When I start casting or channeling"}, {"newTarget", "When I select a new target"},
    {"escape", "When I press Escape"},
}) do
    local id = item[1]
    condition(id, item[2], function() return pulses[id] ~= nil and pulses[id] > GetTime() end, addon.returns)
end
for _, kind in ipairs({"health", "mana"}) do
    local key = kind
    condition(key .. "Full", "When " .. key .. " is full", function(spec)
        local ratio = resource(spec.unit or "player", key); if ratio then return ratio >= 1 end
    end)
    condition(key .. "Rising", "When " .. key .. " is near full (75%+ and increasing)", function(spec)
        local ratio, rising = resource(spec.unit or "player", key); if ratio then return ratio >= 0.75 and rising end
    end)
    condition(key .. "Low", "When " .. key .. " is below 75%", function(spec)
        local ratio = resource(spec.unit or "player", key); if ratio then return ratio < 0.75 end
    end)
end
condition("healthCritical", "When health is at or below 35%", function(spec)
    local ratio = resource(spec.unit or "player", "health"); if ratio then return ratio <= 0.35 end
end)
condition("unitDead", "When this unit is dead", function(spec) return truth(read(UnitIsDeadOrGhost, spec.unit)) end)
condition("friendly", "When this unit is friendly", function(spec) return truth(read(UnitCanAssist, "player", spec.unit)) end)
condition("hostile", "When this unit is attackable", function(spec) return truth(read(UnitCanAttack, "player", spec.unit)) end)
for _, item in ipairs({{"groupHealthFull", "When all members have full health"},
    {"groupManaFull", "When all mana users have full mana"}, {"memberInjured", "When a member needs healing"},
    {"memberUnavailable", "When a member is dead or disconnected"}}) do
    local id = item[1]
    condition(id, item[2], function(spec) return groupState(spec, id) end)
end
condition("noBuffs", "When I have no buffs", function() local n = auraCount("HELPFUL"); if n then return n == 0 end end)
condition("hasBuffs", "When I have buffs", function() local n = auraCount("HELPFUL"); if n then return n > 0 end end)
condition("buffExpiring", "When a buff has 30 seconds or less left", function() local _, expiring = auraCount("HELPFUL"); return expiring end)
condition("noDebuffs", "When I have no debuffs", function() local n = auraCount("HARMFUL"); if n then return n == 0 end end)
condition("hasDebuffs", "When I have a debuff", function() local n = auraCount("HARMFUL"); if n then return n > 0 end end)
condition("noQuests", "When no quests are tracked", function() local n = trackedQuests(); if n then return n == 0 end end)
condition("hasQuests", "When quests are tracked", function() local n = trackedQuests(); if n then return n > 0 end end)
condition("questComplete", "When a tracked quest is ready to turn in", function() local _, complete = trackedQuests(); return complete end)
condition("chatIdle", "When chat has been quiet for 30 seconds", function() return GetTime() - lastChat >= 30 end)
condition("chatRecent", "When a chat message arrived in the last 30 seconds", function() return GetTime() - lastChat < 30 end)
condition("typing", "When I am typing in chat", typing)
condition("notTyping", "When I am not typing in chat", function() return invert(typing()) end)
condition("indoors", "When indoors", function() return truth(read(IsIndoors)) end)
condition("outdoors", "When outdoors", function() return truth(read(IsOutdoors)) end)
condition("petExists", "When I have a pet", function() return exists("pet") end)
condition("noPet", "When I have no pet", function() return invert(exists("pet")) end)

-- Only persistent HUD pieces belong here. CharacterFrame, QuestLogFrame,
-- bags, bank, auction house, maps, and interaction windows are never touched.
local resources = {"healthFull", "manaFull", "healthRising", "manaRising", "healthLow", "manaLow", "healthCritical", "unitDead"}
addon.elements = {
    {key="player", label="Player frame", group="Unit frames", unit="player", names={"PlayerFrame"}, specific=resources},
    {key="target", label="Target frame", group="Unit frames", unit="target", names={"TargetFrame"}, specific={"healthFull", "healthLow", "healthCritical", "unitDead", "friendly", "hostile"}},
    {key="targetTarget", label="Target of target", group="Unit frames", unit="targettarget", names={"TargetFrameToT"}, specific={"healthFull", "healthLow", "unitDead"}},
    {key="pet", label="Pet frame", group="Unit frames", unit="pet", names={"PetFrame"}, specific=resources},
    {key="party", label="Party frames", group="Unit frames", names={"PartyFrame", "CompactPartyFrame"}, specific={"groupHealthFull", "groupManaFull", "memberInjured", "memberUnavailable"}},
    {key="raid", label="Raid frames", group="Unit frames", names={"CompactRaidFrameContainer"}, specific={"groupHealthFull", "groupManaFull", "memberInjured", "memberUnavailable"}},
    {key="buffs", label="Player buffs", group="Auras and casting", names={"BuffFrame"}, specific={"noBuffs", "hasBuffs", "buffExpiring"}},
    {key="debuffs", label="Player debuffs", group="Auras and casting", names={"DebuffFrame"}, specific={"noDebuffs", "hasDebuffs"}},
    {key="castBar", label="Player cast bar", group="Auras and casting", names={"PlayerCastingBarFrame", "CastingBarFrame"}, specific={"manaFull", "manaLow"}},
    {key="minimap", label="Minimap", group="Navigation and tracking", names={"MinimapCluster"}, specific={"indoors", "outdoors"}},
    {key="quests", label="Quest tracker", group="Navigation and tracking", names={"ObjectiveTrackerFrame"}, specific={"noQuests", "hasQuests", "questComplete"}},
    {key="statusBars", label="Experience / reputation bars", group="Navigation and tracking", names={"StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer"}, specific={}},
    {key="chat", label="Chat windows", group="Chat", names={}, specific={"chatIdle", "chatRecent", "typing", "notTyping"}},
    {key="mainBar", label="Main action bar", group="Action bars and menus", names={"MainActionBar"}, fallback="MainMenuBar", specific={}},
    {key="bottomLeft", label="Bottom left action bar", group="Action bars and menus", names={"MultiBarBottomLeft"}, specific={}},
    {key="bottomRight", label="Bottom right action bar", group="Action bars and menus", names={"MultiBarBottomRight"}, specific={}},
    {key="rightBar", label="Right action bar", group="Action bars and menus", names={"MultiBarRight"}, specific={}},
    {key="leftBar", label="Second right action bar", group="Action bars and menus", names={"MultiBarLeft"}, specific={}},
    {key="bar5", label="Action bar 5", group="Action bars and menus", names={"MultiBar5"}, specific={}},
    {key="bar6", label="Action bar 6", group="Action bars and menus", names={"MultiBar6"}, specific={}},
    {key="bar7", label="Action bar 7", group="Action bars and menus", names={"MultiBar7"}, specific={}},
    {key="petBar", label="Pet action bar", group="Action bars and menus", names={"PetActionBar"}, fallback="PetActionBarFrame", specific={"petExists", "noPet"}},
    {key="stanceBar", label="Stance / form bar", group="Action bars and menus", names={"StanceBar"}, fallback="StanceBarFrame", specific={}},
    {key="microMenu", label="Micro menu", group="Action bars and menus", names={"MicroMenuContainer"}, fallback="MicroButtonAndBagsBar", specific={}},
    {key="bags", label="Bag buttons", group="Action bars and menus", names={"BagsBar"}, specific={}},
}
addon.byKey = {}
for _, spec in ipairs(addon.elements) do
    addon.byKey[spec.key] = spec
    spec.allowed, spec.choices = {fadeOut={}, fadeIn={}}, {fadeOut={}, fadeIn={}}
    for _, side in ipairs({"fadeOut", "fadeIn"}) do
        for _, ids in ipairs({spec.specific, addon.common, side == "fadeIn" and addon.returns or {}}) do
            for _, id in ipairs(ids) do
                spec.allowed[side][id] = true
                spec.choices[side][#spec.choices[side] + 1] = addon.conditions[id]
            end
        end
    end
end

function addon.Choices(key, side)
    local spec = addon.byKey[key]
    return spec and spec.choices[side] or {}
end
local function allowed(key, side, id)
    local spec = addon.byKey[key]
    return spec and spec.allowed[side] and spec.allowed[side][id]
end
function addon.InitDB()
    if not VV.db then return end
    if type(VV.db.politeUI) ~= "table" then VV.db.politeUI = {} end
    local db = VV.db.politeUI
    if type(db.rules) ~= "table" then db.rules = {} end
    for key, rule in pairs(db.rules) do
        if not addon.byKey[key] or type(rule) ~= "table" then db.rules[key] = nil
        else
            for _, side in ipairs({"fadeOut", "fadeIn"}) do
                if type(rule[side]) ~= "table" then rule[side] = {} end
                for id, value in pairs(rule[side]) do
                    if value ~= true or not allowed(key, side, id) then rule[side][id] = nil end
                end
            end
            if not next(rule.fadeOut) and not next(rule.fadeIn) then db.rules[key] = nil end
        end
    end
    addon.db = db
end
function addon.GetRule(key)
    local db = VV.db and VV.db.politeUI
    return db and db.rules and db.rules[key] or EMPTY_RULE
end
function addon.Matches(key, side)
    local spec, selection = addon.byKey[key], addon.GetRule(key)[side]
    if not spec or type(selection) ~= "table" or not next(selection) then return false end
    local result = {matches=true, items={}}
    for id, selected in pairs(selection) do
        if selected ~= true or not allowed(key, side, id) then result.matches = false end
    end
    -- Evaluate every selected condition, in menu order. Short-circuiting an
    -- AND list starves recovery history whenever an earlier gate is false.
    for _, item in ipairs(addon.Choices(key, side)) do
        if selection[item.id] then
            local value = read(item.test, spec)
            local reason
            if value == nil then
                local powerType = item.id:find("^mana") and read(UnitPowerType, spec.unit or "player")
                reason = number(powerType) and powerType ~= 0 and "This unit does not use mana." or "Client data unavailable."
            end
            result.items[#result.items + 1] = {id=item.id, label=item.label, value=value, reason=reason}
            if value ~= true then result.matches = false end
        end
    end
    if #result.items == 0 then result.matches = false end
    evaluations[key] = evaluations[key] or {}
    evaluations[key][side] = result
    return result.matches
end

local function usable(frame)
    if not frame or type(frame.SetAlpha) ~= "function" then return false end
    return not frame.IsForbidden or read(frame.IsForbidden, frame) == false
end
local function write(record)
    if not usable(record.frame) then record.retry = true; record.error = "Frame is unavailable or forbidden."; return false end
    record.writing = true
    local desired = record.base * record.factor
    local ok, message = pcall(record.frame.SetAlpha, record.frame, desired)
    record.writing = false
    if ok then
        local actual = read(record.frame.GetAlpha, record.frame)
        if number(actual) and math.abs(actual - desired) > 0.001 then
            ok, message = false, "Another UI controller changed this frame's opacity."
        end
    end
    record.retry, record.error = not ok, not ok and tostring(message) or nil
    return ok
end
local function restore(record)
    record.factor, record.goal = 1, 1
    if write(record) then record.active = false end
end
local function own(frame, key)
    if not usable(frame) then return end
    local record = records[frame]
    if not record then
        local alpha = read(frame.GetAlpha, frame)
        if not number(alpha) or alpha < 0 or alpha > 1 then return end
        record = {frame=frame, key=key, base=alpha, factor=1, goal=1, active=false}
        records[frame] = record
        -- Preserve Blizzard's latest requested alpha, including cast animations.
        local ok = pcall(hooksecurefunc, frame, "SetAlpha", function(_, value)
            if record.writing or not number(value) then return end
            record.base = value
            if record.active and record.factor ~= 1 then write(record) end
        end)
        if not ok then records[frame] = nil; return end
    end
    record.key, record.active, record.seen = key, true, true
end
local function discover()
    for _, record in pairs(records) do record.seen = false end
    for _, spec in ipairs(addon.elements) do
        if next(addon.GetRule(spec.key).fadeOut) then
            for _, name in ipairs(spec.names) do own(_G[name], spec.key) end
            if spec.fallback and not _G[spec.names[1]] then own(_G[spec.fallback], spec.key) end
            if spec.key == "party" and not _G.PartyFrame then
                for i = 1, 4 do own(_G["PartyMemberFrame" .. i], spec.key) end
            elseif spec.key == "chat" then
                for i = 1, (NUM_CHAT_WINDOWS or 10) do
                    for _, suffix in ipairs({"", "Tab", "ButtonFrame", "EditBox"}) do own(_G["ChatFrame" .. i .. suffix], spec.key) end
                end
                own(_G.GeneralDockManager, spec.key)
            end
        end
    end
    -- Chat tabs and edit boxes may be children of their chat window. Apply the
    -- group factor only once, so halfway through a fade means 50%, not 25%.
    for frame, record in pairs(records) do
        if record.active and record.seen then
            local parent = read(frame.GetParent, frame)
            for _ = 1, 32 do
                if not parent then break end
                local ancestor = records[parent]
                if ancestor and ancestor.active and ancestor.seen and ancestor.key == record.key then
                    restore(record)
                    break
                end
                parent = read(parent.GetParent, parent)
            end
        end
    end
    for _, record in pairs(records) do if record.active and not record.seen then restore(record) end end
end
local function hovered(frame)
    if truth(read(frame.IsVisible, frame)) ~= true then return false end
    if MouseIsOver and truth(read(MouseIsOver, frame)) == true then return true end
    return truth(read(frame.IsMouseOver, frame)) == true
end
local function editing()
    if addon.optionsPanel and truth(read(addon.optionsPanel.IsVisible, addon.optionsPanel)) == true then return true end
    local manager = _G.EditModeManagerFrame
    if not manager then return false end
    if manager.IsEditModeActive then return truth(read(manager.IsEditModeActive, manager)) == true end
    return truth(read(manager.IsVisible, manager)) == true
end
local function evaluate()
    dirty = false
    cache, evaluations, overrides = {}, {}, {}
    local reveal = editing()
    for _, spec in ipairs(addon.elements) do
        local key = spec.key
        -- Sample both lists even when fade-in wins. A return state must not
        -- prevent the fade-out list from observing ongoing recovery.
        local fadeIn, fadeOut = addon.Matches(key, "fadeIn"), addon.Matches(key, "fadeOut")
        if not next(addon.GetRule(key).fadeOut) then hidden[key] = false
        elseif fadeIn then hidden[key] = false
        elseif fadeOut then hidden[key] = true end
    end
    local over = {}
    for _, record in pairs(records) do
        if record.active and hovered(record.frame) then over[record.key] = true end
    end
    -- Aura buttons can extend past their container's rectangle. Native mouse
    -- focus reveals the owning group without installing mouse-catching overlays.
    local foci = read(GetMouseFoci)
    if type(foci) == "table" then
        pcall(function()
            for _, focus in ipairs(foci) do
                if not (issecretvalue and issecretvalue(focus)) then
                    for _ = 1, 32 do
                        if not focus or not usable(focus) then break end
                        local record = records[focus]
                        if record and record.active and truth(read(focus.IsVisible, focus)) == true then over[record.key] = true; break end
                        focus = read(focus.GetParent, focus)
                    end
                end
            end
        end)
    end
    -- Typing keeps all chat chrome readable, even with a latched fade.
    if typing() then over.chat = true end
    for _, record in pairs(records) do
        if record.active then
            overrides[record.key] = reveal and "Settings / Edit Mode" or over[record.key] and "Hover / chat input" or nil
            record.goal = hidden[record.key] and not reveal and not over[record.key] and 0 or 1
        end
    end
end
local function enabled() return ready and VV.IsModuleEnabled("politeUI") end
local function activeRules()
    if not enabled() then return false end
    for key in pairs(VV.db.politeUI.rules) do if next(addon.GetRule(key).fadeOut) then return true end end
    return false
end
local function wake()
    local active = activeRules()
    if active then driver:Show(); discover(); evaluate()
    else
        for _, record in pairs(records) do if record.active then restore(record) end end
        local pending = false
        for _, record in pairs(records) do if record.active then pending = true end end
        driver:SetShown(pending)
    end
end
function addon.RefreshModule()
    addon.InitDB()
    hidden, history, pulses = {}, {}, {}
    wake()
    if addon.RefreshOptions then addon.RefreshOptions() end
end
-- Opening/closing a canvas changes only the reveal override. Keep resource
-- history, event grace, and latched rules intact throughout Settings changes.
function addon.RefreshVisibility() wake() end
function addon.SetCondition(key, side, id, selected)
    if not addon.byKey[key] or (side ~= "fadeOut" and side ~= "fadeIn") then return false end
    if id ~= nil and (not allowed(key, side, id) or type(selected) ~= "boolean") then return false end
    addon.InitDB()
    local rule = addon.db.rules[key] or {fadeOut={}, fadeIn={}}
    if id == nil then rule[side] = {} else rule[side][id] = selected and true or nil end
    addon.db.rules[key] = rule
    addon.InitDB()
    if side == "fadeOut" then hidden[key] = false end
    wake()
    if VV.RefreshOptions then VV.RefreshOptions() end
    return true
end
function addon.ResetSettings()
    addon.InitDB()
    for key in pairs(addon.db.rules) do addon.db.rules[key] = nil end
    addon.RefreshModule()
    if VV.RefreshOptions then VV.RefreshOptions() end
end
local opposites = {
    {"inCombat", "outCombat"}, {"hasTarget", "noTarget"}, {"moving", "stationary"},
    {"mounted", "onFoot"}, {"casting", "notCasting"}, {"alive", "dead"},
    {"healthFull", "healthLow"}, {"healthFull", "healthCritical"}, {"healthRising", "healthLow"},
    {"manaFull", "manaLow"}, {"manaRising", "manaLow"}, {"groupHealthFull", "memberInjured"},
    {"noBuffs", "hasBuffs"}, {"noBuffs", "buffExpiring"}, {"noDebuffs", "hasDebuffs"},
    {"noQuests", "hasQuests"}, {"noQuests", "questComplete"}, {"chatIdle", "chatRecent"},
    {"typing", "notTyping"}, {"indoors", "outdoors"}, {"petExists", "noPet"},
}
local function warning(key, side)
    local selected = addon.GetRule(key)[side]
    for _, pair in ipairs(opposites) do
        if selected[pair[1]] and selected[pair[2]] then
            return "Cannot match together: " .. addon.conditions[pair[1]].label .. " AND " .. addon.conditions[pair[2]].label
        end
    end
end
function addon.GetDiagnostics()
    evaluate()
    local result = {}
    for _, spec in ipairs(addon.elements) do
        local key, count, visible, error = spec.key, 0, false, nil
        for _, record in pairs(records) do
            if record.key == key and record.active then
                count = count + 1
                if truth(read(record.frame.IsVisible, record.frame)) == true then visible = true end
                error = error or record.error
            end
        end
        local checks = evaluations[key] or {}
        local status
        if not VV.IsModuleEnabled("politeUI") then status = "Module off"
        elseif not next(addon.GetRule(key).fadeOut) then status = "Never (no fade-out rules)"
        elseif error then status = "Opacity update pending"
        elseif count == 0 then status = "No supported frame found"
        elseif overrides[key] then status = "Revealed: " .. overrides[key]
        elseif not visible then status = "Hidden by the game"
        else status = hidden[key] and "Fading / faded out" or "Fade in / visible" end
        result[key] = {status=status, frames=count, error=error,
            fadeOut=checks.fadeOut or {matches=false, items={}}, fadeIn=checks.fadeIn or {matches=false, items={}},
            fadeOutWarning=warning(key, "fadeOut"), fadeInWarning=warning(key, "fadeIn")}
    end
    return result
end
local function debugStatus()
    local diagnostics, configured = addon.GetDiagnostics(), false
    for _, spec in ipairs(addon.elements) do
        local rule = addon.GetRule(spec.key)
        if next(rule.fadeOut) or next(rule.fadeIn) then
            configured = true
            local state = diagnostics[spec.key]
            VV.Print(spec.label .. ": " .. state.status .. "; " .. state.frames .. " frame(s).")
            for _, side in ipairs({"fadeOut", "fadeIn"}) do
                local labels = {}
                for _, item in ipairs(state[side].items) do
                    labels[#labels + 1] = (item.value == true and "Match: " or item.value == false and "Waiting: " or "Unavailable: ") .. item.label
                        .. (item.reason and " (" .. item.reason .. ")" or "")
                end
                VV.Print((side == "fadeOut" and "Fade out: " or "Fade in: ") .. (#labels > 0 and table.concat(labels, " AND ") or "Never"))
                if state[side .. "Warning"] then VV.Print(state[side .. "Warning"]) end
            end
            if state.error then VV.Print(state.error) end
        end
    end
    if not configured then VV.Print("Polite UI: all elements are set to Never.") end
end
function addon.HandleSlash(message)
    if (message or ""):lower() == "reset" then addon.ResetSettings(); return end
    if (message or ""):lower() == "debug" or (message or ""):lower() == "status" then debugStatus(); return end
    VV.Print("/vv polite opens Polite UI. /vv polite on | off | toggle controls fading; /vv polite reset clears its rules.")
    VV.Print("/vv polite debug explains current conditions and frame status.")
end

driver:Hide()
-- This unprotected listener observes Escape without swallowing native keys.
-- Propagation is configured once; it is never changed during combat.
if driver.EnableKeyboard and driver.SetPropagateKeyboardInput then
    driver:EnableKeyboard(true)
    driver:SetPropagateKeyboardInput(true)
    driver:SetScript("OnKeyDown", function(_, key)
        if key == "ESCAPE" and enabled() then
            pulses.escape = GetTime() + EVENT_HOLD
            evaluate()
        end
    end)
end
local chatEvents = {"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SYSTEM", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE"}
local events = {"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "ADDON_LOADED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
    "PLAYER_TARGET_CHANGED", "GROUP_ROSTER_UPDATE", "UNIT_PET", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE",
    "UNIT_MAXPOWER", "UNIT_AURA", "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_STOP",
    "UNIT_SPELLCAST_CHANNEL_STOP", "QUEST_WATCH_LIST_CHANGED", "QUEST_LOG_UPDATE", "EDIT_MODE_LAYOUTS_UPDATED"}
for _, event in ipairs(events) do driver:RegisterEvent(event) end
for _, event in ipairs(chatEvents) do driver:RegisterEvent(event) end
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        if not VV.db then VV.InitDB() end
        addon.InitDB()
        ready, lastChat = true, GetTime()
        addon.RegisterOptions()
        wake()
        return
    end
    if not ready then return end
    if event:find("^CHAT_MSG_") then lastChat = GetTime() end
    if not activeRules() then return end
    local pulse = ({PLAYER_REGEN_DISABLED="enterCombat", PLAYER_REGEN_ENABLED="leaveCombat"})[event]
    if event == "PLAYER_TARGET_CHANGED" then
        history["target.health"], history["target.mana"] = nil, nil
        history["targettarget.health"], history["targettarget.mana"] = nil, nil
        if exists("target") then pulse = "newTarget" end
    elseif (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START")
        and not (issecretvalue and issecretvalue(unit)) and unit == "player" then pulse = "startCast" end
    if pulse then pulses[pulse] = GetTime() + EVENT_HOLD end
    -- Discover after startup and periodically as Blizzard's load-on-demand UI
    -- and chat windows appear. Native Show/Hide behavior remains in control.
    if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then discover() end
    dirty = true
    if pulse then evaluate() end
end)
driver:SetScript("OnUpdate", function(_, delta)
    if not activeRules() then
        elapsed = elapsed + delta
        if elapsed >= 0.1 then elapsed = 0; wake() end
        return
    end
    elapsed, discoveryElapsed = elapsed + delta, discoveryElapsed + delta
    if discoveryElapsed >= 1 then discoveryElapsed = 0; discover() end
    local poll = dirty or elapsed >= 0.1
    if poll then elapsed = 0; evaluate() end
    for _, record in pairs(records) do
        if record.active then
            if record.factor ~= record.goal then
                local step = delta / FADE_TIME
                if record.factor < record.goal then record.factor = math.min(record.goal, record.factor + step)
                else record.factor = math.max(record.goal, record.factor - step) end
                write(record)
            elseif poll then
                -- Failed protected writes and native updates may arrive after
                -- an animation has finished. Retry instead of getting stuck.
                local actual = read(record.frame.GetAlpha, record.frame)
                if record.retry or number(actual) and math.abs(actual - record.base * record.factor) > 0.001 then write(record) end
            end
        end
    end
end)
addon.driver = driver
