-- UI-engine primitives for running the actual Blizzard nameplate Lua sources.
-- Run with --blizzard-source pointing at a downloaded client snapshot.
local Object, New = Mock.Object, Mock.New
function Object:UnregisterAllEvents() self.events = {} end
function Object:RegisterForClicks() end
function Object:GetParent() return self.parent end
function Object:SetParent(parent) self.parent = parent end
function Object:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function Object:SetFontObject(font) self.font = font end
function Object:SetTextHeight(height) self.fontSize = height end
function Object:SetFontHeight(height) self.fontSize = height end
function Object:GetLineHeight() return self.fontSize or 12 end
function Object:SetTextureSliceMargins(...) self.sliceMargins = {...} end
function Object:SetDrawLayer(...) self.drawLayer = {...} end
function Object:SetStatusBarColor(...) self.statusBarColor = {...} end
function Object:SetStatusBarTexture(texture) self.statusBarTexture = texture end
function Object:SetPlaying(playing) self.playing = playing end
function Object:SetActive(active) self.active = active end
function Object:SetWidth(width) assert(width >= 0); self.width = width end
function Object:SetHeight(height) assert(height >= 0); self.height = height end
function Object:HookScript(event, fn)
    local original = self.scripts[event]
    self.scripts[event] = function(...) if original then original(...) end; fn(...) end
end
function Mixin(object, ...)
    for i = 1, select('#', ...) do for k, v in pairs(select(i, ...)) do object[k] = v end end
    return object
end
function CreateFromMixins(...) return Mixin({}, ...) end
function secretwrap(value) return value end
C_Secrets = {ShouldUnitSpellCastingBeSecret = function() return false end}
function PlayerIsSpellTarget() error('Synthetic sample must not read live cast targeting') end
function UnitCastingInfo(unit) assert(unit == nil) end
function UnitChannelInfo(unit) assert(unit == nil) end
function CreateColor(r, g, b, a)
    return {r = r, g = g, b = b, a = a or 1,
        GetRGB = function(self) return self.r, self.g, self.b end,
        GetRGBA = function(self) return self.r, self.g, self.b, self.a end}
end
CASTBAR_CLASSIC_YELLOW = CreateColor(1, 0.7, 0)
CASTBAR_CLASSIC_GREEN = CreateColor(0, 1, 0)
CASTBAR_CLASSIC_GRAY = CreateColor(0.5, 0.5, 0.5)
CASTBAR_CLASSIC_RED = CreateColor(1, 0, 0)
NAMEPLATE_BORDER_TARGET_COLOR = CreateColor(1, 1, 0)
NAMEPLATE_BORDER_FOCUS_TARGET_COLOR = CreateColor(1, 1, 1)
WHITE_FONT_COLOR = CreateColor(1, 1, 1)
TextureKitConstants = {IgnoreAtlasSize = false}
function GetCVarBool(name) return Mock.cvars[name] == '1' end
function GetCVarNumberOrDefault(name) return tonumber(Mock.cvars[name]) or 2 end
APIDocumentation = {AddDocumentationTable = function(_, doc)
    for _, info in ipairs(doc.Tables) do
        if info.Type == 'Enumeration' then
            Enum[info.Name] = {}
            for _, field in ipairs(info.Fields) do Enum[info.Name][field.Name] = field.EnumValue end
        end
    end
end}
CVarCallbackRegistry = {
    SetCVarCachable = function() end,
    RegisterCallback = function() end,
    GetCVarNumberOrDefault = function(_, key) return tonumber(Mock.cvars[key]) or 2 end,
    GetCVarBitfieldIndex = function(_, key, index)
        local value = tonumber(Mock.cvars[key]) or 0
        return math.floor(value / 2 ^ (index - 1)) % 2 == 1
    end,
}
for _, method in ipairs({'SetPoint', 'SetSize', 'SetHeight', 'SetWidth'}) do
    PixelUtil[method] = function(object, ...) object[method](object, ...) end
end
PixelUtil.SetRoundLayoutToNearestPixelRecursively = function(frame, enabled) frame.roundToPixel = enabled end
function CompactUnitFrame_OnLoad(frame)
    frame:RegisterEvent('PLAYER_ENTERING_WORLD')
    frame:SetScript('OnEvent', function() error('Preview must detach unit events') end)
end
function CompactUnitFrame_SetOptionTable(frame, options)
    frame.optionTable = options
    frame:SetScript('OnUpdate', function() error('Preview must detach unit updates') end)
end
TextStatusBarMixin = {
    InitializeTextStatusBar = function() end,
    SetBarText = function() end,
    UpdateTextString = function(self)
        self.RightText:SetText(self.showNumeric and tostring(self.value or 0) or '')
        self.LeftText:SetText(self.showPercentage and '78%' or '')
    end,
}
local originalCreateFrame = CreateFrame
local function Frame(parent) return originalCreateFrame('Frame', nil, parent) end
local function Texture(parent) return parent:CreateTexture() end
local function Text(parent) return parent:CreateFontString(nil, 'OVERLAY', 'SystemFont_NamePlate') end
local function Fields(parent, keys, factory)
    for key in keys:gmatch('%S+') do parent[key] = factory(parent) end
