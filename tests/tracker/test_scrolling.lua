-- Continue the native grouping fixture with the real container budget contract.
local addon = VV_TEST_NS.QuestTracker
local container, native = ObjectiveTrackerFrame, QuestObjectiveTracker
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function count()
    local result, block = 0, native.firstBlock
    while block do result, block = result + 1, block.nextBlock end
    return result
end
local function find(id)
    local block = native.firstBlock
    while block do if block.id == id then return block end; block = block.nextBlock end
end
local callbacks, editing, collapsed, combat = {}, false, false, false
InCombatLockdown = function() return combat end
EventRegistry = { RegisterCallback = function(_, event, callback) callbacks[event] = callback end }
EditModeManagerFrame = { IsEditModeActive = function() return editing end }
container.Header = CreateFrame("Frame", nil, container)
container.Header:SetHeight(32)
container.Header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
function container.Header:GetTop() return container:GetTop() + select(5, self:GetPoint(1)) end
container.NineSlice = CreateFrame("Frame", nil, container)
container:SetSize(300, 150)
container.topModulePadding, container.bottomModulePadding = 38, 10
for _, module in ipairs(container.modules) do module:SetParent(container) end
local dirty, sizes = 0, 0
local function nativeSizeChanged()
    sizes = sizes + 1
    container:MarkDirty()
end
container:SetScript("OnSizeChanged", nativeSizeChanged)
local nativeSetScript = container.SetScript
function container:SetScript(event, callback)
    assert(event ~= "OnSizeChanged", "never reassign the native resize handler: this taints shared tracker updates")
    nativeSetScript(self, event, callback)
end
function container:IsCollapsed() return collapsed end
function container:ShouldShowHeader() return true end
function container:GetAvailableHeight() return self:GetHeight() - self.topModulePadding end
local nativePadding, headerOffset = 38, 0
function container:UpdateTopPadding() self.topModulePadding = nativePadding end
function container:UpdateHeaderPosition()
    self.Header:SetPoint("TOPLEFT", self, "TOPLEFT", 0, headerOffset)
end
local nativeDirtyUpdate
local function dirtyCallback()
    nativeDirtyUpdate(container, true)
    container.dirty = nil
end
function container:MarkDirty()
    dirty = dirty + 1
    if not self.dirty then C_Timer.After(0, dirtyCallback) end
    self.dirty = true
end
local fail, managedHeight, skipHeaderFinish
function container:Update()
    if not self:ShouldShowHeader() then return end
    if fail then fail = false; error("simulated interrupted native layout") end
    local available = self:GetAvailableHeight()
    self:UpdateTopPadding()
    if addon.Scrolling and addon.Scrolling.IsActive() then
        check(self:GetHeight() < 100000 and self:GetScript("OnSizeChanged") == nativeSizeChanged,
            "real geometry is restored and the native size handler stays intact before constructing native blocks")
    end
    native:Update(available)
    native:ClearAllPoints()
    native:SetPoint("TOP", native:GetParent(), "TOP", 0, -self.topModulePadding)
    native:SetPoint("LEFT", self, "LEFT", 0, 0)
    -- Match the native container: the following module anchors to this frame,
    -- while its space accounting reads native contentsHeight.
    self.modules[2]:SetPoint("TOP", native, "BOTTOM", 0, -self.moduleSpacing)
    if managedHeight then self:SetHeight(managedHeight) end
    if not skipHeaderFinish then self:UpdateHeaderPosition() end
    return "native result", 17
