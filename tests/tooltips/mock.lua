dofile("tests/nameplates/MockWoW.lua")
local hook = hooksecurefunc
function hooksecurefunc(object, key, callback)
    if type(object) == "string" then return hook(_G, object, key) end
    return hook(object, key, callback)
end
WorldFrame = Mock.New(UIParent)
TOOLTIP_UPDATE_TIME = 0.2
Mock.timers = {}
C_Timer = {After=function(_, callback) Mock.timers[#Mock.timers + 1] = callback end}
function Mock.Flush()
    local pending = Mock.timers
    Mock.timers = {}
    for _, callback in ipairs(pending) do callback() end
end
local tick = Mock.Tick
function Mock.Tick(delta) tick(delta); Mock.Flush() end
function Mock.Object:IsMouseOver() return self.hovered ~= false end
function Mock.Object:GetRight() return self.right or 1800 end
function GetScreenWidth() return 1920 end
C_TooltipInfo = {GetWorldCursor=function() return Mock.worldCursorData end}
Mock.unitInfo = { player = {level=30}, mouseover = {level=33, player=true, class="MAGE", name="Ada", surname="Lovelace", hostile=true} }
function UnitLevel(unit) return (Mock.unitInfo[unit] or {}).level end
function UnitIsPlayer(unit) return (Mock.unitInfo[unit] or {}).player end
function UnitRace() return "Human" end
function UnitCanAttack(_, unit) return (Mock.unitInfo[unit] or {}).hostile end
function UnitIsEnemy(_, unit) return (Mock.unitInfo[unit] or {}).hostile end
function UnitClass(unit)
    local data = Mock.unitInfo[unit] or {}
    return data.localizedClass or "Mage", data.class
end
function UnitName(unit)
    local data = Mock.unitInfo[unit] or {}
    return data.name, data.surname
end
RAID_CLASS_COLORS = { MAGE = {r=0.25,g=0.78,b=0.92} }
UNIT_LEVEL_TEMPLATE, LEVEL = "Level %d", "Level"
Constants = { CharacterNameSeparatorConsts = {CHARACTERNAME_SURNAME_SEPARATOR=" "} }
Enum.TooltipDataType = { Unit = 2 }
Enum.WorldCursorAnchorType = { Default=0, Cursor=1, Nameplate=2 }
TooltipDataProcessor = { AddTooltipPostCall = function(kind, callback) assert(kind == 2); Mock.colorCallback = callback end }
TooltipUtil = { GetDisplayedUnit = function(tooltip) return "Ada", Mock.displayedUnit end }
GameTooltipDefaultContainer = Mock.New(UIParent)
SharedTooltipDefaultContainer = GameTooltipDefaultContainer
GameTooltipDefaultContainer:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -9, 85)
function Mock.Object:GetPoint(index) return unpack(self.points[index or 1] or {}) end
function Mock.Tooltip(name)
    local tip = CreateFrame("GameTooltip", name, UIParent)
    tip.name, tip.shown, tip.lineCount = name, false, 0
    tip.updateTooltipTimer = 0
    function tip:SetOwner(owner, anchor)
        self.owner, self.anchor, self.ownerCalls = owner, anchor, (self.ownerCalls or 0) + 1
    end
    function tip:SetAnchorType(anchor, x, y)
        self.anchor, self.offsetX, self.offsetY = anchor, x, y
        self.anchorCalls = (self.anchorCalls or 0) + 1
    end
    function tip:GetAnchorType() return self.anchor end
    function tip:GetOwner() return self.owner end
    function tip:GetName() return self.name end
    function tip:GetUnit() return "Ada", self.unit end
    function tip:GetPrimaryTooltipInfo() return self.info end
    function tip:ProcessInfo(info) self.info = info; self:Show() end
    function tip:NumLines() return self.lineCount end
    function tip:FadeOut() self.fading = true end
    function tip:HookScript(event, fn)
        local old = self.scripts[event]
        self.scripts[event] = function(...) if old then old(...) end; fn(...) end
    end
    function tip:SetText(text) Mock.Lines(self, {text}) end
    function tip:AddLine(text)
        self.lineCount = self.lineCount + 1
        local line = self:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        line:SetText(text)
        _G[name .. "TextLeft" .. self.lineCount] = line
    end
    return tip
end
function Mock.Lines(tooltip, texts)
    tooltip.lineCount = 0
    for _, text in ipairs(texts) do tooltip:AddLine(text) end
end
function Mock.Text(index) return _G["GameTooltipTextLeft" .. index]:GetText() end
GameTooltip, BuffFrameTooltip = Mock.Tooltip("GameTooltip"), Mock.Tooltip("BuffFrameTooltip")
GameSmallHeaderTooltip, GameNoHeaderTooltip = Mock.Tooltip("GameSmallHeaderTooltip"), Mock.Tooltip("GameNoHeaderTooltip")
ShoppingTooltip1, ItemRefTooltip = Mock.Tooltip("ShoppingTooltip1"), Mock.Tooltip("ItemRefTooltip")
function GameTooltip_SetDefaultAnchor(tooltip, parent)
    tooltip:SetOwner(parent, "ANCHOR_NONE")
    tooltip:SetPoint("BOTTOMRIGHT", GameTooltipDefaultContainer)
end
function GetCurrentEnvironment() return _G end
function CreateFromMixins(...) local value = {}; for _, mixin in ipairs({...}) do for key, item in pairs(mixin) do value[key] = item end end; return value end
TooltipDataHandlerMixin = {}
EditModeManagerFrame = { IsEditModeActive=function() return Mock.editing or false end }
function Mock.Hover(tooltip, owner, anchor, text)
    tooltip:Hide()
    tooltip.info, tooltip.unit, tooltip.fading = nil, nil, nil
    tooltip:SetAlpha(1)
    tooltip:SetOwner(owner, anchor)
    tooltip:SetPoint("LEFT", owner, "RIGHT", 1, 0)
    Mock.Lines(tooltip, {text or "Hover text"})
    tooltip:Show()
    Mock.Flush()
end
function Mock.WorldHover(tooltip, unit)
    Mock.Hover(tooltip, UIParent, "ANCHOR_NONE")
    tooltip.info, tooltip.unit = {getterName="GetWorldCursor"}, unit
    Mock.worldCursorData = {}
end
-- Replaced with the actual Forever helper when cached container.lua exists.
function ContainerFrameItemButton_CalculateItemTooltipAnchors(self, mainTooltip)
    if self:GetRight() < GetScreenWidth() / 2 then
        mainTooltip:SetAnchorType("ANCHOR_RIGHT", 0, 0)
        mainTooltip:SetPoint("BOTTOMLEFT", self, "TOPRIGHT")
    else
        mainTooltip:SetAnchorType("ANCHOR_LEFT", 0, 0)
        mainTooltip:SetPoint("BOTTOMRIGHT", self, "TOPLEFT")
    end
end
function GameTooltip_OnUpdate(self)
    local owner = self:GetOwner()
    if owner and owner.UpdateTooltip then owner:UpdateTooltip() end
end
function Mock.WatchNativeSetup()
    local native = ContainerFrameItemButton_CalculateItemTooltipAnchors
    ContainerFrameItemButton_CalculateItemTooltipAnchors = function(self, tooltip)
        Mock.bagSetup = true
        native(self, tooltip)
        assert(tooltip.anchor == (self:GetRight() < 960 and "ANCHOR_RIGHT" or "ANCHOR_LEFT"))
        assert(select(2, tooltip:GetPoint(#tooltip.points)) == self)
        Mock.bagSetup = false
    end
    GameTooltip:SetScript("OnUpdate", GameTooltip_OnUpdate)
end
