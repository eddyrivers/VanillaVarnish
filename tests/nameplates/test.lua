local ns = NST_TEST_NS
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message or ("Check " .. checks .. " failed"))
end
local function Near(a, b) return math.abs(a - b) < 0.00001 end
local function Cmd(text) VV_TEST_NS.Nameplates.HandleSlash(text) end

Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
Check(SLASH_VANILLAVARNISH1 == "/vv" and SLASH_NAMEPLATETWEAKS1 == nil and SLASH_NAMEPLATESWINGTIMERS1 == nil
    and SLASH_NAMEPLATESWINGTIMERS2 == nil and SlashCmdList.NAMEPLATESWINGTIMERS == nil, "Only the unified slash handler is registered")
Check(ns.db.width == 200 and ns.db.height == 10 and ns.db.y == 46 and ns.db.x == 20 and ns.db.gap == 2 and ns.db.effectAlpha == 0.35)
Check(ns.db.visibility == "swing", "While swinging is the default visibility")
Cmd("show combat")
Check(ns.db.borderRadius == 5 and ns.db.bars.main.color == "red" and ns.db.bars.offhand.color == "red"
    and ns.db.bars.ranged.color == "warmyellow", "Requested new appearance defaults")
local target = Mock.Plate("nameplate1")
local soft = Mock.Plate("nameplate2")
Mock.plates.target, Mock.plates.softenemy = target, soft
Mock.units.target, Mock.units.softenemy = true, true
Mock.Event("PLAYER_TARGET_CHANGED")
local stack = Mock.Stack(target)
Check(not stack:IsShown(), "Combat mode must hide outside combat")
Mock.combat = true
Mock.Event("PLAYER_REGEN_DISABLED")
Check(stack:IsShown() and stack.bars.main:IsShown() and stack.bars.ranged:IsShown())
Check(not stack.bars.offhand:IsShown(), "No off-hand weapon")
Check(stack.bars.main.offset == 0 and stack.bars.ranged.offset == 12, "Collapse missing OH")
Check(stack.height == 22 and stack.points[1][5] == -46)
Check(stack.anchor == target.UnitFrame.HealthBarsContainer)
Check(stack.bars.main.fill.alpha == 0)
Check(stack.bars.main.fillRows[3][1].gradient[2].a == 0.4 and stack.bars.main.fillRows[3][1].gradient[3].a == 0.85)
Check(Near(stack.bars.main.fillRows[3][1].gradient[2].g, 0) and Near(stack.bars.main.fillRows[3][1].gradient[2].b, 0))
Check(stack.bars.main.borderRows[1][1].color[4] == 0.3 and not stack.mouse)

Mock.Event("PLAYER_SWING", 2, Enum.PlayerSwingType.MainHand)
Check(not stack.bars.main.fill:IsShown(), "A new swing starts empty")
Mock.Tick(1)
Check(Near(stack.bars.main.fill.width, 98), "Half progress must occupy half the interior")
Check(stack.bars.main.sparkFrame:IsShown() and stack.bars.main.sparkAnim:IsPlaying())
Check(stack.bars.main.spark.atlas == "ui-castingbar-pip", "Reuse Blizzard spark art")
Mock.Event("PLAYER_SWING", 2, Enum.PlayerSwingType.MainHand)
Check(not stack.bars.main.fill:IsShown(), "Next native swing resets")
Mock.Tick(2)
Check(not stack.bars.main.fill:IsShown(), "Expired swing clears without an invented cycle")
Check(not stack.bars.main.sparkFrame:IsShown() and not stack.bars.main.sparkAnim:IsPlaying())
Mock.Tick(3)
Check(not stack.bars.main.fill:IsShown())

Cmd("all off")
Cmd("ranged on")
Check(stack.bars.ranged.offset == 0 and stack.height == 10, "Ranged-only has no holes")
Check(not stack.bars.main:IsShown() and not stack.bars.offhand:IsShown())
Cmd("all toggle")
Check(ns.db.bars.main.enabled and ns.db.bars.offhand.enabled and ns.db.bars.ranged.enabled)
Cmd("all toggle")
Check(not stack:IsShown())
Cmd("mh on"); Cmd("oh on"); Cmd("ranged on")
Mock.speeds[2] = 1.5
Mock.Event("UNIT_ATTACK_SPEED", "player")
Check(stack.bars.offhand.offset == 12 and stack.bars.ranged.offset == 24 and stack.height == 34)
Cmd("offhand off")
Check(stack.bars.ranged.offset == 12)
Cmd("main off")
Check(stack.bars.ranged.offset == 0)
Cmd("all on")

Cmd("show always")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
Check(stack:IsShown(), "Always mode shows out of combat")
Cmd("show combat")
Check(not stack:IsShown())
Cmd("show swing")
Check(not stack:IsShown(), "No active swings")
Mock.Event("PLAYER_SWING", 3, Enum.PlayerSwingType.Ranged)
Check(stack.bars.ranged:IsShown() and stack.bars.ranged.offset == 0)
Mock.Event("PLAYER_SWING", 1.5, Enum.PlayerSwingType.OffHand)
Check(stack.bars.offhand.offset == 0 and stack.bars.ranged.offset == 12)
Mock.Tick(1.5)
Check(not stack.bars.offhand:IsShown() and stack.bars.ranged.offset == 0)
Mock.Tick(1.5)
Check(not stack:IsShown())

Cmd("always")
Mock.units.target = false
Mock.Event("PLAYER_SOFT_ENEMY_CHANGED")
local softStack = Mock.Stack(soft)
Check(softStack:IsShown() and not stack:IsShown() and ns.anchorUnit == "softenemy")
Mock.units.target = true
Mock.Event("PLAYER_TARGET_CHANGED")
Check(stack:IsShown() and not softStack:IsShown() and ns.anchorUnit == "target")
Mock.plates.target = nil
Mock.Event("PLAYER_TARGET_CHANGED")
Check(not softStack:IsShown() and not stack:IsShown(), "An invisible hard target still takes priority")
Mock.units.target = false
Mock.cvars.SoftTargetEnemy = "0"
Mock.Event("CVAR_UPDATE", "SoftTargetEnemy")
Check(not softStack:IsShown(), "No fallback when action targeting is disabled")
Mock.cvars.SoftTargetEnemy = "1"
Mock.Tick(0.1)
Check(softStack:IsShown())
Mock.units.target, Mock.plates.target = true, target
Mock.Event("PLAYER_TARGET_CHANGED")
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate2")
Check(stack:IsShown(), "Unrelated nameplate removal must not flicker the current stack")
Mock.Event("NAME_PLATE_UNIT_REMOVED", "nameplate1")
Check(not stack:IsShown(), "Current nameplate removal hides immediately")
Mock.plates.target = nil
Mock.Tick(0.1)
Check(not stack:IsShown(), "Removed plate cannot show on its recycled unit")
Mock.plates.target = target
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
Check(stack:IsShown())
target.forbidden = true
Mock.Tick(0.1)
Check(not stack:IsShown(), "Forbidden nameplates are skipped")
target.forbidden = false
Mock.Tick(0.1)
Check(stack:IsShown())

Cmd("width 160"); Cmd("height 7"); Cmd("gap 3"); Cmd("offset 20")
Check(stack.bars.main.width == 160 and stack.bars.main.height == 7)
Check(stack.bars.ranged.offset == 20 and stack.height == 27 and stack.points[1][5] == -20)
for _, command in ipairs({ "width 0", "width 401", "height -1", "y 201", "gap -2",
    "effectalpha nan", "borderalpha 2", "width 120 extra" }) do Cmd(command) end
