local _, VV = ...
local ns = VV.Nameplates
local cast = {}
ns.PlayerCastBar = cast
cast.defaults = {x=20, y=90, width=200}
cast.limits = {x={-300, 300}, y={-100, 300}, width={30, 400}}
local states, current = {}, nil
local ready, elapsed = false, 0

local function read(fn, ...)
    if not fn then return end
    local ok, value = pcall(fn, ...)
    if ok then return ns.Known(value) end
end

function cast.InitDB()
    if not ns.tweaksDB then ns.InitializeTweaks() end
    if type(ns.tweaksDB.playerCastBar) ~= "table" then ns.tweaksDB.playerCastBar = {} end
    cast.db = ns.tweaksDB.playerCastBar
    for key, default in pairs(cast.defaults) do
        local limits = cast.limits[key]
        cast.db[key] = ns.Number(cast.db[key], limits[1], limits[2]) or default
    end
end

local function create(parent)
    if not NamePlateCastingBarMixin or not NamePlateSetupOptions then return end
    local holder = CreateFrame("Frame", nil, parent)
    holder:EnableMouse(false)
    holder:SetFrameLevel(parent:GetFrameLevel() + 8)
    -- Use the client's cast engine, artwork, channels, delays, interruptions,
    -- and completion effects. Only the unit source and placement are ours.
    local ok, bar = pcall(CreateFrame, "StatusBar", nil, holder, "NamePlateCastingBarTemplate")
    if not ok or not bar.SetUnit then holder:Hide(); return end
    holder.bar = bar
    bar:EnableMouse(false)
    bar:SetNameTextShown(true)
    bar:SetIconShown(true)
    bar:SetTargetNameTextShown(false)
    bar:SetHighlightImportantCasts(false)
    bar:SetHighlightWhenCastTarget(false)
    bar:Hide()
    return holder
end

local function layout(holder, anchor)
    local source = NamePlateSetupOptions
    if not source then return false end
    local changed = holder.anchor ~= anchor or holder.x ~= cast.db.x or holder.y ~= cast.db.y or holder.width ~= cast.db.width
    for key, value in pairs(source) do
        if not holder.options or holder.options[key] ~= value then changed = true; break end
    end
    if not changed then return true end
    local options = VV.Copy(source)
    local height = ns.Number(options.castBarHeight, 1, 200)
    if not height then return false end
    local horizontal = ns.Number(options.horizontalScale, 0.01, 10) or 1
    local inset = options.useClassicCastBar and 24.25 * horizontal or 0
    local width = cast.db.width + inset
    local nativeWidth = read(C_NamePlate and C_NamePlate.GetNamePlateSize)
    nativeWidth = ns.Number(nativeWidth, 30, 2000)
    local nativeInset = ns.Number(options.insetWidth, 0, 200) or 0
    if nativeWidth and nativeWidth > nativeInset * 2 and options.useClassicCastBar then
        options.castBarBorderWidth = options.castBarBorderWidth * width / (nativeWidth - nativeInset * 2)
    end
    local iconHeight = ns.Number(options.castIconHeight, 1, 200) or height
    holder:SetSize(width, height + (options.spellNameInsideCastBar and 0 or iconHeight))
    holder:ClearAllPoints()
    holder:SetPoint("TOP", anchor, "BOTTOM", cast.db.x, -cast.db.y)
    local bar = holder.bar
    bar:SetHeight(height)
    bar:ApplyStyleAndAnchoring(options)
    bar.Spark:SetHeight(height + 8)
    bar.Text:SetTextHeight(options.castBarFontHeight)
    bar.CastTargetNameText:SetTextHeight(options.castBarFontHeight)
    bar:UpdateBarFillTexture(false)
    holder.anchor, holder.x, holder.y, holder.width = anchor, cast.db.x, cast.db.y, cast.db.width
    holder.options = VV.Copy(source)
    return true
end

local function detach(holder)
    if not holder then return end
    holder.bar:SetUnit(nil)
    holder:Hide()
end

