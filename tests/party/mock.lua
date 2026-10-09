Mock = { frames = {}, active = {}, combat = false, auras = {}, classes = {} }
local Widget = {}
function Widget:SetSize(w, h) self.width, self.height = w, h end
function Widget:SetHeight(h)
    assert(not self.native or not Mock.combat, "protected height changed during combat")
    self.height = h
end
function Widget:GetHeight() return self.height or 53 end
function Widget:GetLeft() return self.left end
function Widget:GetEffectiveScale() return self.scale or (self.parent and self.parent:GetEffectiveScale()) or 1 end
function Widget:SetFrameLevel(level) self.level = level end
function Widget:GetFrameLevel() return self.level or 2 end
function Widget:SetPoint(...) self.point = {...} end
function Widget:ClearAllPoints() self.point = nil end
function Widget:SetAllPoints() end
function Widget:SetColorTexture() end
function Widget:SetTexCoord() end
function Widget:SetReverse() end
function Widget:SetDrawEdge() end
function Widget:SetHideCountdownNumbers() end
function Widget:EnableMouse() end
function Widget:SetMouseClickEnabled(enabled) self.clicks = enabled end
function Widget:SetScript(name, fn) self.scripts[name] = fn end
function Widget:RegisterEvent(event) self.events = self.events or {}; self.events[event] = true end
function Widget:IsShown() return not self.hidden end
function Widget:IsVisible() return not self.hidden and (not self.parent or self.parent:IsVisible()) end
function Widget:Show() self.hidden = false end
function Widget:Hide() self.hidden = true end
function Widget:SetTexture(value) self.textureValue = value end
function Widget:SetText(value) self.text = value end
function Widget:Clear() self.cooldownValue, self.durationObject = nil, nil end
function Widget:SetCooldown(start, duration) self.cooldownValue = {start, duration} end
function Widget:SetCooldownFromDurationObject(value) self.durationObject = value end
function Widget:SetStatusBarColor(r, g, b, a) self.color = {r, g, b, a} end
function Widget:GetStatusBarTexture() return self.barTexture end
function Widget:SetDesaturated(value) self.desaturated = value end
function Widget:IsDesaturated() return self.desaturated or false end
function Widget:GetStatusBarColor() return unpack(self.color or {0, 1, 0}) end
local function widget(parent)
    return setmetatable({parent = parent, scripts = {}}, {__index = Widget})
end
function Widget:CreateTexture() return widget(self) end
function Widget:CreateFontString() return widget(self) end
function CreateFrame(kind, name, parent, template)
    local frame = widget(parent)
    frame.kind, frame.template = kind, template
    Mock.frames[#Mock.frames + 1] = frame
    return frame
end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
function InCombatLockdown() return Mock.combat end
function UnitExists(unit) return Mock.classes[unit] ~= nil end
function UnitClass(unit) return "Class", Mock.classes[unit] end
RAID_CLASS_COLORS = {MAGE = {r = 0.25, g = 0.78, b = 0.92}, WARRIOR = {r = 0.78, g = 0.61, b = 0.43}}
C_Timer = {After = function(_, fn) Mock.pending = fn end}
C_UnitAuras = {}
function C_UnitAuras.GetUnitAuras(unit, filter, max)
    assert(filter == "HELPFUL" and max == 8)
    if Mock.refuse then error("aura access refused") end
    return Mock.auras[unit] or {}
end
function C_UnitAuras.GetAuraApplicationDisplayCount() return "3" end
function C_UnitAuras.GetAuraDuration() return "native duration" end
GameTooltip = {
    IsOwned = function(self, icon) return self.owner == icon end,
    SetOwner = function(self, icon) self.owner = icon end,
    Hide = function(self) self.owner, self.shown = nil, false end,
    Show = function(self) self.shown = true end,
    SetUnitBuffByAuraInstanceID = function(self, unit, id) self.unit, self.id = unit, id end,
    SetUnitBuff = function(self, unit, index) self.unit, self.index = unit, index end,
}
SlashCmdList = {}
function print(value) Mock.message = value end
PartyFrame = {PartyMemberFramePool = {}, Layout = function() Mock.layouts = (Mock.layouts or 0) + 1 end}
function PartyFrame.PartyMemberFramePool:EnumerateActive()
    local index = 0
    return function() index = index + 1; return Mock.active[index] end
end
function Mock.Member(unit)
    local member = widget()
    member.native, member.unit = true, unit
    member.HealthBarContainer = {HealthBar = widget(member)}
    member.HealthBarContainer.HealthBar.left = 45
    member.HealthBarContainer.HealthBar.barTexture = widget()
    member.ManaBar = widget(member)
    member.ManaBar.left = 41
    member.PetFrame = widget(member)
    member.PetFrame:Hide()
    Mock.active[#Mock.active + 1] = member
    Mock.classes[unit] = "MAGE"
    return member
end
function Mock.Event(event, unit)
    for _, frame in ipairs(Mock.frames) do
        if frame.events and frame.events[event] and frame.scripts.OnEvent then frame.scripts.OnEvent(frame, event, unit) end
    end
    if Mock.pending then local fn = Mock.pending; Mock.pending = nil; fn() end
end
function Mock.Tick(delta) for _, frame in ipairs(Mock.frames) do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, delta) end end end
function Mock.Row(member)
    for _, frame in ipairs(Mock.frames) do
        if frame.parent == member and frame.width == 126 then return frame end
    end
end
function Mock.Icons(row)
    local icons = {}
    for _, frame in ipairs(Mock.frames) do
        if frame.parent == row and frame.width == 14 then icons[#icons + 1] = frame end
    end
    return icons
end
