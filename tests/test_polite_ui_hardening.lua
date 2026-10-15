-- Continue from the base Polite UI fixture with stricter client behavior.
local vv, addon = VV_TEST_NS, VV_TEST_NS.PoliteUI
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local function advance(seconds)
    for _ = 1, math.ceil(seconds / 0.05) do Mock.Tick(0.05) end
end
local function reset()
    addon.optionsPanel:Hide()
    EditModeManagerFrame:Hide()
    addon.ResetSettings()
    Mock.combat, Mock.lockdown, Mock.units.target = false, false, false
    Mock.health.player, Mock.maximum.player = 100, 100
    Mock.power.player, Mock.powerMaximum.player, Mock.powerType.player = 100, 100, 0
    Mock.cast, Mock.channel, Mock.foci = nil, nil, {}
    PlayerFrame.mouseOver = false
    PlayerFrame:SetAlpha(0.8)
end

-- Unlike a permissive Lua mock, native health APIs validate their arguments.
function UnitHealth(...)
    assert(select("#", ...) == 1, "UnitHealth expects a unit without an explicit nil predicted-health argument")
    return Mock.health[...]
end
function UnitHealthMax(...)
    assert(select("#", ...) == 1, "UnitHealthMax expects just a unit")
    return Mock.maximum[...]
end
reset()
addon.SetCondition("player", "fadeOut", "healthFull", true)
addon.SetCondition("player", "fadeOut", "manaFull", true)
addon.SetCondition("player", "fadeOut", "outCombat", true)
addon.SetCondition("player", "fadeOut", "noTarget", true)
advance(0.7)
check(PlayerFrame:GetAlpha() == 0, "The reported four-condition player rule fades with native health signatures")

-- Registered canvases retain their local shown flag after Settings hides an
-- ancestor. Calling panel:Hide() directly misses this client lifecycle.
reset()
local settingsHost = CreateFrame("Frame", nil, UIParent)
addon.optionsPanel.parent = settingsHost
addon.optionsPanel:Show()
addon.SetCondition("player", "fadeOut", "healthFull", true)
addon.SetCondition("player", "fadeOut", "outCombat", true)
addon.SetCondition("player", "fadeOut", "noTarget", true)
advance(0.7)
check(near(PlayerFrame:GetAlpha(), 0.8), "Visible configuration page reveals the player frame")
settingsHost:Hide()
check(addon.optionsPanel:IsShown() and not addon.optionsPanel:IsVisible(), "Fixture models a hidden Settings ancestor")
advance(0.7)
check(PlayerFrame:GetAlpha() == 0, "Closing Settings resumes all selected rules without reloading")
settingsHost:Show(); advance(0.7)
check(near(PlayerFrame:GetAlpha(), 0.8), "Reopening Settings reveals the same frame")
settingsHost:Hide(); advance(0.7)
check(PlayerFrame:GetAlpha() == 0, "Repeated Settings cycles remain reliable")
addon.optionsPanel:Hide()
addon.optionsPanel.parent = UIParent

reset()
Mock.health.player = 50
addon.SetCondition("player", "fadeOut", "healthFull", true)
addon.SetCondition("player", "fadeOut", "healthRising", true)
addon.SetCondition("player", "fadeOut", "outCombat", true)
advance(0.2)
Mock.health.player = 80; advance(0.2)
check(near(PlayerFrame:GetAlpha(), 0.8), "Partial recovery does not satisfy full-health AND recovery")
Mock.health.player = 100; advance(0.7)
check(PlayerFrame:GetAlpha() == 0, "Recovery continues sampling when another selected condition is false")

reset()
Mock.combat, Mock.health.player = true, 90
addon.SetCondition("player", "fadeOut", "healthRising", true)
addon.SetCondition("player", "fadeOut", "outCombat", true)
advance(0.2)
Mock.health.player = 50; advance(0.2)
Mock.health.player = 90; advance(0.2)
Mock.combat = false
Mock.Event("PLAYER_REGEN_ENABLED")
advance(0.7)
check(PlayerFrame:GetAlpha() == 0, "Combat gates do not starve recovery history in the fade-out list")

