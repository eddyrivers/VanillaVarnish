local _, VV = ...

-- Built-in designs are separate from the account's editable profile library.
local presets = {
    ["Default"] = {
        ["modules"] = {
            ["nameplates"] = true,
            ["party"] = true,
            ["questTracker"] = true,
            ["tooltips"] = true,
        },
        ["nameplates"] = {
            ["comboPoints"] = {
                ["gap"] = 4,
                ["size"] = 12,
                ["x"] = 17,
                ["y"] = 21,
            },
            ["comboPointsEnabled"] = true,
            ["markers"] = true,
            ["questieFallback"] = false,
            ["rangeEnabled"] = true,
            ["rangeOpacity"] = 0.5,
            ["swingTimers"] = {
                ["appearanceVersion"] = 9,
                ["bars"] = {
                    ["main"] = {
                        ["alpha"] = 1,
                        ["color"] = "red",
                        ["effect"] = "pulse",
                        ["enabled"] = true,
                        ["labelAlign"] = "RIGHT",
                        ["labelColor"] = "white",
                        ["labelEnabled"] = false,
                        ["labelFont"] = "arial",
                        ["labelSize"] = 14,
                    },
                    ["offhand"] = {
                        ["alpha"] = 1,
                        ["color"] = "red",
                        ["effect"] = "pulse",
                        ["enabled"] = true,
                        ["labelAlign"] = "RIGHT",
                        ["labelColor"] = "white",
                        ["labelEnabled"] = false,
                        ["labelFont"] = "arial",
                        ["labelSize"] = 14,
                    },
                    ["ranged"] = {
                        ["alpha"] = 1,
                        ["color"] = "warmyellow",
                        ["effect"] = "pulse",
                        ["enabled"] = true,
                        ["labelAlign"] = "RIGHT",
                        ["labelColor"] = "white",
                        ["labelEnabled"] = false,
                        ["labelFont"] = "arial",
                        ["labelSize"] = 14,
                    },
                },
                ["borderAlpha"] = 0.3,
                ["borderColor"] = "white",
                ["borderRadius"] = 5,
                ["effectAlpha"] = 0.35,
                ["gap"] = 2,
                ["gradientLeft"] = 0.4,
                ["gradientRight"] = 0.85,
                ["height"] = 10,
                ["layout"] = "stack",
                ["spark"] = true,
                ["sparkAlpha"] = 1,
                ["sparkSize"] = 12,
                ["visibility"] = "swing",
                ["width"] = 200,
                ["x"] = 20,
                ["y"] = 37,
            },
            ["swingsEnabled"] = true,
            ["threatColorsEnabled"] = true,
        },
        ["party"] = {
            ["buffs"] = true,
            ["classColors"] = true,
            ["rangeFade"] = true,
        },
        ["questTracker"] = {
            ["completedSort"] = "bottom",
            ["enabled"] = true,
        },
        ["tooltips"] = {
            ["followMouse"] = true,
            ["offsetX"] = 34,
            ["offsetY"] = -6,
            ["pauseInCombat"] = false,
            ["unitColors"] = true,
        },
    },
}

presets["Default (tight)"] = VV.Copy(presets["Default"])
presets["Default (tight)"].nameplates.swingTimers.y = 5
presets["Default (tight)"].nameplates.comboPoints.y = 14

presets["Swing timer row"] = VV.Copy(presets["Default (tight)"])
presets["Swing timer row"].nameplates.swingTimers.layout = "row"

function VV.PresetNames()
    return {"Default", "Default (tight)", "Swing timer row"}
end

function VV.GetPreset(name)
    if presets[name] then return VV.Copy(presets[name]) end
end
