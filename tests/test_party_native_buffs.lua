local vv = VV_TEST_NS
local checks, reads, nativeUpdates = 0, 0, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local create = CreateFrame
local containers = {}
AuraContainerSortMethod = {Default=0}
CustomAuraContainerGroupDefaultOptions = {}

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
    for index, button in ipairs(container.buttons or {}) do
        local aura = data[index]
        if aura then
            button.boundIcon:SetTexture(aura.icon)
            button.boundCount:SetText((aura.applications or 0) > 1 and aura.applications or "")
            button.boundCooldown.nativeAura = aura
            button.nativeAuraID = aura.auraInstanceID
            button:Show()
        else button:Hide() end
    end
end
CreateFrame = function(kind, name, parent, template)
    local frame = create(kind, name, parent, template)
    if kind == "AuraContainer" then
        assert(not Mock.combat, "Native containers must be prepared before combat")
        assert(template == "CustomAuraContainerTemplate")
        frame.buttons = {}
        function frame:SetEnabled(value) self.enabled = value; render(self) end
        function frame:SetUnit(unit) self.unit = unit; render(self) end
        function frame:SetFlowLayoutAnchorPoint(point) self.flowAnchor = point end
        function frame:SetFlowLayoutMaximumLineSize(width) self.lineWidth = width end
        function frame:AddAuraGroup(key, filter, options)
            self.groupKey, self.filter, self.options = key, filter, options
            for index = 1, options.maxFrameCount do
                local button = create("Button", nil, self)
                function button:SetTooltipAnchorPoint(point) self.tooltipAnchor = point end
                function button:SetHideTooltipInCombat(value) self.hideTooltipInCombat = value end
                function button:SetIcon(icon) self.boundIcon = icon end
                function button:SetDurationCooldown(cooldown) self.boundCooldown = cooldown end
                function button:SetApplicationCount(count) self.boundCount = count end
                options.initializeFrame(button)
                button:Hide()
                self.buttons[index] = button
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
for _, frame in ipairs(containers) do if frame.parent == row then container = frame end end
check(container and container.unit == "party1" and not container.enabled and ordinaryIcon:IsShown(),
    "Normal buff rendering is retained outside combat")
check(container.filter == "HELPFUL" and container.options.maxFrameCount == 16
    and container.options.sortMethod == AuraContainerSortMethod.Default, "Native display is limited to sixteen helpful buffs")
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
for _, frame in ipairs(containers) do if frame.parent == Mock.Row(newcomer) then newContainer = frame end end
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
