local _, VV = ...
local addon = VV.QuestTracker
local scroll = {}
addon.Scrolling = scroll

-- This is a layout allowance, never the saved or visible tracker height.
-- Blizzard still builds and owns every block, line, and quest item button.
local LAYOUT_HEIGHT, LEFT_MARGIN = 100000, 30
local container, viewport, canvas
local active, layingOut, pendingHeight, sizeScript
local parents = setmetatable({}, { __mode = "k" })
local Finish

local function Editable(frame)
    return not frame:IsForbidden() and (not InCombatLockdown() or not frame:IsProtected())
end

local function CanChange()
    if not Editable(container) then return false end
    if viewport and (not Editable(viewport) or not Editable(canvas)) then return false end
    for _, module in ipairs(container.modules) do
        if not Editable(module) or (module.ContentsFrame and not Editable(module.ContentsFrame)) then return false end
        local block = module.firstBlock
        while block do
            if not Editable(block) then return false end
            for region in pairs(block.addedRegions or {}) do
                if not Editable(region) then return false end
            end
            block = block.nextBlock
        end
    end
    return true
end

local function Wanted()
    return addon.db and addon.db.scrolling and VV.IsModuleEnabled("questTracker")
        and not (EditModeManagerFrame and EditModeManagerFrame:IsEditModeActive())
end

local function RestoreHeight()
    if not pendingHeight then return end
    local height = pendingHeight
    pendingHeight = nil
    -- Synthetic layout sizing must not enqueue another native dirty update.
    -- Preserve the exact native script, including any other addons' hooks.
    container:SetHeight(height)
    container:SetScript("OnSizeChanged", sizeScript)
    sizeScript = nil
end

local function Detach()
    if not active then return end
    viewport:SetVerticalScroll(0)
    local previous
    for _, module in ipairs(container.modules) do
        if parents[module] then module:SetParent(parents[module]); parents[module] = nil end
        if module:GetContentsHeight() > 0 then
            module:ClearAllPoints()
            module:SetPoint("TOP", previous or container, previous and "BOTTOM" or "TOP", 0,
                previous and -container.moduleSpacing or -(container.topModulePadding or 0))
            module:SetPoint("LEFT", container, "LEFT", module.leftMargin or 0, 0)
            previous = module
        end
    end
    if previous and container.NineSlice then
        container.NineSlice:SetPoint("BOTTOM", previous, "BOTTOM", 0, -(container.bottomModulePadding or 0))
    end
    viewport:Hide()
    active = false
end

