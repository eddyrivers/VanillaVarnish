local vv = VV_TEST_NS
local checks, reads, nativeUpdates = 0, 0, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local create = CreateFrame
local containers = {}
AuraContainerSortMethod = {Default=0}
CustomAuraContainerGroupDefaultOptions = {}
local createGlow = vv.Party.CreateBuffGlow
vv.Party.CreateBuffGlow = function(parent, relative)
    local glow = createGlow(parent, relative)
    relative.testGlow = glow -- Test instrumentation during presentation setup only.
    return glow
end

-- Model the trust boundary: ordinary addon reads throw in combat. Only the
-- native container's own renderer can consume the current aura data then.
local function blockedInCombat(fn)
    return function(...)
        if Mock.combat then reads = reads + 1; error("Auras cannot be accessed when secret while tainted") end
        return fn(...)
    end
end
C_UnitAuras.GetUnitAuras = blockedInCombat(C_UnitAuras.GetUnitAuras)
C_UnitAuras.GetUnitAuraInstanceIDs = blockedInCombat(function(unit)
    local ids = {}
    for _, aura in ipairs(Mock.auras[unit] or {}) do ids[#ids + 1] = aura.auraInstanceID end
    return ids
end)
C_UnitAuras.GetAuraDataByAuraInstanceID = blockedInCombat(function(unit, id)
    for _, aura in ipairs(Mock.auras[unit] or {}) do if aura.auraInstanceID == id then return aura end end
end)
C_UnitAuras.GetAuraDataByIndex = blockedInCombat(function() return nil end)

local function render(container)
    nativeUpdates = nativeUpdates + 1
    local data = container.enabled and container:IsVisible() and Mock.auras[container.unit] or {}
    local flowing = {}
    for _, group in ipairs(container.groups or {}) do
        local filtered = {}
        for _, aura in ipairs(data or {}) do
            local own = aura.sourceUnit == "player" or aura.sourceUnit == "pet" or aura.sourceUnit == "vehicle"
            if own == (group.filter == "HELPFUL|PLAYER") then filtered[#filtered + 1] = aura end
        end
        table.sort(filtered, function(a,b) return a.auraInstanceID < b.auraInstanceID end)
        for index, button in ipairs(group.buttons) do
            local aura = filtered[index]
            if aura then
                button.boundIcon:SetTexture(aura.icon)
                button.boundCount:SetText((aura.applications or 0) > 1 and aura.applications or "")
                button.boundCooldown.nativeAura = aura
                button.nativeAuraID = aura.auraInstanceID
                button:Show()
                flowing[#flowing + 1] = button
                button.flowPosition = #flowing
            else button:Hide() end
        end
    end
    if #flowing > 0 then container.buttons = flowing end
end
CreateFrame = function(kind, name, parent, template)
    local frame = create(kind, name, parent, template)
    if kind == "AuraContainer" then
        assert(not Mock.combat, "Native containers must be prepared before combat")
        assert(template == "CustomAuraContainerTemplate")
        frame.buttons = {}
        frame.groups = {}
        function frame:SetEnabled(value) self.enabled = value; render(self) end
        function frame:SetUnit(unit) self.unit = unit; render(self) end
        function frame:SetFlowLayoutAnchorPoint(point) self.flowAnchor = point end
        function frame:SetFlowLayoutMaximumLineSize(width) self.lineWidth = width end
        function frame:AddAuraGroup(key, filter, options)
            self.groupKey, self.filter, self.options = key, filter, options
            local group = {key=key,filter=filter,options=options,buttons={}}
            self.groups[#self.groups + 1] = group
            for index = 1, options.maxFrameCount do
                local button = create("Button", nil, self)
                local isVisible = button.IsVisible
                function button:IsVisible()
                    local perRow = math.floor((frame.lineWidth + options.layout.elementSpacing)
                        / (options.layout.elementWidth + options.layout.elementSpacing))
                    local y = 2 + math.floor(((self.flowPosition or 1) - 1) / perRow)
                        * (options.layout.elementHeight + options.layout.lineSpacing)
                    return isVisible(self) and y + self:GetHeight() <= frame.parent:GetHeight()
                end
                function button:SetTooltipAnchorPoint(point) self.tooltipAnchor = point end
                function button:SetHideTooltipInCombat(value) self.hideTooltipInCombat = value end
                function button:SetIcon(icon) self.boundIcon = icon end
                function button:SetDurationCooldown(cooldown) self.boundCooldown = cooldown end
                function button:SetApplicationCount(count) self.boundCount = count end
                options.initializeFrame(button)
                button:Hide()
                group.buttons[index] = button
                if #self.groups == 1 then self.buttons[index] = button end
            end
        end
        local show, hide = frame.Show, frame.Hide
        function frame:Show() show(self); render(self) end
        function frame:Hide() hide(self); render(self) end
        containers[#containers + 1] = frame
    end
    return frame
end

local member = Mock.Member("party1")
local newcomer = Mock.Member("party2")
newcomer:Hide()
Mock.auras.party1 = {{icon=17, auraInstanceID=101, applications=2}}
Mock.auras.party2 = {{icon=25, auraInstanceID=201, applications=1}}
Mock.Event("PLAYER_LOGIN")
local row = assert(Mock.Row(member))
local ordinaryIcon = Mock.Icons(row)[1]
check(#containers == 2, "Hidden roster slots also prepare a native combat display")
local container
for _, frame in ipairs(containers) do if frame.parent.parent == row then container = frame end end
check(container and container.unit == "party1" and not container.enabled and ordinaryIcon:IsShown(),
    "Normal buff rendering is retained outside combat")
check(container.groups[1].filter == "HELPFUL|PLAYER" and container.groups[2].filter == "HELPFUL|!PLAYER"
    and container.options.maxFrameCount == 16 and container.options.sortMethod == AuraContainerSortMethod.Default,
    "Complementary native helpful filters separate ownership without addon reads")
check(container.parent.clipsChildren and container.parent.width == 130 and container.parent.height == 39,
    "The fixed native viewport clips after two eight-buff rows and includes the glow margin")
check(container.lineWidth == 126 and container.options.layout.lineSpacing == 7, "Native icons fit eight per reserved row")
check(container.buttons[1].clicks == false and container.buttons[1].hideTooltipInCombat == false
    and container.buttons[1].tooltipAnchor == "ANCHOR_BOTTOMRIGHT", "Native tooltips keep working without intercepting party targeting")

local height, frameCount = member:GetHeight(), #Mock.frames
Mock.combat = true
Mock.Event("PLAYER_REGEN_DISABLED")
check(container.enabled and container:IsVisible() and not ordinaryIcon:IsShown(), "Combat switches immediately to the native renderer")
check(container.buttons[1]:IsShown() and container.buttons[1].boundIcon.textureValue == 17
    and container.buttons[1].boundCount.text == 2, "The native display keeps current buff icons and counts")
Mock.auras.party1 = {{icon=31, auraInstanceID=102, applications=3}, {icon=37, auraInstanceID=103}}
render(container) -- native UNIT_AURA delivery, independent of addon queries
Mock.Event("UNIT_AURA", "party1"); Mock.Tick(1)
check(container.buttons[1].boundIcon.textureValue == 31 and container.buttons[2]:IsShown(), "Native aura updates remain live during combat")
check(reads == 0, "No addon aura API reads are attempted while native combat rendering is active")
check(member:GetHeight() == height and #Mock.frames == frameCount, "Combat never rebuilds the protected layout or creates another container")
newcomer:Show()
Mock.Event("GROUP_ROSTER_UPDATE")
local newContainer
for _, frame in ipairs(containers) do if frame.parent.parent == Mock.Row(newcomer) then newContainer = frame end end
check(newContainer.enabled and newContainer.unit == "party2" and newContainer.buttons[1]:IsShown(),
    "A previously hidden prepared party slot can appear during combat")
Mock.auras.party1 = {}
render(container)
check(not container.buttons[1]:IsShown() and not container.buttons[2]:IsShown(), "The native renderer removes expired buffs")
member.unit = "party3"
Mock.classes.party3 = "MAGE"
Mock.auras.party3 = {{icon=41, auraInstanceID=301}}
Mock.Event("GROUP_ROSTER_UPDATE")
check(container.unit == "party3" and container.buttons[1].boundIcon.textureValue == 41, "A reused slot rebinds natively without carrying another member's buffs")
vv.Party.SetOption("buffs", false)
check(not container.enabled and not container:IsVisible() and not row:IsShown(), "Disabling buffs in combat hides the native row")
vv.Party.SetOption("buffs", true)
check(container.enabled and container.unit == "party3" and container:IsVisible(), "Re-enabling buffs in combat uses the prepared native display")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
check(not container.enabled and not container:IsShown() and ordinaryIcon:IsShown()
    and ordinaryIcon.texture.textureValue == 41, "Leaving combat restores normal buff sorting and presentation")
check(reads == 0 and nativeUpdates > 0, "Native rendering survives the reported all-readers-blocked restriction")
Mock.auras.party3 = {}
for index = 1, 25 do
    Mock.auras.party3[index] = {icon=index, auraInstanceID=index, sourceUnit=index <= 5 and "player" or index == 6 and "pet" or "party2"}
end
Mock.combat = true
Mock.Event("PLAYER_REGEN_DISABLED")
check(container.buttons[1].nativeAuraID == 1 and container.buttons[6].nativeAuraID == 6
    and container.buttons[7].nativeAuraID == 7, "Native player and pet buffs precede other buffs without gaps")
local shown = 0
for _, button in ipairs(container.buttons) do if button:IsVisible() then shown = shown + 1 end end
check(shown == 16 and not container.buttons[17]:IsVisible(), "Mixed native ownership still displays only sixteen buffs")
check(container.buttons[1].testGlow and container.buttons[6].testGlow and not container.buttons[7].testGlow,
    "Native player and pet buffs glow while other players' buffs do not")
check(container.groups[1].options.layout.layoutIndex == 1 and container.groups[2].options.layout.layoutIndex == 2,
    "Native group order is explicit and independent of pooled aura frames")
for _, ownCount in ipairs({0, 1, 8, 9, 16, 20}) do
    Mock.auras.party3 = {}
    for index = 1, 30 do
        Mock.auras.party3[index] = {icon=index, auraInstanceID=index, sourceUnit=index <= ownCount and "player" or "party2"}
    end
    render(container)
    local visible, glowing = 0, 0
    for _, button in ipairs(container.buttons) do
        if button:IsVisible() then
            visible = visible + 1
            if button.testGlow then glowing = glowing + 1 end
        end
    end
    check(visible == 16 and glowing == math.min(16, ownCount), "Native ownership partitions fill two rows without overflowing or losing glows")
end
check(reads == 0, "Ownership highlighting never queries restricted auras from addon code")
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
check(vv.Party.CreateNativeBuffs(row) ~= nil, "Native renderer construction is available outside combat")
Mock.combat = true
local before = #containers
check(vv.Party.CreateNativeBuffs(row) == nil and #containers == before, "Combat cannot construct a replacement aura container")
Mock.combat = false
local failingCreate = CreateFrame
local failedContainer
CreateFrame = function(kind, ...)
    local frame = failingCreate(kind, ...)
    if kind == "AuraContainer" then
        failedContainer = frame
        frame.AddAuraGroup = function() error("native aura template unavailable") end
    end
    return frame
end
local failed, reason = vv.Party.CreateNativeBuffs(row)
check(failed == nil and reason:find("native aura template unavailable", 1, true)
    and not failedContainer.enabled and not failedContainer:IsShown(), "Failed native setup is disabled and reports its cause")
CreateFrame = failingCreate
local messages = {}
print = function(message) messages[#messages + 1] = message end
Mock.combat = true
Mock.Event("PLAYER_REGEN_DISABLED")
vv.Party.HandleSlash("status")
check(table.concat(messages, "\n"):find("source: native container", 1, true)
    and table.concat(messages, "\n"):find("native combat renderer: ready", 1, true), "Status identifies native combat rendering without reading private aura data")
VV_NATIVE_BUFF_CHECKS = checks
