Mock = { time = 100, combat = false, speeds = { 2.6, nil, 3.2 },
    units = {}, plates = {}, cvars = { SoftTargetEnemy = "1" }, frames = {}, messages = {} }
local Object = {}
Object.__index = Object
local function New(parent)
    return setmetatable({ parent = parent, shown = true, points = {}, scripts = {},
        events = {}, width = 1, height = 1, frameLevel = 1 }, Object)
end
Mock.Object, Mock.New = Object, New
function Object:CreateTexture() return New(self) end
function Object:CreateMaskTexture() return New(self) end
function Object:AddMaskTexture(mask) self.mask = mask end
function Object:CreateAnimationGroup() return New(self) end
function Object:CreateAnimation(kind)
    self.animations = self.animations or {}
    local anim = New(self)
    anim.kind = kind
    self.animations[#self.animations + 1] = anim
    return anim
end
function Object:SetLooping(value) self.looping = value end
function Object:SetOrder(value) self.order = value end
function Object:SetFromAlpha(value) self.fromAlpha = value end
function Object:SetToAlpha(value) self.toAlpha = value end
function Object:SetDuration(value) self.duration = value end
function Object:IsPlaying() return self.playing or false end
function Object:Play() self.playing = true end
function Object:Stop() self.playing = false end
function Object:CreateFontString(_, _, template)
    local object = New(self)
    object.isFontString, object.font = true, template
    return object
end
function Object:SetTexture(texture) self.texture = texture end
function Object:SetTexCoord(...) self.texCoord = {...} end
function Object:SetAtlas(atlas) self.atlas = atlas end
function Object:SetColorTexture(...) self.colorTexture = { ... } end
function Object:SetVertexColor(...) self.color = { ... } end
function Object:SetGradient(...) self.gradient = { ... } end
function Object:SetPoint(...) self.points[#self.points + 1] = { ... } end
function Object:ClearAllPoints() self.points = {} end
function Object:SetAllPoints(frame) self.allPoints = frame or self.parent end
function Object:SetWidth(width) assert(width > 0 or (self.isFontString and width == 0)); self.width = width end
function Object:SetHeight(height) assert(height > 0); self.height = height end
function Object:SetSize(width, height) self:SetWidth(width); self:SetHeight(height) end
function Object:EnableMouse(enabled) self.mouse = enabled end
function Object:SetFrameLevel(level) self.frameLevel = level end
function Object:SetRoundLayoutToNearestPixel(enabled) self.roundToPixel = enabled end
function Object:SetScale(scale) self.scale = scale end
function Object:GetEffectiveScale()
    return (self.scale or 1) * (self.parent and self.parent:GetEffectiveScale() or 1)
end
function Object:GetFrameLevel() return self.frameLevel end
function Object:SetAlpha(alpha) assert(alpha >= 0 and alpha <= 1); self.alpha = alpha end
function Object:SetBlendMode(mode) self.blendMode = mode end
function Object:SetText(text)
    assert(not self.isFontString or self.font, "FontString:SetText(): Font not set")
    self.text = text
end
function Object:SetFont(path, size, flags) self.font, self.fontSize, self.fontFlags = path, size, flags; return true end
function Object:SetTextColor(...) self.textColor = {...} end
function Object:SetJustifyV(value) self.justifyV = value end
function Object:GetAlpha() return self.alpha or 1 end
function Object:GetWidth() return self.width end
function Object:GetHeight() return self.height end
function Object:GetStringWidth() return #self:GetText() * 5 end
function Object:GetJustifyH() return self.justify end
function Object:GetText() return self.text or "" end
function Object:SetJustifyH(value) self.justify = value end
function Object:SetWordWrap(value) self.wordWrap = value end
function Object:SetClipsChildren(value) self.clips = value end
function Object:SetScrollChild(value) self.scrollChild = value end
function Object:SetChecked(value) self.checked = value end
function Object:GetChecked() return self.checked end
function Object:SetAutoFocus(value) self.autoFocus = value end
function Object:SetMaxLetters(value) self.maxLetters = value end
function Object:HasFocus() return self.focus or false end
function Object:SetFocus() self.focus = true end
function Object:ClearFocus()
    local hadFocus = self.focus
    self.focus = false
    if hadFocus and self.scripts.OnEditFocusLost then self.scripts.OnEditFocusLost(self) end
end
function Object:SetOrientation(value) self.orientation = value end
function Object:SetMinMaxValues(low, high) self.minimum, self.maximum = low, high end
function Object:SetValueStep(value) self.step = value end
function Object:SetObeyStepOnDrag(value) self.obeyStep = value end
function Object:SetThumbTexture(value) self.thumb = New(self); self.thumb.texture = value end
function Object:GetThumbTexture() return self.thumb end
function Object:SetValue(value)
    local changed = self.value ~= value
    self.value = value
    if changed and self.scripts.OnValueChanged then self.scripts.OnValueChanged(self, value) end
end
function Object:SetDefaultText(value) self.defaultText = value end
function Object:SetupMenu(fn) self.menuGenerator = fn end
function Object:GenerateMenu()
    local function Selected(items)
        for _, item in ipairs(items) do
            if item.selected and item.selected() then return item.name end
            if item.items then
                local name = Selected(item.items)
                if name then return name end
            end
        end
    end
    self.selectionText = Selected(Mock.Menu(self)) or self.defaultText
end
function Object:Show()
    local changed = not self.shown
    self.shown = true
    if changed and self.scripts.OnShow then self.scripts.OnShow(self) end
end
function Object:Hide()
    local changed = self.shown
    self.shown = false
    if changed and self.scripts.OnHide then self.scripts.OnHide(self) end
    if changed and self.hideHook then self.hideHook(self) end
end
function Object:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Object:IsShown() return self.shown end
function Object:IsForbidden() return self.forbidden or false end
function Object:GetUnit() return self.unit end
function Object:RegisterEvent(event) self.events[event] = true end
function Object:UnregisterEvent(event) self.events[event] = nil end
function Object:SetScript(event, fn) self.scripts[event] = fn end
function Object:HookScript(event, fn) assert(event == "OnHide"); self.hideHook = fn end
UIParent = New()
function CreateFrame(_, _, parent)
    local frame = New(parent)
    Mock.frames[#Mock.frames + 1] = frame
    return frame
end
function Mock.Plate(unit)
    local plate = CreateFrame("Frame", nil, UIParent)
    plate.unit = unit
    plate.UnitFrame = CreateFrame("Frame", nil, plate)
    plate.UnitFrame.HealthBarsContainer = CreateFrame("Frame", nil, plate.UnitFrame)
    Mock.plates[unit] = plate
    return plate
end
function Mock.Event(event, ...)
    local handled = false
    for _, driver in ipairs(Mock.frames) do
        if driver.events[event] and driver.scripts.OnEvent then
            handled = true; driver.scripts.OnEvent(driver, event, ...)
        end
    end
    assert(handled, "Unregistered event: " .. event)
end
function Mock.Tick(delta)
    Mock.time = Mock.time + delta
    for _, driver in ipairs(Mock.frames) do
        if driver.scripts.OnUpdate and driver:IsShown() then driver.scripts.OnUpdate(driver, delta) end
    end
end
function Mock.Stack(plate)
    for _, frame in ipairs(Mock.frames) do
        if frame.parent == plate and frame.bars then return frame end
    end
end
function GetTime() return Mock.time end
function UnitAttackSpeed(unit) assert(unit == "player"); return unpack(Mock.speeds, 1, 3) end
function UnitExists(unit) return Mock.units[unit] or false end
function UnitAffectingCombat(unit) assert(unit == "player"); return Mock.combat end
function InCombatLockdown() return Mock.lockdown == true end
function securecallfunction(fn, ...)
    local previous = Mock.secureCall
    Mock.secureCall = true
    local results = {pcall(fn, ...)}
    Mock.secureCall = previous
    if not results[1] then error(results[2]) end
    return unpack(results, 2)
end
function issecretvalue(value) return type(value) == "table" and value.secret == true end
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
C_NamePlate = { GetNamePlateForUnit = function(unit, forbidden)
    assert(not forbidden, "Do not request forbidden nameplates")
    return Mock.plates[unit]
end }
C_CVar = { GetCVar = function(name) return Mock.cvars[name] end }
C_Texture = { GetAtlasInfo = function(atlas) return { name = atlas } end }
C_SwingTimer = {}
PixelUtil = { GetPixelToUIUnitFactor = function() return 768 / (Mock.screenHeight or 768) end }
Enum = { PlayerSwingType = { MainHand = 0, OffHand = 1, Ranged = 2 } }
Mock.categories = {}
Settings = {
    RegisterCanvasLayoutCategory = function(frame, name)
        local id = #Mock.categories + 1
        local category = {frame = frame, name = name, GetID = function() return id end}
        Mock.categories[id] = category
        return category
    end,
    RegisterAddOnCategory = function(category)
        if not category.parent then Mock.addonCategory = category end
    end,
    OpenToCategory = function(id)
        assert(not InCombatLockdown(), "Interface action failed because of an AddOn")
        assert(Mock.secureCall, "Settings should open through a secure call")
        Mock.openCalls = (Mock.openCalls or 0) + 1
        for _, category in ipairs(Mock.categories) do category.frame:Hide() end
        assert(Mock.categories[id]); Mock.categories[id].frame:Show()
    end,
}
function Settings.RegisterCanvasLayoutSubcategory(parent, frame, name)
    local category = Settings.RegisterCanvasLayoutCategory(frame, name)
    category.parent = parent
    return category
end
function hooksecurefunc(object, key, callback)
    local original = object[key]
    object[key] = function(...) original(...); callback(...) end
end
function UnitCanAttack() return not Mock.friendly end
function UnitCanAssist() return Mock.friendly == true end
function UnitIsPlayer() return false end
function UnitName() return "Tester" end
function UnitGUID(unit)
    return Mock.guids and Mock.guids[unit] or "Creature-0-0-0-0-123-0"
end
C_Item = {GetItemCount = function(itemID, includeBank)
    assert(not includeBank, "Quest ingredients must be available in bags")
    return Mock.itemCounts and Mock.itemCounts[itemID] or 0
end,
    GetItemNameByID = function(itemID) return Mock.itemNames and Mock.itemNames[itemID] end,
    RequestLoadItemDataByID = function(itemID)
        Mock.itemRequests = Mock.itemRequests or {}
        Mock.itemRequests[itemID] = (Mock.itemRequests[itemID] or 0) + 1
    end,
}
C_Spell = {
    GetSpellInfo = function(value)
        if value == "Moonfire" or value == 8921 then return {name = "Moonfire", spellID = 8921, maxRange = 30} end
        if value == "Healing Touch" or value == 5185 then return {name = "Healing Touch", spellID = 5185, maxRange = 40} end
    end,
    IsSpellHarmful = function(id) return id == 8921 end,
    IsSpellHelpful = function(id) return id == 5185 end,
    IsSpellInRange = function() return Mock.rangeResult end,
}
C_QuestLog = {
    GetNumQuestLogEntries = function() return Mock.questEntries and #Mock.questEntries or 1 end,
    GetInfo = function(index) return Mock.questEntries and Mock.questEntries[index] or {questID = 123} end,
    GetQuestObjectives = function(id) return Mock.questObjectives and Mock.questObjectives[id] or {
        {text = "Wolf Pelt: 0/5", type = "item", finished = Mock.questComplete},
        {text = "Wolf slain: 0/10", type = "monster", finished = Mock.questComplete},
    } end,
}
C_TooltipInfo = {GetUnit = function() return {lines = Mock.tooltipLines or {
    {leftText = "0/5 Wolf Pelt"}, {leftText = "0/10 Wolf slain"},
}} end}
ColorPickerFrame = New(UIParent)
ColorPickerFrame:Hide()
function ColorPickerFrame:GetColorRGB() return unpack(self.rgb) end
function ColorPickerFrame:SetupColorPickerAndShow(info)
    self.info, self.rgb = info, {info.r, info.g, info.b}
    self:Show()
end
function Mock.Pick(r, g, b)
    ColorPickerFrame.rgb = {r, g, b}
    ColorPickerFrame.info.swatchFunc()
end
function Mock.CancelPicker()
    ColorPickerFrame.info.cancelFunc()
    ColorPickerFrame:Hide()
end
function Mock.Menu(dropdown)
    local function Root()
        local root = { items = {} }
        function root:CreateRadio(name, selected, callback)
            local item = { name = name, selected = selected, callback = callback }
            self.items[#self.items + 1] = item
            return item
        end
        function root:CreateButton(name)
            local item = Root(); item.name = name
            self.items[#self.items + 1] = item
            return item
        end
        return root
    end
    local root = Root()
    dropdown.menuGenerator(dropdown, root)
    return root.items
end
SlashCmdList = {}
function print(message) Mock.messages[#Mock.messages + 1] = message end
