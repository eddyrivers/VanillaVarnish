local _, VV = ...
local controls = {}

function VV.RefreshProfileStatus()
    local profile = VV.profileControls
    if not profile or not VV.db then return end
    local name = VV.db.profileName
    profile.status:SetText(name and ("Current profile: " .. name .. (VV.ProfileModified() and " (modified locally)" or ""))
        or "Current settings have not been saved as a profile.")
end

function VV.RefreshOptions()
    if not VV.db then return end
    VV.Nameplates.UI.RefreshControls(controls)
    local profile = VV.profileControls
    if profile then
        profile.dropdown:GenerateMenu()
        profile.load:SetEnabled(not InCombatLockdown() and VV.FindProfile(VV.selectedProfile) ~= nil)
        profile.save:SetEnabled(VV.ProfileName(profile.name:GetText()) ~= nil)
        profile.save:SetText(VV.FindProfile(profile.name:GetText()) and "Update profile" or "Save profile")
        VV.RefreshProfileStatus()
    end
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
    UI.Label(root, "Profiles", 16, -276, "GameFontNormalLarge")
    VV.selectedProfile = VV.selectedProfile or VV.FindProfile(VV.db.profileName)
    UI.Label(root, "Load profile", 16, -318)
    local dropdown = CreateFrame("DropdownButton", nil, root, "WowStyle1DropdownTemplate")
    dropdown:SetSize(240, 24)
    dropdown:SetPoint("TOPLEFT", root, "TOPLEFT", 136, -312)
    dropdown:SetDefaultText("Select a profile")
    local nameBox = CreateFrame("EditBox", nil, root, "InputBoxTemplate")
    nameBox:SetSize(240, 28)
    nameBox:SetPoint("TOPLEFT", root, "TOPLEFT", 136, -354)
    nameBox:SetAutoFocus(false)
    nameBox:SetMaxLetters(48)
    nameBox:SetText(VV.selectedProfile or VV.db.profileName or "")
    dropdown:SetupMenu(function(_, menu)
        for _, savedName in ipairs(VV.ProfileNames()) do
            local name = savedName
            menu:CreateRadio(name, function() return VV.selectedProfile == name end, function()
                VV.selectedProfile = name
                nameBox:SetText(name)
                VV.RefreshOptions()
            end)
        end
    end)
    UI.Label(root, "Save as", 16, -362)
    local function save()
        local ok, result = VV.SaveProfile(nameBox:GetText())
        if ok then nameBox:SetText(result); nameBox:ClearFocus() else VV.Print(result) end
        VV.RefreshOptions()
    end
    local load = UI.Button(root, "Load", 116, function()
        local ok, result = VV.LoadProfile(VV.selectedProfile)
        if not ok then VV.Print(result) end
    end)
    load:SetPoint("LEFT", dropdown, "RIGHT", 12, 0)
    local saveButton = UI.Button(root, "Save profile", 116, save)
    saveButton:SetPoint("LEFT", nameBox, "RIGHT", 12, 0)
    nameBox:SetScript("OnTextChanged", VV.RefreshOptions)
    nameBox:SetScript("OnEnterPressed", save)
    nameBox:SetScript("OnEscapePressed", function() nameBox:ClearFocus() end)
    local status = UI.Label(root, "", 16, -402, "GameFontHighlightSmall")
    status:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -402)
    status:SetJustifyH("LEFT")
    local hint = UI.Label(root, "Profiles are shared across characters on this account. Loading replaces this character's settings.\nSave under a name to keep your design; saving an existing name updates that profile. Load after combat.",
        16, -442, "GameFontHighlightSmall")
    hint:SetPoint("TOPRIGHT", root, "TOPRIGHT", -16, -442)
    hint:SetJustifyH("LEFT")
    VV.profileControls = {dropdown=dropdown, name=nameBox, load=load, save=saveButton, status=status}
    local conflictText = {}
    for _, key in ipairs(VV.moduleOrder) do
        if VV.conflicts[key] then conflictText[#conflictText + 1] = "Disable " .. VV.conflicts[key] .. " and /reload to activate " .. VV.moduleLabels[key] .. "." end
    end
    if VV.swingConflict then conflictText[#conflictText + 1] = "Disable NameplateSwingTimers and /reload to activate bundled swing timers." end
    UI.Label(root, table.concat(conflictText, "\n"), 16, -510, "GameFontHighlightSmall")
    root:SetScript("OnShow", VV.RefreshOptions)
    VV.optionsPanel = root

    local party = CreateFrame("Frame", nil, UIParent)
    party:Hide()
    Heading(party, "Party frames", "Keep helpful buffs in view and make party members easier to recognize.")
    Check(party, "party.buffs", "Show party buffs", -90,
        function() return VV.db.party.buffs end,
        function(value) VV.Party.SetOption("buffs", value) end,
        "Show up to 16 buffs in two rows of eight beneath mana. Eating/drinking comes first, then your buffs, which are larger. Also enlarge dispellable debuffs. Requires portrait-style party frames.")
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
