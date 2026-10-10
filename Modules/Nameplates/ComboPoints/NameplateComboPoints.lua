local ADDON, VV = ...
local ns = VV.Nameplates
local combo = {}
ns.ComboPoints = combo
combo.defaults = { size = 12, x = 0, y = 0, gap = 4 }
combo.limits = { size = {4, 40}, x = {-300, 300}, y = {-100, 200}, gap = {0, 30} }
local driver = CreateFrame("Frame")
local rows = setmetatable({}, { __mode = "k" })
local current, elapsed = nil, 0

local function Read(func, ...)
    if not func then return end
    local ok, value = pcall(func, ...)
    if ok then return ns.Known(value) end
end

local function UsesComboPoints()
    if not UnitClass then return false end
    local ok, _, class = pcall(UnitClass, "player")
    class = ok and ns.Known(class)
    if class == "ROGUE" then return true end
    if class == "DRUID" then
        return Read(UnitPowerType, "player") == (Enum and Enum.PowerType and Enum.PowerType.Energy or 3)
    end
    return false
end

function combo.InitDB()
    if not ns.tweaksDB then ns.InitializeTweaks() end
    if type(ns.tweaksDB.comboPoints) ~= "table" then ns.tweaksDB.comboPoints = {} end
    combo.db = ns.tweaksDB.comboPoints
    for key, limits in pairs(combo.limits) do
        combo.db[key] = ns.Number(combo.db[key], limits[1], limits[2]) or combo.defaults[key]
    end
end

function combo.SetValue(key, value)
    local limits = combo.limits[key]
    if not limits then return false end
    value = ns.Number(value, limits[1], limits[2])
    if not value then return false end
    combo.db[key] = value
    ns.Changed()
    return true
end

function combo.ResetSettings()
    ns.tweaksDB.comboPoints = {}
    combo.InitDB()
    ns.Changed()
end