local function EnsureFrames()
    if viewport then return end
    viewport = CreateFrame("ScrollFrame", nil, container, "ScrollFrameTemplate")
    viewport:Hide()
    viewport.ScrollBar:SetHideIfUnscrollable(true)
    canvas = CreateFrame("Frame", nil, viewport)
    viewport:SetScrollChild(canvas)
    viewport:EnableMouseWheel(true)
    viewport:SetScript("OnMouseWheel", function(self, delta)
        if not CanChange() then return end
        local value = math.max(0, math.min(self:GetVerticalScrollRange(), self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(value)
    end)
end

local function SizeViewport()
    local padding = container.topModulePadding or 38
    local header = container.Header
    local headerBottom = header and header:GetBottom()
    local top = container:GetTop()
    -- Native padding may include space reserved by other UI providers. The
    -- visible header is the boundary we need, including when its own anchor
    -- changes during a native update. Do not reserve that space twice.
    if top and headerBottom then padding = math.max(0, top - headerBottom + 6) end
    viewport:ClearAllPoints()
    if top and headerBottom then
        viewport:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -LEFT_MARGIN, -6)
    else
        viewport:SetPoint("TOPLEFT", container, "TOPLEFT", -LEFT_MARGIN, -padding)
    end
    viewport:SetSize(container:GetWidth() + LEFT_MARGIN,
        math.max(1, container:GetHeight() - padding - (container.bottomModulePadding or 0)))
    canvas:SetWidth(viewport:GetWidth())
    -- The native pass temporarily anchors the first module below its own
    -- container padding. Pin the scroll child itself to the viewport as well,
    -- so that temporary content bounds cannot leave a second top inset.
    canvas:ClearAllPoints()
    canvas:SetPoint("TOPLEFT", viewport, "TOPLEFT", 0, 0)
end

local function Begin()
    if pendingHeight then return end
    if not CanChange() then return end
    if not Wanted() or container:IsCollapsed() then Detach(); return end
    EnsureFrames()
    SizeViewport()
    for _, module in ipairs(container.modules) do
        if not parents[module] then parents[module] = module:GetParent() end
        module:SetParent(canvas)
    end
    active = true
    layingOut = true
    pendingHeight = container:GetHeight()
    sizeScript = container:GetScript("OnSizeChanged")
    container:SetScript("OnSizeChanged", nil)
    container:SetHeight(LAYOUT_HEIGHT)
    -- Also finish if a captured native update bypasses the outer posthook,
    -- or an interrupted update never reaches its final header-position call.
    C_Timer.After(0, function() Finish() end)
end

local function LayoutCanvas()
    if not CanChange() then return end
    SizeViewport()
    local height = viewport:GetHeight()
    local previous, total = nil, 0
    for _, module in ipairs(container.modules) do
        if module:GetContentsHeight() > 0 then
            module:ClearAllPoints()
            module:SetPoint("TOP", previous or canvas, previous and "BOTTOM" or "TOP", 0,
                previous and -container.moduleSpacing or 0)
            module:SetPoint("LEFT", canvas, "LEFT", LEFT_MARGIN + (module.leftMargin or 0), 0)
            total = total + module:GetHeight() + (previous and container.moduleSpacing or 0)
            previous = module
        end
    end
    canvas:SetHeight(math.max(1, total))
    viewport:UpdateScrollChildRect()
    local range = math.max(0, total - height)
    viewport:SetVerticalScroll(math.min(viewport:GetVerticalScroll(), range))
    local bar = viewport.ScrollBar
    if bar then
        -- Use Blizzard's scrollbar artwork. Put it to the left when the
        -- default tracker position leaves no room at the screen's right edge.
        local right = container:GetRight()
        local room = right and (UIParent:GetRight() * UIParent:GetEffectiveScale()
            - right * container:GetEffectiveScale()) / container:GetEffectiveScale() or 0
        bar:ClearAllPoints()
        local side, relative, x = "TOPLEFT", "TOPRIGHT", 2
        if room < 24 then side, relative, x = "TOPRIGHT", "TOPLEFT", -2 end
        bar:SetPoint(side, viewport, relative, x, 0)
        bar:SetHeight(height)
        bar:SetShown(range > 0)
    end
    if container.NineSlice and previous then
        container.NineSlice:SetPoint("BOTTOM", range > 0 and viewport or previous, "BOTTOM", 0,
            -(container.bottomModulePadding or 0))
    end
    viewport:Show()
end

Finish = function()
    if not layingOut then return end
    RestoreHeight()
    layingOut = false
    LayoutCanvas()
end

function scroll.Install(frame)
    if container then return end
    -- Only the main Forever tracker has the header gate that runs before
    -- Blizzard reads its layout budget. Never replace a native Lua method.
    if not frame or type(frame.ShouldShowHeader) ~= "function"
        or type(frame.UpdateTopPadding) ~= "function" or not frame.modules then return end
    container = frame
    hooksecurefunc(container, "ShouldShowHeader", Begin)
    -- The native container has already read GetAvailableHeight into a local
    -- before this call. Restore its physical height and handler immediately,
    -- before block construction, animations, or managed-frame positioning.
    hooksecurefunc(container, "UpdateTopPadding", RestoreHeight)
    -- DirtiableMixin saves a closure over Update during native OnLoad, before
    -- our posthooks exist. That closure bypasses the outer Update posthook,
    -- but still dispatches this final method after positioning every module.
    if type(container.UpdateHeaderPosition) == "function" then
        hooksecurefunc(container, "UpdateHeaderPosition", Finish)
    end
    hooksecurefunc(container, "Update", Finish)
end

function scroll.IsActive()
    return active == true
end

function scroll.Refresh()
    if not container or layingOut or not CanChange() then return end
    if not Wanted() then Detach() end
    -- Native code owns all dirty flags and the next full layout.
    securecallfunction(container.MarkDirty, container)
end

function scroll.UpdateRange()
    -- Zone folds/sorting can change the C-backed module height between native
    -- passes. Update only the viewport, without requesting another layout.
    if not active or layingOut then return end
    LayoutCanvas()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
events:SetScript("OnEvent", function() scroll.Refresh() end)
if EventRegistry then
    EventRegistry:RegisterCallback("EditMode.Enter", function() scroll.Refresh() end, scroll)
    EventRegistry:RegisterCallback("EditMode.Exit", function() scroll.Refresh() end, scroll)
end
