local _, VV = ...
local ns = VV.Nameplates
local active = {}
local bars = setmetatable({}, { __mode = "k" })
local BLUE = { 0.25, 0.65, 1 }

local function Known(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

local function Read(fn, ...)
    if type(fn) ~= "function" then return nil end
    local ok, value = pcall(fn, ...)
    if ok then return Known(value) end
end

local function Enabled()
    return VV.IsModuleEnabled("nameplates") and ns.tweaksDB and ns.tweaksDB.threatColorsEnabled
end

local function IsTank()
    if PlayerUtil and type(PlayerUtil.IsPlayerEffectivelyTank) == "function" then
        local tank = Read(PlayerUtil.IsPlayerEffectivelyTank)
        if type(tank) == "boolean" then return tank end
    end
    local aura = Read(UnitHasEffectivelyTankAura, "player")
    local role = Read(UnitGroupRolesAssigned, "player")
    if aura == true or role == "TANK" then return true end
    if (aura == false or type(UnitHasEffectivelyTankAura) ~= "function")
        and (role == "DAMAGER" or role == "HEALER" or role == "NONE") then return false end
end

local function HasAggro(unit)
    -- The detailed API exposes whether the player is actually tanking; its
    -- percentages are deliberately ignored, including restricted values.
    if type(UnitDetailedThreatSituation) == "function" then
        local tanking = Read(UnitDetailedThreatSituation, "player", unit)
        if type(tanking) == "boolean" then return tanking end
    end
    if type(UnitThreatSituation) ~= "function" then return end
    local ok, status = pcall(UnitThreatSituation, "player", unit)
    if not ok or (issecretvalue and issecretvalue(status)) then return end
    -- A successful nil result means no threat entry on this fighting NPC.
    if status == nil then return false end
    if type(status) == "number" and status >= 0 and status <= 3 then return status >= 2 end
end

local function SetColor(state, color)
    state.settingColor = true
    local ok = pcall(state.bar.SetStatusBarColor, state.bar, unpack(color))
    state.settingColor = false
    return ok
end

local function Restore(state)
    if state.tinted then
        if SetColor(state, state.original) then state.tinted = nil end
    end
end

local function Update(state)
    local unit = state.unit
    if not Enabled() or not unit
        or Read(UnitCanAttack, "player", unit) ~= true
        or Read(UnitIsPlayer, unit) ~= false
        or Read(UnitAffectingCombat, unit) ~= true
        or Read(UnitIsDeadOrGhost, unit) ~= false
        or Read(UnitIsTapDenied, unit) ~= false then
        Restore(state); return
    end
    local tank, aggro = IsTank(), HasAggro(unit)
    if type(tank) ~= "boolean" or type(aggro) ~= "boolean" or tank ~= aggro then
        Restore(state); return
    end
    if not state.original then
        local ok, r, g, b, a = pcall(state.bar.GetStatusBarColor, state.bar)
        if not ok then return end
        -- Preserve display channels without inspecting or comparing them.
        state.original = { r, g, b, a }
    end
    if SetColor(state, { BLUE[1], BLUE[2], BLUE[3], state.original[4] }) then state.tinted = true end
end

local function Remove(unit)
    local state = active[unit]
    if not state then return end
    state.unit = nil
    Restore(state)
    active[unit] = nil
end

local function Add(unit)
    if not Enabled() then return end
    local plate = Read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, unit)
    local frame = plate and plate.UnitFrame
    if not frame or Read(frame.IsForbidden, frame) ~= false then Remove(unit); return end
    local container = frame.HealthBarsContainer
    local bar = container and container.healthBar or frame.healthBar
    if not bar or Read(bar.IsForbidden, bar) ~= false
        or type(bar.SetStatusBarColor) ~= "function" or type(bar.GetStatusBarColor) ~= "function" then
        Remove(unit); return
    end
    local state = bars[bar]
    if active[unit] and active[unit] ~= state then Remove(unit) end
    if not state then
        state = { bar = bar }
        bars[bar] = state
        hooksecurefunc(bar, "SetStatusBarColor", function(_, ...)
            if state.settingColor then return end
            state.original = { ... }
            state.tinted = nil -- This native write has already replaced VV's tint.
            if state.unit then Update(state) end
        end)
    end
    if state.unit and state.unit ~= unit then Remove(state.unit) end
    state.unit, active[unit] = unit, state
    Update(state)
end

function ns.RefreshThreatColors()
    if Enabled() then
        for index = 1, 80 do
            local unit = "nameplate" .. index
            if Read(UnitExists, unit) == true then Add(unit) else Remove(unit) end
        end
    else
        for unit in pairs(active) do Remove(unit) end
    end
end

local driver = CreateFrame("Frame")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "NAME_PLATE_UNIT_ADDED",
    "NAME_PLATE_UNIT_REMOVED", "UNIT_THREAT_SITUATION_UPDATE", "UNIT_THREAT_LIST_UPDATE",
    "PLAYER_ROLES_ASSIGNED", "UPDATE_SHAPESHIFT_FORM", "PLAYER_REGEN_ENABLED", "UNIT_FLAGS", "UNIT_FACTION"}) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(_, event, unit)
    unit = Known(unit)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        if type(unit) == "string" then Remove(unit) end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if type(unit) == "string" then Add(unit) end
    elseif type(unit) == "string" and active[unit] then
        Add(unit)
    else
        ns.RefreshThreatColors()
    end
end)
