local ADDON, VV = ...
local ns = VV.Nameplates
local driver = CreateFrame("Frame")
local stacks = setmetatable({}, { __mode = "k" })
local timers, available, speeds = {}, {}, {}
local current, previewStack, previewPlate
local pollElapsed = 0
local swingTypes = Enum and Enum.PlayerSwingType
local typeToKey = {}
if swingTypes then
    typeToKey[swingTypes.MainHand] = "main"
    typeToKey[swingTypes.OffHand] = "offhand"
    typeToKey[swingTypes.Ranged] = "ranged"
end

local function SafeCall(func, ...)
    if not func then return nil end
    local ok, value = pcall(func, ...)
    if ok then return ns.Known(value) end
end

local function ReadWeapons()
    local ok, main, offhand, ranged = pcall(UnitAttackSpeed, "player")
    if not ok then return end
    local values = { ns.Known(main), ns.Known(offhand), ns.Known(ranged) }
    for index, key in ipairs(ns.order) do
        -- Retain the last known availability when a value is secret; don't
        -- interpret protected data as an unequipped weapon.
        local raw = select(index, main, offhand, ranged)
        if not (issecretvalue and issecretvalue(raw)) then
            local speed = ns.Number(values[index], 0.001, 120)
            available[key], speeds[key] = speed ~= nil, speed
            if not available[key] then timers[key] = nil end
        end
    end
end

local function HasNameplate(frame)
    return frame and not frame:IsForbidden() and frame:IsShown()
end

local function GetTargetPlate()
    if SafeCall(UnitExists, "target") then
        -- Never switch to a different soft target just because a hard target's
        -- nameplate is offscreen or disabled.
        return SafeCall(C_NamePlate.GetNamePlateForUnit, "target"), "target"
    end
    local enabled = C_CVar and SafeCall(C_CVar.GetCVar, "SoftTargetEnemy")
    if tonumber(enabled or "0") > 0 and SafeCall(UnitExists, "softenemy") then
        return SafeCall(C_NamePlate.GetNamePlateForUnit, "softenemy"), "softenemy"
    end
end

local function AnchorFor(plate)
    local unitFrame = plate.UnitFrame
    if unitFrame and not unitFrame:IsForbidden() then
        -- Use the visible health-bar frame, rather than the invisible clickable
        -- nameplate rectangle, whose padding varies with client settings.
        local health = unitFrame.HealthBarsContainer or unitFrame.healthBar
        if health and not health:IsForbidden() then return health end
        return unitFrame
    end
    return plate
end

local function MakePreview()
    if previewStack then return end
    previewPlate = CreateFrame("Frame", nil, UIParent)
    previewPlate:SetSize(140, 16)
    previewPlate:SetPoint("CENTER", UIParent, "CENTER", 0, 110)
    previewPlate:EnableMouse(false)
    local background = previewPlate:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints()
    background:SetColorTexture(0.25, 0.3, 0.36, 0.8)
    local label = previewPlate:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    label:SetPoint("BOTTOM", previewPlate, "TOP", 0, 5)
    label:SetText("VanillaVarnish preview: main / off hand / ranged")
    previewStack = ns.CreateStack(previewPlate)
    previewPlate:Hide()
end

local function Progress(key, now)
    if ns.preview then
        local periods = { main = 2.6, offhand = 1.8, ranged = 3.2 }
        return (now / periods[key]) % 1
    end
    local timer = timers[key]
    if not timer then return 0 end
    return math.min(1, math.max(0, (now - timer.start) / timer.duration))
end

local function Expire(now)
    local changed = false
    for key, timer in pairs(timers) do
        if now >= timer.finish then timers[key], changed = nil, true end
    end
    return changed
end

