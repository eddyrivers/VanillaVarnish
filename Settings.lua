local _, VV = ...
local controls = {}

function VV.RefreshOptions()
    if not VV.db then return end
    VV.Nameplates.UI.RefreshControls(controls)
end

function VV.RegisterOptions()
    if VV.rootCategory then return end
    local UI = VV.Nameplates.UI
    local function Heading(panel, title, description)
        UI.Label(panel, title, 16, -16, "GameFontNormalLarge")
        local text = UI.Label(panel, description, 16, -44, "GameFontHighlightSmall")
        text:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -16, -44)
        text:SetJustifyH("LEFT")
    end
    local function Check(panel, id, title, y, get, set, tip)
        local holder = CreateFrame("Frame", nil, panel)
        holder:SetPoint("TOPLEFT", panel, "TOPLEFT", 16, y)
        holder:SetSize(480, 28)
        controls[id] = UI.Check(holder, "vv." .. id, title, 0, get, set, tip)
    end
    local root = CreateFrame("Frame", nil, UIParent)
    root:Hide()
    Heading(root, "VanillaVarnish", "A few finishing touches for your UI. Choose what to enable, then explore each settings page.")
    VV.rootCategory = Settings.RegisterCanvasLayoutCategory(root, "VanillaVarnish")
    VV.rootCategory:SetShouldSortAlphabetically(true)
    Settings.RegisterAddOnCategory(VV.rootCategory)
    for index, moduleKey in ipairs(VV.moduleOrder) do
        local key = moduleKey
        Check(root, key, "Enable " .. VV.moduleLabels[key], -90 - (index - 1) * 44,
            function() return VV.db.modules[key] end,
            function(value) VV.SetModuleEnabled(key, value) end,
            "Turn this section on or off. Your settings are kept either way.")
    end
    UI.Label(root, "Your settings save per character. Open this menu anytime with /vv.",
        16, -282, "GameFontHighlightSmall")
    local conflictText = {}
    for _, key in ipairs(VV.moduleOrder) do
        if VV.conflicts[key] then conflictText[#conflictText + 1] = "Disable " .. VV.conflicts[key] .. " and /reload to activate " .. VV.moduleLabels[key] .. "." end
    end
    if VV.swingConflict then conflictText[#conflictText + 1] = "Disable NameplateSwingTimers and /reload to activate bundled swing timers." end
    UI.Label(root, table.concat(conflictText, "\n"), 16, -330, "GameFontHighlightSmall")
    root:SetScript("OnShow", VV.RefreshOptions)
    VV.optionsPanel = root

    local party = CreateFrame("Frame", nil, UIParent)
    party:Hide()
    Heading(party, "Party frames", "Keep helpful buffs in view and make party members easier to recognize.")
    Check(party, "party.buffs", "Show party buffs", -90,
        function() return VV.db.party.buffs end,
        function(value) VV.Party.SetOption("buffs", value) end,
        "Show up to eight buffs beneath mana, with yours first and larger. Also enlarge debuffs you can dispel and color their borders by type. Requires portrait-style party frames.")
    Check(party, "party.classColors", "Class-colored health bars", -134,
        function() return VV.db.party.classColors end,
        function(value) VV.Party.SetOption("classColors", value) end,
        "Use each party member's class color for their health bar. Works with both party-frame styles.")
    Check(party, "party.rangeFade", "Fade out-of-range portraits and buffs", -178,
        function() return VV.db.party.rangeFade end,
        function(value) VV.Party.SetOption("rangeFade", value) end,
        "Use the friendly spell and opacity from Nameplates > Range check. No spell or unavailable range leaves portraits and buffs unchanged. Requires portrait-style party frames.")
    local range = UI.Button(party, "Choose friendly range spell", 210, function() VV.Nameplates.OpenOptions("rangeEnabled") end)
    range:SetPoint("TOPLEFT", party, "TOPLEFT", 16, -222)
    UI.Label(party, "Buffs and range fading need 'Use raid-style party frames' turned off.\nHealth and mana bars keep their native opacity. Some layout changes apply after combat.",
        16, -266, "GameFontHighlightSmall")
    VV.partyCategory = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, party, "Party frames")
    Settings.RegisterAddOnCategory(VV.partyCategory)
    party:SetScript("OnShow", VV.RefreshOptions)
    VV.partyPanel, VV.optionControls = party, controls
    VV.RefreshOptions()
end