end
-- DirtiableMixin captures this function in a closure before addon posthooks
-- are installed. Dirty updates call that saved function, not container.Update.
nativeDirtyUpdate = container.Update
container:Update(); RunMockTimers()
check(count() < C_QuestLog.GetNumQuestWatches(), "small native tracker omits watched quests before scrolling")
local oldNativeUpdate = native.Update
local oldEnum = native.EnumQuestWatchData
local headerParent = container.Header:GetParent()
local points = {container:GetPoint()}
assert(loadfile("Modules/QuestTracker/Scrolling.lua"))("VanillaVarnish", VV_TEST_NS)
native:SetContainer(container) -- native manager may assign this after PLAYER_LOGIN
addon.Scrolling.Refresh()
local result, extra = container:Update(); RunMockTimers()
check(addon.Scrolling.IsActive(), "late native container assignment installs scrolling")
check(result == "native result" and extra == 17, "container return values are preserved")
check(count() == C_QuestLog.GetNumQuestWatches(), "native renderer builds every tracked quest despite a small viewport")
check(native.Update == oldNativeUpdate and native.EnumQuestWatchData == oldEnum, "native renderer and watch enumerator are not replaced")
check(container:GetHeight() == 150 and container:GetWidth() == 300, "visible tracker keeps its native dimensions")
check(container:GetScript("OnSizeChanged") == nativeSizeChanged, "exact native size script stays installed")
check(sizes > 0, "native size handler receives layout size notifications without reassignment")
RunMockTimers(); RunMockTimers()
local settledSizes = sizes
RunMockTimers(); RunMockTimers()
check(sizes == settledSizes and not container.dirty, "native dirty runner settles without size-update loops")
check(container.Header:GetParent() == headerParent and headerParent == container, "native tracker header stays outside the scroller")
local viewport
for _, frame in ipairs(MockFrames) do
    if frame.template == "ScrollFrameTemplate" then viewport = frame end
end
check(viewport and viewport:GetHeight() == 102, "viewport respects native header and bottom padding")
-- Resolve the scroll canvas and module against the fixed header. An
-- unanchored scroll child can retain the temporary native top inset.
local function topInContainer(frame)
    if frame == container then return 0 end
    local _, relative, relativePoint, _, y = frame:GetPoint(1)
    assert(relative and (relativePoint == "TOPLEFT" or relativePoint == "TOP" or relativePoint == "BOTTOMLEFT"),
        "top anchor resolves to a parent")
    return topInContainer(relative) + y - (relativePoint == "BOTTOMLEFT" and relative:GetHeight() or 0)
end
check(topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6,
    "Quests starts directly below All Objectives with only the native six-unit header gap")
nativePadding = 96
addon.SetOption("compact", true); container:Update(); RunMockTimers()
check(topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6
    and container.topModulePadding == 96 and viewport:GetHeight() == 102,
    "compact view ignores extra reserved padding without changing native padding bookkeeping")
headerOffset = -12
container:Update(); RunMockTimers()
check(topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6
    and viewport:GetHeight() == 90, "viewport follows header moves made at the end of native layout")
headerOffset, nativePadding = 0, 38
addon.SetOption("compact", false); container:Update(); RunMockTimers()
skipHeaderFinish = true
nativeDirtyUpdate(container)
RunMockTimers()
check(topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6
    and container:GetScript("OnSizeChanged") == nativeSizeChanged,
    "next-frame recovery finishes saved updates even when the final native header call is skipped")
skipHeaderFinish = false
check(topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6,
    "normal view keeps the same small header gap after compact is disabled")
for _, compact in ipairs({false, true}) do
    addon.SetOption("compact", compact); RunMockTimers()
    nativeDirtyUpdate(container)
    check(topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6,
        "saved native dirty-update closure finishes layout before drawing, compact=" .. tostring(compact))
    RunMockTimers()
    check(topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6,
        "saved native dirty-update closure retains the small header gap on the next frame")
end
addon.SetOption("compact", false); container:Update(); RunMockTimers()
check(viewport:GetVerticalScrollRange() > 0 and viewport.ScrollBar:IsShown(), "overflow has a native scrollbar")
check(native:GetParent() == viewport.child, "existing native module is inside the scroll canvas")
check(select(2, container.NineSlice:GetPoint(1)) == viewport, "overflow background ends at the visible tracker edge")
check(find(1) and find(5) and find(6), "quests from both zones are accessible")
local item, click = find(1).ItemButton, find(1).ItemButton:GetScript("OnClick")
local headerClick = find(1).HeaderButton:GetScript("OnClick")
local contentsHeight = native.contentsHeight
viewport.scripts.OnMouseWheel(viewport, -10000)
check(viewport:GetVerticalScroll() == viewport:GetVerticalScrollRange(), "mouse wheel can reach the final tracked quest")
check(item:GetScript("OnClick") == click and find(1).HeaderButton:GetScript("OnClick") == headerClick,
    "scrolling preserves native quest and item click handlers")