Check(ns.db.width == 160 and ns.db.height == 7 and ns.db.y == 20 and ns.db.gap == 3)
Check(ns.db.effectAlpha == 0.35 and ns.db.sparkAlpha == 1 and ns.db.borderAlpha == 0.3)
Cmd("y -10")
Check(stack.points[1][5] == 10, "Negative Y moves upward")
Cmd("color main steelblue")
Check(ns.db.bars.main.color == "steelblue" and ns.db.bars.main.alpha == 1)
Check(Near(stack.bars.main.fillRows[3][1].gradient[2].r, 70/255), "Color changes the fill")
Check(stack.bars.main.fill.alpha == 0, "Background remains transparent")
Cmd("bg offhand lavender 0.08")
Check(ns.db.bars.offhand.alpha == 0.08)
Cmd("color ranged #abc 0")
Check(ns.db.bars.ranged.color == "#AABBCC" and ns.db.bars.ranged.alpha == 0)
Cmd("color all #40E0D0 0.1")
Check(ns.db.bars.main.color == "#40E0D0" and ns.db.bars.offhand.alpha == 0.1)
Cmd("color main gray"); Cmd("color main slategrey 0.2")
Check(ns.db.bars.main.color == "slategray")
for _, command in ipairs({"color main nonsense", "color main red -1", "color main blue 2",
    "color unknown blue", "color main #12345", "color main #ABCDEF 0.1 extra"}) do Cmd(command) end
Check(ns.db.bars.main.color == "slategray" and ns.db.bars.main.alpha == 0.2)
Cmd("color all transparent")
Check(stack.bars.main.fill.alpha == 0)
Check(stack.bars.main.fillRows[3][1].gradient[2].a == 0)
Cmd("color all warmyellow")
Mock.Event("PLAYER_SWING", 60, Enum.PlayerSwingType.MainHand)
Mock.Tick(0.1)

for _, effect in ipairs({"pulse", "off"}) do
    Cmd("effect " .. effect); Mock.Tick(0.037)
    Check(stack.bars.main.effect == effect)
    Check(stack.bars.main.fillRows[1][2]:IsShown() == (effect == "pulse"))
end
Cmd("effect flow"); Cmd("effect bubbles")
Check(ns.db.bars.main.effect == "off", "Removed effects are rejected")
Cmd("effect pulse"); Cmd("effectalpha 0"); Mock.Tick(0.05)
Check(not stack.bars.main.fillRows[1][2]:IsShown())
Cmd("borderalpha 0.15")
Check(stack.bars.main.borderRows[1][1].color[4] == 0.15)
Cmd("effectalpha 0.25")
Check(Near(ns.PulseStrength(0), 0) and Near(ns.PulseStrength(0.5), 0.35)
    and Near(ns.PulseStrength(0.9), 0.7) and Near(ns.PulseStrength(1), 1), "Pulse progress anchors")
for i = 1, 30 do
    Mock.Tick(0.17)
    local bar = stack.bars.main
    for _, row in ipairs(bar.fillRows) do
        if row[2]:IsShown() then
            local x = row[2].points[1][4]
            Check(x >= bar.inset and x + row[2].width <= bar.inset + bar.fill.width + 0.00001,
                "Pulse stays inside the filled portion")
        end
    end
end

