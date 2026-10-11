local _, VV = ...
local ns = VV.Nameplates
local title = "Swing timers"
local controls = {}
local updating = false
local panel, viewport, previewStack, previewAnchor, status
local labels = { main = "Main hand", offhand = "Off hand", ranged = "Ranged" }
local visibility = {{"combat", "In combat"}, {"always", "Always"}, {"swing", "While swinging"}}
local effects = {{"off", "None"}, {"pulse", "Pulse"}}

local function Label(parent, text, x, y, font)
    local label = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlight")
    label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    label:SetJustifyH("LEFT")
    label:SetText(text)
    return label
end

local function Tooltip(frame, name, text)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(name)
        GameTooltip:AddLine(text, 0.85, 0.85, 0.85, true)
        GameTooltip:Show()
    end)
    frame:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

local function Button(parent, text, width, callback)
    local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 24)
    button:SetText(text)
    button:SetScript("OnClick", callback)
    return button
end

local function AddControl(id, control)
    controls[id] = control
    return control
end

local function Check(parent, id, text, y, get, set, tip)
    local check = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    check:SetSize(24, 24)
    check:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, y)
    local label = Label(parent, text, 28, y - 5)
    check:SetScript("OnClick", function(self) if not updating then set(not not self:GetChecked()) end end)
    Tooltip(check, text, tip)
    return AddControl(id, { button = check, label = label,
        Refresh = function() check:SetChecked(get()) end })
end

local function Dropdown(parent, id, text, y, choices, get, set, tip)
    Label(parent, text, 0, y - 5)
    local dropdown = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    dropdown:SetSize(220, 24)
    dropdown:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, y)
    dropdown:SetupMenu(function(_, root)
        for _, choice in ipairs(choices) do
            local value, name = choice[1], choice[2]
            root:CreateRadio(name, function() return get() == value end, function() set(value) end)
        end
    end)
    Tooltip(dropdown, text, tip)
    return AddControl(id, { dropdown = dropdown, Refresh = function()
        dropdown:GenerateMenu()
    end })
end

local function Slider(parent, id, text, y, low, high, step, percent, get, set, tip)
    Label(parent, text, 0, y - 5)
    local slider = CreateFrame("Slider", nil, parent)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(20)
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, y)
    slider:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -88, y)
    slider:SetMinMaxValues(low, high)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)
    local track = slider:CreateTexture(nil, "BACKGROUND")
    track:SetColorTexture(0.28, 0.3, 0.35, 1)
    track:SetHeight(4)
    track:SetPoint("LEFT"); track:SetPoint("RIGHT")
    slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
    slider:GetThumbTexture():SetSize(14, 20)
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(62, 24)
    box:SetPoint("TOPRIGHT", parent, "TOPRIGHT", percent and -18 or -4, y)
    box:SetAutoFocus(false)
    box:SetMaxLetters(9)
    box:SetJustifyH("CENTER")
    if percent then
        local suffix = Label(parent, "%", 0, y - 5)
        suffix:ClearAllPoints(); suffix:SetPoint("LEFT", box, "RIGHT", 3, 0)
    end
    local function Round(value) return math.floor(value / step + 0.5) * step end
    local function Display(value)
        if not box:HasFocus() then box:SetText(string.format("%g", percent and value * 100 or value)) end
    end
    slider:SetScript("OnValueChanged", function(_, value)
        if updating then return end
        value = math.max(low, math.min(high, Round(value)))
        Display(value)
        set(value)
    end)
    local function Commit()
        local value = tonumber(box:GetText())
        if value then
            if percent then value = value / 100 end
            if value >= low and value <= high then set(Round(value)) end
        end
        box.suppressCommit = true
        box:ClearFocus()
        box.suppressCommit = false
        ns.RefreshOptions()
    end
    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEscapePressed", function()
        box.suppressCommit = true; box:ClearFocus(); box.suppressCommit = false; ns.RefreshOptions()
    end)
    box:SetScript("OnEditFocusLost", function() if not updating and not box.suppressCommit then Commit() end end)
    Tooltip(slider, text, tip)
    Tooltip(box, text, tip .. " Type a value and press Enter to apply it.")
    return AddControl(id, { slider = slider, box = box, Refresh = function()
        slider:SetValue(get()); Display(get())
    end })
end

local pickerSession
local function ReadPicker()
    local picker = ColorPickerFrame
    local hex = (picker.Content and picker.Content.HexBox) or picker.HexBox
    if hex then
        local name, r, g, b = ns.ParseColor(hex:GetText())
        if name and name ~= "transparent" then return r, g, b end
    end
    return picker:GetColorRGB()
