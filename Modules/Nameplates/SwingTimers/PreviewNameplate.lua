local _, VV = ...
local ns = VV.Nameplates

local function SafeCall(func, ...)
    if not func then return end
    local ok, value = pcall(func, ...)
    if ok then return ns.Known(value) end
end

local function CVarNumber(name)
    local value = SafeCall(C_CVar and C_CVar.GetCVar or GetCVar, name)
    return ns.Number(tonumber(value), 0, 100)
end

-- Observe Blizzard's sample without borrowing its globally registered "preview"
-- nameplate. Both addon pages can draw independently, even after that page hides.
local sample = {isPlayer=false, isFriend=false}
local sampleVersion = 0
local observedDriver
local threatArtwork = {"aggroFlash", "aggroHighlightBase", "aggroHighlightMask", "aggroHighlightAdditive"}
local function ReadColor(region, method)
    if not region or not region[method] then return end
    local ok, r, g, b = pcall(region[method], region)
    if ok and ns.Number(r, 0, 1) and ns.Number(g, 0, 1) and ns.Number(b, 0, 1) then return {r, g, b} end
end
local function CaptureSample(plate)
    local frame = plate.UnitFrame
    if not frame then return end
    sample = {isPlayer=SafeCall(frame.IsPlayer, frame) == true, isFriend=SafeCall(frame.IsFriend, frame) == true,
        isSimplified=SafeCall(frame.IsSimplified, frame) == true,
        isMinion=frame.explicitIsMinion == true, isMinusMob=frame.explicitIsMinusMob == true,
        classification=frame.ClassificationFrame and frame.ClassificationFrame.explicitClassification,
        icon=plate.previewIconTexture, auras={}, decorations={},
        healthColor=ReadColor(frame.HealthBarsContainer.healthBar, "GetStatusBarColor"),
        nameColor=ReadColor(frame.name, "GetTextColor")}
    for _, key in ipairs(threatArtwork) do
        local region = frame[key]
        sample.decorations[key] = {shown=SafeCall(region and region.IsShown, region) == true,
            color=ReadColor(region, "GetVertexColor")}
    end
    local list = frame.AurasFrame and frame.AurasFrame.explicitAuraList
    if list then list:Iterate(function(_, aura) sample.auras[#sample.auras + 1] = VV.Copy(aura) end) end
    sampleVersion = sampleVersion + 1
end

local function ObserveSettingsPreview()
    local driver = NamePlateDriverFrame
    if not driver or not NamePlateConstants or not driver.RegisterScriptNamePlate
        or not hooksecurefunc or observedDriver == driver then return end
    observedDriver = driver
    local function Observe(plate, token)
        if token ~= NamePlateConstants.PREVIEW_UNIT_TOKEN or plate.vvPreviewObserved then return end
        plate.vvPreviewObserved = true
        hooksecurefunc(plate, "SetExplicitValues", CaptureSample)
        plate:HookScript("OnShow", CaptureSample)
        -- The first OnShow is already running when registration reaches us.
        -- Sample once when initialization completes, then only on changes.
        if C_Timer then C_Timer.After(0, function() if plate:IsShown() then CaptureSample(plate) end end) end
    end
    hooksecurefunc(driver, "RegisterScriptNamePlate", function(_, plate, token) Observe(plate, token) end)
    if driver.IsScriptNamePlateRegistered and driver:IsScriptNamePlateRegistered(NamePlateConstants.PREVIEW_UNIT_TOKEN) then
        local plate = driver:GetNamePlateForUnit(NamePlateConstants.PREVIEW_UNIT_TOKEN)
        if plate then Observe(plate, NamePlateConstants.PREVIEW_UNIT_TOKEN); CaptureSample(plate) end
    end
end

local observer = CreateFrame("Frame")
observer:RegisterEvent("ADDON_LOADED")
observer:RegisterEvent("PLAYER_LOGIN")
observer:SetScript("OnEvent", ObserveSettingsPreview)

-- Prefer the client's already-scaled setup options. The fallback follows
-- Blizzard_NamePlates for clients where those globals are not yet available.
-- https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns/Blizzard_NamePlates
local function ReadLayout()
    local styles = Enum and Enum.NamePlateStyle or
        { Modern = 0, Thin = 1, Block = 2, HealthFocus = 3, CastFocus = 4, Legacy = 5, Classic = 6 }
    local style = CVarNumber("nameplateStyle") or styles.Modern
    local classic = style == styles.Classic
    local size = CVarNumber("nameplateSize") or 2
    local constants = NamePlateConstants or {}
    local scales = classic and constants.NAME_PLATE_SCALES_CLASSIC_STYLE or constants.NAME_PLATE_SCALES
    local scale = scales and scales[size]
    local fallbackScale = ({0.8, 1, 1.25, 1.4, 1.6})[size] or 1
    local horizontal = scale and scale.horizontal or (size == 1 and not classic and 0.75 or fallbackScale)
    local vertical = scale and scale.vertical or fallbackScale
    local options = NamePlateSetupOptions or {}
    local function Number(key, fallback, low)
        return ns.Number(options[key], low or 0.01, 2000) or fallback
    end
    local function Boolean(key, fallback)
        local value = ns.Known(options[key])
        if type(value) == "boolean" then return value end
        return fallback
    end
    horizontal = Number("horizontalScale", horizontal)
    vertical = Number("verticalScale", vertical)
    local largeHealth = style == styles.Modern or style == styles.Block or style == styles.HealthFocus
    local largeCast = style == styles.CastFocus or style == styles.Block
    local insideName = style == styles.Modern or style == styles.Block
    local insideCast = largeCast or classic
    local nameAnchor = ns.Number(options.unitNameAnchorStyle, 1, 3) or (insideName and 1 or classic and 3 or 2)
    insideCast = Boolean("spellNameInsideCastBar", insideCast)
    local width = SafeCall(C_NamePlate and C_NamePlate.GetNamePlateSize)
    width = ns.Number(width, 30, 2000) or
        (classic and (constants.CLASSIC_NAMEPLATE_WIDTH or 152) or (constants.NAMEPLATE_WIDTH or 230)) * horizontal
    return {
        width = math.max(30, width - 2 * Number("insetWidth", (constants.HORIZONTAL_INSET or 12) * horizontal, 0)),
        healthHeight = Number("healthBarHeight", (largeHealth and 20 or 10) * vertical),
        castHeight = Number("castBarHeight", (largeCast and 16 or 10) * vertical),
        spacing = Number("castBarToHealthBarSpacing", (classic and 4 or 2) * vertical, 0),
        nameSpacing = Number("healthBarToNameAboveSpacing", (classic and 4 or 2) * vertical, 0),
        nameSize = Number("healthBarFontHeight", (classic and 10 or 12) * vertical),
        castSize = Number("castBarFontHeight", 10 * vertical),
        iconSize = Number("castIconHeight", (classic and 14 or 12) * vertical),
        levelSize = Number("levelFontHeight", 10 * vertical),
        classicHealth = Boolean("useClassicHealthBar", classic),
        classicCast = Boolean("useClassicCastBar", classic),
        horizontal = horizontal, vertical = vertical, nameAnchor = nameAnchor, insideCast = insideCast,
        healthBorderWidth = Number("healthBarBorderWidth", 128 * horizontal),
        healthBorderHeight = Number("healthBarBorderHeight", 16 * vertical),
        castBorderWidth = Number("castBarBorderWidth", 128 * horizontal),
        castBorderHeight = Number("castBarBorderHeight", 16 * vertical),
    }
end

local function MakeBar(parent, r, g, b)
    local bar = CreateFrame("Frame", nil, parent)
    bar:EnableMouse(false)
    bar.background = bar:CreateTexture(nil, "BACKGROUND")
    bar.background:SetAllPoints()
    bar.fill = bar:CreateTexture(nil, "ARTWORK")
    bar.fill:SetPoint("LEFT", bar, "LEFT", 0, 0)
    bar.fill:SetVertexColor(r, g, b, 1)
    bar.border = bar:CreateTexture(nil, "OVERLAY")
    return bar
end

function ns.CreateMenuNameplatePreview(parent)
    -- This frame represents HealthBarsContainer, the same anchor used in game.
    local plate = CreateFrame("Frame", nil, parent, NamePlateScriptBaseMixin and "NamePlateScriptBaseTemplate" or nil)
    plate.menuParent = parent
    plate:EnableMouse(false)
    plate.healthBar = MakeBar(plate, 0.65, 0.12, 0.12)
    plate.castBar = MakeBar(plate, 1, 0.7, 0.15)
    -- Put health text on the bar's frame so its child artwork cannot cover it.
    plate.name = plate.healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.name:SetText("Training Dummy")
    plate.name:SetWordWrap(false)
    plate.level = plate.healthBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.level:SetText("60")
    plate.castBar.icon = plate.castBar:CreateTexture(nil, "OVERLAY")
    plate.castBar.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
    plate.castBar.text = plate.castBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    plate.castBar.text:SetText("Fireball")
    plate.castBar.text:SetWordWrap(false)
    plate.castBar.spark = plate.castBar:CreateTexture(nil, "OVERLAY")
    plate.castBar.spark:SetAtlas("ui-castingbar-pip")
    plate.castBar.spark:SetBlendMode("ADD")
    plate.castBar.spark:SetPoint("CENTER", plate.castBar.fill, "RIGHT", 0, 0)
    return plate
end

local function StyleBar(bar, width, height, classic, cast, borderWidth, borderHeight)
    bar:SetSize(width, height)
    bar.fill:SetHeight(height)
    if classic then
        bar.background:SetColorTexture(0, 0, 0, 0.8)
        bar.fill:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
        bar.border:SetTexture(cast and "Interface\\Tooltips\\Nameplate-Border-Castbar" or "Interface\\Tooltips\\Nameplate-Border")
        bar.border:SetTexCoord(0, 1, 0.5, 1)
        bar.border:SetSize(borderWidth, borderHeight)
        bar.border:Show()
    else
        bar.background:SetAtlas(cast and "ui-castingbar-background" or "UI-HUD-CoolDownManager-Bar-BG")
        bar.fill:SetAtlas("UI-HUD-CoolDownManager-Bar")
        bar.border:Hide()
    end
end

local function Layout(plate)
    local layout = ReadLayout()
    local health, cast = plate.healthBar, plate.castBar
    plate.castDepth = layout.spacing + layout.castHeight + (layout.insideCast and 0 or layout.iconSize)
    plate:SetSize(layout.width, layout.healthHeight)
    local healthInset = layout.classicHealth and 24.25 * layout.horizontal or 0
    local castInset = layout.classicCast and 24.25 * layout.horizontal or 0
    StyleBar(health, math.max(1, layout.width - healthInset), layout.healthHeight,
        layout.classicHealth, false, layout.healthBorderWidth, layout.healthBorderHeight)
    StyleBar(cast, math.max(1, layout.width - castInset), layout.castHeight,
        layout.classicCast, true, layout.castBorderWidth, layout.castBorderHeight)
    health:ClearAllPoints()
    health:SetPoint("TOPLEFT", plate, "TOPLEFT", layout.classicHealth and 3.5 * layout.horizontal or 0,
        layout.classicHealth and 0.5 * layout.vertical or 0)
    health.border:ClearAllPoints()
    health.border:SetPoint("CENTER", plate, "CENTER", 0, 0)
    health.fill:SetWidth(health:GetWidth() * 0.78)
    plate.level:SetFont("Fonts\\FRIZQT__.TTF", layout.levelSize, "OUTLINE")
    plate.level:ClearAllPoints()
    plate.level:SetPoint("RIGHT", plate, "RIGHT", -3 * layout.horizontal, 0)
    plate.level:SetShown(layout.classicHealth)
    cast:ClearAllPoints()
    cast:SetPoint("TOPLEFT", plate, "BOTTOMLEFT", layout.classicCast and 20.75 * layout.horizontal or 0,
        -layout.spacing + (layout.classicCast and 0.5 * layout.vertical or 0))
    cast.border:ClearAllPoints()
    cast.border:SetPoint("CENTER", plate, "BOTTOM", 0, -layout.spacing - layout.castHeight / 2)
    plate.name:SetFont("Fonts\\FRIZQT__.TTF", layout.nameSize, "OUTLINE")
    plate.name:ClearAllPoints()
    plate.name:SetJustifyH(layout.nameAnchor == 3 and "CENTER" or "LEFT")
    if layout.nameAnchor == 1 then
        plate.name:SetPoint("LEFT", plate, "LEFT", 4, 0)
    elseif layout.nameAnchor == 3 then
        plate.name:SetPoint("BOTTOM", plate, "TOP", 0, layout.nameSpacing)
    else
        plate.name:SetPoint("BOTTOMLEFT", plate, "TOPLEFT", 4, layout.nameSpacing)
    end
    cast.icon:SetSize(layout.iconSize, layout.iconSize)
    cast.icon:ClearAllPoints()
    if layout.classicCast then
        cast.icon:SetPoint("CENTER", cast.border, "LEFT", 11.5 * layout.horizontal, 0)
    elseif layout.insideCast then
        cast.icon:SetPoint("LEFT", cast, "LEFT", 0, 0)
    else
        cast.icon:SetPoint("TOPLEFT", cast, "BOTTOMLEFT", 0, 0)
    end
    cast.text:SetFont("Fonts\\FRIZQT__.TTF", layout.castSize, "OUTLINE")
    cast.spark:SetSize(4, layout.castHeight + 8)
    cast.text:ClearAllPoints()
    if layout.classicCast then
        cast.text:SetPoint("CENTER", cast, "CENTER", 0, -layout.vertical)
    else
        cast.text:SetPoint("LEFT", cast.icon, "RIGHT", 2, 0)
    end
end

local function Hide(frame)
    if frame then frame:Hide() end
end

local function CreateNativePreview(plate)
    if plate.nativeFrame then return true end
    if not NamePlateUnitFrameMixin or not NamePlateScriptBaseMixin or not NamePlateSetupOptions or not NamePlateEnemyFrameOptions then return false end
    -- Use the installed client's complete artwork/layout, rather than retail
    -- texture guesses. Never bind a unit or register with NamePlateDriverFrame:
    -- this keeps it independent of live plates and Blizzard's "preview" token.
    -- Also support a menu created before Blizzard_NamePlates finished loading.
    if not plate.SetHitTestPoints then Mixin(plate, NamePlateScriptBaseMixin) end
    local frame = CreateFrame("Button", nil, plate, "NamePlateUnitFrameTemplate")
    frame:UnregisterAllEvents()
    frame:SetScript("OnEvent", nil)
    frame:SetScript("OnUpdate", nil)
    frame:EnableMouse(false)
    frame:SetNamePlateFrame(plate)
    local level = frame.PlayerLevelDiffFrame
    -- Classic 1.60 uses this separate, bordered level indicator for NPCs.
    -- Its native layout reserves space only when ShouldDisplay sees a unit;
    -- provide the equivalent sample state before ApplyFrameOptions anchors it.
    if level and level.selectedBorder and level.playerLevelDiffText then
        level.ShouldDisplay = function() return true end
        plate.nativeLevelBox = level
    end
    if frame.AurasFrame then
        frame.AurasFrame:SetActive(false)
        frame.AurasFrame:UnregisterAllEvents()
        -- A synthetic token lets native visibility rules run; never SetUnit,
        -- which registers aura events and queries real unit data.
        frame.AurasFrame.unitToken = NamePlateConstants.PREVIEW_UNIT_TOKEN
    end
    if frame.ClassificationFrame then frame.ClassificationFrame:UnregisterAllEvents() end
    local cast = frame.CastBarsContainer.castBar
    cast:UnregisterAllEvents()
    cast:SetScript("OnEvent", nil)
    -- Cast display settings normally ask PlayerIsSpellTarget(self.unit).
    -- This independent sample has no unit token and always casts at "You".
    cast.UpdateHighlightWhenCastTarget = function(self)
        self:SetIsHighlightedCastTarget(self:GetHighlightWhenCastTarget())
    end
    Hide(plate.healthBar); Hide(plate.castBar)
    plate.nativeFrame = frame
    return true
end

local function UpdatePreviewScale(plate)
    -- Native target plates enlarge independently of nameplateSize. Timers stay
    -- at UI scale, so the sample must use the target's screen scale too: using
    -- the settings canvas scale changes their size and left-edge relationship.
    local target = SafeCall(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "target")
    local scale
    if target and SafeCall(target.IsForbidden, target) == false and SafeCall(target.IsShown, target) == true then
        scale = ns.Number(SafeCall(target.GetEffectiveScale, target), 0.01, 100)
    end
    local uiScale = ns.Number(SafeCall(UIParent.GetEffectiveScale, UIParent), 0.01, 100) or 1
    local selectedScale = ns.Number(CVarNumber("nameplateSelectedScale"), 0.01, 100) or 1
    scale = scale or uiScale * selectedScale
    local menuScale = ns.Number(SafeCall(plate.menuParent.GetEffectiveScale, plate.menuParent), 0.01, 100) or uiScale
    plate:SetScale(scale / menuScale)
end

local previewCVars = {"nameplateCastBarDisplay", "nameplateInfoDisplay", "nameplateSize", "nameplateStyle",
    "nameplateEnemyNpcAuraDisplay", "nameplateEnemyPlayerAuraDisplay", "nameplateFriendlyPlayerAuraDisplay",
    "nameplateShowDebuffsOnFriendly", "nameplateAuraScale", "nameplateDebuffPadding",
    "nameplateShowOnlyNameForFriendlyPlayerUnits", "nameplateSimplifiedTypes",
    "nameplateShowClassColor", "nameplateUseClassColorForFriendlyPlayerUnitNames", "nameplateThreatDisplay"}
local auraIcons = {"Spell_Nature_Rejuvenation", "Spell_Holy_Renew", "Spell_Shadow_ShadowWordPain",
    "Spell_Fire_FlameBolt", "Spell_Frost_FrostNova", "Spell_Nature_Polymorph"}

local function UpdateNativeAuras(plate)
    local auras = plate.nativeFrame.AurasFrame
    if not auras or not auras.RefreshExplicitAuras or not TableUtil or not AuraUtil then return end
    if not auras.explicitAuraList or plate.sampleVersion ~= sampleVersion then
        local list = TableUtil.CreatePriorityTable(AuraUtil.DefaultAuraCompare, TableUtil.Constants.AssociativePriorityTable)
        for index = 1, 6 do
            list[index] = sample.auras and sample.auras[index] and VV.Copy(sample.auras[index])
                or {auraInstanceID=index, sourceUnit="player", applications=1, expirationTime=0, duration=10,
                    icon="Interface\\Icons\\" .. auraIcons[index]}
        end
        auras.explicitAuraList = list
    end
    auras.isPlayer, auras.isFriend = sample.isPlayer, sample.isFriend
    auras.isSimplified = plate.nativeFrame.isSimplified
    auras.showOnlyName = plate.nativeFrame.showOnlyName
    auras:UpdateShownState()
    auras:UpdateScale(plate.nativeFrame:GetScaleData())
    auras:RefreshExplicitAuras()
end

local function BitEnabled(value, index)
    return index and math.floor((tonumber(value) or 0) / 2 ^ (index - 1)) % 2 == 1
end

local function IsSimplified(cvars)
    local types = Enum and Enum.NamePlateSimplifiedType
    if not types then return sample.isSimplified == true end
    local value = cvars.nameplateSimplifiedTypes
    return sample.isMinion and BitEnabled(value, types.Minion)
        or sample.isMinusMob and BitEnabled(value, types.MinusMob)
        or sample.isFriend and BitEnabled(value, sample.isPlayer and types.FriendlyPlayer or types.FriendlyNpc)
        or false
end

local function NativeLayout(plate)
    local frame, setup = plate.nativeFrame, NamePlateSetupOptions
    local width = ns.Number(SafeCall(C_NamePlate and C_NamePlate.GetNamePlateSize), 30, 2000)
        or (ReadLayout().width + 2 * setup.insetWidth)
    local changed = width ~= plate.nativeWidth or plate.sampleVersion ~= sampleVersion
    local cvars = {}
    for _, name in ipairs(previewCVars) do
        cvars[name] = SafeCall(C_CVar and C_CVar.GetCVar or GetCVar, name)
        if not plate.nativeCVars or plate.nativeCVars[name] ~= cvars[name] then changed = true end
    end
    local previous = plate.nativeOptions or {}
    for key, value in pairs(setup) do if previous[key] ~= value then changed = true end end
    for key, value in pairs(NamePlateEnemyFrameOptions) do
        if not plate.nativeFrameOptions or plate.nativeFrameOptions[key] ~= value then changed = true end
    end
    if changed then
        frame.isPlayer, frame.isFriend = sample.isPlayer, sample.isFriend
        frame.isSimplified = IsSimplified(cvars)
        frame.showOnlyName = sample.isPlayer and sample.isFriend and cvars.nameplateShowOnlyNameForFriendlyPlayerUnits == "1"
        local health = frame.HealthBarsContainer.healthBar
        health:SetIsPlayer(frame.isPlayer)
        health:SetIsSimplified(frame.isSimplified)
        health:SetShowOnlyName(frame.showOnlyName)
        frame.CastBarsContainer.castBar:SetShowOnlyName(frame.showOnlyName)
        if plate.nativeLevelBox then plate.nativeLevelBox.ShouldDisplay = function() return not frame.showOnlyName end end
        local castHeight = setup.castBarHeight + (setup.spellNameInsideCastBar and 0 or setup.castIconHeight)
        plate:SetSize(width - 2 * setup.insetWidth, setup.healthBarHeight)
        frame:ClearAllPoints()
        frame:SetSize(width, setup.healthBarHeight + setup.castBarToHealthBarSpacing + castHeight)
        frame:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT", -setup.insetWidth,
            -setup.castBarToHealthBarSpacing - castHeight)
        frame:ApplyFrameOptions(setup, NamePlateEnemyFrameOptions)
        frame:UpdateCastBarDisplay()
        health:UpdateTextDisplay()
        UpdateNativeAuras(plate)
        local classification = frame.ClassificationFrame
        if classification and classification.SetExplicitValues then
            classification.unitToken = NamePlateConstants.PREVIEW_UNIT_TOKEN
            classification.showOnlyName = frame.showOnlyName
            classification:SetOptions(NamePlateEnemyFrameOptions)
            classification:SetExplicitValues({classification=sample.classification})
        end
        frame:SetScript("OnUpdate", nil)
        plate.nativeOptions = {}
        for key, value in pairs(setup) do plate.nativeOptions[key] = value end
        plate.nativeWidth, plate.nativeCVars = width, cvars
        plate.nativeFrameOptions = {}
        for key, value in pairs(NamePlateEnemyFrameOptions) do plate.nativeFrameOptions[key] = value end
        plate.sampleVersion = sampleVersion
        plate.nextCast = nil
    end
    frame:Show()
    frame.name:SetText(UNIT_NAMEPLATES_TARGET_NAME_PREVIEW or "Training Dummy")
    frame.name:SetShown(not frame.isSimplified)
    local legacy = Enum and Enum.NamePlateStyle and CVarNumber("nameplateStyle") == Enum.NamePlateStyle.Legacy
    local nameColor = sample.nameColor or (legacy and {1, 0, 0} or {1, 1, 1})
    frame.name:SetTextColor(unpack(nameColor))
    local health = frame.HealthBarsContainer.healthBar
    health:SetIsTarget(false)
    health:SetMinMaxValues(0, 100)
    health:SetValue(78)
    health:SetStatusBarColor(unpack(sample.healthColor or {0.8, 0.1, 0.1}))
    health:UpdateShownState()
    -- Keep native optional health text and level-box placement. Sample data is
    -- synthetic; no health, cast, target-name, or level API is read from a mob.
    if frame.LevelFrame then
        frame.LevelFrame:SetShown(NamePlateEnemyFrameOptions.showLevel == true and not frame.showOnlyName)
        frame.LevelFrame.LevelText:SetText("60")
        frame.LevelFrame.LevelText:Show()
        Hide(frame.LevelFrame.HighLevelTexture)
    end
    local level = plate.nativeLevelBox
    if level then
        level.playerLevelDiffText:ClearAllPoints()
        level.playerLevelDiffText:SetPoint("CENTER", level.playerLevelDiffIcon, "CENTER", 0, 0)
        level.playerLevelDiffText:SetText("60")
        level.playerLevelDiffText:SetTextColor(1, 0.82, 0)
        level.playerLevelDiffText:Show()
        Hide(level.highLevelTexture)
        level:SetIsTarget(false)
        level:SetShown(not frame.showOnlyName)
    else
        Hide(frame.PlayerLevelDiffFrame)
    end
    if not frame.ClassificationFrame.SetExplicitValues then Hide(frame.ClassificationFrame) end
    for _, key in ipairs({"RaidTargetFrame", "SoftTargetFrame",
        "WidgetContainer", "behindCameraIcon", "selectionHighlight", "myHealPrediction", "otherHealPrediction", "totalAbsorb", "totalAbsorbOverlay",
        "overAbsorbGlow", "myHealAbsorb", "myHealAbsorbLeftShadow", "myHealAbsorbRightShadow", "overHealAbsorbGlow"}) do
        Hide(frame[key])
    end
    for _, key in ipairs(threatArtwork) do
        local decoration = sample.decorations and sample.decorations[key]
        local types = Enum and Enum.NamePlateThreatDisplay or {}
        local enabled = BitEnabled(cvars.nameplateThreatDisplay, key == "aggroFlash" and types.Flash or types.Progressive)
        local region = frame[key]
        if region then
            region:SetShown(decoration ~= nil and decoration.shown and enabled == true and not frame.showOnlyName)
            if decoration and decoration.color then region:SetVertexColor(unpack(decoration.color)) end
        end
    end
    local color = NamePlateEnemyFrameOptions.selectedBorderColor
    if color and frame.HealthBarsContainer.border then
        frame.HealthBarsContainer.border:SetVertexColor(color:GetRGBA())
        local cast = frame.CastBarsContainer.castBar
        if cast.border then cast.border:SetVertexColor(color:GetRGBA()) end
    end
end

function ns.UpdateMenuNameplatePreview(plate, now)
    ObserveSettingsPreview()
    -- Poll only while the menu preview is drawing, including on reopen. Read
    -- options again so style/size changes work without a target or a reload.
    if not plate.nextLayout or now >= plate.nextLayout then
        UpdatePreviewScale(plate)
        if CreateNativePreview(plate) then NativeLayout(plate) else Layout(plate) end
        plate.nextLayout = now + 0.1
    end
    if plate.nativeFrame then
        local cast = plate.nativeFrame.CastBarsContainer.castBar
        if not plate.nextCast or now >= plate.nextCast then
            cast:SimulateCast({barType = "standard", iconTexture = sample.icon or "Interface\\Icons\\Spell_Fire_FlameBolt",
                spellName = UNIT_NAMEPLATES_SPELL_NAME_PREVIEW or "Fireball",
                targetName = UNIT_NAMEPLATES_TARGET_NAME_PREVIEW or "You", castTime = 3, isImportantSpell = true, isSpellTarget = true})
            plate.nextCast = now + 3
        end
    else
        plate.castBar.fill:SetWidth(plate.castBar:GetWidth() * (0.05 + 0.9 * ((now / 3) % 1)))
    end
end

function ns.MenuNameplatePreviewAnchor(plate)
    return plate.nativeFrame and plate.nativeFrame.HealthBarsContainer or plate
end

function ns.StopMenuNameplatePreview(plate)
    plate.nextLayout, plate.nextCast = nil, nil
    if plate.nativeFrame then
        local cast = plate.nativeFrame.CastBarsContainer.castBar
        cast:StopAnims()
        cast:SetIsHighlightedImportantCast(false)
    end
end

local swingPeriods = { main = 2.6, offhand = 1.8, ranged = 3.2 }

function ns.CreateMenuFeaturePreview(parent)
    local plate = ns.CreateMenuNameplatePreview(parent)
    plate.swingStack = ns.CreateStack(plate)
    plate.comboRow = ns.ComboPoints.CreateRow(plate)
    return plate
end

function ns.DrawMenuFeaturePreview(plate)
    if not ns.db or not ns.ComboPoints.db then return end
    local now = GetTime()
    ns.UpdateMenuNameplatePreview(plate, now)
    local anchor = ns.MenuNameplatePreviewAnchor(plate)
    local shown = {}
    for _, key in ipairs(ns.order) do
        shown[key] = ns.tweaksDB.swingsEnabled and not VV.swingConflict and ns.db.bars[key].enabled
    end
    ns.LayoutStack(plate.swingStack, shown, anchor,
        ns.CastClearance(plate.nativeFrame or plate, anchor, plate.swingStack))
    ns.RenderStack(plate.swingStack, now, function(key, time) return (time / swingPeriods[key]) % 1 end)
    local health = ns.ComboPoints.HealthAnchor(plate.nativeFrame, plate.healthBar)
    ns.ComboPoints.LayoutRow(plate.comboRow, health, ns.tweaksDB.comboPointsEnabled and 3 or nil,
        ns.ComboPoints.CastBar(plate.nativeFrame or plate))
end

function ns.StopMenuFeaturePreview(plate)
    for _, bar in pairs(plate.swingStack.bars) do bar.sparkAnim:Stop() end
    ns.StopMenuNameplatePreview(plate)
end
