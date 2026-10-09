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
    Heading(root, "VanillaVarnish", "Improve Blizzard's native UI. Choose whole modules here, then configure their individual features in the sub-pages.")
    VV.rootCategory = Settings.RegisterCanvasLayoutCategory(root, "VanillaVarnish")
    Settings.RegisterAddOnCategory(VV.rootCategory)
    for index, moduleKey in ipairs(VV.moduleOrder) do
        local key = moduleKey
        Check(root, key, "Enable " .. VV.moduleLabels[key], -90 - (index - 1) * 44,
            function() return VV.db.modules[key] end,
            function(value) VV.SetModuleEnabled(key, value) end,
            "Turning this module off preserves all its individual feature settings. Protected layout changes apply when combat ends.")
    end
    UI.Label(root, "All settings save per character. Module switches keep your smaller feature choices.\nOpen this menu with /vv. Use /vv status for module diagnostics.",
        16, -238, "GameFontHighlightSmall")
    local conflictText = {}
    for _, key in ipairs(VV.moduleOrder) do
        if VV.conflicts[key] then conflictText[#conflictText + 1] = "Disable " .. VV.conflicts[key] .. " and /reload to activate " .. VV.moduleLabels[key] .. "." end
    end
    if VV.swingConflict then conflictText[#conflictText + 1] = "Disable NameplateSwingTimers and /reload to activate bundled swing timers." end
    UI.Label(root, table.concat(conflictText, "\n"), 16, -306, "GameFontHighlightSmall")
    root:SetScript("OnShow", VV.RefreshOptions)
    VV.optionsPanel = root

    local party = CreateFrame("Frame", nil, UIParent)
    party:Hide()
    Heading(party, "Party frames", "Aura enhancements for portrait-style party frames, and class colors for both party-frame styles.")
    Check(party, "party.buffs", "Show party buffs", -90,
        function() return VV.db.party.buffs end,
        function(value) VV.Party.SetOption("buffs", value) end,
        "Only shown when 'Use raid-style party frames' is OFF. Shows up to eight buffs beneath mana: yours come first and are 5px larger. Native debuffs you can dispel are doubled in size with type-colored borders. Includes counts, cooldowns, and tooltips.")
    Check(party, "party.classColors", "Class-colored health bars", -134,
        function() return VV.db.party.classColors end,
        function(value) VV.Party.SetOption("classColors", value) end,
        "Color portrait-style and raid-style party health bars by class while preserving native artwork and bar height.")
    UI.Label(party, "Enable Party frames on the VanillaVarnish main page to apply these features.\nBuffs and larger dispellable debuffs apply only with 'Use raid-style party frames' OFF.\nClass colors apply to both styles. Protected restoration waits for combat to end.\n/pt status shows detected frames and any refused client API call.",
        16, -204, "GameFontHighlightSmall")
    VV.partyCategory = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, party, "Party frames")
    Settings.RegisterAddOnCategory(VV.partyCategory)
    party:SetScript("OnShow", VV.RefreshOptions)
    VV.partyPanel, VV.optionControls = party, controls
    VV.RefreshOptions()
end