reset()
Mock.health.player = 50
addon.SetCondition("player", "fadeOut", "healthRising", true)
addon.optionsPanel:Show()
advance(0.2)
Mock.health.player = 90; advance(0.2)
addon.optionsPanel:Hide(); advance(0.7)
check(PlayerFrame:GetAlpha() == 0, "Closing the page preserves recovery observed during configuration")

reset()
local nativeSetAlpha = PlayerFrame.SetAlpha
local block = true
PlayerFrame.SetAlpha = function(self, value)
    if block then error("Simulated temporary protected opacity update") end
    nativeSetAlpha(self, value)
end
addon.SetCondition("player", "fadeOut", "outCombat", true)
advance(0.7)
local state = addon.GetDiagnostics().player
check(state.error and state.status == "Opacity update pending" and near(PlayerFrame:GetAlpha(), 0.8),
    "A failed opacity write is visible in diagnostics")
block = false; advance(0.3)
check(PlayerFrame:GetAlpha() == 0 and not addon.GetDiagnostics().player.error,
    "Failed writes retry after the animation finishes and recover without reloading")
block = true
vv.SetModuleEnabled("politeUI", false)
check(addon.driver:IsShown(), "A failed restore keeps its retry driver alive")
block = false; advance(0.2)
check(near(PlayerFrame:GetAlpha(), 0.8) and not addon.driver:IsShown(), "Pending restoration recovers while the module is disabled")
PlayerFrame.SetAlpha = nativeSetAlpha
vv.SetModuleEnabled("politeUI", true)
reset()
addon.SetCondition("player", "fadeOut", "outCombat", true)
advance(0.7)
Mock.Object.SetAlpha(PlayerFrame, 1) -- A native update bypassing the Lua hook.
advance(0.2)
check(PlayerFrame:GetAlpha() == 0, "Native opacity changes after an animation are corrected on the next poll")

