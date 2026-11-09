-- Minimal owned-frame API for exercising the real fallback renderer.
MockFrames = {}
MockGeometry = {}
UIParent = {}
function UIParent:GetRight() return 1920 end
function UIParent:GetEffectiveScale() return 1 end
MockTimers = {}
function MockDropdownMenu(dropdown)
    local root = {items={}}
    function root:CreateRadio(label, selected, callback)
        self.items[#self.items + 1] = {label=label, selected=selected, callback=callback}
    end
    dropdown.menuGenerator(dropdown, root)
    return root.items
end
C_Timer = { After = function(_, callback) MockTimers[#MockTimers + 1] = callback end }
function RunMockTimers()
    local pending = MockTimers
    MockTimers = {}
    for _, callback in ipairs(pending) do callback() end
end
local function region()
    local value = { size = 12 }
    function value:SetPoint(...) self.point = { ... } end
    function value:ClearAllPoints() self.point = nil end
    function value:SetWidth(width) self.width = width end
    function value:SetSize(width, height) self.width, self.height = width, height end
    function value:SetJustifyH() end
    function value:SetWordWrap() end
    function value:SetText(text) self.text = text end
    function value:SetTextColor(...) self.color = { ... } end
    function value:GetFont() return "TestFont.ttf", self.size, "" end
    function value:SetFont(_, size) self.size = size end
    function value:GetStringHeight()
        local _, lines = (self.text or ""):gsub("\n", "")
        return (lines + 1) * self.size
    end
    function value:SetTexture(texture) self.texture = texture end
    function value:GetText() return self.text end
    function value:GetSize() return self.width or 20, self.height or 20 end
    function value:GetWidth() return self.width or 20 end
    function value:GetHeight() return self.height or 20 end
    function value:GetScale() return self.scale or 1 end
    function value:SetScale(scale) self.scale = scale end
    function value:GetPoint() return unpack(self.point) end
    function value:Show() self.shown = true end
    function value:Hide() self.shown = false end
    return value
end
CreateFrame = function(kind, name, parent, template)
    local frame = { kind = kind, parent = parent, template = template, scripts = {}, scroll = 0 }
    MockGeometry[frame] = { width = 300, height = 1, points = {}, shown = true }
    MockFrames[#MockFrames + 1] = frame
    if name then _G[name] = frame end
    function frame:SetScript(event, callback)
        self.scripts[event] = callback
        if event == "OnEvent" then self.callback = callback end
    end
    function frame:GetScript(event) return self.scripts[event] end
    function frame:GetParent() return self.parent end
    function frame:SetParent(parent) self.parent = parent end
    function frame:EnableMouseWheel(enabled) self.mouseWheel = enabled end
    function frame:SetHideIfUnscrollable(enabled) self.hideIfUnscrollable = enabled end
    function frame:GetEffectiveScale() return 1 end
    function frame:GetRight() return 1900 end
    function frame:RegisterEvent() end
    function frame:HookScript(event, callback)
        local original = self.scripts[event]
        self.scripts[event] = function(...)
            if original then original(...) end
            callback(...)
        end
    end
    function frame:RegisterForClicks() end
    function frame:SetText(text) self.text = text end
    function frame:SetChecked(checked) self.checked = not not checked end
    function frame:GetChecked() return self.checked end
    function frame:SetupMenu(generator) self.menuGenerator = generator end
    function frame:GenerateMenu()
        self.selectionText = nil
        for _, item in ipairs(MockDropdownMenu(self)) do
            if item.selected() then self.selectionText = item.label end
        end
    end
    function frame:SetNormalTexture(texture) self.normalTexture = texture end
    function frame:SetHighlightTexture(texture) self.highlightTexture = texture end
    function frame:RegisterForDrag() end
    function frame:IsForbidden() return self.forbidden == true end
    function frame:IsProtected() return self.protected == true end
    local function CheckLayout(self)
        assert(not (InCombatLockdown() and (self:IsProtected() or self:IsForbidden())),
            "An addon cannot change a protected frame in combat")
    end
    function frame:SetPoint(...)
        CheckLayout(self)
        local point = { ... }
        local points = MockGeometry[self].points
        for index, current in ipairs(points) do
            if current[1] == point[1] then points[index] = point; return end
        end
        points[#points + 1] = point
    end
    function frame:GetNumPoints() return #MockGeometry[self].points end
    function frame:GetPoint(index) return unpack(MockGeometry[self].points[index or 1] or {}) end
    function frame:ClearAllPoints() CheckLayout(self); MockGeometry[self].points = {} end
    function frame:SetWidth(width) MockGeometry[self].width = width end
    function frame:GetWidth() return MockGeometry[self].width end
    function frame:SetHeight(height)
        CheckLayout(self)
        local changed = MockGeometry[self].height ~= height
        MockGeometry[self].height = height
        if changed and self.scripts.OnSizeChanged then self.scripts.OnSizeChanged(self, self:GetWidth(), height) end
    end
    function frame:SetSize(width, height) MockGeometry[self].width, MockGeometry[self].height = width, height end
    function frame:GetSize() return MockGeometry[self].width, MockGeometry[self].height end
    function frame:SetFrameStrata() end
    function frame:SetClampedToScreen() end
    function frame:SetMovable() end
    function frame:SetBackdrop() end
    function frame:SetBackdropColor() end
    function frame:StartMoving() self.moving = true end
    function frame:StopMovingOrSizing() self.moving = false end
    function frame:GetLeft() return 100 end
    function frame:GetTop() return 500 end
    function frame:GetBottom() return self:GetTop() - self:GetHeight() end
    function frame:GetHeight() return MockGeometry[self].height end
    function frame:SetScrollChild(child) self.child = child end
    function frame:SetVerticalScroll(value) self.scroll = value end
    function frame:GetVerticalScroll() return self.scroll end
    function frame:GetVerticalScrollRange() return math.max(0, self.child:GetHeight() - self:GetHeight()) end
    function frame:UpdateScrollChildRect() end
    function frame:CreateFontString() return region() end
    function frame:CreateTexture() return region() end
    function frame:IsShown() return MockGeometry[self].shown end
    function frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
    function frame:Show()
        CheckLayout(self)
        local wasShown = MockGeometry[self].shown
        MockGeometry[self].shown = true
        if not wasShown and self.scripts.OnShow then self.scripts.OnShow(self) end
    end
    function frame:Hide() CheckLayout(self); MockGeometry[self].shown = false end
    if template == "ScrollFrameTemplate" then
        frame.ScrollBar = CreateFrame("Slider", nil, frame)
    end
    return frame
end
