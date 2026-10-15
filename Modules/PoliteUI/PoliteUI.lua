local _, VV = ...
local addon = VV.PoliteUI
local resourceRules = {
    healthFull={kind="health", test=function(x) return x >= 1 end},
    healthLow={kind="health", test=function(x) return x < 0.75 end},
    healthCritical={kind="health", test=function(x) return x <= 0.35 end},
    manaFull={kind="mana", test=function(x) return x >= 1 end},
    manaLow={kind="mana", test=function(x) return x < 0.75 end},
}
local resourcePlans = {}

function addon.NativeResourceKind(id)
    return resourceRules[id] and resourceRules[id].kind
end

local function combineWithRange(bar, a, b, base)
    bar:SetMinMaxValues(0, base + 1)
    bar:SetValue(b)
    bar:SetMinMaxValues(a, base + 1)
end
local function combineWithValue(bar, a, b, base)
    bar:SetMinMaxValues(a, base + 1)
    bar:SetValue(b)
end
local function nativeCombiner()
    local bar = CreateFrame("StatusBar")
    bar:Hide()
    -- Fading requires every resource to match. Each native curve returns
    -- visible alpha when its resource fails, so combine those alphas with
    -- max(a, b). Native bar clamping can do this without revealing either
    -- value: range [a, base + 1], value b. The extra 1 avoids an empty range.
    -- Validate which setter/getter combination actually clamps on this client.
    -- Verify the client's actual clamping behavior using PUBLIC values only,
    -- before putting any restricted values into this private display object.
    for _, apply in ipairs({combineWithRange, combineWithValue}) do
        for _, name in ipairs({"GetValue", "GetInterpolatedValue"}) do
            local getter, valid = bar[name], true
            if type(getter) == "function" then
                for _, base in ipairs({1, 0.65, 0, 1}) do
                    for _, previousA in ipairs({0, base}) do
                        for _, previousB in ipairs({0, base}) do
                            for _, a in ipairs({0, base}) do
                                for _, b in ipairs({0, base}) do
                                    apply(bar, previousA, previousB, base)
                                    apply(bar, a, b, base)
                                    local value = getter(bar)
                                    if (issecretvalue and issecretvalue(value)) or type(value) ~= "number" or value ~= value
                                        or math.abs(value - math.max(a, b)) > 0.000001 then valid = false end
                                end
                            end
                        end
                    end
                end
                if valid then return {bar=bar, getter=getter, apply=apply} end
            end
        end
    end
    return nil, "This client's native bars cannot combine restricted health and mana."
end

