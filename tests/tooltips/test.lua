local vv, tip = VV_TEST_NS, GameTooltip
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local addon = vv.Tooltips
local owner = Mock.New(UIParent)
assert(addon.db.followMouse and addon.db.unitColors and not addon.db.pauseInCombat and addon.db.instantHide == nil)

-- Explicit anchors for bag items, spells, auras, controls and world units all
-- yield to the cursor. Never pass their owner back through addon SetOwner.
owner.forbidden = true
for _, tooltip in ipairs({tip, BuffFrameTooltip, GameSmallHeaderTooltip, GameNoHeaderTooltip}) do
    for _, kind in ipairs({"Bag item", "Spell", "Player", "Mob", "Aura", "Control"}) do
        local before = tooltip.ownerCalls or 0
        Mock.Hover(tooltip, owner, "ANCHOR_RIGHT", kind)
        assert(tooltip.anchor == "ANCHOR_CURSOR_RIGHT" and tooltip.ownerCalls == before + 1)
        assert(tooltip.offsetX == 34 and tooltip.offsetY == -6 and tooltip:GetOwner() == owner)
    end
end
GameTooltip_SetDefaultAnchor(tip, owner)
Mock.Flush()
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT")
addon.SetOption("offsetX", -25); addon.SetOption("offsetY", 40)
assert(tip.offsetX == -25 and tip.offsetY == 40)
local calls = tip.anchorCalls
Mock.Tick(1); Mock.Tick(1)
assert(tip.anchorCalls == calls, "Do not interfere with native fades by moving the tooltip every frame")
tip:SetAnchorType("ANCHOR_LEFT")
Mock.Flush()
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT")
Mock.Hover(ShoppingTooltip1, owner, "ANCHOR_LEFT")
Mock.Hover(ItemRefTooltip, owner, "ANCHOR_LEFT")
assert(ShoppingTooltip1.anchor == "ANCHOR_LEFT" and ItemRefTooltip.anchor == "ANCHOR_LEFT")

-- Pause takes effect on the current tooltip and all new hover targets, using
-- the native container corner even for center/edge Edit Mode placements.
Mock.lockdown = true
Mock.Event("PLAYER_REGEN_DISABLED")
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT", "Combat pause defaults off")
addon.SetOption("pauseInCombat", true)
assert(tip.anchor == "ANCHOR_NONE" and tip:GetPoint(1) == "BOTTOMRIGHT")
assert(select(2, tip:GetPoint(1)) == GameTooltipDefaultContainer)
for _, spec in ipairs({{"CENTER", 20, 40, "TOPRIGHT"}, {"TOP", -20, 10, "TOPLEFT"},
    {"LEFT", 0, -20, "BOTTOMLEFT"}, {"BOTTOMLEFT", 0, 0, "BOTTOMLEFT"}}) do
    GameTooltipDefaultContainer:ClearAllPoints()
    GameTooltipDefaultContainer:SetPoint(spec[1], UIParent, spec[1], spec[2], spec[3])
    Mock.Hover(tip, owner, "ANCHOR_RIGHT")
    assert(tip.anchor == "ANCHOR_NONE" and tip:GetPoint(1) == spec[4])
end
Mock.lockdown = false
Mock.Event("PLAYER_REGEN_ENABLED")
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT" and tip.offsetX == -25)
addon.SetOption("pauseInCombat", false)

-- Always hide on native FadeOut; only disabling the module restores fading.
for _, tooltip in ipairs({tip, BuffFrameTooltip, GameSmallHeaderTooltip, GameNoHeaderTooltip}) do
    tooltip:FadeOut(); assert(not tooltip:IsShown())
end
tip:Show(); vv.SetModuleEnabled("tooltips", false)
Mock.Hover(tip, owner, "ANCHOR_TOP")
tip:FadeOut(); assert(tip:IsShown() and tip.anchor == "ANCHOR_TOP")
vv.SetModuleEnabled("tooltips", true)
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT")
addon.SetOption("followMouse", false)
assert(tip.anchor == "ANCHOR_NONE")
Mock.Hover(tip, owner, "ANCHOR_LEFT")
assert(tip.anchor == "ANCHOR_LEFT")
tip:FadeOut(); assert(not tip:IsShown(), "Immediate hiding also applies with mouse following off")
Mock.Hover(tip, owner, "ANCHOR_LEFT")
addon.SetOption("followMouse", true)

-- Native bag refresh must complete both anchor calls without VV switching
-- families between them, even while the previous tooltip is already shown.
local bag = Mock.New(UIParent)
local setPoint = tip.SetPoint
tip.SetPoint = function(self, ...)
    if Mock.bagSetup then
        assert(self.anchor == "ANCHOR_LEFT" or self.anchor == "ANCHOR_RIGHT",
            "VV must not switch to cursor/Edit Mode anchors inside native bag setup")
    end
    return setPoint(self, ...)