check(native.contentsHeight == contentsHeight, "scrolling does not rewrite native contents bookkeeping")
container:Update(); RunMockTimers()
check(viewport:GetVerticalScroll() == viewport:GetVerticalScrollRange(), "progress rebuild retains scroll position")
RunMockTimers(); RunMockTimers()
settledSizes = sizes
RunMockTimers(); RunMockTimers()
check(sizes == settledSizes and not container.dirty, "successive native layouts remain free of size-update loops")
viewport.scripts.OnMouseWheel(viewport, 10000)
check(viewport:GetVerticalScroll() == 0, "wheel clamps at the top")
addon.SetAllZonesCollapsed(true); RunMockTimers()
check(count() == C_QuestLog.GetNumQuestWatches(), "folding zones keeps every native quest in the watch list")
check(not find(1):IsShown() and not item:IsShown(), "folding hides a quest and its native item together")
addon.SetAllZonesCollapsed(false); RunMockTimers()
check(find(1):IsShown() and item:IsShown(), "expanding restores quest and item without untracking")
check(find(6):IsShown(), "deferred grouping does not truncate quests to the viewport height")
combat = true
container:Update(); RunMockTimers()
check(count() == C_QuestLog.GetNumQuestWatches(), "unprotected native quest rows remain accessible through combat updates")
viewport.scripts.OnMouseWheel(viewport, -10000)
check(viewport:GetVerticalScroll() == viewport:GetVerticalScrollRange(), "unprotected tracker scrolls during combat")
item.protected = true
local protectedScroll, protectedHeight = viewport:GetVerticalScroll(), container:GetHeight()
viewport.scripts.OnMouseWheel(viewport, 1)
addon.SetOption("scrolling", false); RunMockTimers()
check(viewport:GetVerticalScroll() == protectedScroll and container:GetHeight() == protectedHeight
    and addon.Scrolling.IsActive(), "protected combat layout defers scrolling and reparenting")
combat, item.protected = false, nil
addon.Scrolling.Refresh()
check(not addon.Scrolling.IsActive(), "deferred scrolling preference applies after combat")
addon.SetOption("scrolling", true); RunMockTimers(); container:Update(); RunMockTimers()
addon.SetOption("enabled", false); RunMockTimers()
container:Update(); RunMockTimers()
check(count() == C_QuestLog.GetNumQuestWatches(), "all quests also remain accessible with zone grouping off")
addon.SetOption("enabled", true); RunMockTimers()

-- A real resize or managed-position height update must survive the layout.
local sizesBeforeResize = sizes
container:SetHeight(600)
check(sizes == sizesBeforeResize + 1, "real resize still reaches the untouched native size handler")
container:Update(); RunMockTimers()
check(viewport:GetVerticalScrollRange() == 0 and not viewport.ScrollBar:IsShown(), "scrollbar disappears when all objectives fit")
nativePadding = 96
addon.SetOption("compact", true)
container:Update(); RunMockTimers(); container:Update(); RunMockTimers()
check(viewport:GetVerticalScrollRange() == 0 and not viewport.ScrollBar:IsShown()
    and topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6,
    "compact list without overflow keeps quests immediately below the header across native updates")
for _, compact in ipairs({false, true}) do
    addon.SetOption("compact", compact); RunMockTimers()
    nativeDirtyUpdate(container); nativeDirtyUpdate(container)
    check(viewport:GetVerticalScrollRange() == 0
        and topInContainer(container.Header) - container.Header:GetHeight() - topInContainer(native) == 6,
        "saved dirty updates keep the header gap small without overflow, compact=" .. tostring(compact))
    RunMockTimers()
end
nativePadding = 38
addon.SetOption("compact", false); container:Update(); RunMockTimers()
managedHeight = 200
container:Update(); RunMockTimers()
check(container:GetHeight() == 200 and viewport:GetHeight() == 152, "managed height changes during layout are retained")
managedHeight = nil

-- Edit Mode receives the original module parenting and the real frame size.
editing = true; callbacks["EditMode.Enter"]()
check(not addon.Scrolling.IsActive() and not viewport:IsShown(), "Edit Mode suspends scrolling")
check(native:GetParent() == container and container:GetHeight() == 200, "Edit Mode keeps native parent and physical height")
container:SetHeight(170); container:Update(); RunMockTimers()
editing = false; callbacks["EditMode.Exit"]()
container:Update(); RunMockTimers()
check(addon.Scrolling.IsActive() and count() == C_QuestLog.GetNumQuestWatches(), "scrolling and every watched quest return after Edit Mode")
check(container:GetHeight() == 170, "Edit Mode's new height survives")

-- Edit Mode can broadcast a native update while auras are restricted outside
-- combat. Its scenario tracker must run without an addon-driven resize.
local function FireTrackerEvent(event)
    for _, frame in ipairs(MockFrames) do
        if frame.events and frame.events[event] then frame.callback(frame, event) end
    end
