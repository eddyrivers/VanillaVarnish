local _, VV = ...
local fields = {
    nameplates = {"markers", "rangeEnabled", "swingsEnabled", "comboPointsEnabled", "threatColorsEnabled",
        "questieFallback", "rangeOpacity", "damage", "friendly", "swingTimers", "comboPoints"},
    questTracker = {"enabled", "completedSort"},
    party = {"buffs", "classColors", "rangeFade"},
    tooltips = {"followMouse", "offsetX", "offsetY", "unitColors", "pauseInCombat"},
}

local function validSettings(settings)
    if type(settings) ~= "table" or type(settings.modules) ~= "table" then return false end
    for section in pairs(fields) do
        if type(settings[section]) ~= "table" then return false end
    end
    local plates = settings.nameplates
    for _, key in ipairs({"swingTimers", "comboPoints"}) do
        if plates[key] ~= nil and type(plates[key]) ~= "table" then return false end
    end
    for _, key in ipairs({"damage", "friendly"}) do
        if plates[key] ~= nil and type(plates[key]) ~= "string" then return false end
    end
    local bars = plates.swingTimers and plates.swingTimers.bars
    if bars ~= nil then
        if type(bars) ~= "table" then return false end
        for _, key in ipairs({"main", "offhand", "ranged"}) do
            if bars[key] ~= nil and type(bars[key]) ~= "table" then return false end
        end
    end
    return true
end

function VV.InitProfiles()
    if type(VanillaVarnishProfilesDB) ~= "table" then VanillaVarnishProfilesDB = {} end
    if type(VanillaVarnishProfilesDB.profiles) ~= "table" then VanillaVarnishProfilesDB.profiles = {} end
    VV.profileStore = VanillaVarnishProfilesDB.profiles
end

function VV.ProfileName(name)
    if type(name) ~= "string" then return end
    name = name:match("^%s*(.-)%s*$")
    local _, length = name:gsub("[^\128-\191]", "") -- UTF-8 leading bytes, not byte length.
    if length == 0 or length > 48 or name:find("[%c|]") then return end
    return name
end

function VV.FindProfile(name)
    name = VV.ProfileName(name)
    if not name then return end
    VV.InitProfiles()
    if VV.profileStore[name] then return name end
    for saved in pairs(VV.profileStore) do
        if type(saved) == "string" and saved:lower() == name:lower() then return saved end
    end
end

function VV.ProfileNames()
    VV.InitProfiles()
    local names = {}
    for name, record in pairs(VV.profileStore) do
        if VV.ProfileName(name) and type(record) == "table" and record.version == 1 and validSettings(record.settings) then
            names[#names + 1] = name
        end
    end
    table.sort(names, function(a, b)
        if a:lower() ~= b:lower() then return a:lower() < b:lower() end
        return a < b
    end)
    return names
end

local function snapshot()
    local settings = {modules=VV.Copy(VV.db.modules)}
    for section, keys in pairs(fields) do
        settings[section] = {}
        for _, key in ipairs(keys) do settings[section][key] = VV.Copy(VV.db[section][key]) end
    end
    return settings
end

local function same(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= "table" then return a == b end
    for key, value in pairs(a) do if not same(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end

function VV.ProfileModified()
    local name = VV.FindProfile(VV.db.profileName)
    local record = name and VV.profileStore[name]
    if type(record) ~= "table" or record.version ~= 1 or not validSettings(record.settings) then return true end
    local saved = VV.Copy(record.settings)
    -- Profiles saved before row layouts implicitly use the stacked layout.
    local swings = saved.nameplates and saved.nameplates.swingTimers
    if type(swings) == "table" and swings.layout == nil then swings.layout = "stack" end
    return not same(snapshot(), saved)
end

function VV.PresetModified()
    local settings = VV.GetPreset(VV.db.presetName)
    return not settings or not same(snapshot(), settings)
end

function VV.SaveProfile(input)
    local name = VV.ProfileName(input)
    if not name then return false, "Enter a profile name (1-48 characters, without control characters or |)." end
    name = VV.FindProfile(name) or name
    VV.profileStore[name] = {version=1, settings=snapshot()}
    VV.db.profileName, VV.selectedProfile = name, name
    VV.db.presetName = nil
    if VV.RefreshOptions then VV.RefreshOptions() end
    VV.Print("Saved profile: " .. name .. ". Available to characters on this account after /reload or logout.")
    return true, name
end

-- Keep the existing section/nested tables: modules hold references to them.
local function replace(destination, source)
    for key in pairs(destination) do if source[key] == nil then destination[key] = nil end end
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(destination[key]) ~= "table" then destination[key] = {} end
            replace(destination[key], value)
        else destination[key] = value end
    end
end

local function apply(settings, name, preset)
    if not validSettings(settings) then return false, "That profile has invalid settings." end
    local collapsed = VV.db.questTracker.collapsed
    replace(VV.db.modules, settings.modules)
    for section in pairs(fields) do replace(VV.db[section], settings[section]) end
    -- Quest folds describe this character's current quests, not a shared design.
    VV.db.questTracker.collapsed = collapsed
    VV.db.profileName = not preset and name or nil
    VV.db.presetName = preset and name or nil
    if not preset then VV.selectedProfile = name end
    VV.InitDB()
    local ns = VV.Nameplates
    ns.InitializeTweaks()
    ns.InitDB()
    ns.ComboPoints.InitDB()
    ns.styleVersion = (ns.styleVersion or 0) + 1
    VV.Tooltips.InitDB()
    for _, key in ipairs(VV.moduleOrder) do VV.RefreshModule(key) end
    if ns.RefreshComboOptions then ns.RefreshComboOptions() end
    if ns.RefreshFeatureOptions then ns.RefreshFeatureOptions() end
    if VV.RefreshOptions then VV.RefreshOptions() end
    return true, name
end

function VV.LoadProfile(input)
    if InCombatLockdown() then return false, "Leave combat before loading a profile." end
    local name = VV.FindProfile(input)
    local record = name and VV.profileStore[name]
    if type(record) ~= "table" or record.version ~= 1 or type(record.settings) ~= "table" then
        return false, "Choose a compatible saved profile first."
    end
    local ok, result = apply(record.settings, name)
    if ok then VV.Print("Loaded profile: " .. name .. ". Changes stay on this character until you save the profile again.") end
    return ok, result
end

function VV.LoadPreset(name)
    if InCombatLockdown() then return false, "Leave combat before applying a preset." end
    local settings = VV.GetPreset(name)
    if not settings then return false, "Choose a built-in preset first." end
    local ok, result = apply(settings, name, true)
    if ok then VV.Print("Applied preset: " .. name .. ". Save a profile to keep your own version.") end
    return ok, result
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if VV.db and VV.RefreshOptions then VV.RefreshOptions() end
end)
