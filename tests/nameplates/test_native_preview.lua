local ns = NST_TEST_NS
local checks = 0
local function Check(value, message) checks = checks + 1; assert(value, message) end
local function Near(a, b) return math.abs(a - b) < 0.00001 end
Mock.Event('ADDON_LOADED', 'VanillaVarnish')
Mock.Event('PLAYER_LOGIN')
ns.OpenSwingOptions()
local plate, stack = ns.optionsPreviewNameplate, ns.optionsPreview
local frame = plate.nativeFrame
local cast, health = frame.CastBarsContainer.castBar, frame.HealthBarsContainer.healthBar
Check(frame and Mock.nativeFrames == 1, 'Use one complete native nameplate template')
Check(not plate.healthBar:IsShown() and not plate.castBar:IsShown(), 'Remove approximated artwork')
Check(frame.unit == nil and cast.unit == nil, 'Sample must never bind a live unit')
Check(next(frame.events) == nil and next(cast.events) == nil and not frame.scripts.OnUpdate, 'Detach unit events and updates')
Check(plate.SetHitTestPoints ~= nil, 'Native layout can set hit-test points safely on the script frame')
Check(stack.parent == plate and stack.anchor == frame.HealthBarsContainer, 'Native health container anchors scaled swings')
Check(Near(plate:GetEffectiveScale(), 1.2), 'Selected-target enlargement applies without a target')
Check(health.value == 78 and health.isTarget and frame.name.text == 'Training Dummy', 'Synthetic native health and name')
Check(health.RightText.text == '78' and health.LeftText.text == '78%', 'Native health display uses selected info settings')
Check(cast.casting and cast:IsShown() and cast.Text.text == 'Fireball' and cast.CastTargetNameText.text == 'You', 'Native sample includes spell and target')
Check(cast.Icon:IsShown() and cast.ImportantCastIndicator:IsShown() and cast.CastTargetIndicator:IsShown(), 'Native cast icon and configured highlights')
Check(not frame.behindCameraIcon:IsShown() and not frame.AurasFrame:IsShown(), 'Hide unit-dependent decorations')
local level = plate.nativeLevelBox
if NameplateLevelFrameMixin then
    Check(level == frame.PlayerLevelDiffFrame and level:IsShown(), 'Classic NPC preview displays separate native level box')
    Check(level.selectedBorder:IsShown() and level.isTarget, 'Native level box uses selected-target border')
    Check(level.playerLevelDiffIcon.atlas == 'ui-hud-nameplates-levelindicator' and
        level.selectedBorder.atlas == 'ui-hud-nameplates-levelindicator-rectangle-selected', 'Use actual Classic level box artwork')
    Check(level.playerLevelDiffText.text == '60' and level.playerLevelDiffText.points[1][2] == level.playerLevelDiffIcon and
        not level.highLevelTexture:IsShown(), 'Center synthetic level text and hide skull')
else
    Check(not frame.PlayerLevelDiffFrame:IsShown(), 'Older clients retain their original level display')
end
Mock.Tick(0.5)
Check(cast.value > 0 and cast.value < 3 and cast.Spark:IsShown(), 'Native cast animates')

for style = 0, 6 do
    for size = 1, 5 do
        Mock.ApplyNameplateStyle(style, size)
        Mock.Tick(0.11)
        local setup = NamePlateSetupOptions
        Check(Near(plate.width, Mock.nativeWidth - 2 * setup.insetWidth), 'Native clickable insets excluded from health width')
        Check(Near(frame.HealthBarsContainer.height, setup.healthBarHeight) and Near(cast.height, setup.castBarHeight), 'Native driver determines health and cast size')
        Check(frame.HealthBarsContainer.points[1][2] == frame.CastBarsContainer and
            frame.HealthBarsContainer.points[1][5] == setup.castBarToHealthBarSpacing, 'Native health and cast spacing')
        Check(Near(frame.points[1][5] + frame.CastBarsContainer.height + setup.castBarToHealthBarSpacing, 0), 'Native health bottom matches preview anchor')
        Check(cast.Border:IsShown() == setup.useClassicCastBar, 'Native classic cast border follows style')
        Check(frame.LevelFrame:IsShown() == NamePlateEnemyFrameOptions.showLevel, 'Native level visibility follows style')
        Check(stack.anchor == frame.HealthBarsContainer and stack.offset >= ns.db.y, 'Swings clear the native cast container and retain their health anchor')
        Check(stack.offset >= frame.CastBarsContainer.height + setup.castBarToHealthBarSpacing + stack.bars.main.visualPadding + 2 * stack.pixel - 0.00001, 'Native cast container cannot overlap swing artwork')
        if level then
            Check(level:IsShown() and Near(level.width, setup.playerLevelDiffWidth) and Near(level.height, setup.playerLevelDiffHeight),
                'Separate level box follows native style and size')
            Check(Near(frame.HealthBarsContainer.points[2][4], -level.width - 5),
                'Native health bar reserves level box width and gap')
            Check(level.points[1][2] == frame.HealthBarsContainer and level.points[1][3] == 'RIGHT' and level.points[1][4] == 5,
                'Level box keeps native position to the right of health')
        end
    end
