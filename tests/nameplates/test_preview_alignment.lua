local ns = NST_TEST_NS
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local function Near(a, b) return math.abs(a - b) < 0.00001 end
Mock.Event('ADDON_LOADED', 'VanillaVarnish')
Mock.Event('PLAYER_LOGIN')
ns.OpenSwingOptions()

-- Resolve screen geometry from native anchors: the mock's explicit width does
-- not implement the client's sizing of frames anchored at both left and right.
local function Factor(point)
    if point:find('LEFT') then return 0 end
    if point:find('RIGHT') then return 1 end
    return 0.5
end
local function Bounds(region)
    if region.allPoints then return Bounds(region.allPoints) end
    local left, right, center
    local scale = region:GetEffectiveScale()
    for _, point in ipairs(region.points) do
        local relative = point[2]
        local l, r = 0, 0
        if type(relative) == 'table' then l, r = Bounds(relative) end
        local anchor = l + (r - l) * Factor(point[3] or point[1]) + (point[4] or 0) * scale
        local factor = Factor(point[1])
        if factor == 0 then left = anchor elseif factor == 1 then right = anchor else center = anchor end
    end
    local width = region:GetWidth() * scale
    if left and right then return left, right end
    if left then return left, left + width end
    if right then return right - width, right end
    return (center or 0) - width / 2, (center or 0) + width / 2
end
local function Gap(stack, frame)
    local timerLeft = Bounds(stack.bars.main)
    local healthLeft = Bounds(frame.HealthBarsContainer.healthBar)
    return timerLeft - healthLeft
end

local target = CreateFrame('Frame', nil, UIParent, 'NamePlateScriptBaseTemplate')
Mock.plates.target = target
target.UnitFrame = CreateFrame('Button', nil, target, 'NamePlateUnitFrameTemplate')
local live = target.UnitFrame
live:SetNamePlateFrame(target)
live.PlayerLevelDiffFrame.ShouldDisplay = function() return true end
live:UnregisterAllEvents()
live.CastBarsContainer.castBar:UnregisterAllEvents()
local liveStack = ns.CreateStack(target)
local liveCombo = ns.ComboPoints.CreateRow(target)
local shown = {main=true, offhand=true, ranged=true}

for _, uiScale in ipairs({0.8, 1, 1.2}) do
    UIParent:SetScale(uiScale)
    for _, menuScale in ipairs({0.7, 1, 1.4}) do
        for _, targetScale in ipairs({1, 1.2, 1.44}) do
            target:SetScale(targetScale)
            for _, style in ipairs({0, 4, 6}) do
                Mock.ApplyNameplateStyle(style, 2)
                local setup = NamePlateSetupOptions
                live:SetSize(Mock.nativeWidth, 100)
                live:ClearAllPoints()
                live:SetPoint('BOTTOMLEFT', target, 'BOTTOMLEFT', 0, 0)
                live:ApplyFrameOptions(setup, NamePlateEnemyFrameOptions)
                live:SetScript('OnUpdate', nil)
                for _, layout in ipairs({'stack', 'row'}) do
                    ns.SetValue('layout', layout)
                    ns.SetValue('width', 200)
                    ns.SetValue('x', 20)
                    ns.LayoutStack(liveStack, shown, live.HealthBarsContainer)
                    ns.ComboPoints.LayoutRow(liveCombo, live.HealthBarsContainer.healthBar, 3, live.CastBarsContainer.castBar)
                    for _, plate in ipairs({ns.optionsPreviewNameplate, ns.ComboPoints.previewNameplate}) do
                        plate.menuParent:SetScale(menuScale)
                        plate.nextLayout = nil
                        ns.DrawMenuFeaturePreview(plate)
                        local frame = plate.nativeFrame
                        Check(Near(plate:GetEffectiveScale(), target:GetEffectiveScale()), 'Preview follows live plate screen scale across canvas and UI scales')
                        Check(Near(Gap(plate.swingStack, frame), Gap(liveStack, live)), 'Timer left edge has the same physical offset from health as in game')
                        local l, r = Bounds(live.HealthBarsContainer.healthBar)
                        local pl, pr = Bounds(frame.HealthBarsContainer.healthBar)
                        Check(Near(r - l, pr - pl), 'Preview health width matches the live native health width')
                        l, r = Bounds(liveStack.bars.main)
                        pl, pr = Bounds(plate.swingStack.bars.main)
                        Check(Near(r - l, pr - pl), 'Timer width stays at live UI scale in both layouts')
                        local comboLeft = Bounds(liveCombo)
                        local previewComboLeft = Bounds(plate.comboRow)
                        local healthLeft = Bounds(live.HealthBarsContainer.healthBar)
                        local previewHealthLeft = Bounds(frame.HealthBarsContainer.healthBar)
                        Check(Near(comboLeft - healthLeft, previewComboLeft - previewHealthLeft), 'Combo points retain the live offset from the visible health bar')
                    end
                end
            end
        end
    end
end

-- Reproduce aligned edges using a saved offset, without changing that offset
-- to compensate for the preview's options canvas scale.
UIParent:SetScale(1)
target:SetScale(1.2)
Mock.ApplyNameplateStyle(6, 2)
live:ApplyFrameOptions(NamePlateSetupOptions, NamePlateEnemyFrameOptions)
live:SetScript('OnUpdate', nil)
local healthLeft = Bounds(live.HealthBarsContainer.healthBar)
local anchorLeft, anchorRight = Bounds(live.HealthBarsContainer)
ns.SetValue('x', healthLeft - (anchorLeft + anchorRight) / 2 + ns.db.width / 2)
ns.LayoutStack(liveStack, shown, live.HealthBarsContainer)
local savedX = ns.db.x
for _, plate in ipairs({ns.optionsPreviewNameplate, ns.ComboPoints.previewNameplate}) do
    plate.menuParent:SetScale(0.8)
    plate.nextLayout = nil
    ns.DrawMenuFeaturePreview(plate)
    Check(math.abs(Gap(plate.swingStack, plate.nativeFrame)) <= 0.5, 'Aligned live edges remain aligned in the preview within pixel rounding')
    Check(ns.db.x == savedX, 'Preview scale correction never changes saved offsets')
end
NST_PREVIEW_ALIGNMENT_CHECKS = checks
