local _, VV = ...
local fields = {
    nameplates = {"markers", "rangeEnabled", "swingsEnabled", "comboPointsEnabled", "threatColorsEnabled",
        "questieFallback", "rangeOpacity", "damage", "friendly", "swingTimers", "comboPoints"},
    questTracker = {"enabled", "completedSort"},
    party = {"buffs", "classColors", "rangeFade"},
    tooltips = {"followMouse", "offsetX", "offsetY", "unitColors", "pauseInCombat"},
}

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
        if VV.ProfileName(name) and type(record) == "table" and type(record.settings) == "table" then
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
    return type(record) ~= "table" or type(record.settings) ~= "table" or not same(snapshot(), record.settings)
end

function VV.SaveProfile(input)
    local name = VV.ProfileName(input)
    if not name then return false, "Enter a profile name (1-48 characters, without control characters or |)." end
    name = VV.FindProfile(name) or name
    VV.profileStore[name] = {version=1, settings=snapshot()}
    VV.db.profileName, VV.selectedProfile = name, name
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

function VV.LoadProfile(input)
    if InCombatLockdown() then return false, "Leave combat before loading a profile." end
    local name = VV.FindProfile(input)
    local record = name and VV.profileStore[name]
    if type(record) ~= "table" or record.version ~= 1 or type(record.settings) ~= "table" then
        return false, "Choose a compatible saved profile first."
    end
    local settings = record.settings
    if type(settings.modules) ~= "table" then return false, "That profile has invalid settings." end
    for section in pairs(fields) do
        if type(settings[section]) ~= "table" then return false, "That profile has invalid settings." end
    end
    local collapsed = VV.db.questTracker.collapsed
    replace(VV.db.modules, settings.modules)
    for section in pairs(fields) do replace(VV.db[section], settings[section]) end
    -- Quest folds describe this character's current quests, not a shared design.
    VV.db.questTracker.collapsed = collapsed
    VV.db.profileName, VV.selectedProfile = name, name
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
    VV.Print("Loaded profile: " .. name .. ". Changes stay on this character until you save the profile again.")
    return true, name
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function()
    if VV.db and VV.RefreshOptions then VV.RefreshOptions() end
end)
