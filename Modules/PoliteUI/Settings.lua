local _, VV = ...
local addon = VV.PoliteUI
local controls = {}

local function summary(key, side)
    local selected, labels = addon.GetRule(key)[side], {}
    for _, choice in ipairs(addon.Choices(key, side)) do
        if selected[choice.id] then labels[#labels + 1] = choice.label end
    end
    if #labels == 0 then return "Never" end
    if #labels == 1 then return labels[1] end
    return #labels .. " conditions (AND)"
end

function addon.RefreshOptions()
    if not addon.optionsPanel then return end
    for _, control in pairs(controls) do control:GenerateMenu() end
end

function addon.RegisterOptions()
    if addon.optionsPanel then return end
    VV.RegisterOptions()
    -- VV.RegisterOptions also registers this page after creating its root.
    if addon.optionsPanel then return end
    addon.InitDB()
    local UI = VV.Nameplates.UI
    local panel = CreateFrame("Frame", nil, UIParent)
    panel:Hide()
    addon.optionsPanel = panel
    UI.Label(panel, "Polite UI", 16, -16, "GameFontNormalLarge")
    local intro = UI.Label(panel, "Let the HUD step aside until you need it. Every element starts at Never.",
        16, -44, "GameFontHighlightSmall")
    intro:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -44)
    local presets = CreateFrame("DropdownButton", nil, panel, "WowStyle1DropdownTemplate")
    presets:SetSize(240, 24)
    presets:SetPoint("TOPLEFT", panel, "TOPLEFT", 106, -78)
    presets:SetDefaultText("Coming soon")
    presets:SetEnabled(false)
    UI.Label(panel, "Presets", 16, -84)
    local help = UI.Label(panel, "Fade out only while ALL selected conditions match (AND).\nReturn automatically when any condition stops matching. Hover always reveals.\nNormal fades take 0.5 seconds; restricted resource rules use native opacity.",
        16, -118, "GameFontHighlightSmall")
    help:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -118)
    help:SetJustifyH("LEFT")
    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, -178)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -36, 52)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(570, 1400)
    scroll:SetScrollChild(content)
    scroll:SetScript("OnSizeChanged", function(_, width) content:SetWidth(math.max(570, width)) end)
    local function select(row, key, side)
        local dropdown = CreateFrame("DropdownButton", nil, row, "WowStyle1DropdownTemplate")
        dropdown:SetSize(376, 24)
        dropdown:SetPoint("TOPLEFT", row, "TOPLEFT", 188, 0)
        dropdown:SetDefaultText("Never")
        dropdown:SetSelectionText(function() return summary(key, side) end)
        dropdown:SetupMenu(function(_, menu)
            if menu.SetScrollMode then menu:SetScrollMode(440) end
            menu:CreateRadio("Never (clear selections)", function() return not next(addon.GetRule(key)[side]) end,
                function() addon.SetCondition(key, side, nil) end)
            menu:CreateDivider()
            local choices = addon.Choices(key, side)
            local spec = addon.byKey[key]
            for index, choice in ipairs(choices) do
                local id = choice.id
                if index == 1 and #spec.specific > 0 then menu:CreateTitle("For " .. spec.label) end
                if index == #spec.specific + 1 then menu:CreateTitle("Common conditions") end
                menu:CreateCheckbox(choice.label, function() return addon.GetRule(key)[side][id] == true end,
                    function() addon.SetCondition(key, side, id, not addon.GetRule(key)[side][id]) end)
            end
        end)
        dropdown:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(addon.byKey[key].label .. ": Fade out")
            local state = addon.GetDiagnostics()[key]
            GameTooltip:AddLine(state.status, 1, 0.82, 0, true)
            local items = state[side].items
            if #items == 0 then GameTooltip:AddLine("Never: no automatic conditions.", 0.85, 0.85, 0.85, true) end
            for _, item in ipairs(items) do
                local marker = item.native and "Native: " or item.value == true and "Match: " or item.value == false and "Waiting: " or "Unavailable: "
                GameTooltip:AddLine(marker .. item.label .. (item.reason and " (" .. item.reason .. ")" or ""),
                    item.value == true and 0.4 or 1, item.value == true and 1 or 0.82, 0.4, true)
            end
            if state[side .. "Warning"] then GameTooltip:AddLine(state[side .. "Warning"], 1, 0.3, 0.3, true) end
            if state.error then GameTooltip:AddLine(state.error, 1, 0.3, 0.3, true) end
            GameTooltip:AddLine("ALL selections must match (AND). Hover always reveals this element.", 0.85, 0.85, 0.85, true)
            GameTooltip:Show()
        end)
        dropdown:SetScript("OnLeave", function() GameTooltip:Hide() end)
        controls[key .. "." .. side] = dropdown
    end
    local y, group = -4, nil
    for _, spec in ipairs(addon.elements) do
        if group ~= spec.group then
            if group then y = y - 16 end
            group = spec.group
            UI.Label(content, group, 0, y, "GameFontNormalLarge")
            UI.Label(content, "Fade out", 188, y - 28, "GameFontNormal")
            y = y - 52
        end
        local row = CreateFrame("Frame", nil, content)
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        row:SetHeight(32)
        local label = UI.Label(row, spec.label, 0, -5)
        label:SetWidth(180)
        select(row, spec.key, "fadeOut")
        y = y - 36
    end
    content:SetHeight(-y + 12)
    local reset = UI.Button(panel, "Clear all fade rules", 160, addon.ResetSettings)
    reset:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 12)
    local footer = UI.Label(panel, "Typing and Edit Mode keep the UI visible.", 16, 0, "GameFontHighlightSmall")
    footer:ClearAllPoints()
    footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 18)
    addon.optionsCategory = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, panel, "Polite UI")
    Settings.RegisterAddOnCategory(addon.optionsCategory)
    addon.optionControls, addon.presetControl = controls, presets
    panel:SetScript("OnShow", function() addon.RefreshOptions(); addon.RefreshVisibility() end)
    panel:SetScript("OnHide", addon.RefreshVisibility)
    addon.RefreshOptions()
end

function addon.OpenOptions()
    addon.RegisterOptions()
    VV.OpenSettingsCategory(addon.optionsCategory)
end
