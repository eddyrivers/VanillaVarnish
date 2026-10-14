local ADDON, VV = ...

VV.Nameplates, VV.QuestTracker, VV.Party, VV.Tooltips, VV.PoliteUI = {}, {}, {}, {}, {}
VV.moduleOrder = { "nameplates", "party", "questTracker", "tooltips", "politeUI" }
VV.moduleLabels = { nameplates = "Nameplates", questTracker = "Quest tracker", party = "Party frames", tooltips = "Tooltips", politeUI = "Polite UI" }
local legacy = { nameplates = "NameplateTweaks", questTracker = "QuestTrackerOrganizer", party = "PartyTweaks", tooltips = "ForeverMouseTooltip" }
local events = CreateFrame("Frame")
local pendingCategory

function VV.Print(message)
    print("|cff80cfffVanillaVarnish:|r " .. tostring(message):gsub("|", "||"))
end

function VV.Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, item in pairs(value) do result[key] = VV.Copy(item) end
    return result
end

function VV.IsLegacyLoaded(name)
    local fn = C_AddOns and C_AddOns.IsAddOnLoaded or IsAddOnLoaded
    if not fn then return false end
    local ok, loaded = pcall(fn, name)
    return ok and loaded == true
end

function VV.IsModuleEnabled(key)
    return VV.db and VV.db.modules[key] == true and not VV.conflicts[key]
end

function VV.InitDB()
    if type(VanillaVarnishDB) ~= "table" then VanillaVarnishDB = {} end
    VV.db = VanillaVarnishDB
    local db = VV.db
    local defaults = VV.GetPreset and VV.GetPreset("Default")
    if type(db.modules) ~= "table" then db.modules = {} end
    for _, key in ipairs(VV.moduleOrder) do
        if type(db.modules[key]) ~= "boolean" then db.modules[key] = true end
    end
    -- Import each section only when it has no settings of its own. Never alias
    -- legacy tables or replace preferences on subsequent loads.
    if type(db.nameplates) ~= "table" then
        db.nameplates = type(NameplateTweaksDB) == "table" and VV.Copy(NameplateTweaksDB)
            or defaults and defaults.nameplates or {}
        if type(NameplateTweaksDB) ~= "table" and type(NameplateSwingTimersDB) == "table" then
            db.nameplates.swingTimers = VV.Copy(NameplateSwingTimersDB)
        end
    end
    if type(db.nameplates.swingTimers) ~= "table" then
        db.nameplates.swingTimers = type(NameplateSwingTimersDB) == "table" and VV.Copy(NameplateSwingTimersDB) or {}
    end
    if type(db.questTracker) ~= "table" then
        db.questTracker = type(QuestTrackerOrganizerDB) == "table" and VV.Copy(QuestTrackerOrganizerDB)
            or defaults and defaults.questTracker or {}
    end
    if type(db.party) ~= "table" then db.party = defaults and defaults.party or {} end
    if type(db.tooltips) ~= "table" then db.tooltips = defaults and defaults.tooltips or {} end
    if type(db.politeUI) ~= "table" then db.politeUI = {} end
    if VV.PoliteUI.InitDB then VV.PoliteUI.InitDB() end
    if type(db.questTracker.enabled) ~= "boolean" then db.questTracker.enabled = true end
    local sort = db.questTracker.completedSort
    if sort ~= "off" and sort ~= "top" and sort ~= "bottom" then
        db.questTracker.completedSort = db.questTracker.completedFirst == true and "top" or "off"
    end
    db.questTracker.completedFirst = nil
    if type(db.questTracker.collapsed) ~= "table" then db.questTracker.collapsed = {} end
    for _, key in ipairs({ "buffs", "classColors", "rangeFade" }) do
        if type(db.party[key]) ~= "boolean" then db.party[key] = true end
    end
    db.schemaVersion = 1
    VV.conflicts = {}
    for key, name in pairs(legacy) do
        if VV.IsLegacyLoaded(name) then VV.conflicts[key] = name end
    end
    VV.swingConflict = VV.IsLegacyLoaded("NameplateSwingTimers")
    if VV.InitProfiles then VV.InitProfiles() end
end