local function targetPlate()
    local hasTarget = read(UnitExists, "target")
    if hasTarget == true then
        return read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "target")
    end
    if hasTarget ~= false then return end
    local soft = read(C_CVar and C_CVar.GetCVar or GetCVar, "SoftTargetEnemy")
    if tonumber(soft or "0") and tonumber(soft or "0") > 0 and read(UnitExists, "softenemy") == true then
        return read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "softenemy")
    end
end

function ns.RefreshPlayerCastBar()
    if not ready or not cast.db then return end
    local plate = VV.IsModuleEnabled("nameplates") and ns.tweaksDB.playerCastBarEnabled and targetPlate()
    if not plate or read(plate.IsForbidden, plate) ~= false or read(plate.IsShown, plate) ~= true then
        detach(current); current = nil; return
    end
    local frame = plate.UnitFrame
    local anchor = frame and (frame.HealthBarsContainer or frame.healthBar) or plate
    if read(anchor.IsForbidden, anchor) ~= false or read(anchor.IsShown, anchor) ~= true then
        detach(current); current = nil; return
    end
    local holder = states[plate]
    if not holder then holder = create(plate); states[plate] = holder end
    if current ~= holder then detach(current); current = holder end
    if not holder or not layout(holder, anchor) then detach(current); current = nil; return end
    holder:Show()
    -- Bind only to player. The target keeps its own native cast bar untouched.
    holder.bar:SetUnit("player", true, false)
end

function cast.SetValue(key, value)
    local limits = cast.limits[key]
    value = limits and ns.Number(value, limits[1], limits[2])
    if not value then return false end
    cast.db[key] = value
    ns.RefreshPlayerCastBar()
    if cast.RefreshOptions then cast.RefreshOptions() end
    return true
end

function cast.Reset()
    for key, value in pairs(cast.defaults) do cast.db[key] = value end
    ns.RefreshPlayerCastBar()
    if cast.RefreshOptions then cast.RefreshOptions() end
end

function cast.HandleSlash(message)
    local key, value = (message or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    if key == "" or key == "options" then cast.OpenOptions(); return end
    if key == "on" or key == "off" or key == "toggle" then
        ns.SetFeature("playerCastBarEnabled", key == "on" or key == "toggle" and not ns.tweaksDB.playerCastBarEnabled)
    elseif key == "reset" then cast.Reset()
    elseif cast.limits[key] and cast.SetValue(key, tonumber(value)) then return
    elseif key ~= "status" then
        ns.Print("/vv nameplates cast on | off | toggle; cast x <offset>, y <offset>, width <30-400>, or reset.")
    end
    ns.Print("Player cast bar: " .. (ns.tweaksDB.playerCastBarEnabled and "on" or "off")
        .. "; target nameplate when visible; height follows the game's nameplate style.")
end

local driver = CreateFrame("Frame")
for _, event in ipairs({"ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "CVAR_UPDATE", "PLAYER_SOFT_ENEMY_CHANGED"}) do
    driver:RegisterEvent(event)
end
driver:SetScript("OnEvent", function(_, event, addon)
    if event == "ADDON_LOADED" and addon == "VanillaVarnish" then cast.InitDB() end
    if event == "PLAYER_LOGIN" then cast.InitDB(); ready = true end
    if event == "CVAR_UPDATE" then
        -- Blizzard recalculates its shared setup options on this event first.
        C_Timer.After(0, ns.RefreshPlayerCastBar)
    else ns.RefreshPlayerCastBar() end
end)
driver:SetScript("OnUpdate", function(_, delta)
    if not ready or not ns.tweaksDB.playerCastBarEnabled or not VV.IsModuleEnabled("nameplates") then return end
    elapsed = elapsed + delta
    if elapsed < 0.1 then return end
    elapsed = 0
    ns.RefreshPlayerCastBar()
end)

-- Settings preview uses the same native template without a unit binding.
function cast.CreatePreview(parent) return create(parent) end
function cast.LayoutPreview(holder, anchor) return holder and layout(holder, anchor) end
