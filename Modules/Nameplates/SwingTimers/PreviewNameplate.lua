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
    if frame.AurasFrame then frame.AurasFrame:SetActive(false); frame.AurasFrame:UnregisterAllEvents() end
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
    local sample = SafeCall(C_NamePlate and C_NamePlate.GetNamePlateForUnit, "target")
    local scale
    if sample and not SafeCall(sample.IsForbidden, sample) and SafeCall(sample.IsShown, sample) then
        local worldScale = ns.Number(SafeCall(sample.GetEffectiveScale, sample), 0.01, 100)
        local menuScale = ns.Number(SafeCall(plate.menuParent.GetEffectiveScale, plate.menuParent), 0.01, 100)
        if worldScale and menuScale then scale = worldScale / menuScale end
    end
    -- A swing anchor is a selected target, which is enlarged independently of
    -- nameplateSize. Apply the same scale to BOTH the plate and swing stack.
    if not scale then
        local worldScale = ns.Number(SafeCall(UIParent.GetEffectiveScale, UIParent), 0.01, 100) or 1
        local menuScale = ns.Number(SafeCall(plate.menuParent.GetEffectiveScale, plate.menuParent), 0.01, 100) or worldScale
        scale = (CVarNumber("nameplateSelectedScale") or 1) * worldScale / menuScale
    end
    plate:SetScale(scale)
end

local function NativeLayout(plate)
    local frame, setup = plate.nativeFrame, NamePlateSetupOptions
    local width = ns.Number(SafeCall(C_NamePlate and C_NamePlate.GetNamePlateSize), 30, 2000)
        or (ReadLayout().width + 2 * setup.insetWidth)
    local castDisplay = SafeCall(C_CVar and C_CVar.GetCVar or GetCVar, "nameplateCastBarDisplay")
    local changed = width ~= plate.nativeWidth or castDisplay ~= plate.nativeCastDisplay
    local previous = plate.nativeOptions or {}
    for key, value in pairs(setup) do if previous[key] ~= value then changed = true end end
    if changed then
        local castHeight = setup.castBarHeight + (setup.spellNameInsideCastBar and 0 or setup.castIconHeight)
        plate:SetSize(width - 2 * setup.insetWidth, setup.healthBarHeight)
        frame:ClearAllPoints()
        frame:SetSize(width, setup.healthBarHeight + setup.castBarToHealthBarSpacing + castHeight)
        frame:SetPoint("BOTTOMLEFT", plate, "BOTTOMLEFT", -setup.insetWidth,
            -setup.castBarToHealthBarSpacing - castHeight)
        frame:ApplyFrameOptions(setup, NamePlateEnemyFrameOptions)
        frame:UpdateCastBarDisplay()
        frame:SetScript("OnUpdate", nil)
        plate.nativeOptions = {}
        for key, value in pairs(setup) do plate.nativeOptions[key] = value end
        plate.nativeWidth, plate.nativeCastDisplay = width, castDisplay
        plate.nextCast = nil
    end
    frame:Show()
    frame.name:SetText("Training Dummy")
    frame.name:Show()
    local health = frame.HealthBarsContainer.healthBar
    health:SetIsTarget(true)
    health:SetMinMaxValues(0, 100)
    health:SetValue(78)
    health:SetStatusBarColor(0.8, 0.1, 0.1)
    health:Show()
    -- Keep native optional health text and level-box placement. Sample data is
    -- synthetic; no health, cast, target-name, or level API is read from a mob.
    if frame.LevelFrame then
        frame.LevelFrame:SetShown(NamePlateEnemyFrameOptions.showLevel == true)
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
        level:SetIsTarget(true)
        level:Show()
    else
        Hide(frame.PlayerLevelDiffFrame)
    end
    for _, key in ipairs({"AurasFrame", "ClassificationFrame", "RaidTargetFrame", "SoftTargetFrame",
        "WidgetContainer", "behindCameraIcon", "selectionHighlight", "aggroFlash", "aggroHighlightBase", "aggroHighlightMask",
        "aggroHighlightAdditive", "myHealPrediction", "otherHealPrediction", "totalAbsorb", "totalAbsorbOverlay",
        "overAbsorbGlow", "myHealAbsorb", "myHealAbsorbLeftShadow", "myHealAbsorbRightShadow", "overHealAbsorbGlow"}) do
        Hide(frame[key])
    end
    local color = NamePlateEnemyFrameOptions.selectedBorderColor
    if color and frame.HealthBarsContainer.border then
        frame.HealthBarsContainer.border:SetVertexColor(color:GetRGBA())
        local cast = frame.CastBarsContainer.castBar
        if cast.border then cast.border:SetVertexColor(color:GetRGBA()) end
    end
end

function ns.UpdateMenuNameplatePreview(plate, now)
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
            cast:SimulateCast({barType = "standard", iconTexture = "Interface\\Icons\\Spell_Fire_FlameBolt",
                spellName = "Fireball", targetName = "You", castTime = 3, isImportantSpell = true, isSpellTarget = true})
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
    ns.ComboPoints.LayoutRow(plate.comboRow, health, ns.tweaksDB.comboPointsEnabled and 5 or 0)
end

function ns.StopMenuFeaturePreview(plate)
    for _, bar in pairs(plate.swingStack.bars) do bar.sparkAnim:Stop() end
    ns.StopMenuNameplatePreview(plate)
end
