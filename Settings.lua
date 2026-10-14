local _, VV = ...
local controls = {}

function VV.RefreshProfileStatus()
    local profile = VV.profileControls
    if not profile or not VV.db then return end
    local name = VV.db.profileName
    local preset = VV.db.presetName
    profile.status:SetText(preset and ("Current preset: " .. preset .. (VV.PresetModified() and " (modified locally)" or ""))
        or name and ("Current profile: " .. name .. (VV.ProfileModified() and " (modified locally)" or ""))
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
    local preset = VV.presetControls
    if preset then
        preset.dropdown:GenerateMenu()
        preset.apply:SetEnabled(not InCombatLockdown() and VV.GetPreset(VV.selectedPreset) ~= nil)
    end
    if VV.PoliteUI.RefreshOptions then VV.PoliteUI.RefreshOptions() end
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
    local profilesLink = UI.Button(root, "Profiles & Presets", 180, function() VV.OpenOptions("profiles") end)
    profilesLink:SetPoint("TOPLEFT", root, "TOPLEFT", 16, -90 - #VV.moduleOrder * 44 - 10)
    VV.profilesLink = profilesLink
    local profiles = CreateFrame("Frame", nil, UIParent)
    profiles:Hide()
    Heading(profiles, "Profiles & Presets", "Start with a built-in design or save your own settings to share across characters.")
    VV.profilesCategory = Settings.RegisterCanvasLayoutSubcategory(VV.rootCategory, profiles, "Profiles & Presets")
    Settings.RegisterAddOnCategory(VV.profilesCategory)
    VV.profilesPanel = profiles
    UI.Label(profiles, "Presets", 16, -86, "GameFontNormalLarge")
    UI.Label(profiles, "Choose preset", 16, -128)
    VV.selectedPreset = VV.db.presetName or "Default"
    local presets = CreateFrame("DropdownButton", nil, profiles, "WowStyle1DropdownTemplate")
    presets:SetSize(240, 24)
    presets:SetPoint("TOPLEFT", profiles, "TOPLEFT", 136, -122)
    presets:SetDefaultText("Select a preset")
    presets:SetupMenu(function(_, menu)
        for _, presetName in ipairs(VV.PresetNames()) do
            local name = presetName
            menu:CreateRadio(name, function() return VV.selectedPreset == name end, function()
                VV.selectedPreset = name
                VV.RefreshOptions()
            end)
        end
    end)
    local applyPreset = UI.Button(profiles, "Apply preset", 116, function()
        local ok, result = VV.LoadPreset(VV.selectedPreset)
        if not ok then VV.Print(result) end
    end)
    applyPreset:SetPoint("LEFT", presets, "RIGHT", 12, 0)
    VV.presetControls = {dropdown=presets, apply=applyPreset}
    local presetHint = UI.Label(profiles, "Applying replaces this character's settings. Save a profile first to keep your current design.\nBuilt-in presets stay available; your saved profiles are kept separately.", 16, -164, "GameFontHighlightSmall")
    presetHint:SetPoint("TOPRIGHT", profiles, "TOPRIGHT", -16, -164)
    presetHint:SetJustifyH("LEFT")
    UI.Label(profiles, "Profiles", 16, -226, "GameFontNormalLarge")
    VV.selectedProfile = VV.selectedProfile or VV.FindProfile(VV.db.profileName)
    UI.Label(profiles, "Load profile", 16, -268)
    local dropdown = CreateFrame("DropdownButton", nil, profiles, "WowStyle1DropdownTemplate")
    dropdown:SetSize(240, 24)
    dropdown:SetPoint("TOPLEFT", profiles, "TOPLEFT", 136, -262)
    dropdown:SetDefaultText("Select a profile")
    local nameBox = CreateFrame("EditBox", nil, profiles, "InputBoxTemplate")
    nameBox:SetSize(240, 28)
    nameBox:SetPoint("TOPLEFT", profiles, "TOPLEFT", 136, -304)
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
    UI.Label(profiles, "Save as", 16, -312)
    local function save()
        local ok, result = VV.SaveProfile(nameBox:GetText())
        if ok then nameBox:SetText(result); nameBox:ClearFocus() else VV.Print(result) end
        VV.RefreshOptions()
    end
    local load = UI.Button(profiles, "Load", 116, function()
        local ok, result = VV.LoadProfile(VV.selectedProfile)
        if not ok then VV.Print(result) end
    end)
    load:SetPoint("LEFT", dropdown, "RIGHT", 12, 0)
    local saveButton = UI.Button(profiles, "Save profile", 116, save)
    saveButton:SetPoint("LEFT", nameBox, "RIGHT", 12, 0)
    nameBox:SetScript("OnTextChanged", VV.RefreshOptions)
    nameBox:SetScript("OnEnterPressed", save)
    nameBox:SetScript("OnEscapePressed", function() nameBox:ClearFocus() end)
    local status = UI.Label(profiles, "", 16, -352, "GameFontHighlightSmall")
    status:SetPoint("TOPRIGHT", profiles, "TOPRIGHT", -16, -352)
    status:SetJustifyH("LEFT")
    local hint = UI.Label(profiles, "Profiles are shared across characters on this account. Loading replaces this character's settings.\nSave under a name to keep your design; saving an existing name updates that profile. Load after combat.",
        16, -392, "GameFontHighlightSmall")
    hint:SetPoint("TOPRIGHT", profiles, "TOPRIGHT", -16, -392)
    hint:SetJustifyH("LEFT")
    VV.profileControls = {dropdown=dropdown, name=nameBox, load=load, save=saveButton, status=status}
    profiles:SetScript("OnShow", VV.RefreshOptions)
    local conflictText = {}
    for _, key in ipairs(VV.moduleOrder) do
        if VV.conflicts[key] then conflictText[#conflictText + 1] = "Disable " .. VV.conflicts[key] .. " and /reload to activate " .. VV.moduleLabels[key] .. "." end
    end
    if VV.swingConflict then conflictText[#conflictText + 1] = "Disable NameplateSwingTimers and /reload to activate bundled swing timers." end
    UI.Label(root, table.concat(conflictText, "\n"), 16, -90 - #VV.moduleOrder * 44 - 60, "GameFontHighlightSmall")
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
    if VV.PoliteUI.RegisterOptions then VV.PoliteUI.RegisterOptions() end
    VV.RefreshOptions()
end