function VV.GetModule(key)
    return ({ nameplates = VV.Nameplates, questTracker = VV.QuestTracker,
        party = VV.Party, tooltips = VV.Tooltips, politeUI = VV.PoliteUI })[key]
end

function VV.RefreshModule(key)
    local module = VV.GetModule(key)
    if module.RefreshModule then module.RefreshModule() end
    if VV.RefreshOptions then VV.RefreshOptions() end
end

function VV.SetModuleEnabled(key, enabled)
    if not VV.db or not VV.moduleLabels[key] or type(enabled) ~= "boolean" then return false end
    VV.db.modules[key] = enabled
    VV.RefreshModule(key)
    return true
end

function VV.OpenSettingsCategory(category)
    if InCombatLockdown() then
        pendingCategory = category
        VV.Print("Settings will open when combat ends.")
        return
    end
    pendingCategory = nil
    if securecallfunction then securecallfunction(Settings.OpenToCategory, category:GetID())
    else Settings.OpenToCategory(category:GetID()) end
end

function VV.OpenOptions(page)
    VV.RegisterOptions()
    if page == "nameplates" then VV.Nameplates.OpenOptions(); return end
    if page == "questTracker" then VV.QuestTracker.OpenOptions(); return end
    if page == "tooltips" then VV.Tooltips.OpenOptions(); return end
    if page == "politeUI" then VV.PoliteUI.OpenOptions(); return end
    VV.OpenSettingsCategory(page == "party" and VV.partyCategory
        or page == "profiles" and VV.profilesCategory or VV.rootCategory)
end

local function Status()
    for _, key in ipairs(VV.moduleOrder) do
        VV.Print(VV.moduleLabels[key] .. ": " .. (VV.db.modules[key] and "on" or "off")
            .. (VV.conflicts[key] and "; waiting for " .. VV.conflicts[key] .. " to be disabled and /reload" or ""))
    end
end

SLASH_VANILLAVARNISH1 = "/vv"
SlashCmdList.VANILLAVARNISH = function(message)
    if not VV.db then return end
    local command, rest = (message or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    local key = ({nameplates = "nameplates", nameplate = "nameplates", tracker = "questTracker",
        quests = "questTracker", party = "party", tooltip = "tooltips", tooltips = "tooltips",
        fade = "politeUI", polite = "politeUI", politeui = "politeUI"})[command]
    if command == "" or command == "options" or command == "settings" then VV.OpenOptions(); return end
    if command == "status" then Status(); return end
    if command == "profiles" or command == "presets" then VV.OpenOptions("profiles"); return end
    if key then
        local mode = rest:lower()
        if mode == "on" or mode == "off" or mode == "toggle" then
            VV.SetModuleEnabled(key, mode == "on" or mode == "toggle" and not VV.db.modules[key])
            Status()
        elseif rest == "" or mode == "options" then VV.OpenOptions(key)
        else
            local module = VV.GetModule(key)
            module.HandleSlash(rest)
        end
        return
    end
    VV.Print("/vv opens settings. /vv nameplates, /vv tracker, /vv party, /vv tooltips, /vv polite open module pages.")
    VV.Print("/vv <module> on | off | toggle controls the whole module and preserves its feature settings.")
    VV.Print("/vv status shows module status. Use /vv <module> help for feature commands.")
end

events:RegisterEvent("ADDON_LOADED")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name == ADDON then
        if not VV.db then VV.InitDB() end
    elseif event == "PLAYER_LOGIN" then
        VV.RegisterOptions()
        VV.Print("Loaded. Type /vv to configure your finishing touches, including Polite UI.")
        for _, key in ipairs(VV.moduleOrder) do
            if VV.conflicts[key] and VV.db.modules[key] then
                VV.Print(VV.moduleLabels[key] .. " paused: " .. VV.conflicts[key]
                    .. " is loaded. Disable it and /reload to activate " .. VV.moduleLabels[key] .. ".")
            end
        end
        if VV.swingConflict then VV.Print("Disable NameplateSwingTimers and /reload to activate bundled swing timers.") end
    elseif event == "PLAYER_REGEN_ENABLED" and pendingCategory then
        VV.OpenSettingsCategory(pendingCategory)
    end
end)
