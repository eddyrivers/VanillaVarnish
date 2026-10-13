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
Check(frame and Mock.nativeFrames == 2, 'Use a complete native nameplate template on each feature preview')
Check(not plate.healthBar:IsShown() and not plate.castBar:IsShown(), 'Remove approximated artwork')
Check(frame.unit == nil and cast.unit == nil, 'Sample must never bind a live unit')
Check(next(frame.events) == nil and next(cast.events) == nil and not frame.scripts.OnUpdate, 'Detach unit events and updates')
Check(plate.SetHitTestPoints ~= nil, 'Native layout can set hit-test points safely on the script frame')
Check(stack.parent == plate and stack.anchor == frame.HealthBarsContainer, 'Native health container anchors scaled swings')
Check(Near(plate:GetEffectiveScale(), 1), 'Use the game options preview scale without target enlargement')
Check(health.value == 78 and not health.isTarget and frame.name.text == 'Training Dummy', 'Synthetic native health and name')
Check(health.RightText.text == '78' and health.LeftText.text == '78%', 'Native health display uses selected info settings')
Check(cast.casting and cast:IsShown() and cast.Text.text == 'Fireball' and cast.CastTargetNameText.text == 'You', 'Native sample includes spell and target')
Check(cast.Icon:IsShown() and cast.ImportantCastIndicator:IsShown() and cast.CastTargetIndicator:IsShown(), 'Native cast icon and configured highlights')
Check(not frame.behindCameraIcon:IsShown(), 'Hide world-only decorations')
local level = plate.nativeLevelBox
if NameplateLevelFrameMixin then
    Check(level == frame.PlayerLevelDiffFrame and level:IsShown(), 'Classic NPC preview displays separate native level box')
    Check(not level.selectedBorder:IsShown() and not level.isTarget, 'Native level box uses options preview selection state')
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
        Check(plate.comboRow.points[1][2] == health and plate.comboRow.points[1][3] == 'BOTTOM', 'Combo dots use the native health bar across styles and sizes')
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
Check(Near(plate:GetEffectiveScale(), plate.menuParent:GetEffectiveScale()) and Near(stack:GetEffectiveScale(), UIParent:GetEffectiveScale()), 'Nameplate inherits the options canvas scale while timers retain live UI scale')
target:SetScale(1.1)
ns.RefreshOptions()
Check(Near(stack:GetEffectiveScale(), UIParent:GetEffectiveScale()), 'Control refresh preserves timer scale through native target scaling')
target:Hide()
Mock.Tick(0.11)
Check(Near(plate:GetEffectiveScale(), plate.menuParent:GetEffectiveScale()), 'Hiding the target does not change the options preview scale')

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
Check(Mock.nativeFrames == 2 and not ns.preview and ns.anchorUnit == nil, 'Native sample is reused and isolated from world timers')
local unitMixin, scriptMixin = NamePlateUnitFrameMixin, NamePlateScriptBaseMixin
NamePlateUnitFrameMixin, NamePlateScriptBaseMixin = nil, nil
local late = ns.CreateMenuNameplatePreview(plate.menuParent)
ns.UpdateMenuNameplatePreview(late, GetTime())
Check(not late.nativeFrame, 'Menu created before native templates load uses fallback')
NamePlateUnitFrameMixin, NamePlateScriptBaseMixin = unitMixin, scriptMixin
ns.UpdateMenuNameplatePreview(late, GetTime() + 1)
Check(late.nativeFrame and late.SetHitTestPoints, 'Late-loaded templates safely replace fallback with native layout')

