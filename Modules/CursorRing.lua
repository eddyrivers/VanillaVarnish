local _, VV = ...
local ring = {}
VV.CursorRing = ring

local defaults = {enabled = false, radius = 22, stroke = 3, r = 1, g = 1, b = 1}
local limits = {radius = {16, 64}, stroke = {1, 10}}
local art = "Interface\\AddOns\\VanillaVarnish\\Textures\\Cursor"
local frame, outline, outlineHole, stroke, strokeHole
local lastX, lastY

function ring.Normalize(db)
    db.enabled = db.enabled == true
    for _, key in ipairs({"radius", "stroke", "r", "g", "b"}) do
        local low, high = 0, 1
        if limits[key] then low, high = unpack(limits[key]) end
        local value = db[key]
        if type(value) ~= "number" or value ~= value or value < low or value > high then
            value = defaults[key]
        end
        db[key] = limits[key] and math.floor(value + 0.5) or value
    end
end

local function Position()
    local visible = not (IsMouselooking and IsMouselooking())
    outline:SetShown(visible)
    stroke:SetShown(visible)
    if not visible then return end
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale()
    x, y = x / scale, y / scale
    if x == lastX and y == lastY then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
    lastX, lastY = x, y
end

local function MakeLayer(layer)
    local disk = frame:CreateTexture(nil, layer)
    disk:SetTexture(art .. "Disk.tga")
    disk:SetPoint("CENTER")
    local hole = frame:CreateMaskTexture()
    hole:SetTexture(art .. "Hole.tga", "CLAMPTOWHITE", "CLAMPTOWHITE")
    hole:SetPoint("CENTER")
    disk:AddMaskTexture(hole)
    return disk, hole
end

local function Diameter(texture, radius)
    -- The artwork has two transparent padding pixels around a 124px circle.
    local size = 2 * radius * 128 / 124
    texture:SetSize(size, size)
end

function ring.Refresh()
    local db = VV.db.cursorRing
    if not db.enabled then
        if frame then frame:Hide() end
        return
    end
    if not frame then
        frame = CreateFrame("Frame", nil, UIParent)
        frame:SetFrameStrata("TOOLTIP")
        frame:SetSize(1, 1)
        frame:EnableMouse(false)
        outline, outlineHole = MakeLayer("ARTWORK")
        outline:SetVertexColor(0, 0, 0)
        stroke, strokeHole = MakeLayer("OVERLAY")
        frame:SetScript("OnUpdate", Position)
    end
    local radius, inner = db.radius, db.radius - db.stroke
    Diameter(outline, radius + 1.5)
    Diameter(outlineHole, inner - 1.5)
    Diameter(stroke, radius)
    Diameter(strokeHole, inner)
    stroke:SetVertexColor(db.r, db.g, db.b)
    Position()
    frame:Show()
end

function ring.AddOptions(panel, controls)
    local UI = VV.Nameplates.UI
    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -90)
    content:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -90)
    content:SetHeight(200)

    local function Set(key, value)
        VV.db.cursorRing[key] = value
        ring.Refresh()
        VV.RefreshOptions()
    end

    controls["cursorRing.enabled"] = UI.Check(content, "cursorRing.enabled", "Show cursor ring", 0,
        function() return VV.db.cursorRing.enabled end, function(value) Set("enabled", value) end,
        "Draw a steady ring around the cursor, including during combat.")
    for index, spec in ipairs({{"radius", "Radius"}, {"stroke", "Stroke width"}}) do
        local key = spec[1]
        local low, high = unpack(limits[key])
        controls["cursorRing." .. key] = UI.Slider(content, "cursorRing." .. key, spec[2], -44 * index,
            low, high, 1, false, function() return VV.db.cursorRing[key] end,
            function(value) Set(key, value) end, spec[2] .. " in UI units.")
    end

    local color = UI.Button(content, "Ring color", 136, function()
        if not ColorPickerFrame and C_AddOns then C_AddOns.LoadAddOn("Blizzard_ColorPicker") end
        local picker = ColorPickerFrame
        if not picker then VV.Print("The client color picker is unavailable."); return end
        local db = VV.db.cursorRing
        local r, g, b = db.r, db.g, db.b
        local function Apply(red, green, blue)
            db.r, db.g, db.b = red, green, blue
            ring.Refresh()
            VV.RefreshOptions()
        end
        if picker:IsShown() then picker:Hide() end
        picker:SetupColorPickerAndShow({r = r, g = g, b = b, hasOpacity = false,
            swatchFunc = function() Apply(picker:GetColorRGB()) end,
            cancelFunc = function() Apply(r, g, b) end})
    end)
    color:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -140)
    local chip = content:CreateTexture(nil, "ARTWORK")
    chip:SetSize(20, 20)
    chip:SetPoint("LEFT", color, "RIGHT", 8, 0)
    controls["cursorRing.color"] = {Refresh = function()
        local db = VV.db.cursorRing
        chip:SetColorTexture(db.r, db.g, db.b)
    end}

    local reset = UI.Button(content, "Restore defaults", 144, function()
        for key, value in pairs(defaults) do
            if key ~= "enabled" then VV.db.cursorRing[key] = value end
        end
        ring.Refresh()
        VV.RefreshOptions()
    end)
    reset:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -184)
end