function ns.Refresh()
    if not ns.db then return end
    if not VV.IsModuleEnabled("nameplates") or VV.swingConflict or (ns.tweaksDB and not ns.tweaksDB.swingsEnabled) then
        if current then current:Hide() end
        if previewPlate then previewPlate:Hide() end
        ns.anchorUnit = nil
        return
    end
    local plate, unit = GetTargetPlate()
    local stack, anchor
    if HasNameplate(plate) then
        stack = stacks[plate]
        if not stack then stack = ns.CreateStack(plate); stacks[plate] = stack end
        stack.unitToken = SafeCall(plate.GetUnit, plate)
        anchor = AnchorFor(plate)
        ns.anchorUnit = unit
    elseif ns.preview then
        MakePreview()
        stack, anchor = previewStack, previewPlate
        ns.anchorUnit = "preview"
    else
        ns.anchorUnit = nil
    end
    if current and current ~= stack then current:Hide() end
    if previewPlate then previewPlate:SetShown(stack == previewStack and ns.preview) end
    current = stack
    if not stack then return end
    local now = GetTime()
    Expire(now)
    local inCombat = SafeCall(UnitAffectingCombat, "player") == true
    local visible = ns.preview or ns.db.visibility ~= "combat" or inCombat
    local shown = {}
    for _, key in ipairs(ns.order) do
        shown[key] = visible and ns.db.bars[key].enabled and (ns.preview or available[key])
            and (ns.preview or ns.db.visibility ~= "swing" or timers[key] ~= nil)
    end
    ns.LayoutStack(stack, shown, anchor, plate and ns.CastClearance(plate.UnitFrame, anchor, stack) or 0)
    ns.RenderStack(stack, now, Progress)
end

local function ClearTimers()
    for key in pairs(timers) do timers[key] = nil end
end

local function OnUpdate(_, elapsed)
    if not VV.IsModuleEnabled("nameplates") or VV.swingConflict or not ns.tweaksDB.swingsEnabled then return end
    pollElapsed = pollElapsed + elapsed
    local now = GetTime()
    local expired = Expire(now)
    -- A short poll also handles CVar changes, cast/nameplate layout changes,
    -- and Blizzard recycling nameplates without a target-change notification.
    if expired or pollElapsed >= 0.1 then
        pollElapsed = 0
        ns.Refresh()
    elseif current and current:IsShown() then
        ns.RenderStack(current, now, Progress)
    end
end

local function OnEvent(_, event, ...)
    if event == "ADDON_LOADED" then
        if ... ~= ADDON then return end
        ns.InitDB()
        ns.styleVersion = 1
        ns.RegisterOptions()
        driver:UnregisterEvent("ADDON_LOADED")
        return
    end
    if not ns.db then return end
    if event == "PLAYER_LOGIN" then driver:SetScript("OnUpdate", OnUpdate) end
    if not VV.IsModuleEnabled("nameplates") or VV.swingConflict then return end
    if event == "PLAYER_LOGIN" then
        ReadWeapons()
        if not swingTypes or not C_SwingTimer then
            ns.Print("This build lacks Forever's native swing API. Preview and settings are available.")
        end
        driver:SetScript("OnUpdate", OnUpdate)
    elseif event == "PLAYER_SWING" then
        local duration, swingType = ...
        swingType = ns.Known(swingType)
        duration = ns.Number(duration, 0.001, 120)
        local key = swingType and typeToKey[swingType]
        if key and duration then
            local now = GetTime()
            timers[key] = { start = now, duration = duration, finish = now + duration }
            -- A native swing is also positive evidence of an equipped weapon.
            available[key] = true
        end
    elseif event == "UNIT_ATTACK_SPEED" then
        if ns.Known(...) ~= "player" then return end
        ReadWeapons()
    elseif event == "WEAPON_SLOT_CHANGED" then
        ReadWeapons()
        -- Match the native timer: swapping weapons restarts existing cooldowns.
        local now = GetTime()
        for key, timer in pairs(timers) do
            if speeds[key] then
                timer.start, timer.duration, timer.finish = now, speeds[key], now + speeds[key]
            end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        ClearTimers()
        ReadWeapons()
    elseif event == "PLAYER_DEAD" then
        ClearTimers()
        ns.preview = false
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        -- Hide immediately before Blizzard reuses the frame for another unit.
        local removedUnit = ns.Known(...)
        for _, stack in pairs(stacks) do
            if removedUnit and stack.unitToken == removedUnit then stack:Hide() end
        end
        return -- the next poll resolves the current target after removal finishes
    end
    ns.Refresh()
end

driver:SetScript("OnEvent", OnEvent)
driver:RegisterEvent("ADDON_LOADED")
for _, event in ipairs({ "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "PLAYER_SOFT_ENEMY_CHANGED", "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED",
    "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED", "PLAYER_IN_COMBAT_CHANGED",
    "UNIT_ATTACK_SPEED", "WEAPON_SLOT_CHANGED", "PLAYER_DEAD",
    "PLAYER_SWING", "CVAR_UPDATE" }) do
    -- The beta may change its optional events between builds.
    pcall(driver.RegisterEvent, driver, event)
end

ns.RefreshSwingWeapons = ReadWeapons