function addon.NativeResourcePlan(unit, ids)
    if not C_CurveUtil or not C_CurveUtil.CreateCurve or not Enum
        or not Enum.LuaCurveType or not Enum.LuaCurveType.Step then
        return nil, "Native resource display API unavailable."
    end
    local key = unit .. ":" .. table.concat(ids, ",")
    local plan = resourcePlans[key]
    if not plan then
        plan = {unit=unit, axes={}}
        for _, kind in ipairs({"health", "mana"}) do
            local axis = {kind=kind, ids={}, curves={}}
            for _, id in ipairs(ids) do
                if addon.NativeResourceKind(id) == kind then axis.ids[#axis.ids + 1] = id end
            end
            if #axis.ids > 0 then plan.axes[#plan.axes + 1] = axis end
        end
        if #plan.axes > 1 then
            local ok, combiner, reason = pcall(nativeCombiner)
            plan.combiner = ok and combiner or nil
            plan.combineError = ok and reason or "Native resource combination API unavailable."
        end
        resourcePlans[key] = plan
    end
    -- APIs may temporarily disappear while client UI modules are loading.
    for _, axis in ipairs(plan.axes) do
        if (axis.kind == "health" and not UnitHealthPercent) or (axis.kind == "mana" and not UnitPowerPercent) then
            return nil, "Native resource display API unavailable."
        end
    end
    if #plan.axes > 1 and not plan.combiner then return nil, plan.combineError end
    return plan
end

-- Restricted percentages never enter Lua comparisons, arithmetic, logging,
-- or condition state. A native curve evaluates the rule and the resulting
-- opaque alpha is passed to native display setters only. With two resources,
-- the private status bar combines opaque alphas and its getter stays opaque.
function addon.NativeResourceOpacity(plan, base)
    local ok, value = pcall(function()
        local alphas = {}
        for index, axis in ipairs(plan.axes) do
            local curve = axis.curves[base]
            if not curve then
                curve = C_CurveUtil.CreateCurve()
                curve:SetType(Enum.LuaCurveType.Step)
                for _, x in ipairs({0, 0.3500001, 0.75, 1}) do
                    local matches = true
                    for _, id in ipairs(axis.ids) do if not resourceRules[id].test(x) then matches = false end end
                    curve:AddPoint(x, matches and 0 or base)
                end
                axis.curves[base] = curve
            end
            if axis.kind == "health" then alphas[index] = UnitHealthPercent(plan.unit, false, curve)
            else alphas[index] = UnitPowerPercent(plan.unit, Enum.PowerType and Enum.PowerType.Mana or 0, false, curve) end
        end
        if plan.combiner then
            plan.combiner.apply(plan.combiner.bar, alphas[1], alphas[2], base)
            return plan.combiner.getter(plan.combiner.bar)
        end
        return alphas[1]
    end)
    if not ok then return false, "Native resource opacity is unavailable: " .. tostring(value) end
    if issecretvalue and issecretvalue(value) then return true, value end
    if type(value) == "number" and value >= 0 and value <= 1 then return true, value end
    return false, "Native resource opacity returned no usable value."
end

local driver = CreateFrame("Frame")
local ready, elapsed, discoveryElapsed = false, 0, 0
local records, hidden, history = {}, {}, {}
local evaluations, overrides = {}, {}
local resourceInfo, nativePlans = {}, {}
local EMPTY_RULE = {fadeOut={}}
local lastChat, cache, dirty = 0, {}, false
local FADE_TIME, RECOVERY_HOLD = 0.5, 3

-- Unknown or restricted data must never satisfy a condition, including a
-- negative condition such as "no debuffs" or "not casting".
local function read(fn, ...)
    if type(fn) ~= "function" then return end
    local ok, value = pcall(fn, ...)
    if ok and not (issecretvalue and issecretvalue(value)) then return value end
end
local function number(value)
    if issecretvalue and issecretvalue(value) then return false end
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
    local info = {unit=unit, kind=kind}
    resourceInfo[key] = info
    local function sample(fn, ...)
        if not fn then info.reason = "Resource API unavailable."; return end
        local ok, value = pcall(fn, ...)
        if not ok then info.reason = "Resource API failed: " .. tostring(value); return end
        if issecretvalue and issecretvalue(value) then info.native = true; return end
        return value
    end
    local current, maximum
    if kind == "health" then
        -- An omitted optional argument is different from an explicit nil in
        -- the client's generated API bindings. HealthMax takes only the unit.
        current, maximum = sample(UnitHealth, unit), sample(UnitHealthMax, unit)
    else
        local mana = Enum and Enum.PowerType and Enum.PowerType.Mana or 0
        current, maximum = sample(UnitPower, unit, mana), sample(UnitPowerMax, unit, mana)
        -- A druid still has mana while rage/energy is the active resource.
        -- Query the mana pool explicitly rather than gating on UnitPowerType.
        if number(maximum) and maximum <= 0 then
            info.native, info.reason = false, "This unit has no mana pool."
            return
        end
    end
    if not number(current) or not number(maximum) or maximum <= 0 then return end
    local guid = read(UnitGUID, unit)
    local previous, now = history[key], GetTime()
    local rising = previous and previous.guid == guid and previous.maximum == maximum and previous.rising or 0
    if previous and previous.guid == guid and previous.maximum == maximum then
        if current > previous.current then rising = now + RECOVERY_HOLD
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
                local maximum = read(UnitPowerMax, unit, Enum and Enum.PowerType and Enum.PowerType.Mana or 0)
                if not number(maximum) then return end
                if maximum > 0 then
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
addon.common = {}
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
    spec.allowed, spec.choices = {fadeOut={}}, {fadeOut={}}
    for _, side in ipairs({"fadeOut"}) do
        for _, ids in ipairs({spec.specific, addon.common}) do
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
            rule.fadeIn = nil -- Older beta profiles used separate return lists.
            for _, side in ipairs({"fadeOut"}) do
                if type(rule[side]) ~= "table" then rule[side] = {} end
                for id, value in pairs(rule[side]) do
                    if value ~= true or not allowed(key, side, id) then rule[side][id] = nil end
                end
            end
            if not next(rule.fadeOut) then db.rules[key] = nil end
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
    local result = {matches=true, ready=true, items={}, nativeIDs={}}
    for id, selected in pairs(selection) do
        if selected ~= true or not allowed(key, side, id) then result.matches, result.ready = false, false end
    end
    -- Evaluate every selected condition, in menu order. Short-circuiting an
    -- AND list starves recovery history whenever an earlier gate is false.
    for _, item in ipairs(addon.Choices(key, side)) do
        if selection[item.id] then
            local value = read(item.test, spec)
            local reason, native
            if value == nil then
                local kind = item.id:find("^health") and "health" or item.id:find("^mana") and "mana"
                local info = kind and resourceInfo[(spec.unit or "player") .. "." .. kind]
                reason = info and info.reason or "Client data unavailable."
                if info and info.native and not info.reason and addon.NativeResourceKind and addon.NativeResourceKind(item.id) then
                    native = true
                    reason = "Evaluated by the client's native resource display."
                    result.nativeIDs[#result.nativeIDs + 1] = item.id
                elseif info and info.native then reason = "Recovery history is unavailable for restricted resources." end
            end
            result.items[#result.items + 1] = {id=item.id, label=item.label, value=value, reason=reason, native=native}
            if value ~= true then result.matches = false end
            if value ~= true and not native then result.ready = false end
        end
    end
    if #result.items == 0 then result.matches, result.ready = false, false end
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
    local desired
    if record.nativePlan then
        local ok, value = addon.NativeResourceOpacity(record.nativePlan, record.base)
        if not ok then
            -- A native API becoming unavailable must not strand a previously
            -- faded frame at an opaque alpha that Lua cannot inspect.
            pcall(record.frame.SetAlpha, record.frame, record.base)
            record.writing = false
            record.retry, record.error = true, value
            return false
        end
        desired = value
    else desired = record.base * record.factor end
    local ok, message = pcall(record.frame.SetAlpha, record.frame, desired)
    if not ok and record.nativePlan then pcall(record.frame.SetAlpha, record.frame, record.base) end
    record.writing = false
    if ok then
        local actual = read(record.frame.GetAlpha, record.frame)
        if not record.nativePlan and number(actual) and math.abs(actual - desired) > 0.001 then
            ok, message = false, "Another UI controller changed this frame's opacity."
        end
    end
    record.retry, record.error = not ok, not ok and tostring(message) or nil
    return ok
end
local function restore(record)
    record.factor, record.goal, record.nativePlan = 1, 1, nil
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
            if record.active and (record.factor ~= 1 or record.nativePlan) then write(record) end
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
    cache, evaluations, overrides, resourceInfo, nativePlans = {}, {}, {}, {}, {}
    local reveal = editing()
    for _, spec in ipairs(addon.elements) do
        local key = spec.key
        hidden[key] = addon.Matches(key, "fadeOut")
        local result = evaluations[key] and evaluations[key].fadeOut
        if result and result.ready and #result.nativeIDs > 0 and addon.NativeResourcePlan then
            local plan, reason = addon.NativeResourcePlan(spec.unit or "player", result.nativeIDs)
            nativePlans[key] = plan
            if not nativePlans[key] then
                for _, item in ipairs(result.items) do
                    if item.native then item.native, item.reason = false, reason end
                end
            end
        end
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
    -- Typing keeps all chat chrome readable regardless of fade conditions.
    if typing() then over.chat = true end
    for _, record in pairs(records) do
        if record.active then
            overrides[record.key] = reveal and "Settings / Edit Mode" or over[record.key] and "Hover / chat input" or nil
            record.goal = hidden[record.key] and not reveal and not over[record.key] and 0 or 1
            local plan = not reveal and not over[record.key] and nativePlans[record.key] or nil
            local changed = record.nativePlan ~= plan
            record.nativePlan = plan
            if plan or changed then
                record.factor = plan and 1 or record.goal
                write(record) -- Native opaque alpha cannot be interpolated in Lua.
            end
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
    hidden, history = {}, {}
    wake()
    if addon.RefreshOptions then addon.RefreshOptions() end
end
-- Opening/closing a canvas changes only the reveal override and keeps history.
function addon.RefreshVisibility() wake() end
function addon.SetCondition(key, side, id, selected, menuResponse)
    if not addon.byKey[key] or side ~= "fadeOut" then return false end
    if id ~= nil and (not allowed(key, side, id) or type(selected) ~= "boolean") then return false end
    addon.InitDB()
    local rule = addon.db.rules[key] or {fadeOut={}}
    if id == nil then rule[side] = {} else rule[side][id] = selected and true or nil end
    addon.db.rules[key] = rule
    addon.InitDB()
    if side == "fadeOut" then hidden[key] = false end
    wake()
    -- Native checkbox responses update selection text and checked states.
    -- Rebuilding an open menu inside its responder reinitializes its layout
    -- while the old menu is still handling the click (including scroll order).
    if menuResponse then
        if VV.RefreshProfileStatus then VV.RefreshProfileStatus() end
    elseif VV.RefreshOptions then VV.RefreshOptions() end
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
        elseif nativePlans[key] then status = "Native resource-driven visibility"
        else status = hidden[key] and "Fading / faded out" or "Visible (fade conditions not met)" end
        result[key] = {status=status, frames=count, error=error,
            fadeOut=checks.fadeOut or {matches=false, items={}}, fadeOutWarning=warning(key, "fadeOut")}
    end
    return result
end
local function debugStatus()
    local diagnostics, configured = addon.GetDiagnostics(), false
    for _, spec in ipairs(addon.elements) do
        local rule = addon.GetRule(spec.key)
        if next(rule.fadeOut) then
            configured = true
            local state = diagnostics[spec.key]
            VV.Print(spec.label .. ": " .. state.status .. "; " .. state.frames .. " frame(s).")
            for _, side in ipairs({"fadeOut"}) do
                local labels = {}
                for _, item in ipairs(state[side].items) do
                    labels[#labels + 1] = (item.native and "Native: " or item.value == true and "Match: " or item.value == false and "Waiting: " or "Unavailable: ") .. item.label
                        .. (item.reason and " (" .. item.reason .. ")" or "")
                end
                VV.Print("Fade out: " .. (#labels > 0 and table.concat(labels, " AND ") or "Never"))
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
    if event == "PLAYER_TARGET_CHANGED" then
        history["target.health"], history["target.mana"] = nil, nil
        history["targettarget.health"], history["targettarget.mana"] = nil, nil
    end
    -- Discover after startup and periodically as Blizzard's load-on-demand UI
    -- and chat windows appear. Native Show/Hide behavior remains in control.
    if event == "ADDON_LOADED" or event == "PLAYER_ENTERING_WORLD" or event == "GROUP_ROSTER_UPDATE" then discover() end
    dirty = true
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
                if record.retry or (not record.nativePlan and number(actual) and math.abs(actual - record.base * record.factor) > 0.001) then write(record) end
            end
        end
    end
end)
addon.driver = driver