if NamePlateAurasMixin then
    local auras = frame.AurasFrame
    local comboPlate = ns.ComboPoints.previewNameplate
    local comboAuras = comboPlate.nativeFrame.AurasFrame
    for mask = 0, 7 do
        Mock.cvars.nameplateEnemyNpcAuraDisplay = tostring(mask)
        ns.RefreshOptions()
        Check(auras:IsShown() and auras.isActive == false and auras.unitToken == 'preview', 'Native auras use an inert sample token')
        for _, previewAuras in ipairs({auras, comboAuras}) do
            local buffs, debuffs, cc = mask % 2 == 1, math.floor(mask / 2) % 2 == 1, math.floor(mask / 4) % 2 == 1
            Check(previewAuras.BuffListFrame:IsShown() == buffs and previewAuras.DebuffListFrame:IsShown() == debuffs
                and previewAuras.CrowdControlListFrame:IsShown() == cc, 'Both feature previews follow every native aura display combination')
            if buffs then Check(#previewAuras.BuffListFrame.items == 2, 'Native buff list keeps its two-icon limit') end
            if debuffs then Check(#previewAuras.DebuffListFrame.items == 6, 'Native debuff preview shows six sample icons') end
            if cc then Check(#previewAuras.CrowdControlListFrame.items == 2, 'Native crowd-control list keeps its two-icon limit') end
        end
        Check(next(auras.events) == nil and frame.unit == nil and cast.unit == nil, 'Sample auras never bind live units or events')
    end
    for _, auraScale in ipairs({0.7, 1, 1.3}) do
        Mock.cvars.nameplateAuraScale = tostring(auraScale)
        Mock.Tick(0.11)
        Check(Near(auras.auraItemScale, auraScale * frame:GetScaleData().aura), 'Aura size follows native size and aura-scale options')
        Check(auras.DebuffListFrame.stride == (auraScale == 0.7 and 12 or auraScale == 1 and 8 or 6), 'Native aura wrapping follows the selected scale')
    end
    Mock.cvars.nameplateDebuffPadding = '17'
    Mock.Tick(0.11)
    Check(auras.DebuffListFrame.points[#auras.DebuffListFrame.points][5] == 17, 'Aura padding changes update without a style or size change')
    Mock.cvars.nameplateInfoDisplay = '0'
    Mock.Tick(0.11)
    Check(health.RightText.text == '' and health.LeftText.text == '', 'Health information choices refresh immediately')
    local layouts = auras.DebuffListFrame.layoutCount
    Mock.Tick(0.11)
    Check(auras.DebuffListFrame.layoutCount == layouts, 'Unchanged options reuse aura widgets without rebuilding each poll')
    ns.optionsPanel:Hide()
    Mock.cvars.nameplateEnemyNpcAuraDisplay = '0'
    ns.OpenSwingOptions()
    Check(not auras.BuffListFrame:IsShown() and not auras.DebuffListFrame:IsShown() and not auras.CrowdControlListFrame:IsShown(),
        'Reopening applies aura options changed while the page was hidden')

    if NamePlatePreviewMixin then
        local source = CreateFrame('Frame', nil, UIParent)
        source:Hide()
        source.previewIconTexture = 'same-game-preview-cast-icon'
        source.UnitFrame = CreateFrame('Button', nil, source, 'NamePlateUnitFrameTemplate')
        local sourceFrame = source.UnitFrame
        sourceFrame.SetExplicitValues = function(self, values)
            self.isPlayer, self.isFriend = values.isPlayer, values.isFriend
            self.isSimplified, self.showOnlyName = false, false
            self.ClassificationFrame.explicitClassification = values.classification
        end
        sourceFrame.HealthBarsContainer.healthBar:SetStatusBarColor(0.3, 0.6, 0.9)
        sourceFrame.name:SetTextColor(0.1, 0.4, 0.7)
        sourceFrame.aggroHighlightBase:Show()
        sourceFrame.aggroHighlightBase:SetVertexColor(1, 0, 0)
        source.SetExplicitValues = NamePlatePreviewMixin.SetExplicitValues
        source.UpdatePreviewText = function() end
        sourceFrame.AurasFrame.explicitAuraList = TableUtil.CreatePriorityTable()
        for index = 1, 6 do
            sourceFrame.AurasFrame.explicitAuraList[index] = {auraInstanceID=index, sourceUnit='player', applications=1,
                expirationTime=0, duration=10, icon='game-preview-icon-' .. index}
        end
        local driver = {scriptNamePlates={}, registrations=0}
        function driver:RegisterScriptNamePlate(plate, token) self.scriptNamePlates[token] = plate; self.registrations = self.registrations + 1 end
        function driver:IsScriptNamePlateRegistered(token) return self.scriptNamePlates[token] ~= nil end
        function driver:GetNamePlateForUnit(token) return self.scriptNamePlates[token] end
        NamePlateDriverFrame = driver
        Mock.Event('ADDON_LOADED', 'Blizzard_SettingsDefinitions_Frame')
        driver:RegisterScriptNamePlate(source, 'preview')
        source:Show()
        Mock.cvars.nameplateEnemyPlayerAuraDisplay = '7'
        Mock.cvars.nameplateThreatDisplay = '7'
        source:SetExplicitValues({isPlayer=true, isFriend=false})
        source:Hide()
        ns.RefreshOptions()
        Check(auras.isPlayer and not auras.isFriend and auras.LossOfControlFrame:IsShown()
            and not auras.CrowdControlListFrame:IsShown(), 'Carry the last game-preview unit type into the addon previews')
        Check(auras.explicitAuraList[1].icon == 'game-preview-icon-1' and comboAuras.explicitAuraList[1].icon == 'game-preview-icon-1'
            and cast.Icon.texture == 'same-game-preview-cast-icon', 'Both pages retain the exact game-preview sample icons')
        Check(driver.registrations == 1 and driver.scriptNamePlates.preview == source, 'Addon samples never replace Blizzard\'s registered preview')
        Check(health.statusBarColor[2] == 0.6 and frame.name.textColor[3] == 0.7 and frame.aggroHighlightBase:IsShown(),
            'Retain the game preview\'s name, health colors, and enabled threat artwork')
        Mock.cvars.nameplateThreatDisplay = '0'
        Mock.Tick(0.11)
        Check(not frame.aggroHighlightBase:IsShown(), 'Threat display options can hide the captured sample artwork')
        auras.explicitAuraList[1].icon = 'local-edit'
        Check(sourceFrame.AurasFrame.explicitAuraList[1].icon == 'game-preview-icon-1'
            and comboAuras.explicitAuraList[1].icon == 'game-preview-icon-1', 'Sample tables stay isolated between all three previews')
        source:SetExplicitValues({isPlayer=true, isFriend=true})
        Mock.cvars.nameplateFriendlyPlayerAuraDisplay = '1'
        ns.RefreshOptions()
        Check(auras.isFriend and auras.BuffListFrame:IsShown() and not auras.DebuffListFrame:IsShown(), 'Friendly sample follows friendly aura options')
        Mock.cvars.nameplateSimplifiedTypes = tostring(2 ^ (Enum.NamePlateSimplifiedType.FriendlyPlayer - 1))
        Mock.Tick(0.11)
        Check(not auras:IsShown() and not frame.name:IsShown(), 'Simplified display follows current options for the captured sample type')
        Mock.cvars.nameplateSimplifiedTypes = '0'
        Mock.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = '1'
        Mock.Tick(0.11)
        Check(not auras:IsShown() and not health:IsShown(), 'Name-only friendly options hide native bars and auras')
        Mock.cvars.nameplateShowOnlyNameForFriendlyPlayerUnits = '0'
        source:SetExplicitValues({isPlayer=false, isFriend=false, classification='elite'})
        Mock.cvars.nameplateInfoDisplay = '4'
        NamePlateEnemyFrameOptions.showClassificationIndicator = true
        ns.RefreshOptions()
        Check(frame.ClassificationFrame:IsShown() and frame.ClassificationFrame.classificationIndicator.atlas == 'nameplates-icon-elite-gold',
            'Native rarity display follows the selected sample and client frame options')
        NamePlateEnemyFrameOptions.showClassificationIndicator = false
        Mock.Tick(0.11)
        Check(not frame.ClassificationFrame:IsShown(), 'Client classification overrides refresh even without geometry changes')
    end
end
NST_NATIVE_PREVIEW_CHECKS = checks
