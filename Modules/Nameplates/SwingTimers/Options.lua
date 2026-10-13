local _, VV = ...
local ns = VV.Nameplates

ns.order = { "main", "offhand", "ranged" }
ns.defaults = {
    width = 200, height = 10, x = 20, y = 37, gap = 2, layout = "stack",
    visibility = "swing", effectAlpha = 0.35, borderAlpha = 0.3,
    borderColor = "white", gradientLeft = 0.40, gradientRight = 0.85,
    spark = true, sparkAlpha = 1, sparkSize = 12, borderRadius = 5,
    bars = {
        main = { enabled = true, color = "red", alpha = 1, effect = "pulse" },
        offhand = { enabled = true, color = "red", alpha = 1, effect = "pulse" },
        ranged = { enabled = true, color = "warmyellow", alpha = 1, effect = "pulse" },
    },
}
ns.effects = { off = true, pulse = true }
ns.fonts = {
    {"montserrat", "Montserrat", "Interface\\AddOns\\VanillaVarnish\\Media\\Montserrat-Regular.ttf"},
    {"arial", "Arial Narrow", "Fonts\\ARIALN.TTF"},
    {"friz", "Friz Quadrata", "Fonts\\FRIZQT__.TTF"},
    {"morpheus", "Morpheus", "Fonts\\MORPHEUS.TTF"},
}
ns.fontPaths = {}
for _, font in ipairs(ns.fonts) do ns.fontPaths[font[1]] = font[3] end
ns.limits = { width = {30, 400}, height = {5, 30}, x = {-300, 300}, y = {-100, 200},
    gap = {0, 12}, effectAlpha = {0, 1}, borderAlpha = {0, 1},
    gradientLeft = {0, 1}, gradientRight = {0, 1}, sparkAlpha = {0, 1},
    sparkSize = {4, 48}, borderRadius = {0, 15} }

-- CSS keyword RGB values; opacity is independent of the chosen color.
ns.colors = {
    warmyellow = "FFD36B",
    white = "FFFFFF", black = "000000", silver = "C0C0C0", gray = "808080",
    charcoal = "36454F", slategray = "708090", dimgray = "696969",
    red = "FF0000", crimson = "DC143C", firebrick = "B22222", coral = "FF7F50",
    salmon = "FA8072", tomato = "FF6347", orange = "FFA500", darkorange = "FF8C00",
    gold = "FFD700", goldenrod = "DAA520", yellow = "FFFF00", khaki = "F0E68C",
    ivory = "FFFFF0", beige = "F5F5DC", wheat = "F5DEB3", tan = "D2B48C",
    brown = "A52A2A", chocolate = "D2691E", sienna = "A0522D", olive = "808000",
    green = "008000", lime = "00FF00", forestgreen = "228B22", seagreen = "2E8B57",
    springgreen = "00FF7F", mint = "98FF98", aquamarine = "7FFFD4", teal = "008080",
    turquoise = "40E0D0", cyan = "00FFFF", skyblue = "87CEEB", steelblue = "4682B4",
    dodgerblue = "1E90FF", royalblue = "4169E1", blue = "0000FF", navy = "000080",
    indigo = "4B0082", purple = "800080", rebeccapurple = "663399", slateblue = "6A5ACD",
    violet = "EE82EE", orchid = "DA70D6", plum = "DDA0DD", lavender = "E6E6FA",
    magenta = "FF00FF", pink = "FFC0CB", hotpink = "FF69B4", deeppink = "FF1493",
}
local aliases = { mh = "main", mainhand = "main", oh = "offhand", off = "offhand",
    range = "ranged", all = "all", main = "main", offhand = "offhand", ranged = "ranged" }
local colorAliases = { grey = "gray", slategrey = "slategray", dimgrey = "dimgray",
    aqua = "cyan", fuchsia = "magenta", none = "transparent", clear = "transparent" }

function ns.Print(message)
    -- WoW consumes single pipes as escape sequences, including 'r' in ranged.
    print("|cffb8dbffVanillaVarnish:|r " .. message:gsub("|", "||"))
end