reset()
Mock.powerType.player = 1
addon.SetCondition("player", "fadeOut", "manaFull", true)
state = addon.GetDiagnostics().player
check(state.fadeOut.matches, "Mana conditions use a real mana pool even when rage is active")
addon.SetCondition("player", "fadeOut", "inCombat", true)
addon.SetCondition("player", "fadeOut", "outCombat", true)
state = addon.GetDiagnostics().player
check(state.fadeOutWarning and state.fadeOutWarning:find("Cannot match together", 1, true), "Contradictory AND choices are explained")
local before = #Mock.messages
SlashCmdList.VANILLAVARNISH("polite debug")
check(#Mock.messages > before, "Slash diagnostics expose configured conditions and blockers")
reset()

-- Use the real predicates, not the truth-table substitutions in the matrix.
local function verdict(id)
    addon.SetCondition("player", "fadeOut", nil)
    addon.SetCondition("player", "fadeOut", id, true)
    return addon.GetDiagnostics().player.fadeOut.items[1].value
end
for _, percent in ipairs({0, 34, 35, 74, 75, 99, 100}) do
    Mock.health.player, Mock.power.player = percent, percent
    check(verdict("healthFull") == (percent == 100), "Full-health boundary at " .. percent)
    check(verdict("healthLow") == (percent < 75), "Low-health boundary at " .. percent)
    check(verdict("healthCritical") == (percent <= 35), "Critical-health boundary at " .. percent)
    check(verdict("manaFull") == (percent == 100), "Full-mana boundary at " .. percent)
    check(verdict("manaLow") == (percent < 75), "Low-mana boundary at " .. percent)
end
for _, sample in ipairs({
    {"inCombat", "combat"}, {"mounted", "mounted"}, {"resting", "resting"}, {"hasTarget", "target"},
}) do
    for _, value in ipairs({false, true}) do
        if sample[2] == "target" then Mock.units.target = value else Mock[sample[2]] = value end
        check(verdict(sample[1]) == value, sample[1] .. ": real boolean predicate")
    end
    if sample[2] == "target" then Mock.units.target = false else Mock[sample[2]] = false end
end
Mock.speed = 0
check(verdict("stationary") and not verdict("moving"), "Standing-still and moving are exclusive")
Mock.speed = 7
check(verdict("moving") and not verdict("stationary"), "Movement predicates track the native speed")
Mock.speed = 0
Mock.channel = "Channel"
check(verdict("casting") and not verdict("notCasting"), "Channeling satisfies the casting state")
Mock.channel = nil
check(verdict("notCasting") and not verdict("casting"), "Both casting APIs must be idle for not-casting")
Mock.health.player, Mock.maximum.player = 100, 0
check(verdict("healthFull") == nil, "A zero maximum is unavailable rather than full")
Mock.maximum.player = 100
Mock.health.player = 0 / 0
check(verdict("healthFull") == nil, "NaN health cannot satisfy a resource rule")
Mock.health.player = math.huge
check(verdict("healthFull") == nil, "Infinite health cannot satisfy a resource rule")
reset()

addon.SetCondition("player", "fadeOut", "outCombat", true)
EditModeManagerFrame.IsEditModeActive = function() return false end
EditModeManagerFrame:Show(); advance(0.7)
check(PlayerFrame:GetAlpha() == 0, "An inactive Edit Mode manager cannot suppress fades through its local shown flag")
EditModeManagerFrame.IsEditModeActive = function() return true end
EditModeManagerFrame:Hide(); advance(0.7)
check(near(PlayerFrame:GetAlpha(), 0.8), "An active locked Edit Mode still reveals the UI")
EditModeManagerFrame.IsEditModeActive = nil
reset()

addon.SetCondition("player", "fadeOut", "outCombat", true)
advance(0.7)
Mock.combat, Mock.units.target, Mock.channel = true, true, "Channel"
Mock.Event("UNIT_SPELLCAST_CHANNEL_START", "player")
advance(0.7)
check(near(PlayerFrame:GetAlpha(), 0.8), "Entering combat returns an out-of-combat fade automatically")
reset()

local oldTooltip, lines = GameTooltip, {}
GameTooltip = {SetOwner=function() end, SetText=function() end, Show=function() end, Hide=function() end,
    AddLine=function(_, text) lines[#lines + 1] = text end}
addon.SetCondition("player", "fadeOut", "healthFull", true)
addon.optionControls["player.fadeOut"].scripts.OnEnter(addon.optionControls["player.fadeOut"])
check(table.concat(lines, "\n"):find("Match: When health is full", 1, true), "Dropdown tooltip reports actual condition status")
GameTooltip = oldTooltip
reset()

Mock.units.party1, Mock.units.party2 = true, true
Mock.health.party1, Mock.maximum.party1 = 100, 100
Mock.health.party2, Mock.maximum.party2 = 60, 100
Mock.connected.party1 = false
addon.SetCondition("party", "fadeOut", "memberInjured", true)
check(addon.GetDiagnostics().party.fadeOut.matches, "A disconnected member does not mask another member needing healing")
Mock.connected.party1, Mock.dead.party1 = true, true
check(addon.GetDiagnostics().party.fadeOut.matches, "A dead member does not mask another member needing healing")
addon.SetCondition("party", "fadeOut", nil)
addon.SetCondition("party", "fadeOut", "groupHealthFull", true)
check(not addon.GetDiagnostics().party.fadeOut.matches, "Dead and injured members do not count as all health full")
Mock.dead.party1, Mock.units.party1, Mock.units.party2 = false, false, false
reset()

addon.SetCondition("player", "fadeOut", "outCombat", true)
vv.SaveProfile("Old beta return migration")
local oldDesign = vv.profileStore["Old beta return migration"].settings.politeUI.rules
oldDesign.player.fadeIn = {hasTarget=true, inCombat=true}
oldDesign.buffs = {fadeOut={}, fadeIn={inCombat=true}}
check(vv.LoadProfile("Old beta return migration") and addon.GetRule("player").fadeOut.outCombat
    and not addon.GetRule("player").fadeIn and not addon.db.rules.buffs,
    "Loading an older beta profile keeps fade-out rules and drops retired return lists")
check(not vv.ProfileModified(), "Migrated beta profiles compare cleanly without changing the stored snapshot")
check(oldDesign.player.fadeIn.hasTarget, "Migration does not rewrite account profile snapshots")
reset()

VV_POLITE_UI_HARDENING_CHECKS = checks