end
-- Child keys follow BaseNamePlateUnitFrameTemplate and NamePlateCastingBarTemplate.
function CreateFrame(kind, name, parent, template)
    local frame = originalCreateFrame(kind, name, parent)
    if template == 'NamePlateScriptBaseTemplate' then Mixin(frame, NamePlateScriptBaseMixin) end
    if template ~= 'NamePlateUnitFrameTemplate' then return frame end
    Mock.nativeFrames = (Mock.nativeFrames or 0) + 1
    Mixin(frame, NamePlateUnitFrameMixin)
    Fields(frame, 'HealthBarsContainer CastBarsContainer AurasFrame ClassificationFrame RaidTargetFrame PlayerLevelDiffFrame LevelFrame SoftTargetFrame WidgetContainer', Frame)
    Fields(frame, 'name', Text)
    Fields(frame, 'behindCameraIcon selectionHighlight aggroFlash aggroHighlight aggroHighlightBase aggroHighlightAdditive aggroHighlightMask', Texture)
    Fields(frame, 'LoseAggroAnim AggroHighlightFadeOutAnim AggroHighlightScrollAnim', Frame)
    frame.aggroHighlightTextures = {frame.aggroHighlightBase, frame.aggroHighlightAdditive, frame.aggroHighlightMask}
    Fields(frame.AurasFrame, 'DebuffListFrame CrowdControlListFrame LossOfControlFrame', Frame)
    Fields(frame.ClassificationFrame, 'classificationIndicator', Texture)
    Fields(frame.LevelFrame, 'LevelText', Text)
    Fields(frame.LevelFrame, 'HighLevelTexture', Texture)
    if NameplateLevelFrameMixin then
        local level = frame.PlayerLevelDiffFrame
        Mixin(level, NameplateLevelFrameMixin)
        Fields(level, 'playerLevelDiffText', Text)
        Fields(level, 'playerLevelDiffIcon selectedBorder highLevelTexture', Texture)
        level.playerLevelDiffIcon:SetAtlas('ui-hud-nameplates-levelindicator')
        level.selectedBorder:SetAtlas('ui-hud-nameplates-levelindicator-rectangle-selected')
        level:SetPoint('LEFT', frame.HealthBarsContainer, 'RIGHT', 5, 0)
    end
    local health = Frame(frame.HealthBarsContainer)
    frame.HealthBarsContainer.healthBar = health
    Mixin(health, NamePlateHealthBarMixin)
    Fields(health, 'Text LeftText RightText', Text)
    Fields(health, 'barTexture bgTexture selectedBorder deselectedOverlay myHealPrediction otherHealPrediction totalAbsorb totalAbsorbOverlay overAbsorbGlow myHealAbsorb myHealAbsorbLeftShadow myHealAbsorbRightShadow overHealAbsorbGlow', Texture)
    health:OnLoad()
    health:SetScript('OnValueChanged', function(self) self:UpdateTextString() end)
    local cast = Frame(frame.CastBarsContainer)
    frame.CastBarsContainer.castBar = cast
    -- Match the XML: cast artwork draws well above the health frame.
    cast:SetFrameLevel(100)
    Mixin(cast, NamePlateCastingBarMixin)
    Fields(cast, 'Text CastTargetNameText', Text)
    Fields(cast, 'Background Border BorderShield CastTargetIndicator ImportantCastIndicator Icon Spark Flash', Texture)
    Fields(cast, 'ImportantCastFlashAnim FlashAnim FadeOutAnim StandardFinish', Frame)
    cast.Spark:SetPoint('CENTER', cast, 'CENTER', 0, 0)
    cast:OnLoad()
    cast:SetScript('OnShow', cast.OnShow)
    cast:SetScript('OnEvent', cast.OnEvent)
    cast:SetScript('OnUpdate', cast.OnUpdate)
    frame:OnLoad()
    return frame
end
-- Run the actual driver's style/size calculations without creating world plates.
function Mock.ApplyNameplateStyle(style, size)
    Mock.cvars.nameplateStyle, Mock.cvars.nameplateSize = tostring(style), tostring(size)
    local driver = CreateFromMixins(NamePlateDriverMixin)
    driver.ForEachNamePlate = function() end
    driver.ForEachScriptNamePlate = function() end
    driver.SetupClassNameplateBars = function() end
    driver:UpdateNamePlateOptions()
end
C_NamePlate.SetNamePlateSize = function(width, height) Mock.nativeWidth, Mock.nativeHeight = width, height end
C_NamePlate.GetNamePlateSize = function() return Mock.nativeWidth, Mock.nativeHeight end
