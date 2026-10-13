local vv, ns = VV_TEST_NS, VV_TEST_NS.Nameplates
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
check(table.concat(vv.PresetNames(), ",") == "Default,Default (tight),Swing timer row", "All built-in presets are available in order")
check(ns.db.y == 37 and ns.ComboPoints.db.y == 24 and vv.db.questTracker.completedSort == "bottom",
    "Fresh characters use the complete new Default design")
vv.QuestTracker.SetOption("completedSort", "top")
vv.QuestTracker.ResetOptions()
check(vv.db.questTracker.completedSort == "bottom", "Tracker reset uses the new Default sorting choice")
check(#vv.ProfileNames() == 0, "Built-ins do not populate the editable account library")
vv.profilesLink.scripts.OnClick()
check(vv.profilesPanel:IsShown(), "Main-page link opens Profiles & Presets")
SlashCmdList.VANILLAVARNISH("profiles")
check(vv.profilesPanel:IsShown(), "Profiles slash command opens the new category")
vv.SaveProfile("Default")
local saved = vv.profileStore.Default
ns.SetValue("width", 301)
vv.SaveProfile("Default")
check(vv.LoadPreset("Default (tight)"), "Tight preset applies")
check(ns.db.width == 200 and ns.db.y == 5 and ns.ComboPoints.db.y == 14,
    "Tight preset keeps the captured layout")
check(vv.db.presetName == "Default (tight)" and not vv.db.profileName and not vv.PresetModified(), "Active preset status starts clean")
check(vv.profileStore.Default.settings.nameplates.swingTimers.width == 301 and saved ~= vv.profileStore.Default,
    "Presets never overwrite even a same-name account profile")
local copy = vv.GetPreset("Default")
copy.nameplates.swingTimers.width = 399
check(vv.GetPreset("Default").nameplates.swingTimers.width == 200, "Returned designs cannot mutate the built-in library")
local refs = {vv.db.nameplates, ns.db, ns.db.bars.main, ns.ComboPoints.db, vv.db.questTracker, vv.Tooltips.db}
vv.db.questTracker.collapsed.Elwynn = true
local ui = vv.presetControls
for _, choice in ipairs(Mock.Menu(ui.dropdown)) do
    if choice.name == "Swing timer row" then choice.callback() end
end
check(ns.db.layout == "stack" and vv.selectedPreset == "Swing timer row", "Selecting a preset waits for Apply")
ui.apply.scripts.OnClick()
check(ns.db.layout == "row" and ns.db.width == 200 and ns.db.y == 5 and ns.ComboPoints.db.y == 14,
    "Row preset retains the tight design and total span")
check(vv.db.questTracker.collapsed.Elwynn and ns.db == refs[2] and ns.db.bars.main == refs[3]
    and vv.db.nameplates == refs[1] and ns.ComboPoints.db == refs[4] and vv.db.questTracker == refs[5]
    and vv.Tooltips.db == refs[6], "Applying presets preserves personal quest folds and module table references")
check(not vv.PresetModified() and vv.profileControls.status:GetText() == "Current preset: Swing timer row", "Preset status identifies the loaded design")
ns.SetValue("gap", 3)
check(vv.PresetModified() and vv.profileControls.status:GetText():find("modified locally", 1, true), "Local edits mark presets modified")
vv.SaveProfile("My row")
check(vv.profileStore["My row"].settings.nameplates.swingTimers.layout == "row" and not vv.db.presetName,
    "A row can be saved as an editable profile")
vv.LoadPreset("Default")
check(vv.LoadProfile("My row") and ns.db.layout == "row" and not vv.db.presetName, "Loading a profile restores its layout")
vv.LoadPreset("Default")
vv.SaveProfile("Older profile")
vv.profileStore["Older profile"].settings.nameplates.swingTimers.layout = nil
ns.SetValue("layout", "row")
check(vv.LoadProfile("Older profile") and ns.db.layout == "stack" and not vv.ProfileModified(),
    "Older profiles retain stacked layout and clean status without rewriting the library")
check(vv.profileStore["Older profile"].settings.nameplates.swingTimers.layout == nil, "Older saved record stays intact")
Mock.lockdown = true
Mock.Event("PLAYER_REGEN_DISABLED")
check(not ui.apply:IsEnabled() and not vv.LoadPreset("Swing timer row") and ns.db.layout == "stack", "Combat blocks preset application")
Mock.lockdown = false
Mock.Event("PLAYER_REGEN_ENABLED")
check(ui.apply:IsEnabled() and not vv.LoadPreset("Missing"), "Combat end re-enables Apply; unknown presets preserve settings")

-- Geometric checks use actual widget sizes and anchors at several pixel scales.
local stack = ns.CreateStack(UIParent)
ns.SetValue("layout", "row")
for _, geometry in ipairs({{768, 1}, {1080, 0.8}, {1440, 1.15}, {2160, 0.65}}) do
    Mock.screenHeight = geometry[1]
    UIParent:SetScale(geometry[2])
    for _, width in ipairs({30, 199, 200, 400}) do
        for _, gap in ipairs({0, 2, 12}) do
            ns.SetValue("width", width)
            ns.SetValue("gap", gap)
            ns.SetValue("y", 0)
            ns.SetBarValue("ranged", "labelEnabled", true)
            ns.SetBarValue("ranged", "labelSize", 24)
            local baseline
            for mask = 0, 7 do
                local shown = {}
                for index, key in ipairs(ns.order) do shown[key] = math.floor(mask / 2^(index-1)) % 2 == 1 end
                ns.LayoutStack(stack, shown, UIParent, 32)
                ns.RenderStack(stack, 0, function() return 0.5 end)
                local right, count = 0, 0
                for _, key in ipairs(ns.order) do
                    local bar = stack.bars[key]
                    check(bar:IsShown() == shown[key], "Row shows only active timers")
                    if shown[key] then
                        local point = bar.points[1]
                        check(near(point[4], count == 0 and 0 or right + stack.gap) and point[5] == 0,
                            "Visible row timers pack left in weapon order with the requested gap")
                        check(bar.innerWidth > 0 and bar.innerHeight > 0, "Even the smallest row keeps a drawable interior")
                        right, count = point[4] + bar.width, count + 1
                    end
                end
                check(stack:IsShown() == (count > 0), "An empty row hides")
                if count > 0 then
                    check(near(stack.height, stack.barHeight), "Row occupies one timer's height")
                    check(stack.offset - stack.bars.ranged.visualPadding >= 32 + 2 * stack.pixel - 0.00001,
                        "All row artwork clears cast bounds")
                    baseline = baseline or stack.offset
                    check(near(stack.offset, baseline), "Changing visible timers never changes row height or vertical placement")
                end
                if mask == 7 then
                    check(near(right, stack.width), "All three timers fill the exact total span")
                    local rowWidth = stack.width
                    ns.SetValue("layout", "stack")
                    ns.LayoutStack(stack, shown, UIParent, 32)
                    check(near(stack.width, rowWidth), "Stacked and row layouts share the same overall horizontal footprint")
                    check(stack.bars.main.points[1][4] == 0 and stack.bars.offhand.points[1][5] < 0,
                        "Switching layout restores vertical anchors immediately")
                    ns.SetValue("layout", "row")
                end
            end
        end
    end
end
UIParent:SetScale(1)
Mock.screenHeight = 768
vv.LoadPreset("Swing timer row")
check(ns.optionsPreviewNameplate.swingStack.bars.offhand.points[1][5] == 0, "Menu preview uses the row layout")
ns.optionControls.layout.dropdown.menuGenerator(ns.optionControls.layout.dropdown, {
    CreateRadio = function(_, name, selected, callback) if name == "Stacked" then callback() end end,
})
check(ns.db.layout == "stack" and vv.PresetModified(), "Layout dropdown changes a preset locally")
SlashCmdList.VANILLAVARNISH("nameplates layout row")
check(ns.db.layout == "row", "Slash command can choose Row")
check(not ns.SetValue("layout", "bad"), "Invalid layout leaves the design intact")
VV_PRESET_CHECKS = checks