end
local beforeLayoutEventDirty = dirty
FireTrackerEvent("EDIT_MODE_LAYOUTS_UPDATED")
check(dirty == beforeLayoutEventDirty, "layout notifications leave the native Edit Mode tracker update in charge")
container:Update(); RunMockTimers()
check(addon.Scrolling.IsActive() and count() == C_QuestLog.GetNumQuestWatches(),
    "the native Edit Mode update retains scrolling and every watched quest")

local restricted = true
C_Secrets = {ShouldAurasBeSecret = function() return restricted end}
local beforeRestrictionSizes, beforeRestrictionDirty = sizes, dirty
container:Update(); RunMockTimers()
addon.Scrolling.Refresh()
check(sizes == beforeRestrictionSizes and dirty == beforeRestrictionDirty,
    "Restricted native layout and addon refresh leave shared height and dirty state alone")
check(native:GetParent() == container and not addon.Scrolling.IsActive(),
    "Restricted layout uses native parenting and height")
FireTrackerEvent("ADDON_RESTRICTION_STATE_CHANGED")
restricted = false
RunMockTimers(); RunMockTimers(); RunMockTimers()
check(addon.Scrolling.IsActive() and count() == C_QuestLog.GetNumQuestWatches(),
    "Scrolling resumes when restrictions lift outside combat")
C_Secrets = nil

collapsed = true; container:Update(); RunMockTimers()
check(not viewport:IsShown() and not addon.Scrolling.IsActive(), "native tracker collapse hides the scroller")
collapsed = false; container:Update(); RunMockTimers()
check(viewport:IsShown() and count() == C_QuestLog.GetNumQuestWatches(), "native tracker expansion restores all tracked quests")

local originalCount, originalID = C_QuestLog.GetNumQuestWatches, C_QuestLog.GetQuestIDForQuestWatchIndex
C_QuestLog.GetNumQuestWatches = function() return 120 end
C_QuestLog.GetQuestIDForQuestWatchIndex = function(index) return index end
container:Update(); RunMockTimers()
check(count() == 120 and find(120):IsShown(), "large watch lists include the final quest, even in a zone absent from the native viewport")
viewport.scripts.OnMouseWheel(viewport, -100000)
check(viewport:GetVerticalScroll() == viewport:GetVerticalScrollRange() and viewport:GetVerticalScroll() > 1000,
    "large watch lists scroll through the full native content height")
C_QuestLog.GetNumQuestWatches, C_QuestLog.GetQuestIDForQuestWatchIndex = originalCount, originalID
container:Update(); RunMockTimers()
check(viewport:GetVerticalScroll() <= viewport:GetVerticalScrollRange(), "untracking quests clamps an old bottom position to the remaining list")

-- Abort recovery restores native geometry and scripts even without a posthook.
fail = true
local ok = pcall(container.Update, container)
check(not ok, "fixture exercises an interrupted native update")
RunMockTimers()
check(container:GetHeight() == 170 and container:GetScript("OnSizeChanged") == nativeSizeChanged,
    "aborted layout restores real height and native size handler")
fail = false; container:Update(); RunMockTimers()

addon.SetOption("scrolling", false); RunMockTimers()
container:Update(); RunMockTimers()
check(not addon.Scrolling.IsActive() and native:GetParent() == container, "turning scrolling off restores native module parenting")
check(count() < C_QuestLog.GetNumQuestWatches(), "turning scrolling off restores the game's native height limit")
addon.SetOption("scrolling", true); RunMockTimers()
container:Update(); RunMockTimers()
check(count() == C_QuestLog.GetNumQuestWatches(), "turning scrolling back on restores every watched quest")
VV_TEST_NS.SetModuleEnabled("questTracker", false); RunMockTimers()
container:Update(); RunMockTimers()
check(not addon.Scrolling.IsActive() and not viewport:IsShown(), "module off restores the original tracker")
check(container:GetScript("OnSizeChanged") == nativeSizeChanged, "module off retains the original native size handler")
VV_TEST_NS.SetModuleEnabled("questTracker", true); RunMockTimers()
container:Update(); RunMockTimers()
check(count() == C_QuestLog.GetNumQuestWatches(), "module re-enable restores scrolling with saved preferences")
print("PASS: " .. checks .. " native tracker scrolling, overflow, item ownership, resize, Edit Mode, and recovery checks")
