local ns = NST_TEST_NS
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local stack = ns.CreateStack(UIParent)
-- Derive actual artwork bounds from widget geometry, independently of the
-- layout's padding calculations. Labels include the eight 1px outline copies.
local function Bounds(bar, key)
    local top, bottom = bar.offset, bar.offset + bar.height
    if bar.sparkFrame:IsShown() then
        local half = (bar.sparkFrame.height - bar.height) / 2
        top, bottom = math.min(top, bar.offset - half), math.max(bottom, bar.offset + bar.height + half)
    end
    if bar.labelFrame:IsShown() then
        for _, label in ipairs({bar.label, unpack(bar.labelOutline)}) do
            local center = bar.offset + bar.height / 2 - label.points[1][5]
            top, bottom = math.min(top, center - label.height / 2), math.max(bottom, center + label.height / 2)
        end
    end
    return top, bottom
end
for _, geometry in ipairs({{768, 1}, {1080, 0.8}, {1440, 1.15}, {2160, 0.65}, {768, 1.6}}) do
    Mock.screenHeight = geometry[1]; stack:SetScale(geometry[2])
    for _, height in ipairs({5, 10, 30}) do
        for _, spark in ipairs({false, true}) do
            for _, sparkSize in ipairs({4, 12, 48}) do
                for _, labelSize in ipairs({6, 14, 24}) do
                    for _, gap in ipairs({0, 2, 12}) do
                        for _, key in ipairs(ns.order) do
                            ns.db.bars[key].labelEnabled = key ~= "offhand"
                            ns.db.bars[key].labelSize = key == "ranged" and 24 or labelSize
                        end
                        ns.db.height, ns.db.spark, ns.db.sparkSize, ns.db.gap = height, spark, sparkSize, gap
                        ns.styleVersion = ns.styleVersion + 1
                        for mask = 0, 7 do
                            local shown = {}
                            for index, key in ipairs(ns.order) do shown[key] = math.floor(mask / 2^(index-1)) % 2 == 1 end
                            ns.LayoutStack(stack, shown, UIParent)
                            ns.RenderStack(stack, 0, function() return 0.5 end)
                            local previousBottom
                            for _, key in ipairs(ns.order) do
                                local bar = stack.bars[key]
                                Check(bar:IsShown() == shown[key], "Only selected bars occupy the stack")
                                if shown[key] then
                                    local top, bottom = Bounds(bar, key)
                                    if previousBottom then
                                        Check(top + 0.00001 >= previousBottom + stack.gap,
                                            "Swing spark/label artwork overlaps its neighbor")
                                    else
                                        Check(bar.offset == 0, "Hidden bars leave no leading gap")
                                    end
                                    previousBottom = bottom
                                end
                            end
                            local offsets = {}
                            for _, key in ipairs(ns.order) do offsets[key] = stack.bars[key].offset end
                            ns.RenderStack(stack, 1, function() return 0 end)
                            ns.LayoutStack(stack, shown, UIParent)
                            for _, key in ipairs(ns.order) do
                                Check(offsets[key] == stack.bars[key].offset, "Swing progress cannot make the stack jump")
                            end
                        end
                    end
                end
            end
        end
    end