function ns.Known(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

function ns.Number(value, low, high)
    value = ns.Known(value)
    if type(value) ~= "number" or value ~= value or value < low or value > high then return nil end
    return value
end

function ns.ParseColor(value)
    if type(value) ~= "string" then return nil end
    value = value:lower():gsub("[%s_%-]", "")
    value = colorAliases[value] or value
    if value == "transparent" then return value, 0, 0, 0 end
    local hex = ns.colors[value]
    if not hex then
        hex = value:gsub("^#", "")
        if #hex == 3 and not hex:find("[^%x]") then
            hex = hex:gsub("(.)", "%1%1")
        end
        if #hex ~= 6 or hex:find("[^%x]") then return nil end
        value = "#" .. hex:upper()
    end
    return value, tonumber(hex:sub(1, 2), 16) / 255,
        tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

function ns.InitDB()
    if not ns.tweaksDB then ns.InitializeTweaks() end
    local NameplateTweaksDB = VV.db.nameplates
    local function Copy(value)
        if type(value) ~= "table" then return value end
        local result = {}
        for key, item in pairs(value) do result[key] = Copy(item) end
        return result
    end
    if type(NameplateTweaksDB.swingTimers) ~= "table" then
        NameplateTweaksDB.swingTimers = type(NameplateSwingTimersDB) == "table"
            and Copy(NameplateSwingTimersDB) or {}
    end
    local db = NameplateTweaksDB.swingTimers
    if db.layout ~= "row" then db.layout = "stack" end
    -- Move existing installations using the original default to the taller bar.
    local oldVersion = tonumber(db.appearanceVersion) or 0
    if oldVersion < 2 then
        if db.height == 5 then db.height = ns.defaults.height end
    end
    if oldVersion < 3 then
        if db.width == 120 then db.width = ns.defaults.width end
        if db.effectAlpha == 0.045 then db.effectAlpha = ns.defaults.effectAlpha end
    end
    if oldVersion < 4 and db.sparkAlpha == 0.22 then db.sparkAlpha = ns.defaults.sparkAlpha end
    if oldVersion < 5 and db.borderRadius == 3 then db.borderRadius = ns.defaults.borderRadius end
    if oldVersion < 7 then
        if db.y == 15 then db.y = ns.defaults.y end
        if db.visibility == "combat" then db.visibility = ns.defaults.visibility end
    end
    if oldVersion < 8 then
        if db.effectAlpha == 0.18 then db.effectAlpha = ns.defaults.effectAlpha end
        if db.sparkAlpha == 0.65 then db.sparkAlpha = ns.defaults.sparkAlpha end
    end
    if oldVersion < 9 and db.y == 10 then db.y = ns.defaults.y end
    db.appearanceVersion = 9
    for key, limits in pairs(ns.limits) do
        db[key] = ns.Number(db[key], limits[1], limits[2]) or ns.defaults[key]
    end
    if db.visibility ~= "combat" and db.visibility ~= "always" and db.visibility ~= "swing" then
        db.visibility = ns.defaults.visibility
    end
    db.borderColor = ns.ParseColor(db.borderColor) or ns.defaults.borderColor
    if type(db.spark) ~= "boolean" then db.spark = ns.defaults.spark end
    if type(db.bars) ~= "table" then db.bars = {} end
    for _, key in ipairs(ns.order) do
        if type(db.bars[key]) ~= "table" then db.bars[key] = {} end
        local bar, default = db.bars[key], ns.defaults.bars[key]
        if oldVersion < 3 then
            if not bar.color or bar.color == "transparent" then bar.color = default.color end
            bar.alpha = 1 -- old alpha described background tint, not fill opacity
        end
        if type(bar.enabled) ~= "boolean" then bar.enabled = default.enabled end
        if oldVersion < 5 then
            if key ~= "ranged" and bar.color == "warmyellow" then bar.color = default.color end
            if bar.labelFont == "montserrat" then bar.labelFont = "arial" end
            if bar.labelSize == 8 then bar.labelSize = 14 end
        end
        if oldVersion == 5 and key ~= "ranged" and bar.color == "crimson" then bar.color = default.color end
        bar.color = ns.ParseColor(bar.color) or default.color
        bar.alpha = ns.Number(bar.alpha, 0, 1) or default.alpha
        if bar.color == "transparent" then bar.alpha = 0 end
        if type(bar.effect) ~= "string" or not ns.effects[bar.effect] then bar.effect = default.effect end
        if type(bar.labelEnabled) ~= "boolean" then bar.labelEnabled = false end
        if not ns.fontPaths[bar.labelFont or ""] then bar.labelFont = "arial" end
        bar.labelSize = ns.Number(bar.labelSize, 6, 24) or 14
        bar.labelColor = ns.ParseColor(bar.labelColor) or "white"
        if bar.labelAlign ~= "LEFT" and bar.labelAlign ~= "CENTER" and bar.labelAlign ~= "RIGHT" then
            bar.labelAlign = "RIGHT"
        end
    end
    ns.db = db
end

local function EachBar(key, callback)
    if key == "all" then
        for _, name in ipairs(ns.order) do callback(ns.db.bars[name]) end
    else
        callback(ns.db.bars[key])
    end
end

local function Help()
    ns.Print("/vv nameplates swings - open swing timer settings with live preview.")
    ns.Print("/vv nameplates main on   /vv nameplates offhand off   /vv nameplates ranged toggle   /vv nameplates all on")
    ns.Print("/vv nameplates show swing - while swinging (default); other modes: always, combat.")
    ns.Print("/vv nameplates x 20   /vv nameplates y 37 - positive X moves right; positive Y moves down.")
    ns.Print("/vv nameplates width 200   /vv nameplates height 10   /vv nameplates gap 2")
    ns.Print("/vv nameplates layout row or stack - row shares the width; visible timers pack left.")
    ns.Print("/vv nameplates color main red - Blizzard hostile red; replace main with offhand, ranged, or all.")
    ns.Print("/vv nameplates color ranged #FFD36B 1 - optional fill opacity, from 0 to 1.")
    ns.Print("/vv nameplates bordercolor white   /vv nameplates borderalpha 0.3")
    ns.Print("/vv nameplates effect pulse - choose off or pulse.")
    ns.Print("/vv nameplates effect ranged pulse   /vv nameplates effectalpha 0.35")
    ns.Print("/vv nameplates gradientleft 0.40   /vv nameplates gradientright 0.85")
    ns.Print("/vv nameplates spark on   /vv nameplates sparkalpha 1")
    ns.Print("/vv nameplates sparksize 12   /vv nameplates borderradius 5")
    ns.Print("/vv nameplates label main on   /vv nameplates labelfont all arial   /vv nameplates labelsize main 14")
    ns.Print("/vv nameplates labelalign main right   /vv nameplates labelcolor main white")
    ns.Print("/vv nameplates range on   /vv nameplates quests off   /vv nameplates swings on")
    ns.Print("/vv nameplates preview on or off; /vv nameplates help for all commands.")
    ns.Print("/vv nameplates colors   /vv nameplates status   /vv nameplates reset")
end

local function Status()
    local db = ns.db
    ns.Print(string.format("Show: %s; %g x %g; X: %g; Y: %g below; gap: %g.",
        db.visibility, db.width, db.height, db.x, db.y, db.gap))
    for _, name in ipairs(ns.order) do
        local bar = db.bars[name]
        ns.Print(string.format("%s: %s; fill %s @ %.2f; effect %s.",
            name, bar.enabled and "on" or "off", bar.color, bar.alpha, bar.effect))
    end
    ns.Print("Anchor: " .. (ns.anchorUnit or "no visible target nameplate") ..
        (ns.preview and "; preview on (synthetic swings)" or ""))
end

ns.SwingHelp, ns.SwingStatus = Help, Status

function ns.Changed()
    ns.styleVersion = (ns.styleVersion or 0) + 1
    if ns.Refresh then ns.Refresh() end
    if ns.RefreshComboPoints then ns.RefreshComboPoints() end
    if ns.RefreshOptions then ns.RefreshOptions() end
    if ns.RefreshFeatureOptions then ns.RefreshFeatureOptions() end
    if VV.RefreshProfileStatus then VV.RefreshProfileStatus() end
end

function ns.SetValue(key, value)
    if ns.limits[key] then
        local limits = ns.limits[key]
        value = ns.Number(value, limits[1], limits[2])
        if not value then return false end
    elseif key == "borderColor" then
        value = ns.ParseColor(value)
        if not value then return false end
    elseif key == "visibility" then
        if value ~= "combat" and value ~= "always" and value ~= "swing" then return false end
    elseif key == "spark" then
        if type(value) ~= "boolean" then return false end
    elseif key == "layout" then
        if value ~= "row" and value ~= "stack" then return false end
    else return false end
    ns.db[key] = value
    ns.Changed()
    return true
end

function ns.SetBarValue(key, field, value, alpha)
    if not ns.db.bars[key] then return false end
    if field == "color" then
        value = ns.ParseColor(value)
        if not value then return false end
        alpha = alpha == nil and 1 or ns.Number(alpha, 0, 1)
        if not alpha then return false end
        ns.db.bars[key].alpha = value == "transparent" and 0 or alpha
    elseif field == "alpha" then
        value = ns.Number(value, 0, 1)
        if not value then return false end
        if value > 0 and ns.db.bars[key].color == "transparent" then
            ns.db.bars[key].color = ns.defaults.bars[key].color
        end
    elseif field == "enabled" then
        if type(value) ~= "boolean" then return false end
    elseif field == "effect" then
        if not ns.effects[value] then return false end
    elseif field == "labelEnabled" then
        if type(value) ~= "boolean" then return false end
    elseif field == "labelSize" then
        value = ns.Number(value, 6, 24)
        if not value then return false end
    elseif field == "labelFont" then
        if not ns.fontPaths[value or ""] then return false end
    elseif field == "labelAlign" then
        if value ~= "LEFT" and value ~= "CENTER" and value ~= "RIGHT" then return false end
    elseif field == "labelColor" then
        value = ns.ParseColor(value)
        if not value then return false end
    else return false end
    ns.db.bars[key][field] = value
    ns.Changed()
    return true
end

function ns.ResetSettings()
    VV.db.nameplates.swingTimers = {}
    ns.InitDB()
    ns.preview = false
    ns.Changed()
end

function ns.Slash(message)
    local args = {}
    for word in (message or ""):lower():gmatch("%S+") do args[#args + 1] = word end
    local command = args[1]
    if not command or command == "options" or command == "config" then
        if ns.OpenOptions then ns.OpenOptions() else Help() end
        return
    end
    if command == "help" then Help(); return end
    local barKey = aliases[command]
    if barKey then
        local mode = args[2] or "toggle"
        if mode ~= "on" and mode ~= "off" and mode ~= "toggle" or args[3] then
            ns.Print("Use /vv nameplates " .. command .. " on|off|toggle."); return
        end
        -- An all-toggle enables all unless they are already all enabled.
        local enable = mode == "on"
        if mode == "toggle" then
            enable = false
            EachBar(barKey, function(bar) if not bar.enabled then enable = true end end)
        end
        EachBar(barKey, function(bar) bar.enabled = enable end)
        ns.Print(barKey .. ": " .. (enable and "on" or "off"))
    elseif command == "show" or command == "visibility" or command == "mode"
        or command == "always" or command == "combat" then
        local mode = (command == "always" or command == "combat") and command or args[2]
        if mode ~= "always" and mode ~= "combat" and mode ~= "swing" then
            ns.Print("Use /vv nameplates show always|combat|swing."); return
        end
        ns.db.visibility = mode
        ns.Print("Visibility: " .. mode)
    elseif command == "color" or command == "background" or command == "bg" then
        local key, name = aliases[args[2]], ns.ParseColor(args[3])
        local alpha = args[4] and ns.Number(tonumber(args[4]), 0, 1) or nil
        if not key or not name or args[4] and not alpha or args[5] then
            ns.Print("Use /vv nameplates color main|offhand|ranged|all <color> [opacity 0-1]. Try /vv nameplates colors."); return
        end
        alpha = name == "transparent" and 0 or (alpha or 1)
        EachBar(key, function(bar) bar.color, bar.alpha = name, alpha end)
        ns.Print(key .. " fill: " .. name .. " @ " .. alpha)
    elseif command == "bordercolor" then
        local name = ns.ParseColor(args[2])
        if not name or args[3] then ns.Print("Use /vv nameplates bordercolor white, a named color, or #RRGGBB."); return end
        ns.db.borderColor = name
        ns.Print("Border color: " .. name)
    elseif command == "label" or command == "labelfont" or command == "labelsize"
        or command == "labelalign" or command == "labelcolor" then
        local key = aliases[args[2] or ""]
        if not key or not args[3] or args[4] then
            ns.Print("Use /vv nameplates " .. command .. " main|offhand|ranged|all <value>."); return
        end
        local field = ({label = "labelEnabled", labelfont = "labelFont", labelsize = "labelSize",
            labelalign = "labelAlign", labelcolor = "labelColor"})[command]
        local value = args[3]
        if command == "label" then
            if value ~= "on" and value ~= "off" then ns.Print("Use on or off for labels."); return end
            value = value == "on"
        elseif command == "labelsize" then value = tonumber(value)
        elseif command == "labelalign" then value = value:upper() end
        local valid = true
        if key == "all" then
            for _, name in ipairs(ns.order) do if not ns.SetBarValue(name, field, value) then valid = false end end
        else valid = ns.SetBarValue(key, field, value) end
        if not valid then ns.Print("Invalid label value. Fonts: montserrat, arial, friz, morpheus; size: 6-24; alignment: left, center, right.") end
        return
    elseif command == "layout" then
        if args[3] or not ns.SetValue("layout", args[2]) then ns.Print("Use /vv nameplates layout stack|row.") end
        return
    elseif command == "spark" then
        local mode = args[2] or "toggle"
        if mode ~= "on" and mode ~= "off" and mode ~= "toggle" then
            ns.Print("Use /vv nameplates spark on or /vv nameplates spark off."); return
        end
        ns.db.spark = mode == "on" or mode == "toggle" and not ns.db.spark
        ns.Print("Spark: " .. (ns.db.spark and "on" or "off"))
    elseif command == "effect" or command == "animation" then
        local key, effect = aliases[args[2]], args[3]
        if not key then key, effect = "all", args[2] end
        -- 'off' alone is the effect, rather than the off-hand alias.
        if args[2] == "off" and not args[3] then key, effect = "all", "off" end
        if not ns.effects[effect or ""] or args[4] then
            ns.Print("Use /vv nameplates effect [main|offhand|ranged|all] off|pulse."); return
        end
        EachBar(key, function(bar) bar.effect = effect end)
        ns.Print(key .. " effect: " .. effect)
    elseif command == "preview" or command == "test" then
        local mode = args[2] or "toggle"
        if mode ~= "on" and mode ~= "off" and mode ~= "toggle" then
            ns.Print("Use /vv nameplates preview on|off."); return
        end
        ns.preview = mode == "on" or mode == "toggle" and not ns.preview
        ns.Print("Preview " .. (ns.preview and "on: synthetic swings, including unequipped weapons." or "off."))
    elseif command == "colors" then
        local names = { "transparent" }
        for name in pairs(ns.colors) do names[#names + 1] = name end
        table.sort(names)
        for i = 1, #names, 12 do
            local row = {}
            for j = i, math.min(i + 11, #names) do row[#row + 1] = names[j] end
            ns.Print(table.concat(row, ", "))
        end
        ns.Print("Also accepts gray/grey aliases and hex #RGB or #RRGGBB; fill opacity defaults to 1.")
        return
    elseif command == "status" then Status(); return
    elseif command == "reset" then
        ns.ResetSettings()
        ns.Print("Defaults restored.")
        return
    else
        local setting = ({ offset = "y", ypos = "y", xpos = "x", effectalpha = "effectAlpha",
            borderalpha = "borderAlpha", sparkalpha = "sparkAlpha", gradientleft = "gradientLeft",
            gradientright = "gradientRight", sparksize = "sparkSize", borderradius = "borderRadius",
            radius = "borderRadius" })[command] or command
        local limits = ns.limits[setting]
        if not limits then ns.Print("Unknown command. Use /vv nameplates help."); return end
        local value = ns.Number(tonumber(args[2]), limits[1], limits[2])
        if not value or args[3] then
            ns.Print(string.format("Use /vv nameplates %s <number %g to %g>.", command, limits[1], limits[2])); return
        end
        ns.db[setting] = value
        ns.Print(setting .. ": " .. value)
    end
    ns.Changed()
end