-- The highlight uses only fill progress, preserving its additive tint without
-- flashing or dimming as unrelated wall-clock time advances.
local pulseStack = ns.CreateStack(UIParent)
local function PulsePixel(bar)
    local row = bar.fillRows[math.ceil(#bar.fillRows / 2)]
    local gradient, overlay = row[1].gradient[2], row[2]
    local rgb = {}
    for index, channel in ipairs({"r", "g", "b"}) do
        local base = row[1]:IsShown() and gradient[channel] * gradient.a or 0
        local light = overlay:IsShown() and overlay.color[index] * overlay.color[4] or 0
        rgb[index] = math.min(1, base + light)
    end
    return rgb
end
local savedGradientLeft, savedGradientRight = ns.db.gradientLeft, ns.db.gradientRight
ns.SetValue("gradientLeft", 1); ns.SetValue("gradientRight", 1)
ns.SetValue("effectAlpha", 1)
for _, color in ipairs({"red", "blue", "lime"}) do
    ns.SetBarValue("main", "color", color)
    ns.SetBarValue("main", "effect", "off")
    ns.LayoutStack(pulseStack, {main = true}, UIParent)
    ns.RenderStack(pulseStack, 0, function() return 0.9 end)
    local base = PulsePixel(pulseStack.bars.main)
    ns.SetBarValue("main", "effect", "pulse")
    ns.LayoutStack(pulseStack, {main = true}, UIParent)
    ns.RenderStack(pulseStack, 1000, function() return 0.9 end)
    local light = PulsePixel(pulseStack.bars.main)
    local difference = math.max(light[1]-base[1], light[2]-base[2], light[3]-base[3])
    Check(difference > 0.6, "100% pulse preserves the visible highlight on an opaque " .. color .. " fill")
    Check(pulseStack.bars.main.fillRows[1][2].blendMode == "ADD", "Highlight really adds light over the fill")
end
ns.SetBarValue("main", "color", "red")
ns.SetValue("effectAlpha", ns.defaults.effectAlpha)
ns.LayoutStack(pulseStack, {main = true}, UIParent)
ns.RenderStack(pulseStack, 0, function() return 0.9 end)
local defaultLight = PulsePixel(pulseStack.bars.main)
Check(defaultLight[2] > 0.1, "Default pulse preserves visible tint on Blizzard red")
Check(defaultLight[2] > defaultLight[3] + 0.02 and defaultLight[2] < defaultLight[3] * 1.25,
    "Default pulse adds a subtle gold warmth instead of a white or saturated yellow highlight")
for _, progress in ipairs({0, 0.5, 0.9, 1}) do
    for _, now in ipairs({0, 0.3, 1.2, 17, 100000}) do
        ns.RenderStack(pulseStack, now, function() return progress end)
        Check(Near(pulseStack.bars.main.pulseOpacity, ns.defaults.effectAlpha * ns.PulseStrength(progress)),
            "The same fill has the same highlight regardless of clock time")
        Check(pulseStack.bars.main.fillRows[3][1].gradient[2].r == 1,
            "Fill keeps its original color instead of independently dimming")
    end
end
local previousOpacity, previousGreen = -1, -1
for step = 0, 100 do
    ns.RenderStack(pulseStack, step * 397.13, function() return step / 100 end)
    local bar, pixel = pulseStack.bars.main, PulsePixel(pulseStack.bars.main)
    Check(bar.pulseOpacity >= previousOpacity and pixel[2] >= previousGreen,
        "Highlight continuously brightens toward 100% fill without intermediate flashes")
    previousOpacity, previousGreen = bar.pulseOpacity, pixel[2]
end
ns.LayoutStack(pulseStack, {main = true, offhand = true, ranged = true}, UIParent)
local weaponProgress = {main = 0.25, offhand = 0.5, ranged = 0.9}
ns.RenderStack(pulseStack, 200, function(key) return weaponProgress[key] end)
for _, key in ipairs(ns.order) do
    Check(Near(pulseStack.bars[key].pulseOpacity, ns.defaults.effectAlpha * ns.PulseStrength(weaponProgress[key])),
        "Each weapon follows its own fill instead of a shared pulse clock")
end
ns.RenderStack(pulseStack, 201, function() return 0 end)
for _, key in ipairs(ns.order) do
    Check(pulseStack.bars[key].pulseOpacity == 0 and not pulseStack.bars[key].fillRows[3][2]:IsShown(),
        "New swings reset the highlight with the empty fill")
end
ns.SetValue("effectAlpha", 0)
ns.LayoutStack(pulseStack, {main = true}, UIParent)
ns.RenderStack(pulseStack, 10, function() return 0.9 end)
Check(PulsePixel(pulseStack.bars.main)[2] == 0 and pulseStack.bars.main.fillRows[3][1].gradient[2].r == 1,
    "Zero strength preserves the original fill with no highlight")
ns.SetBarValue("main", "effect", "off"); ns.SetValue("effectAlpha", 1)
ns.LayoutStack(pulseStack, {main = true}, UIParent)
ns.RenderStack(pulseStack, 10, function() return 0.9 end)
Check(pulseStack.bars.main.fillRows[3][1].gradient[2].r == 1 and not pulseStack.bars.main.fillRows[1][2]:IsShown(),
    "Disabling pulse restores the original fill regardless of strength")
ns.SetBarValue("main", "effect", "pulse")
ns.SetValue("gradientLeft", savedGradientLeft); ns.SetValue("gradientRight", savedGradientRight)
ns.SetValue("effectAlpha", 0.25); ns.SetBarValue("main", "color", "warmyellow")
pulseStack:Hide()

Mock.Event("PLAYER_SWING", 4, Enum.PlayerSwingType.MainHand)
Mock.Tick(1)
Mock.speeds[1] = 2
Mock.Event("WEAPON_SLOT_CHANGED")
Check(not stack.bars.main.fill:IsShown(), "Weapon swap resets an existing timer")
Mock.Tick(1)
Check(Near(stack.bars.main.fill.width, (ns.db.width-4)/2))
Mock.speeds[2], Mock.speeds[3] = nil, nil
Mock.Event("UNIT_ATTACK_SPEED", "player")
Check(not stack.bars.offhand:IsShown() and not stack.bars.ranged:IsShown() and stack.height == 7)
Cmd("combat"); Check(not stack:IsShown())
Cmd("preview on")
Check(stack:IsShown() and stack.bars.offhand:IsShown() and stack.bars.ranged:IsShown())
Mock.Tick(0.05)
Check(stack.bars.ranged.fill:IsShown(), "Preview simulates unequipped weapon timers")
Cmd("ranged off")
Check(not stack.bars.ranged:IsShown(), "Preview respects toggles")
Cmd("preview off")
Check(not stack:IsShown(), "Preview does not change configured combat visibility")
Cmd("show swing")
Mock.Tick(3)
Check(not stack:IsShown(), "Preview must not leave fake timers in live state")
Mock.units.target, Mock.units.softenemy = false, false
Cmd("preview on")
Check(ns.anchorUnit == "preview")
local dummy
for _, frame in ipairs(Mock.frames) do
    if frame.bars and frame.parent ~= target and frame.parent ~= soft then dummy = frame end
end
Check(dummy and dummy:IsShown() and dummy.parent:IsShown())
Cmd("preview off")
Check(not dummy:IsShown() and not dummy.parent:IsShown())

-- Secret values never reach arithmetic, comparisons, or table indexes.
local secret = setmetatable({ secret = true }, {
    __add = function() error("secret arithmetic") end,
    __lt = function() error("secret comparison") end,
    __tostring = function() error("secret formatting") end,
})
Mock.units.target, Mock.plates.target = true, target
Cmd("always")
Mock.Event("PLAYER_SWING", secret, Enum.PlayerSwingType.MainHand)
Mock.Event("PLAYER_SWING", 2, secret)
Mock.Event("PLAYER_SWING", 0, Enum.PlayerSwingType.MainHand)
Mock.speeds = { secret, secret, secret }
Mock.Event("UNIT_ATTACK_SPEED", "player")
Check(stack.bars.main:IsShown(), "Preserve last known availability for secret speeds")
Check(not stack.bars.offhand:IsShown(), "Do not invent missing weapons from secret data")
Mock.Event("PLAYER_SWING", 1, Enum.PlayerSwingType.OffHand)
Check(stack.bars.offhand:IsShown(), "A native swing proves availability")
Mock.Event("PLAYER_DEAD")
Check(not stack.bars.offhand.fill:IsShown())

Cmd("colors"); Cmd("status"); Cmd("help")
Check(#Mock.messages > 20)
VV_TEST_NS.db.nameplates.swingTimers.width = "bad"
VV_TEST_NS.db.nameplates.swingTimers.height = 99
VV_TEST_NS.db.nameplates.swingTimers.bars.main = false
VV_TEST_NS.db.nameplates.swingTimers.bars.offhand.effect = {}
ns.InitDB()
Check(ns.db.width == 200 and ns.db.height == 10 and ns.db.bars.main.enabled)
Check(ns.db.bars.offhand.effect == "pulse", "Recover corrupted saved settings")
Cmd("color main coral 0.16")
ns.InitDB()
Check(ns.db.bars.main.color == "coral" and ns.db.bars.main.alpha == 0.16, "Preserve saved configuration")
Cmd("reset")
Check(ns.db.visibility == "swing" and ns.db.y == 46 and not ns.preview)
Check(ns.db.bars.main.color == "red" and ns.db.bars.ranged.enabled)

-- Border, padding, and corner radius retain physical pixel size at different
-- nameplate scales and resolutions, including changes after frame creation.
Cmd("always")
for _, geometry in ipairs({{768, 1}, {1080, 0.8}, {1440, 1.15}, {2160, 0.65}}) do
    Mock.screenHeight = geometry[1]
    target:SetScale(geometry[2])
    Mock.Tick(0.1)
    local bar = stack.bars.main
    local pixel = (768 / Mock.screenHeight) / bar:GetEffectiveScale()
    Check(Near(bar.borderRows[1][1].height / pixel, 1), "1px border at scale")
    Check(Near(bar.inset / pixel, 2), "1px stroke plus 1px gap")
    Check(Near(bar.radius, math.min(5 * pixel, bar.barHeight / 2)) and Near(bar.fillRadius, math.max(0, bar.radius - 2 * pixel)), "Concentric corner radii")
    Check(Near(bar.width / pixel, math.floor(bar.width / pixel + 0.5)), "Width aligns to screen pixels")
    Check(Near(bar.height / pixel, math.floor(bar.height / pixel + 0.5)), "Height aligns to screen pixels")
    Check(bar.roundToPixel and bar.fill.roundToPixel)

end
VV_TEST_NS.db.nameplates.swingTimers.appearanceVersion = nil
VV_TEST_NS.db.nameplates.swingTimers.height = 5
ns.InitDB()
Check(ns.db.height == 10 and ns.db.appearanceVersion == 9, "Migrate original height")
VV_TEST_NS.db.nameplates.swingTimers.appearanceVersion = nil
VV_TEST_NS.db.nameplates.swingTimers.height = 7
ns.InitDB()
Check(ns.db.height == 7, "Preserve custom height")
Cmd("height 5")
ns.InitDB()
Check(ns.db.height == 5, "Allow an explicit smaller height after migration")

-- Options page construction, control callbacks, preview isolation, and picker
-- cancellation are exercised against the same setting setters as the CLI.
Mock.screenHeight = 768
target:SetScale(1)
Cmd("reset")
Check(Mock.addonCategory.name == "VanillaVarnish", "Registered in AddOns settings")
ns.OpenSwingOptions()
Check(ns.optionsPanel:IsShown() and ns.optionsPreview, "Prebuilt options page opens correctly")
local ui = ns.optionControls
for key in pairs(ns.limits) do Check(ui[key], "Missing settings control: " .. key) end
for _, name in ipairs(ns.order) do
    for _, field in ipairs({"enabled", "color", "alpha", "effect"}) do
        Check(ui[name .. "." .. field], "Missing per-bar control")
    end
end
Check(not ns.preview, "The embedded preview does not enable world preview")
Check(ns.optionsPreview.bars.offhand:IsShown(), "Options preview shows equipped or unequipped enabled bars")
-- Square fill makes the gradient endpoints visible; rounded slices sample
-- inside the gradient because the circle removes their outside corners.
Cmd("borderradius 0")
Cmd("effect off") -- Inspect configured colors without animated brightness modulation.
Check(ns.optionsPreview.bars.main.fillRows[3][1].gradient[2].a == 0.4 and ns.optionsPreview.bars.main.fillRows[3][1].gradient[3].a == 0.85)
ui.width.slider:SetValue(180)
Check(ns.db.width == 180 and ns.optionsPreview.bars.main.width == 180, "Slider applies instantly")
ui.x.slider:SetValue(25)
Check(ns.db.x == 25 and ns.optionsPreview.points[1][4] == 25, "GUI X offset")
Cmd("x -20")
Check(ui.x.slider.value == -20 and ns.optionsPreview.points[1][4] == -20, "CLI refreshes GUI")
ui.width.box:SetFocus(); ui.width.box:SetText("201")
ui.width.box.scripts.OnEnterPressed()
Check(ns.db.width == 201 and not ui.width.box:HasFocus(), "Typed numeric value")
ui.width.box:SetFocus(); ui.width.box:SetText("401")
ui.width.box.scripts.OnEnterPressed()
Check(ns.db.width == 201 and ui.width.box:GetText() == "201", "Invalid input restores current value")
ui.width.box:SetFocus(); ui.width.box:SetText("220")
ui.width.box.scripts.OnEscapePressed()
Check(ns.db.width == 201, "Escape discards uncommitted slider entry")
ui.borderAlpha.box:SetFocus(); ui.borderAlpha.box:SetText("55")
ui.borderAlpha.box.scripts.OnEnterPressed()
Check(Near(ns.db.borderAlpha, 0.55), "GUI opacity uses percent")
local modes = Mock.Menu(ui.visibility.dropdown)
modes[2].callback()
Check(ns.db.visibility == "always" and ui.visibility.dropdown.selectionText == "Always")
ui["offhand.enabled"].button:SetChecked(false)
ui["offhand.enabled"].button.scripts.OnClick(ui["offhand.enabled"].button)
Check(not ns.db.bars.offhand.enabled and not ns.optionsPreview.bars.offhand:IsShown())
Check(ns.optionsPreview.bars.ranged.offset == 12, "Preview collapses disabled bars")
ui["main.color"].swatch.scripts.OnClick()
Check(ColorPickerFrame:IsShown(), "Color swatch opens picker")
Mock.Pick(0.25, 0.5, 0.75)
Check(ns.db.bars.main.color == "#4080BF", "Picker updates live")
Check(Near(ns.optionsPreview.bars.main.fillRows[3][1].gradient[2].r, 64/255))
Mock.CancelPicker()
Check(ns.db.bars.main.color == "red" and ns.db.bars.main.alpha == 1, "Cancel restores color and opacity")
ui["main.color"].swatch.scripts.OnClick()
Mock.Pick(1, 0.5, 0)
ColorPickerFrame:Hide()
Check(ns.db.bars.main.color == "#FF8000", "Picker commits when closed")
ui.borderColor.swatch.scripts.OnClick()
Mock.Pick(0, 0.5, 1)
ColorPickerFrame:Hide()
Check(ns.db.borderColor == "#0080FF" and Near(ns.optionsPreview.bars.main.borderRows[1][1].color[2], 128/255))
Cmd("bordercolor gold")
Check(Near(ns.optionsPreview.bars.main.borderRows[1][1].color[2], 215/255), "CLI border color")
Check(Near(ns.optionsPreview.bars.main.borderRows[2][1].color[2], 215/255), "Rounded corners share border color")
Cmd("gradientleft 0.3"); Cmd("gradientright 0.9")
Check(ui.gradientLeft.slider.value == 0.3 and Near(ns.optionsPreview.bars.main.fillRows[3][1].gradient[3].a, 0.9))
local choices = Mock.Menu(ui["main.effect"].dropdown)
Check(#choices == 2, "Only none and pulse appear in the menu")
choices[2].callback()
Check(ns.db.bars.main.effect == "pulse" and ns.optionsPreview.bars.main.pulseOpacity > 0)
local spark = ns.optionsPreview.bars.main
Check(spark.sparkAnim:IsPlaying() and spark.sparkAnim.looping == "REPEAT")
Check(#spark.sparkAnim.animations == 4 and spark.sparkAnim.animations[1].fromAlpha ~= spark.sparkAnim.animations[1].toAlpha)
ui.spark.button:SetChecked(false); ui.spark.button.scripts.OnClick(ui.spark.button)
Check(not ns.db.spark and not spark.sparkFrame:IsShown() and not spark.sparkAnim:IsPlaying())
Cmd("spark on")
Check(ui.spark.button:GetChecked() and spark.sparkAnim:IsPlaying())
Cmd("spark off")
Check(not ui.spark.button:GetChecked() and not spark.sparkAnim:IsPlaying(), "Slash command disables spark and synchronizes the menu")
Cmd("spark on")
ui["main.color"].box:SetText("steelblue")
ui["main.color"].box.scripts.OnEnterPressed()
Check(ns.db.bars.main.color == "steelblue")
ui["main.alpha"].slider:SetValue(0.5)
Check(Near(spark.fillRows[3][1].gradient[2].a, 0.15) and Near(spark.fillRows[3][1].gradient[3].a, 0.45), "Per-bar opacity multiplies gradient")
local presets = Mock.Menu(ui["main.color"].palette)
Check(#presets == 4 and #presets[1].items > 0, "Palette uses bounded submenus")
presets[4].callback()
Check(ns.db.bars.main.color == "transparent" and ns.db.bars.main.alpha == 0)
ui["main.alpha"].slider:SetValue(1)
Check(ns.db.bars.main.color == "red", "Raising transparent fill opacity restores a visible color")
ui.preview.button:SetChecked(true); ui.preview.button.scripts.OnClick(ui.preview.button)
Check(ns.preview)
ui.preview.button:SetChecked(false); ui.preview.button.scripts.OnClick(ui.preview.button)
Check(not ns.preview)
ui.disableAll.button.scripts.OnClick(); Check(not ns.optionsPreview:IsShown())
ui.enableAll.button.scripts.OnClick(); Check(ns.optionsPreview:IsShown())
ui.reset.button.scripts.OnClick()
Check(ns.db.width == 200 and ns.db.x == 20 and ns.db.borderColor == "white" and ns.db.bars.main.color == "red")
Check(ui.width.slider.value == 200 and ui.gradientLeft.slider.value == 0.4)
ns.optionsPanel:Hide()
Check(not spark.sparkAnim:IsPlaying(), "Closing options stops its preview spark animation")
Cmd("")
Check(ns.featurePanels.main:IsShown(), "Bare nameplate command opens the main page")
local firstMessage = #Mock.messages + 1
Cmd("help")
for i = firstMessage, #Mock.messages do
    Check(not Mock.messages[i]:match("|r (.*)$"):find("|"), "Help avoids pipe separators that WoW consumes")
    Check(#Mock.messages[i] < 150, "Help lines remain short")
end
VV_TEST_NS.db.nameplates.swingTimers.appearanceVersion = 2
VV_TEST_NS.db.nameplates.swingTimers.width = 120
VV_TEST_NS.db.nameplates.swingTimers.effectAlpha = 0.045
VV_TEST_NS.db.nameplates.swingTimers.bars.main = { enabled = false, color = "coral", alpha = 0.12, effect = "flow" }
VV_TEST_NS.db.nameplates.swingTimers.bars.ranged.color = "transparent"
ns.InitDB()
Check(ns.db.width == 200 and ns.db.effectAlpha == 0.35, "Migrate old defaults")
Check(ns.db.bars.main.color == "coral" and ns.db.bars.main.alpha == 1 and not ns.db.bars.main.enabled, "Migrate chosen background color to fill")
Check(ns.db.bars.ranged.color == "warmyellow" and ns.db.bars.ranged.alpha == 1)
Check(ns.db.bars.main.effect == "pulse", "Removed saved effects migrate to pulse")

-- Each nameplate feature has its own switch and settings page.
Cmd("reset")
Check(#Mock.categories == 8 and Mock.categories[1].name == "VanillaVarnish" and Mock.categories[3].name == "Nameplates")
for i, name in ipairs({"Range check", "Quest icons", "Swing timers", "Combo points"}) do
    Check(Mock.categories[i + 3].name == name and Mock.categories[i + 3].parent == ns.rootCategory)
end
local nt = VV_TEST_NS.Nameplates.HandleSlash
nt(""); Check(ns.featurePanels.main:IsShown())
nt("range"); Check(ns.featurePanels.rangeEnabled:IsShown())
Cmd("quests"); Check(ns.featurePanels.markers:IsShown())
nt("swings"); Check(ns.optionsPanel:IsShown())
local fc = ns.featureControls
Check(fc.rangeEnabled and fc.markers and fc.swingsEnabled)
fc.damage.box:SetText("Moonfire"); fc.damage.button.scripts.OnClick()
fc.friendly.box:SetText("|cff71d5ff|Hspell:5185:0|h[Healing Touch]|h|r")
fc.friendly.box.scripts.OnEnterPressed()
Check(ns.tweaksDB.damage == "Moonfire" and ns.tweaksDB.friendly == "Healing Touch")
fc.damage.box:SetText("Invalid"); fc.damage.button.scripts.OnClick()
Check(ns.tweaksDB.damage == "Moonfire" and fc.damage.box:GetText() == "Moonfire")
fc.damage.box:SetFocus(); fc.damage.box:SetText("off"); fc.damage.box.scripts.OnEscapePressed()
Check(ns.tweaksDB.damage == "Moonfire")

-- Range master switch restores the original alpha immediately and retains spells.
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
Mock.rangeResult = false
Mock.Tick(0.2)
Check(target.UnitFrame:GetAlpha() == 0.5)
nt("range off")
Check(target.UnitFrame:GetAlpha() == 1 and ns.tweaksDB.damage == "Moonfire")
nt("range on"); Check(target.UnitFrame:GetAlpha() == 0.5)
target.UnitFrame:SetAlpha(0.8)
Check(target.UnitFrame:GetAlpha() == 0.4)
fc.rangeEnabled.button:SetChecked(false); fc.rangeEnabled.button.scripts.OnClick(fc.rangeEnabled.button)
Check(target.UnitFrame:GetAlpha() == 0.8)
Cmd("RANGECHECK on"); Check(target.UnitFrame:GetAlpha() == 0.4)
nt("range off")

-- Fade opacity is configurable and always multiplies Blizzard's baseline alpha.
Check(ns.tweaksDB.rangeOpacity == 0.5, "Preserve the existing default fade")
nt("range opacity 25")
Check(ns.tweaksDB.rangeOpacity == 0.25 and fc.rangeOpacity.slider.value == 0.25
    and fc.rangeOpacity.box:GetText() == "25")
Check(target.UnitFrame:GetAlpha() == 0.8, "Opacity changes do not fade disabled range checks")
nt("range on"); Check(Near(target.UnitFrame:GetAlpha(), 0.2))
target.UnitFrame:SetAlpha(0.6)
Check(Near(target.UnitFrame:GetAlpha(), 0.15), "Custom opacity preserves external alpha changes")
nt("range opacity 0"); Check(target.UnitFrame:GetAlpha() == 0, "Zero opacity hides out-of-range plates")
nt("range opacity 100"); Check(target.UnitFrame:GetAlpha() == 0.6, "Full opacity preserves normal appearance")
nt("range opacity 25")
Mock.rangeResult = nil; Mock.Tick(0.2)
Check(target.UnitFrame:GetAlpha() == 0.6, "Unknown range restores normal opacity")
Mock.rangeResult = secret; Mock.Tick(0.2)
Check(target.UnitFrame:GetAlpha() == 0.6, "Restricted range restores normal opacity")
Mock.rangeResult = false; Mock.friendly = true; Mock.Tick(0.2)
Check(Near(target.UnitFrame:GetAlpha(), 0.15), "Friendly range uses the configured opacity too")
Mock.friendly = false
for _, value in ipairs({"-1", "101", "nan", "50 extra"}) do nt("range opacity " .. value) end
Check(ns.tweaksDB.rangeOpacity == 0.25, "Invalid percentages preserve the saved opacity")
fc.rangeOpacity.slider:SetValue(0.75)
Check(Near(target.UnitFrame:GetAlpha(), 0.45) and fc.rangeOpacity.box:GetText() == "75")
fc.rangeOpacity.box:SetFocus(); fc.rangeOpacity.box:SetText("30")
fc.rangeOpacity.box.scripts.OnEnterPressed()
Check(ns.tweaksDB.rangeOpacity == 0.3 and Near(target.UnitFrame:GetAlpha(), 0.18))
fc.rangeOpacity.box:SetFocus(); fc.rangeOpacity.box:SetText("101")
fc.rangeOpacity.box.scripts.OnEnterPressed()
Check(ns.tweaksDB.rangeOpacity == 0.3 and fc.rangeOpacity.box:GetText() == "30", "Invalid GUI input restores the current value")
Check(not ns.SetRangeOpacity(0/0) and not ns.SetRangeOpacity(secret))
nt("range opacity 50"); nt("range off"); target.UnitFrame:SetAlpha(0.8)

-- Quest icons update immediately, and only the loot icon loses a bottom pixel.
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
local loot, kill
for _, frame in ipairs(Mock.frames) do
    if frame.parent == target.UnitFrame and frame.kind == "loot" then loot = frame end
    if frame.parent == target.UnitFrame and frame.kind == "kill" then kill = frame end
end
Check(loot and loot:IsShown() and kill and kill:IsShown())
local pixel = PixelUtil.GetPixelToUIUnitFactor() / loot:GetEffectiveScale()
Check(Near(loot.icon.points[2][5], pixel) and kill.icon.allPoints ~= nil)
nt("quests off"); Check(not loot:IsShown() and not kill:IsShown())
nt("quests on"); Check(loot:IsShown() and kill:IsShown())
Mock.questComplete = true; Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(not loot:IsShown() and not kill:IsShown())
Mock.questComplete = false

-- Trade goods omitted from native tooltips still mark their known drop sources.
-- IDs rather than item names keep this working on localized clients.
Mock.questEntries = {{questID = 4161}}
Mock.questObjectives = {[4161] = {{text = "Patte d'araignee: 0/7", type = "item", finished = false}}}
Mock.tooltipLines = {}
Mock.itemCounts = {[5465] = 0}
Mock.guids = {nameplate1 = "Creature-0-0-0-0-1998-0"}
nt("questie off")
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(loot:IsShown() and not kill:IsShown(), "Webwood Lurker supplies needed ordinary cooking ingredients without Questie")
for _, npcID in ipairs({1998, 1999, 2000, 2001}) do
    Mock.guids.nameplate1 = "Creature-0-0-0-0-" .. npcID .. "-0"
    Mock.Tick(1)
    Check(loot:IsShown(), "All Webwood spider sources are recognized")
end
Mock.guids.nameplate1 = "Creature-0-0-0-0-123-0"; Mock.Tick(1)
Check(not loot:IsShown(), "Unrelated mobs do not get ingredient icons")
Mock.guids.nameplate1 = "Creature-0-0-0-0-1998-0"
Mock.itemCounts[5465] = 6; Mock.Event("BAG_UPDATE_DELAYED"); Mock.Tick(0.2)
Check(loot:IsShown(), "Six legs still need another drop")
Mock.itemCounts[5465] = 7; Mock.Event("BAG_UPDATE_DELAYED"); Mock.Tick(0.2)
Check(not loot:IsShown(), "Ingredient icon disappears at seven legs even before quest text catches up")
Mock.itemCounts[5465] = 6; Mock.Event("BAG_UPDATE_DELAYED"); Mock.Tick(0.2)
Check(loot:IsShown(), "Spending an ingredient restores the needed-drop icon")
Mock.friendly = true; Mock.Tick(1); Check(not loot:IsShown(), "Only hostile mobs are marked")
Mock.friendly = false
Mock.guids.nameplate1 = secret; Mock.Tick(1); Check(not loot:IsShown(), "Restricted GUIDs cannot create drop relationships")
Mock.guids.nameplate1 = "Creature-0-0-0-0-1998-0"
Mock.itemCounts[5465] = secret; Mock.Event("BAG_UPDATE_DELAYED"); Mock.Tick(0.2)
Check(loot:IsShown(), "Incomplete quest objectives can supply progress when inventory counts are restricted")
Mock.questObjectives[4161][1].finished = true; Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(not loot:IsShown(), "Completed native objective hides icons when bag counts are unknown")
Mock.itemCounts[5465] = 0; Mock.questEntries[1].isComplete = true
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(not loot:IsShown(), "Completed quests never mark ingredient sources")
Mock.questEntries = {}; Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(not loot:IsShown(), "Abandoning or turning in the quest removes ingredient icons")

-- Older clients expose quest IDs through the ninth GetQuestLogTitle result.
local modernLog = C_QuestLog
C_QuestLog = nil
GetNumQuestLogEntries = function() return 1 end
GetQuestLogTitle = function() return "Recipe", 7, nil, false, false, false, nil, nil, 4161 end
GetNumQuestLeaderBoards = function() return 1 end
GetQuestLogLeaderBoard = function() return "Small Spider Leg: 0/7", "item", false end
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(loot:IsShown(), "Legacy quest log also identifies needed ingredients")
C_QuestLog = modernLog

-- Merge optional Questie loot data with a native kill icon, and reject stale
-- entries for quests that are no longer in our own log.
Mock.questEntries, Mock.questObjectives, Mock.itemCounts, Mock.guids = nil, nil, nil, nil
Mock.tooltipLines = {{leftText = "0/10 Wolf slain"}}
local questieObjective = {Type = "item", Collected = 0, Needed = 5}
local tooltipModule = {lookupByKey = {m_123 = {
    {questId = 123, objective = questieObjective},
    {questId = 999, objective = {Type = "event"}},
}}}
Questie = {API = {isReady = true}}
QuestieLoader = {ImportModule = function(_, name) assert(name == "QuestieTooltips"); return tooltipModule end}
nt("questie on"); Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(loot:IsShown() and kill:IsShown(), "Questie fills missing loot relationships even when native kill data exists")
local other
for _, frame in ipairs(Mock.frames) do
    if frame.parent == target.UnitFrame and frame.kind == "other" then other = frame end
end
Check(other and not other:IsShown(), "Stale Questie entries cannot mark another quest's mobs")
questieObjective.Collected = 5; Mock.Tick(1)
Check(not loot:IsShown() and kill:IsShown(), "Completed Questie loot preserves the native kill icon")
questieObjective.Collected = 0; questieObjective.Update = function() error("Unavailable quest data") end
Mock.Tick(1); Check(loot:IsShown() and kill:IsShown(), "Unavailable optional updates cannot break native markers")
Questie.API.isReady = false; Mock.Tick(1)
Check(not loot:IsShown() and kill:IsShown(), "Wait for optional Questie initialization")
Questie, QuestieLoader, Mock.tooltipLines = nil, nil, nil
nt("questie off"); Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)

-- General database coverage: cooking and other item objectives use the same
-- path, with individual counts and localized names rather than item class.
local definitions = {
    [9001] = {[3] = {{10001}, {10002}}},
    [9002] = {[3] = {{10003}}},
    [9003] = {[3] = {{10004}}},
}
local itemData = {
    [10001] = {name = "Raw Meat", npcDrops = {3001, 3999}, vendors = {3999}},
    [10002] = {name = "Leather", npcDrops = {3002}},
    [10003] = {name = "Cloth", npcDrops = {3003}},
    [10004] = {name = "Ore", npcDrops = {3004}},
}
local queryCount = 0
local function QuestRead(id, field) assert(field == "objectives"); queryCount = queryCount + 1; return definitions[id] end
local function ItemRead(id, field)
    Check(field == "name" or field == "npcDrops" or field == "vendors", "Only item names, drops, and vendor exclusions are queried")
    return itemData[id] and itemData[id][field]
end
LibQuestieDB = {RequireContract = function(version) return version == 1 end,
    Quest = {Get = QuestRead}, Item = {Get = ItemRead}}
Mock.questEntries = {{questID = 9001}, {questID = 9002}, {questID = 9003, isComplete = true}}
Mock.questObjectives = {
    [9001] = {
        {text = "Viande crue: 0/4", type = "item", numFulfilled = 0, numRequired = 4, finished = false},
        {text = "Cuir: 0/3", type = "item", numFulfilled = 0, numRequired = 3, finished = false},
    },
    [9002] = {{text = "Uncached translated cloth: 0/2", type = "item", finished = false}},
    [9003] = {{text = "Ore: 0/2", type = "item", finished = false}},
}
Mock.itemNames = {[10001] = "Viande crue", [10002] = "Cuir"}
Mock.itemCounts = {[10001] = 4, [10002] = 2, [10003] = 0, [10004] = 0}
Mock.tooltipLines = {}
Mock.guids = {nameplate1 = "Creature-0-0-0-0-3002-0"}
Mock.Tick(1)
Check(loot:IsShown(), "Late database availability refreshes active plates without needing a quest-log event")
Mock.guids.nameplate1 = "Creature-0-0-0-0-3001-0"; Mock.Tick(1)
Check(not loot:IsShown(), "An already-collected ingredient does not mark its source")
Mock.itemCounts[10001] = 3; Mock.Event("BAG_UPDATE_DELAYED"); Mock.Tick(0.2)
Check(loot:IsShown(), "Spending an ordinary cooking ingredient restores its icon")
Mock.questObjectives[9001][1].finished = true; Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(not loot:IsShown(), "Completed individual objectives are respected even when required items have been consumed")
Mock.guids.nameplate1 = "Creature-0-0-0-0-3002-0"; Mock.Tick(1)
Check(loot:IsShown(), "Another unfinished item in the same quest remains marked")
Mock.guids.nameplate1 = "Creature-0-0-0-0-3003-0"; Mock.Tick(1)
Check(loot:IsShown(), "Unique item objectives work before translated item names are cached")
Mock.guids.nameplate1 = "Creature-0-0-0-0-3004-0"; Mock.Tick(1)
Check(not loot:IsShown(), "Completed quests never add database sources")
Mock.guids.nameplate1 = "Creature-0-0-0-0-3999-0"; Mock.Tick(1)
Check(not loot:IsShown(), "A vendor relationship is not treated as a loot source")
local readsBefore = queryCount
Mock.Tick(1); Mock.Tick(1)
Check(queryCount == readsBefore, "Database reads happen when progress or availability changes, not on each marker refresh")
Mock.itemCounts[10002] = secret; Mock.guids.nameplate1 = "Creature-0-0-0-0-3002-0"
Mock.Event("BAG_UPDATE_DELAYED"); Mock.Tick(0.2)
Check(loot:IsShown(), "Native incomplete progress works when ingredient bag counts are restricted")
Mock.questEntries = {}; Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(not loot:IsShown(), "Removing item quests clears all generic sources")

-- Ambiguous translated names wait for the client item cache, rather than
-- attributing the wrong count to a source. Item load events retry the lookup.
Mock.questEntries = {{questID = 9001}}
Mock.questObjectives[9001][1].finished = false
Mock.itemNames, Mock.itemCounts = {}, {[10001] = 0, [10002] = 0}
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(not loot:IsShown() and Mock.itemRequests[10001] == 1 and Mock.itemRequests[10002] == 1,
    "Request uncached names once when matching several localized objectives")
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)
Check(Mock.itemRequests[10001] == 1 and Mock.itemRequests[10002] == 1, "Do not repeat item-cache requests")
Mock.itemNames[10002] = "Cuir"; Mock.Event("ITEM_DATA_LOAD_RESULT", 10002, true); Mock.Tick(0.2)
Check(loot:IsShown(), "Localized item name arrival enables the right objective")
LibQuestieDB.RequireContract = function() return false end; Mock.Tick(1)
Check(not loot:IsShown(), "An incompatible provider cannot break native icons")
LibQuestieDB = nil
Questie = {API = {isReady = true}}
QuestieLoader = {ImportModule = function(_, name)
    if name == "QuestieDB" then return {QueryQuestSingle = QuestRead, QueryItemSingle = ItemRead} end
    return tooltipModule
end}
Mock.Tick(1); Check(loot:IsShown(), "Older Questie's internal database works with tooltip fallback disabled")
QuestieLoader.ImportModule = function() error("Unavailable optional addon") end
Mock.Tick(1); Check(not loot:IsShown(), "Missing optional data leaves the addon usable")
Questie, QuestieLoader, Mock.questEntries, Mock.questObjectives = nil, nil, nil, nil
Mock.itemNames, Mock.itemCounts, Mock.guids, Mock.tooltipLines = nil, nil, nil, nil
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.2)

-- Swing master switch is independent of the three weapon/bar switches.
Cmd("always"); Cmd("preview on")
Check(stack:IsShown())
fc.swingsEnabled.button:SetChecked(false); fc.swingsEnabled.button.scripts.OnClick(fc.swingsEnabled.button)
Check(not stack:IsShown() and not stack.bars.main.sparkAnim:IsPlaying())
Mock.Tick(0.2); Check(not stack:IsShown())
nt("swings on"); Check(stack:IsShown() and ns.db.bars.main.enabled)
nt("swings width 155"); Check(ns.db.width == 155)

ns.OpenSwingOptions()
ui = ns.optionControls
ui.sparkSize.slider:SetValue(20)
Check(ns.db.sparkSize == 20 and Near(ns.optionsPreview.bars.main.sparkFrame.width, 20))
Cmd("sparksize 1"); Check(ns.db.sparkSize == 20, "Reject unusably small spark")
for _, key in ipairs(ns.order) do
    for _, field in ipairs({"labelEnabled", "labelFont", "labelSize", "labelAlign", "labelColor"}) do
        Check(ui[key .. "." .. field], "Every timer has its own text controls")
    end
end
Check(ns.db.bars.main.labelFont == "arial" and ns.db.bars.main.labelSize == 14
    and ns.db.bars.main.labelAlign == "RIGHT" and ns.db.bars.main.labelColor == "white")
Check(ns.optionsPreview.bars.main.label.points[1][1] == "RIGHT"
    and Near(ns.optionsPreview.bars.main.label.points[1][4], -5 * ns.optionsPreview.pixel)
    and ns.optionsPreview.bars.main.label.height >= 16 * ns.optionsPreview.pixel, "5px label inset with room for 14px text")
Cmd("label all on"); Cmd("labelsize main 10"); Cmd("labelalign main left")
Cmd("labelfont offhand arial"); Cmd("labelcolor ranged coral")
local pb = ns.optionsPreview.bars
Check(pb.main.labelFrame:IsShown() and pb.main.label:GetText() == "MAIN" and pb.main.label.justify == "LEFT")
Check(pb.offhand.label:GetText() == "OFF" and pb.ranged.label:GetText() == "RANGE")
Check(pb.main.label.fontSize == 10 and pb.offhand.label.font == ns.fontPaths.arial)
Check(Near(pb.ranged.label.textColor[1], 1) and Near(pb.ranged.label.textColor[2], 127/255))
for _, outline in ipairs(pb.main.labelOutline) do
    Check(outline.textColor[1] == 0 and outline.textColor[4] == 1)
    Check(math.abs(outline.points[1][4] - pb.main.label.points[1][4]) <= pb.main.pixel
        and math.abs(outline.points[1][5] - pb.main.label.points[1][5]) <= pb.main.pixel, "1px text outline")
end
Cmd("labelsize main 99"); Cmd("labelfont main invalid"); Cmd("labelalign main bottom")
Check(ns.db.bars.main.labelSize == 10 and ns.db.bars.main.labelFont == "arial" and ns.db.bars.main.labelAlign == "LEFT")
local aligns = Mock.Menu(ui["main.labelAlign"].dropdown)
local selectedLabel = stack.bars.main.label
local function TextLeft(bar)
    local text, point = bar.label, bar.label.points[1]
    if point[1] == "LEFT" then return point[4] end
    if point[1] == "RIGHT" then return bar.barWidth + point[4] - text.width end
    return (bar.barWidth - text.width) / 2 + point[4]
end
for _, choice in ipairs({1, 3, 2, 1, 3}) do
    aligns[choice].callback()
    local alignment = ({"LEFT", "CENTER", "RIGHT"})[choice]
    for _, bar in ipairs({pb.main, stack.bars.main}) do
        Check(bar.label.justify == alignment and bar.label.points[1][1] == alignment,
            "Changing label alignment reanchors both preview and selected mob immediately")
        local expected = alignment == "LEFT" and 5 * bar.pixel
            or alignment == "RIGHT" and bar.barWidth - 5 * bar.pixel - bar.label.width
            or (bar.barWidth - bar.label.width) / 2
        Check(Near(TextLeft(bar), expected) and bar.label.width <= bar.barWidth - 10 * bar.pixel,
            "Label moves to the requested edge or center inside the 5px insets")
        for _, outline in ipairs(bar.labelOutline) do
            Check(outline.points[1][1] == alignment and outline.width == bar.label.width,
                "The 1px outline follows the live label alignment")
        end
    end
    Check(stack.bars.main.label == selectedLabel and Mock.plates.target == target,
        "Live updates preserve the selected mob and existing timer frames")
end
aligns[2].callback(); Check(pb.main.label.justify == "CENTER")
ui["main.labelEnabled"].button:SetChecked(false)
ui["main.labelEnabled"].button.scripts.OnClick(ui["main.labelEnabled"].button)
Check(not pb.main.labelFrame:IsShown() and pb.offhand.labelFrame:IsShown())

-- Verify corner spacing along the circle normal, not just horizontally at the
-- straight edges. Border's inner arc and fill's arc share the outer center.
for _, geometry in ipairs({{768, 1}, {1080, 0.8}, {1440, 1.15}, {2160, 0.65}}) do
    Mock.screenHeight = geometry[1]; target:SetScale(geometry[2])
    for _, requested in ipairs({0, 1, 2, 3, 5, 15}) do
        ns.SetValue("borderRadius", requested); Mock.Tick(0.1)
        local bar = stack.bars.main
        local p, radius = bar.pixel, bar.radius
        Check(Near(bar.fillRadius, math.max(0, radius - 2*p)))
        Check(radius <= bar.barHeight / 2 and radius <= bar.barWidth / 2)
        if radius > 2*p then
            for _, theta in ipairs({0.15, 0.4, 0.8, 1.2, 1.45}) do
                local innerRadius, fillRadius = radius - p, radius - 2*p
                local iy, fy = radius - innerRadius * math.sin(theta), radius - fillRadius * math.sin(theta)
                local ix = p + ns.RoundedInset(bar.barWidth-2*p, bar.barHeight-2*p, innerRadius, iy-p)
                local fx = 2*p + ns.RoundedInset(bar.innerWidth, bar.innerHeight, fillRadius, fy-2*p)
                Check(Near(math.sqrt((fx-ix)^2 + (fy-iy)^2), p), "Corner gap remains 1 physical pixel")
            end
        end
        for _, value in ipairs({0, 0.01, 0.5, 0.9, 1}) do
            ns.RenderStack(stack, GetTime(), function() return value end)
            for _, row in ipairs(bar.fillRows) do
                Check(row[1]:IsShown() == row[2]:IsShown(), "Pulse and fill share rounded geometry")
                if row[1]:IsShown() then
                    local x = row[1].points[1][4]
                    Check(x >= bar.inset and x + row[1].width <= bar.inset + bar.innerWidth * value + 0.00001)
                    Check(row[1].width == row[2].width and row[1].height == row[2].height)
                end
            end
        end
    end
end
Mock.screenHeight = 768; target:SetScale(1)
Cmd("borderradius 4"); Check(ns.db.borderRadius == 4)
Cmd("borderradius -1"); Check(ns.db.borderRadius == 4)
ui.borderRadius.slider:SetValue(5); Check(ns.db.borderRadius == 5)

-- Close and reopen every page, and defer combat requests without touching the
-- protected opener. The most recent requested page wins when combat ends.
for _, page in ipairs({"", "range", "quests", "swings"}) do
    nt(page)
    for _, category in ipairs(Mock.categories) do category.frame:Hide() end
    nt(page)
    local panel = page == "range" and ns.featurePanels.rangeEnabled or page == "quests" and ns.featurePanels.markers
        or page == "swings" and ns.optionsPanel or ns.featurePanels.main
    Check(panel:IsShown(), "Settings reopen after closing: " .. page)
end
for _, category in ipairs(Mock.categories) do category.frame:Hide() end
Mock.lockdown = true
local openCalls = Mock.openCalls
nt(""); nt("swings"); nt("range")
Check(Mock.openCalls == openCalls and not ns.optionsPanel:IsShown(), "Combat slash calls never attempt a protected open")
Mock.Event("PLAYER_REGEN_ENABLED")
Check(Mock.openCalls == openCalls, "Wait until lockdown really ends")
Mock.lockdown = false; Mock.Event("PLAYER_REGEN_ENABLED")
Check(Mock.openCalls == openCalls + 1 and ns.featurePanels.rangeEnabled:IsShown(), "Last requested page opens after combat")
for _, category in ipairs(Mock.categories) do category.frame:Hide() end
nt(""); Check(ns.featurePanels.main:IsShown(), "Root page reopens after deferred combat request")

-- Upgrade matching prior defaults once while preserving customized settings.
VV_TEST_NS.db.nameplates.swingTimers = {appearanceVersion = 4, borderRadius = 3, bars = {
    main = {color = "warmyellow", labelFont = "montserrat", labelSize = 8},
    offhand = {color = "steelblue", labelFont = "friz", labelSize = 11, labelAlign = "LEFT"},
    ranged = {color = "warmyellow", labelFont = "montserrat", labelSize = 8},
}}
ns.InitDB()
Check(ns.db.borderRadius == 5 and ns.db.appearanceVersion == 9)
Check(ns.db.bars.main.color == "red" and ns.db.bars.main.labelFont == "arial" and ns.db.bars.main.labelSize == 14)
Check(ns.db.bars.offhand.color == "steelblue" and ns.db.bars.offhand.labelFont == "friz"
    and ns.db.bars.offhand.labelSize == 11 and ns.db.bars.offhand.labelAlign == "LEFT", "Preserve custom appearance")
Check(ns.db.bars.ranged.color == "warmyellow" and ns.db.bars.ranged.labelFont == "arial")
ns.db.borderRadius = 3
ns.db.bars.main.color, ns.db.bars.main.labelFont, ns.db.bars.main.labelSize = "warmyellow", "montserrat", 8
ns.InitDB()
Check(ns.db.borderRadius == 3 and ns.db.bars.main.color == "warmyellow"
    and ns.db.bars.main.labelFont == "montserrat" and ns.db.bars.main.labelSize == 8, "Do not repeat default migration")
VV_TEST_NS.db.nameplates.swingTimers = {appearanceVersion = 5, bars = {main = {color = "crimson"}, offhand = {color = "steelblue"}}}
ns.InitDB()
Check(ns.db.bars.main.color == "red" and ns.db.bars.offhand.color == "steelblue",
    "Update the intermediate crimson default while preserving a customized off-hand color")
VV_TEST_NS.db.nameplates.swingTimers = {appearanceVersion = 6, y = 15, visibility = "combat"}
ns.InitDB()
Check(ns.db.y == 46 and ns.db.visibility == "swing" and ns.db.appearanceVersion == 9,
    "Migrate the prior vertical offset and visibility defaults")
VV_TEST_NS.db.nameplates.swingTimers = {appearanceVersion = 6, y = 21, visibility = "always"}
ns.InitDB()
Check(ns.db.y == 21 and ns.db.visibility == "always", "Preserve custom offset and visibility")
ns.db.y, ns.db.visibility = 15, "combat"; ns.InitDB()
Check(ns.db.y == 15 and ns.db.visibility == "combat", "Only apply the default migration once")
VV_TEST_NS.db.nameplates.swingTimers = {appearanceVersion = 7, y = 10, effectAlpha = 0.18, sparkAlpha = 0.65}
ns.InitDB()
Check(ns.db.effectAlpha == 0.35 and ns.db.sparkAlpha == 1 and ns.db.y == 46, "Upgrade the prior pulse, spark, and offset defaults")
VV_TEST_NS.db.nameplates.swingTimers = {appearanceVersion = 7, effectAlpha = 0.77, sparkAlpha = 0.3}
ns.InitDB()
Check(ns.db.effectAlpha == 0.77 and ns.db.sparkAlpha == 0.3, "Preserve customized effect strengths")
ns.db.effectAlpha, ns.db.sparkAlpha = 0.18, 0.65; ns.InitDB()
Check(ns.db.effectAlpha == 0.18 and ns.db.sparkAlpha == 0.65, "Do not repeat strength migration after upgrade")

-- Import the standalone table once, with no table sharing or overwrite later.
NameplateSwingTimersDB = {appearanceVersion = 3, width = 170, height = 11, sparkAlpha = 0.22,
    bars = {main = {enabled = false, color = "coral", alpha = 0.6, effect = "bubbles"}}}
VV_TEST_NS.db.nameplates.swingTimers = nil; ns.InitDB()
Check(ns.db.width == 170 and ns.db.height == 11 and ns.db.sparkAlpha == 1)
Check(not ns.db.bars.main.enabled and ns.db.bars.main.color == "coral" and ns.db.bars.main.effect == "pulse")
Check(ns.db ~= NameplateSwingTimersDB and ns.db.bars.main ~= NameplateSwingTimersDB.bars.main)
ns.SetValue("width", 190); NameplateSwingTimersDB.width = 220; ns.InitDB()
Check(ns.db.width == 190, "Do not overwrite migrated settings")
local prompted = false
for _, message in ipairs(Mock.messages) do if message:find("Type /vv to configure", 1, true) then prompted = true end end
Check(prompted, "Startup prompts the user to configure all three modules")
NST_TEST_CHECKS = checks