end

local function Hex(r, g, b)
    return string.format("#%02X%02X%02X", math.floor(r * 255 + 0.5),
        math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function Picker(get, set, getAlpha)
    if not ColorPickerFrame and C_AddOns then C_AddOns.LoadAddOn("Blizzard_ColorPicker") end
    local picker = ColorPickerFrame
    if not picker then ns.Print("The client color picker is unavailable."); return end
    if picker:IsShown() then picker:Hide() end
    if not picker.nstHooked then
        picker:HookScript("OnHide", function()
            local session = pickerSession
            pickerSession = nil
            if session and not session.cancelled then session.apply(ReadPicker()) end
        end)
        picker.nstHooked = true
    end
    local original, originalAlpha = get(), getAlpha and getAlpha()
    local _, r, g, b = ns.ParseColor(original)
    local session = { cancelled = false }
    function session.apply(red, green, blue)
        set(Hex(red, green, blue), original == "transparent" and 1 or originalAlpha)
    end
    pickerSession = session
    picker:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false,
        swatchFunc = function() session.apply(picker:GetColorRGB()) end,
        cancelFunc = function()
            session.cancelled = true
            pickerSession = nil
            set(original, originalAlpha)
        end,
    })
end

local function Color(parent, id, text, y, get, set, getAlpha)
    Label(parent, text, 0, y - 5)
    local swatch = Button(parent, "", 44, function() Picker(get, set, getAlpha) end)
    swatch:SetPoint("TOPLEFT", parent, "TOPLEFT", 200, y)
    local chip = swatch:CreateTexture(nil, "OVERLAY")
    chip:SetPoint("TOPLEFT", 5, -5); chip:SetPoint("BOTTOMRIGHT", -5, 5)
    chip:SetTexture("Interface\\Buttons\\WHITE8x8")
    local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
    box:SetSize(80, 24)
    box:SetPoint("LEFT", swatch, "RIGHT", 12, 0)
    box:SetAutoFocus(false); box:SetMaxLetters(24)
    local palette = CreateFrame("DropdownButton", nil, parent, "WowStyle1DropdownTemplate")
    palette:SetSize(150, 24)
    palette:SetPoint("LEFT", box, "RIGHT", 12, 0)
    palette:SetDefaultText("Color presets")
    palette:SetupMenu(function(_, root)
        local names = {}
        for name in pairs(ns.colors) do names[#names + 1] = name end
        table.sort(names)
        -- Small submenus avoid an enormous menu that runs off the screen.
        for _, range in ipairs({{"A - G", "a", "g"}, {"H - P", "h", "p"}, {"R - Y", "r", "z"}}) do
            local submenu = root:CreateButton(range[1])
            for _, name in ipairs(names) do
                local first = name:sub(1, 1)
                if first >= range[2] and first <= range[3] then
                    local color = name
                    submenu:CreateRadio(name, function() return get() == color end,
                        function() set(color, get() == "transparent" and 1 or getAlpha and getAlpha()) end)
                end
            end
        end
        root:CreateRadio("Transparent", function() return get() == "transparent" end,
            function() set("transparent", 0) end)
    end)
    local function Commit()
        local name = ns.ParseColor(box:GetText())
        if name then set(name, name == "transparent" and 0 or get() == "transparent" and 1 or getAlpha and getAlpha()) end
        box:ClearFocus()
        ns.RefreshOptions()
    end
    box:SetScript("OnEnterPressed", Commit)
    box:SetScript("OnEscapePressed", function() box:ClearFocus(); ns.RefreshOptions() end)
    Tooltip(swatch, text, "Choose a color. Cancel returns to your previous color.")
    Tooltip(box, text, "Enter a color name or #RRGGBB, or choose a preset.")
    return AddControl(id, { swatch = swatch, box = box, palette = palette, Refresh = function()
        local name, r, g, b = ns.ParseColor(get())
        chip:SetVertexColor(r, g, b, name == "transparent" and 0 or 1)
        if not box:HasFocus() then box:SetText(name == "transparent" and "transparent" or Hex(r, g, b)) end
        palette:GenerateMenu()
    end })
end

local function DrawPreview()
    if not previewStack then return end
    ns.DrawMenuFeaturePreview(previewAnchor)
end

function ns.RefreshOptions()
    if ns.RefreshFeatureOptions then ns.RefreshFeatureOptions() end
    if ns.RefreshComboOptions then ns.RefreshComboOptions() end
    if not viewport then return end
    updating = true
    for _, control in pairs(controls) do control.Refresh() end
    updating = false
    status:SetText("Changes save as you go.")
    previewAnchor.nextLayout = nil
    DrawPreview()
end

local function BuildPanel()
    Label(panel, title, 16, -16, "GameFontNormalLarge")
    local intro = Label(panel, "Follow your weapon swings on your target's nameplate.", 16, -42, "GameFontHighlightSmall")
    intro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -42)
    viewport = CreateFrame("Frame", nil, panel)
    viewport:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -64)
    viewport:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -64)
    viewport:SetHeight(210)
    viewport:SetClipsChildren(true)
    local bg = viewport:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.025, 0.03, 0.04, 0.9)
    Label(viewport, "Live preview", 12, -10, "GameFontNormal")
    Label(viewport, "Shows your enabled swing timers and combo points.", 12, -30, "GameFontDisableSmall")
    previewAnchor = ns.CreateMenuFeaturePreview(viewport)
    previewAnchor:SetPoint("CENTER", viewport, "CENTER", 0, 20)
    previewStack = previewAnchor.swingStack
    ns.optionsPreview = previewStack
    ns.optionsPreviewNameplate = previewAnchor
    viewport:SetScript("OnUpdate", DrawPreview)
    panel:SetScript("OnHide", function()
        ns.StopMenuFeaturePreview(previewAnchor)
    end)
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", viewport, "BOTTOMLEFT", 0, -16)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 64)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(540, 1400)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(self, width) content:SetWidth(math.max(510, width)) end)
    local y = -4
    local function Section(text)
        Label(content, text, 0, y, "GameFontNormalLarge"); y = y - 32
    end
    local function GlobalSlider(key, text, step, percent, tip)
        local limits = ns.limits[key]
        Slider(content, key, text, y, limits[1], limits[2], step, percent,
            function() return ns.db[key] end, function(value) ns.SetValue(key, value) end, tip)
        y = y - 40
    end
    Section("Visibility and layout")
    Dropdown(content, "visibility", "Show bars", y, visibility, function() return ns.db.visibility end,
        function(value) ns.SetValue("visibility", value) end,
        "Show timers all the time, only in combat, or only while a swing is in progress.")
    y = y - 40
    Check(content, "preview", "Show a test preview in game", y, function() return ns.preview end,
        function(value) ns.preview = value; ns.Changed() end,
        "Show sample swings on your target, or near the center of your screen. Turn off to return to live timers.")
    y = y - 38
    local enable = Button(content, "Enable all bars", 132, function() ns.Slash("all on") end)
    enable:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
    local disable = Button(content, "Disable all bars", 132, function() ns.Slash("all off") end)
    disable:SetPoint("LEFT", enable, "RIGHT", 10, 0)
    AddControl("enableAll", { button = enable, Refresh = function() end })
    AddControl("disableAll", { button = disable, Refresh = function() end })
    y = y - 40
    GlobalSlider("width", "Bar width", 1, false, "Set the width of all swing bars.")
    GlobalSlider("height", "Bar height", 1, false, "Set the height of all swing bars.")
    GlobalSlider("x", "Horizontal offset", 1, false, "Positive moves right; negative moves left.")
    GlobalSlider("y", "Vertical offset", 1, false, "Move bars down with positive values or up with negative values. At 0 or higher, bars move farther down if needed to clear the cast bar.")
    GlobalSlider("gap", "Space between bars", 1, false, "Gap between bar borders. At 0, bars touch. Sparks and large labels may extend into the gap.")
    y = y - 12
    Section("Border, gradient, and effects")
    Color(content, "borderColor", "Border color", y, function() return ns.db.borderColor end,
        function(value) ns.SetValue("borderColor", value) end)
    y = y - 40
    GlobalSlider("borderAlpha", "Border opacity", 0.01, true, "Make borders faint or solid. At 0%, they disappear.")
    GlobalSlider("borderRadius", "Corner radius (px)", 1, false,
        "Round the bar's corners. Larger values make softer corners, up to half the bar height.")
    GlobalSlider("gradientLeft", "Fill opacity at left", 0.01, true, "How solid the fill looks at its left edge.")
    GlobalSlider("gradientRight", "Fill opacity at right", 0.01, true, "How solid the fill looks at its moving right edge.")
    GlobalSlider("effectAlpha", "Pulse strength", 0.01, true, "Brightness of the pale gold highlight that builds with each swing. Defaults to 35%.")
    Check(content, "spark", "Show spark at the fill edge", y, function() return ns.db.spark end,
        function(value) ns.SetValue("spark", value) end, "Add a flickering spark at the moving edge of the bar.")
    y = y - 36
    GlobalSlider("sparkAlpha", "Spark brightness", 0.01, true, "Make the spark faint or bright.")
    GlobalSlider("sparkSize", "Spark size (px)", 1, false, "Set the spark's width. It extends above and below the bar.")
    y = y - 12
    for _, key in ipairs(ns.order) do
        local name = key
        Section(labels[name])
        Check(content, name .. ".enabled", "Enable this bar", y, function() return ns.db.bars[name].enabled end,
            function(value) ns.SetBarValue(name, "enabled", value) end,
            "Show a timer for this weapon. The preview includes it even if the weapon is unequipped.")
        y = y - 34
        Color(content, name .. ".color", "Fill color", y, function() return ns.db.bars[name].color end,
            function(value, alpha) ns.SetBarValue(name, "color", value, alpha) end,
            function() return ns.db.bars[name].alpha end)
        y = y - 40
        Slider(content, name .. ".alpha", "Fill opacity", y, 0, 1, 0.01, true,
            function() return ns.db.bars[name].alpha end, function(value) ns.SetBarValue(name, "alpha", value) end,
            "Make this bar's fill more transparent. The gradient still applies.")
        y = y - 40
        Dropdown(content, name .. ".effect", "Animation", y, effects, function() return ns.db.bars[name].effect end,
            function(value) ns.SetBarValue(name, "effect", value) end,
            "Pulse brightens the fill as each swing finishes. Choose None for a steady fill.")
        y = y - 40
        Check(content, name .. ".labelEnabled", "Show timer label", y,
            function() return ns.db.bars[name].labelEnabled end,
            function(value) ns.SetBarValue(name, "labelEnabled", value) end,
            "Label the bar MAIN, OFF, or RANGE.")
        y = y - 34
        Dropdown(content, name .. ".labelFont", "Label font", y, ns.fonts,
            function() return ns.db.bars[name].labelFont end,
            function(value) ns.SetBarValue(name, "labelFont", value) end, "Choose the font for this bar's label.")
        y = y - 40
        Slider(content, name .. ".labelSize", "Label size (px)", y, 6, 24, 1, false,
            function() return ns.db.bars[name].labelSize end,
            function(value) ns.SetBarValue(name, "labelSize", value) end, "Font size in physical screen pixels.")
        y = y - 40
        Color(content, name .. ".labelColor", "Label color", y,
            function() return ns.db.bars[name].labelColor end,
            function(value) ns.SetBarValue(name, "labelColor", value) end)
        y = y - 40
        Dropdown(content, name .. ".labelAlign", "Label alignment", y,
            {{"LEFT", "Left"}, {"CENTER", "Center"}, {"RIGHT", "Right"}},
            function() return ns.db.bars[name].labelAlign end,
            function(value) ns.SetBarValue(name, "labelAlign", value) end, "Place the label at the left, center, or right of the bar.")
        y = y - 56
    end
    content:SetHeight(-y + 12)
    status = Label(panel, "", 16, -4, "GameFontDisableSmall")
    status:ClearAllPoints(); status:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 44)
    local reset = Button(panel, "Restore defaults", 144, ns.ResetSettings)
    reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 12)
    local help = Button(panel, "Chat command help", 152, function() ns.Slash("help") end)
    help:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 12)
    AddControl("reset", { button = reset, Refresh = function() end })
    ns.optionControls = controls
end

function ns.RegisterOptions()
    if panel then return end
    ns.RegisterFeatureOptions()
    panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    ns.optionsPanel = panel
    -- Build before Blizzard displays the registered canvas, so OnShow only refreshes.
    BuildPanel()
    local category = Settings.RegisterCanvasLayoutSubcategory(ns.rootCategory, panel, title)
    Settings.RegisterAddOnCategory(category)
    ns.optionsCategory = category
    ns.RegisterComboOptions()
    ns.RegisterPlayerCastOptions()
    panel:SetScript("OnShow", function()
        ns.RefreshOptions()
    end)
end

function ns.OpenSwingOptions()
    if not panel then ns.RegisterOptions() end
    ns.OpenSettingsCategory(ns.optionsCategory)
end

ns.UI = {Label = Label, Check = Check, Button = Button, Slider = Slider,
    RefreshControls = function(list)
        local previous = updating
        updating = true
        for _, control in pairs(list) do control.Refresh() end
        updating = previous
    end}