end

-- The installed beta may use Classic artwork for another selected style.
-- The client's setup, rather than the style's numeric enum, is authoritative.
Mock.ApplyNameplateStyle(4, 2)
NamePlateSetupOptions.useClassicHealthBar, NamePlateSetupOptions.useClassicCastBar = true, true
NamePlateEnemyFrameOptions.showLevel = true
Mock.Tick(0.11)
Check(cast.Border:IsShown() and frame.LevelFrame:IsShown() and
    health.bgTexture.texture == 'Interface\\Tooltips\\Nameplate-Border', 'Client artwork overrides style assumptions')

-- Size alone cannot explain the screenshot: selected plates are enlarged and
-- the Settings panel may itself have a different effective UI scale.
local target = Mock.Plate('nameplate1')
Mock.plates.target = target
target:SetScale(1.44)
plate.menuParent:SetScale(0.8)
Mock.Tick(0.11)
Check(Near(plate:GetEffectiveScale(), target:GetEffectiveScale()) and Near(stack:GetEffectiveScale(), target:GetEffectiveScale()), 'Plate and swing pixels match live target through menu UI scale')
target:SetScale(1.1)
ns.RefreshOptions()
Check(Near(stack:GetEffectiveScale(), 1.1), 'Control refresh immediately updates target scale')
target:Hide()
Mock.Tick(0.11)
Check(Near(plate:GetEffectiveScale(), 1.2), 'Hidden live plate uses selected-scale fallback through menu UI scale')

Mock.cvars.nameplateCastBarDisplay = '0'
Mock.Tick(0.11)
Check(not cast.Icon:IsShown() and not cast.Text:IsShown() and not cast.CastTargetNameText:IsShown(), 'Cast display options hide optional text and icon')
Check(not cast.ImportantCastIndicator:IsShown() and not cast.CastTargetIndicator:IsShown(), 'Cast display options hide highlights')
Mock.cvars.nameplateCastBarDisplay = '31'
ns.optionsPanel:Hide()
Mock.ApplyNameplateStyle(6, 2)
ns.OpenSwingOptions()
Check(frame.LevelFrame:IsShown() and cast.Border:IsShown(), 'Reopen immediately applies native classic artwork')
Check(cast.Icon:IsShown() and cast.Text:IsShown(), 'Reopen restarts cast with current display options')
Check(Mock.nativeFrames == 1 and not ns.preview and ns.anchorUnit == nil, 'Native sample is reused and isolated from world timers')
local unitMixin, scriptMixin = NamePlateUnitFrameMixin, NamePlateScriptBaseMixin
NamePlateUnitFrameMixin, NamePlateScriptBaseMixin = nil, nil
local late = ns.CreateMenuNameplatePreview(plate.menuParent)
ns.UpdateMenuNameplatePreview(late, GetTime())
Check(not late.nativeFrame, 'Menu created before native templates load uses fallback')
NamePlateUnitFrameMixin, NamePlateScriptBaseMixin = unitMixin, scriptMixin
ns.UpdateMenuNameplatePreview(late, GetTime() + 1)
Check(late.nativeFrame and late.SetHitTestPoints, 'Late-loaded templates safely replace fallback with native layout')
NST_NATIVE_PREVIEW_CHECKS = checks