function combo.CreateRow(parent)
    local row = CreateFrame("Frame", nil, parent)
    row:EnableMouse(false)
    row.dots = {}
    for index = 1, 5 do
        local dot = CreateFrame("Frame", nil, row)
        dot:EnableMouse(false)
        dot.layers = {}
        -- Static empty/filled layers from Forever's personal-resource display:
        -- Blizzard_UnitFrame/Mainline/RogueComboPoint.xml. Keep native colors
        -- and atlas proportions; no generated dot artwork or recoloring.
        for _, spec in ipairs({
            {"uf-roguecp-bg-shadow", "BACKGROUND", -4, "shadow"},
            {"uf-roguecp-bg", "BACKGROUND", 0, "active"},
            {"uf-roguecp-icon-red", "ARTWORK", 0, "icon"},
            {"uf-roguecp-bg-dis", "BACKGROUND", 0, "inactive"},
        }) do
            local texture = dot:CreateTexture(nil, spec[2])
            texture:SetAtlas(spec[1], true)
            local info = Read(C_Texture and C_Texture.GetAtlasInfo, spec[1])
            texture.nativeWidth = info and ns.Number(info.width, 1, 200) or 20
            texture.nativeHeight = info and ns.Number(info.height, 1, 200) or 20
            texture.offsetY = spec[3]
            dot.layers[#dot.layers + 1] = texture
            dot[spec[4]] = texture
        end
        row.dots[index] = dot
    end
    row:Hide()
    return row
end

function combo.LayoutRow(row, anchor, count, castBar)
    local db = combo.db
    local width = 5 * db.size + 4 * db.gap
    row:SetSize(width, db.size)
    row:ClearAllPoints()
    -- Positive Y moves down, matching swing timer controls. At zero, half of
    -- each dot overlaps the bottom edge of the visible health bar.
    row:SetPoint("CENTER", anchor, "BOTTOM", db.x, -db.y)
    -- Blizzard's cast bar uses frame level 100, independently of health.
    -- Dots overlap both bars, so their artwork must draw above either one.
    local healthLevel = ns.Number(Read(anchor.GetFrameLevel, anchor), 0, 10000) or 0
    local castLevel = castBar and ns.Number(Read(castBar.GetFrameLevel, castBar), 0, 10000) or 0
    local level = math.max(healthLevel, castLevel) + 10
    row:SetFrameLevel(level)
    for index, dot in ipairs(row.dots) do
        dot:SetFrameLevel(level + 1)
        dot:SetSize(db.size, db.size)
        dot:ClearAllPoints()
        dot:SetPoint("LEFT", row, "LEFT", (index - 1) * (db.size + db.gap), 0)
        for _, texture in ipairs(dot.layers) do
            texture:SetSize(texture.nativeWidth * db.size / 20, texture.nativeHeight * db.size / 20)
            texture:ClearAllPoints()
            texture:SetPoint("CENTER", dot, "CENTER", 0, texture.offsetY * db.size / 20)
        end
        local filled = count ~= nil and index <= count
        dot.active:SetShown(filled)
        dot.icon:SetShown(filled)
        dot.inactive:SetShown(not filled)
        dot:Show()
    end
    -- Zero points is a visible empty row; nil means the feature is disabled.
    row:SetShown(count ~= nil)
end

function combo.HealthAnchor(frame, fallback)
    local container = frame and frame.HealthBarsContainer
    return container and (container.healthBar or container) or frame and frame.healthBar or fallback
end

function combo.CastBar(frame)
    local container = frame and frame.CastBarsContainer
    return container and container.castBar or frame and frame.castBar
end

function combo.Refresh()
    if current then current:Hide(); current = nil end
    if not combo.db or not VV.IsModuleEnabled("nameplates") or not ns.tweaksDB.comboPointsEnabled then return end
    if not UsesComboPoints() then return end
    -- Forever points belong to the hard target. Never attach its count to a
    -- soft target, or retain a count when the API result is unavailable.
    if Read(UnitExists, "target") ~= true then return end
    local count = ns.Number(Read(GetComboPoints, "player", "target"), 0, 5)
    if not count or count ~= math.floor(count) then return end
    local plate = Read(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "target")
    if not plate or Read(plate.IsForbidden, plate) ~= false or Read(plate.IsShown, plate) ~= true then return end
    local frame = plate.UnitFrame
    if frame and Read(frame.IsForbidden, frame) ~= false then return end
    local anchor = combo.HealthAnchor(frame, plate)
    if Read(anchor.IsForbidden, anchor) ~= false or Read(anchor.IsShown, anchor) ~= true then return end
    local row = rows[plate]
    if not row then row = combo.CreateRow(plate); rows[plate] = row end
    row.unitToken = Read(plate.GetUnit, plate)
    combo.LayoutRow(row, anchor, count, combo.CastBar(frame))
    current = row
end

ns.RefreshComboPoints = combo.Refresh
driver:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= ADDON then return end
        combo.InitDB()
        driver:UnregisterEvent("ADDON_LOADED")
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local removed = ns.Known(unit)
        for _, row in pairs(rows) do
            if removed and row.unitToken == removed then row:Hide() end
        end
        return
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_DISPLAYPOWER" then
        unit = ns.Known(unit)
        if unit and unit ~= "player" then return end
    end
    combo.Refresh()
end)
driver:SetScript("OnUpdate", function(_, delta)
    if not combo.db or not VV.IsModuleEnabled("nameplates") or not ns.tweaksDB.comboPointsEnabled then return end
    elapsed = elapsed + delta
    if elapsed >= 0.1 then elapsed = 0; combo.Refresh() end
end)
driver:RegisterEvent("ADDON_LOADED")
for _, event in ipairs({"PLAYER_LOGIN", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED",
    "COMBO_TARGET_CHANGED", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_DISPLAYPOWER", "UPDATE_SHAPESHIFT_FORM",
    "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "PLAYER_DEAD", "CVAR_UPDATE"}) do
    pcall(driver.RegisterEvent, driver, event)
end