end
for _, pause in ipairs({false, true}) do
    Mock.lockdown = pause
    addon.SetOption("pauseInCombat", pause)
    for _, right in ipairs({200, 1820.778320}) do
        bag.right = right
        tip:SetOwner(bag, "ANCHOR_NONE")
        Mock.bagSetup = true
        ContainerFrameItemButton_CalculateItemTooltipAnchors(bag, tip)
        Mock.bagSetup = false
        assert(tip.anchor == (right < 960 and "ANCHOR_RIGHT" or "ANCHOR_LEFT"))
        assert(select(2, tip:GetPoint(#tip.points)) == bag)
        Mock.Flush()
        assert(tip.anchor == (pause and "ANCHOR_NONE" or "ANCHOR_CURSOR_RIGHT"))
        if not pause then assert(#tip.points == 0, "Clear explicit bag anchors before native cursor tracking") end
    end
end
tip.SetPoint = setPoint
Mock.lockdown = false
addon.SetOption("pauseInCombat", false)

-- World departure and UI owner departure need no Lua FadeOut call at all.
Mock.WorldHover(tip, "mouseover")
Mock.units.mouseover = true
Mock.Tick(0); assert(tip:IsShown())
Mock.worldCursorData = nil
Mock.Tick(0); assert(not tip:IsShown() and not tip.fading)
Mock.WorldHover(tip, "mouseover")
Mock.units.mouseover = false
Mock.Event("UPDATE_MOUSEOVER_UNIT")
assert(not tip:IsShown())
for _, tooltip in ipairs({tip, BuffFrameTooltip, GameSmallHeaderTooltip, GameNoHeaderTooltip}) do
    bag.hovered = true
    Mock.Hover(tooltip, bag, "ANCHOR_RIGHT")
    Mock.Tick(0); assert(tooltip:IsShown())
    bag.hovered = false
    Mock.Tick(0); assert(not tooltip:IsShown() and not tooltip.fading)
end
bag.hovered = true
Mock.Hover(tip, bag, "ANCHOR_RIGHT")
Mock.editing, bag.hovered = true, false
Mock.Tick(0); assert(tip:IsShown(), "Preserve Blizzard's Edit Mode tooltip preview")
Mock.editing = false
Mock.Tick(0); assert(not tip:IsShown())
bag.hovered = true
-- An engine-only alpha fade is stopped, while stable custom opacity is kept.
Mock.Hover(tip, bag, "ANCHOR_RIGHT")
tip:Hide(); tip:SetAlpha(0.6); tip:Show(); Mock.Flush()
Mock.Tick(0); assert(tip:IsShown())
tip:SetAlpha(0.5); Mock.Tick(0); assert(not tip:IsShown())
Mock.Hover(tip, owner, "ANCHOR_RIGHT")

-- Names cover Forever surnames while guild/quest text remains intact. Colors
-- apply only to completed unit text, so item/spell contents stay untouched.
tip.unit = "mouseover"
Mock.Lines(tip, {"Ada Lovelace", "<Mage Society>", "Level 33 Human Mage", "Help the Mage: 0/1"})
Mock.colorCallback(tip)
local class = "|cff40c7eb"
assert(Mock.Text(1) == class .. "Ada Lovelace|r")
assert(Mock.Text(2) == "<Mage Society>" and Mock.Text(4) == "Help the Mage: 0/1")
assert(Mock.Text(3) == "|cffff8040Level 33|r Human " .. class .. "Mage|r")
local colored = Mock.Text(3)
Mock.colorCallback(tip); assert(Mock.Text(3) == colored, "Repeated refresh must not nest color codes")
addon.SetOption("unitColors", false)
assert(Mock.Text(1) == "Ada Lovelace" and Mock.Text(3) == "Level 33 Human Mage")
addon.SetOption("unitColors", true)
assert(Mock.Text(1) == class .. "Ada Lovelace|r")
Mock.unitInfo.mouseover.name = "Ada Lovelace"
Mock.Lines(tip, {"Ada Lovelace", "Level 33 Mage"})
Mock.colorCallback(tip); assert(Mock.Text(1) == class .. "Ada Lovelace|r")

local data = Mock.unitInfo.mouseover
data.player, data.hostile = false, true
for _, spec in ipairs({{35, "ff1a1a"}, {33, "ff8040"}, {32, "ffff00"}, {28, "ffff00"}, {27, "40bf40"}, {22, "808080"}}) do
    data.level = spec[1]
    Mock.Lines(tip, {"Wolf", "Level " .. spec[1] .. " Beast"})
    Mock.colorCallback(tip)
    assert(Mock.Text(1) == "Wolf")
    assert(Mock.Text(2) == "|cff" .. spec[2] .. "Level " .. spec[1] .. "|r Beast")
end
data.hostile = false
Mock.Lines(tip, {"Friendly", "Level 22 Beast"})
Mock.colorCallback(tip); assert(Mock.Text(2) == "Level 22 Beast")
data.player, data.hostile, data.name, data.level = true, true, "Ada", 33
UNIT_LEVEL_TEMPLATE = "Niveau %d"
Mock.Lines(tip, {"Ada", "Niveau 33 Mage"})
Mock.colorCallback(tip); assert(Mock.Text(2):find("|cffff8040Niveau 33|r", 1, true))
UNIT_LEVEL_TEMPLATE = "Level %d"
Mock.Lines(tip, {"Ada", "Human Mage"})
Mock.colorCallback(tip); assert(Mock.Text(2) == "Human " .. class .. "Mage|r")
tip.unit = nil
Mock.Lines(tip, {"Ada", "Level 33 Mage"})
Mock.colorCallback(tip, {guid=UnitGUID("mouseover")})
assert(Mock.Text(1) == class .. "Ada|r", "Matching GUID permits transient world mouseover coloring")
Mock.Lines(tip, {"Ada", "Level 33 Mage"})
Mock.colorCallback(tip, {guid="different-unit"})
assert(Mock.Text(1) == "Ada", "Do not color a different tooltip from the current mouseover")
tip.unit = "mouseover"

-- Secret and unavailable API values are cosmetic no-ops; one refused getter
-- must not prevent subsequent hover tooltips from working.
local secret = {secret=true}
data.level, data.class, data.name = secret, secret, secret
Mock.Lines(tip, {"Restricted", "Level 33 Mage"})
Mock.colorCallback(tip)
assert(Mock.Text(1) == "Restricted" and Mock.Text(2) == "Level 33 Mage")
Mock.displayedUnit, tip.unit = secret, secret
Mock.colorCallback(tip)
Mock.displayedUnit, tip.unit = nil, "mouseover"
data.level, data.class, data.name = 33, "MAGE", "Ada"
local savedGetText = GameTooltipTextLeft1.GetText
GameTooltipTextLeft1.GetText = function() error("restricted text") end
Mock.colorCallback(tip)
GameTooltipTextLeft1.GetText = savedGetText
GameTooltipTextLeft1.GetText = function() return secret end
Mock.colorCallback(tip)
GameTooltipTextLeft1.GetText = savedGetText
local savedNumLines = tip.NumLines
tip.NumLines = function() return secret end
Mock.colorCallback(tip)
tip.NumLines = savedNumLines
tip.forbidden = true
tip:SetAnchorType("ANCHOR_LEFT"); tip:FadeOut()
assert(tip.anchor == "ANCHOR_LEFT" and tip:IsShown())
Mock.colorCallback(tip)
tip.forbidden = false
Mock.Hover(tip, owner, "ANCHOR_RIGHT")
assert(tip.anchor == "ANCHOR_CURSOR_RIGHT")
assert(not addon.SetOption("offsetX", 501) and not addon.SetOption("offsetY", 0/0))
assert(not addon.SetOption("instantHide", true) and not addon.SetOption("unknown", true))
vv.InitDB(); addon.InitDB()
assert(addon.db.offsetX == -25 and addon.db.offsetY == 40 and addon.db.instantHide == nil)
for _, value in ipairs({false, true}) do
    addon.db.instantHide = value
    addon.InitDB()
    assert(addon.db.instantHide == nil)
    Mock.Hover(tip, owner, "ANCHOR_RIGHT")
    tip:FadeOut(); assert(not tip:IsShown())
end

-- Restricted live-world queries do not dismiss readable hover information.
Mock.WorldHover(tip)
local getWorldCursor = C_TooltipInfo.GetWorldCursor
C_TooltipInfo.GetWorldCursor = function() return secret end
Mock.Tick(0); assert(tip:IsShown())
C_TooltipInfo.GetWorldCursor = function() error("restricted hover") end
Mock.Tick(0); assert(tip:IsShown())
C_TooltipInfo.GetWorldCursor = getWorldCursor

-- Exercise the native Forever world-hover departure path when sources exist.
if GameTooltipDataMixin then
    local getPrimary = tip.GetPrimaryTooltipInfo
    tip.GetPrimaryTooltipInfo = function() return {getterName="GetWorldCursor", fadeOut=true} end
    tip.ClearHandlerInfo = function(self) self.cleared = true end
    C_TooltipInfo.GetWorldCursor = function() return nil end
    tip:SetWorldCursor(Enum.WorldCursorAnchorType.Default, owner)
    assert(tip.cleared and not tip:IsShown())
    vv.SetModuleEnabled("tooltips", false); tip:Show()
    tip:SetWorldCursor(Enum.WorldCursorAnchorType.Default, owner)
    assert(tip:IsShown() and tip.fading)
    tip.GetPrimaryTooltipInfo = getPrimary
    vv.SetModuleEnabled("tooltips", true)
end

-- A loaded standalone addon blocks VV's tooltip effects without importing its
-- settings. Controls and VV preferences stay available for the next reload.
C_AddOns = {IsAddOnLoaded=function(name) return name == "ForeverMouseTooltip" end}
ForeverMouseTooltipDB = {offsetX=222, enabled=false}
vv.InitDB(); addon.InitDB()
assert(vv.conflicts.tooltips == "ForeverMouseTooltip" and not vv.IsModuleEnabled("tooltips"))
Mock.Hover(tip, owner, "ANCHOR_TOP")
Mock.colorCallback(tip)
assert(tip.anchor == "ANCHOR_TOP" and addon.db.offsetX == -25 and ForeverMouseTooltipDB.offsetX == 222)