end
-- Live anchoring and the menu use the same readable cast-clearance calculation.
ns.ResetSettings()
Mock.screenHeight = 768; stack:SetScale(1)
local plate = Mock.Plate("nameplate1")
local frame, health = plate.UnitFrame, plate.UnitFrame.HealthBarsContainer
frame.CastBarsContainer = Mock.New(frame)
frame.CastBarsContainer:SetHeight(32)
local cast = Mock.New(frame.CastBarsContainer)
frame.CastBarsContainer.castBar = cast
cast:SetHeight(24)
cast.Spark = Mock.New(cast); cast.Spark:SetHeight(40)
NamePlateSetupOptions = {castBarToHealthBarSpacing = 5}
ns.LayoutStack(stack, {main=true, ranged=true}, health, ns.CastClearance(frame, health))
ns.RenderStack(stack, 0, function() return 0.5 end)
local top = Bounds(stack.bars.main, "main")
Check(stack.offset + top >= 41, "First swing clears cast-container artwork with a physical-pixel margin")
Check(ns.db.y == 20, "Automatic clearance preserves the saved vertical offset")
Mock.plates.target, Mock.units.target = plate, true
ns.SetValue("visibility", "always")
Mock.Event("PLAYER_TARGET_CHANGED")
Check(Mock.Stack(plate).offset == stack.offset, "Live target gets the same cast clearance")
-- A restricted coordinate is never used for arithmetic or comparison.
health.GetBottom = function() return {secret=true} end
cast.GetBottom = health.GetBottom
ns.LayoutStack(stack, {main=true}, health, ns.CastClearance(frame, health))
Check(stack.offset >= 41, "Restricted geometry falls back to readable cast dimensions")
plate:SetScale(1.4); stack:SetScale(0.8)
ns.LayoutStack(stack, {main=true}, health, ns.CastClearance(frame, health, stack))
Check(stack.offset >= 41 * 1.4 / 0.8, "Cast clearance converts into swing-stack units across different scales")
health.GetBottom = function() return 100 end
cast.GetBottom = function() return 50 end
ns.LayoutStack(stack, {main=true}, health, ns.CastClearance(frame, health, stack))
local visibleTop = stack.offset - stack.bars.main.visualPadding
Check(visibleTop >= 50 * 1.4 / 0.8, "Readable cast coordinates clear artwork at different scales")
-- Lua 5.1 mocks cannot forbid branching on secret booleans. Instrument the
-- secrecy probe and mark even a literal false as restricted to verify both
-- that visibility is sanitized and that unknown/hidden are distinct states.
local originalSecret = issecretvalue
for _, field in ipairs({"cast", "Border", "Spark", "CastTargetNameText", "Icon", "Text", "BorderShield"}) do
    local caseFrame = Mock.New(UIParent)
    local caseHealth = Mock.New(caseFrame)
    local caseContainer = Mock.New(caseFrame); caseContainer:SetHeight(32)
    caseFrame.CastBarsContainer = caseContainer
    local caseCast = Mock.New(caseContainer); caseCast:SetHeight(24); caseCast:Hide()
    caseContainer.castBar = caseCast
    local artwork = field == "cast" and caseCast or Mock.New(caseCast)
    if field ~= "cast" then caseCast[field] = artwork end
    artwork:SetHeight(80)
    for _, token in ipairs({{secret=true}, false}) do
        local probes = 0
        issecretvalue = function(value)
            if value == token then probes = probes + 1; return true end
            return originalSecret(value)
        end
        artwork.IsShown = function() return token end
        local clearance = ns.CastClearance(caseFrame, caseHealth)
        issecretvalue = originalSecret
        Check(probes > 0, field .. " visibility is checked for secrecy before branching")
        Check(clearance == 61, field .. " restricted visibility reserves the artwork's full bounds")
    end
    artwork.IsShown = function() return false end
    Check(ns.CastClearance(caseFrame, caseHealth) == 37, field .. " readable hidden artwork is excluded")
    artwork.IsShown = function() return true end
    Check(ns.CastClearance(caseFrame, caseHealth) == 61, field .. " readable visible artwork is included")
    artwork.IsShown = function() error("restricted visibility getter") end
    Check(ns.CastClearance(caseFrame, caseHealth) == 61, field .. " refused visibility safely reserves space")
end
-- Exercise the reported live Refresh/OnUpdate path as well as the helper.
plate:SetScale(1); stack:SetScale(1)
health.GetBottom = function() return {secret=true} end
cast.GetBottom = health.GetBottom
cast.Spark.IsShown = function() return false end
local visibilityProbes = 0
issecretvalue = function(value)
    if value == false then visibilityProbes = visibilityProbes + 1; return true end
    return originalSecret(value)
end
Mock.combat = true
Mock.Event("PLAYER_TARGET_CHANGED")
Mock.Tick(0.1)
issecretvalue = originalSecret
Mock.combat = false
Check(visibilityProbes >= 2, "Live refreshes sanitize restricted false cast visibility in combat")
Check(Mock.Stack(plate).offset >= 41, "Live combat refresh retains cast-artwork clearance")
ns.SetValue("y", -10)
ns.LayoutStack(stack, {main=true}, health, ns.CastClearance(frame, health))
Check(stack.offset == -10, "Explicit negative placements retain manual positioning")
NST_SPACING_CHECKS = checks
