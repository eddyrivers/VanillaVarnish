local vv, addon = VV_TEST_NS, VV_TEST_NS.PoliteUI
local checks = 0
local function check(value, message) checks = checks + 1; assert(value, message) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local function frame(name, parent, alpha)
    local result = CreateFrame("Frame", nil, parent or UIParent)
    _G[name] = result
    result:SetAlpha(alpha or 1)
    return result
end
local player = frame("PlayerFrame", nil, 0.8)
local buffs = frame("BuffFrame")
local chat = frame("ChatFrame1", nil, 0.9)
local chatTab = frame("ChatFrame1Tab", chat)
local box = frame("ChatFrame1EditBox", chat)
local character, questLog = frame("CharacterFrame"), frame("QuestLogFrame")
local bank, auction = frame("BankFrame"), frame("AuctionHouseFrame")
local target = frame("TargetFrame")
Mock.units.player = true
Mock.health, Mock.maximum, Mock.power, Mock.powerMaximum = {}, {}, {}, {}
Mock.health.player, Mock.maximum.player = 100, 100
Mock.power.player, Mock.powerMaximum.player = 100, 100
Mock.powerType, Mock.dead, Mock.connected = {}, {}, {}
function UnitHealth(unit) return Mock.health[unit] end
function UnitHealthMax(unit) return Mock.maximum[unit] end
function UnitPower(unit) return Mock.power[unit] end
function UnitPowerMax(unit) return Mock.powerMaximum[unit] end
function UnitPowerType(unit) return Mock.powerType[unit] or 0 end
function UnitIsDeadOrGhost(unit) return Mock.dead[unit] or false end
function UnitIsConnected(unit) return Mock.connected[unit] ~= false end
function GetUnitSpeed() return Mock.speed or 0 end
function IsMounted() return Mock.mounted == true end
function IsResting() return Mock.resting == true end
function IsIndoors() return Mock.indoors == true end
function IsOutdoors() return not Mock.indoors end
function UnitCastingInfo() return Mock.cast end
function UnitChannelInfo() return Mock.channel end
function GetMouseFoci() return Mock.foci or {} end
Mock.auras = {HELPFUL={}, HARMFUL={}}
C_UnitAuras = {GetAuraDataByIndex=function(_, index, filter) return Mock.auras[filter][index] end}
C_QuestLog.GetNumQuestWatches = function() return Mock.watches or 0 end
C_QuestLog.GetQuestIDForQuestWatchIndex = function(i) return i end
C_QuestLog.IsComplete = function() return Mock.watchedComplete == true end
local click = function() end
player:SetScript("OnClick", click)
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
check(vv.db.modules.politeUI and not next(addon.db.rules), "All rules start at Never")
check(not addon.driver:IsShown() and near(player:GetAlpha(), 0.8), "No rules means no polling or frame changes")
check(player.scripts.OnClick == click, "Native mouse handlers survive initialization")
check(not addon.presetControl:IsEnabled() and addon.presetControl.defaultText == "Coming soon", "Presets are an honest placeholder")
check(addon.optionControls["player.fadeOut"].selectionText == "Never", "Empty multiselect displays Never")
local function select(key, side, name)
    local control = addon.optionControls[key .. "." .. side]
    for _, item in ipairs(Mock.Menu(control)) do
        if item.name == name then
            Mock.inPoliteResponse = true
            local ok, message = pcall(item.callback)
            Mock.inPoliteResponse = false
            assert(ok, message)
            -- Native OnMenuResponse updates selections on the existing menu.
            control.selectionText = control.selectionTextFunction()
            return
        end
    end
    error("Missing condition " .. name)
end
for _, control in pairs(addon.optionControls) do
    local generate = control.GenerateMenu
    control.GenerateMenu = function(self)
        check(not Mock.inPoliteResponse, "A checkbox response must not rebuild any open Polite UI menu")
        return generate(self)
    end
end
Mock.combat = true
select("player", "fadeOut", "When not in combat")
select("player", "fadeOut", "When health is full")
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.8), "AND requires combat and resource conditions together")
check(addon.optionControls["player.fadeOut"].selectionText == "2 conditions (AND)", "Multiselect summarizes its AND selections")
Mock.combat = false
Mock.health.player = 70
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.8), "One matching condition does not start a fade")
Mock.health.player = 100
Mock.Tick(0.25)
check(near(player:GetAlpha(), 0.4), "Fade reaches half of native opacity after 250 ms")
Mock.Tick(0.25)
check(player:GetAlpha() == 0 and player:IsShown(), "Complete transparency never hides the native unit button")
player.mouseOver = true
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.8), "Hover always reveals to native opacity")
player.mouseOver = false
Mock.Tick(0.5)
check(player:GetAlpha() == 0, "Leaving hover resumes matching fade-out conditions")
player:SetAlpha(0.6)
check(player:GetAlpha() == 0, "Native opacity changes preserve a hidden fade")
addon.SetCondition("player", "fadeOut", "noTarget", true)
Mock.units.target = true
Mock.Event("PLAYER_TARGET_CHANGED")
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.6), "A target breaks the fade-out AND list and restores the latest native alpha")
Mock.units.target = false
Mock.Event("PLAYER_TARGET_CHANGED")
Mock.Tick(0.5)
check(player:GetAlpha() == 0, "Clearing the target allows fade-out again")
Mock.combat = true
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.6), "Losing any fade-out criterion automatically reveals the frame")
check(not addon.optionControls["player.fadeIn"] and not addon.driver.scripts.OnKeyDown,
    "Separate fade-in controls and the Escape keyboard listener are removed")
Mock.lockdown = true
vv.SetModuleEnabled("politeUI", false)
check(near(player:GetAlpha(), 0.6) and not addon.driver:IsShown(), "Disabling restores immediately, including during combat")
check(addon.GetRule("player").fadeOut.healthFull, "Disabling preserves preferences")
player:SetAlpha(0.7)
vv.SetModuleEnabled("politeUI", true)
Mock.combat, Mock.lockdown = false, false
Mock.Tick(0.5)
check(player:GetAlpha() == 0, "Re-enabling uses the retained conditions")
vv.OpenOptions("politeUI")
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.7), "Polite UI page reveals the interface for configuration")
addon.optionsPanel:Hide()
Mock.Tick(0.5)
check(player:GetAlpha() == 0, "Closing settings resumes fading")
EditModeManagerFrame = frame("EditModeManagerFrame")
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.7), "Edit Mode reveals affected frames")
EditModeManagerFrame:Hide()
Mock.Tick(0.5)
check(player:GetAlpha() == 0, "Leaving Edit Mode resumes fading")
addon.SetCondition("player", "fadeOut", nil)
check(near(player:GetAlpha(), 0.7), "Clearing fade-out restores native alpha immediately")
check(not next(addon.db.rules), "Empty selections are removed from saved settings")
check(not addon.SetCondition("player", "fadeOut", "escape", true)
    and not addon.SetCondition("player", "fadeOut", "noQuests", true), "Reject event and unrelated field conditions")

-- Resource conditions, restrictions, and trend history.
addon.SetCondition("player", "fadeOut", "healthRising", true)
Mock.health.player = 74; Mock.Tick(0.1)
Mock.health.player = 76; Mock.Tick(0.5)
check(player:GetAlpha() == 0, "Near-full requires at least 75% and recent recovery")
addon.SetCondition("player", "fadeOut", nil)
Mock.health.player = {secret=true}
addon.SetCondition("player", "fadeOut", "healthFull", true)
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.7), "Restricted health never matches full health")
addon.SetCondition("player", "fadeOut", nil)
Mock.health.player = 100
Mock.cast = {secret=true}
addon.SetCondition("player", "fadeOut", "notCasting", true)
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.7), "Restricted casting data does not mean not casting")
addon.SetCondition("player", "fadeOut", nil)
Mock.cast = nil
Mock.powerType.player = 1
Mock.powerMaximum.player = 0
addon.SetCondition("player", "fadeOut", "manaFull", true)
Mock.Tick(0.5)
check(near(player:GetAlpha(), 0.7), "Non-mana classes do not match full mana")
addon.ResetSettings()
Mock.powerType.player = 0
Mock.powerMaximum.player = 100

-- Auras, focus beyond container bounds, native cast fading, and late frames.
addon.SetCondition("buffs", "fadeOut", "noDebuffs", true) -- not a buffs condition
check(not next(addon.db.rules), "Buff selectors offer only their own aura conditions")
Mock.auras.HELPFUL = {{name="Fortitude", expirationTime=GetTime()+20}}
addon.SetCondition("buffs", "fadeOut", "buffExpiring", true)
Mock.Tick(0.5)
check(buffs:GetAlpha() == 0, "Buff expiry condition sees a timed native aura")
Mock.foci = {frame("PoliteUITestAuraButton", buffs)}
Mock.Tick(0.5)
check(buffs:GetAlpha() == 1, "Hovering a descendant outside container bounds reveals buffs")
Mock.foci = {}
addon.ResetSettings()
local cast = frame("PlayerCastingBarFrame", nil, 0.5)
cast:Hide()
addon.SetCondition("castBar", "fadeOut", "outCombat", true)
Mock.Tick(0.5)
check(cast:GetAlpha() == 0 and not cast:IsShown(), "Native hidden cast bars are never forcibly shown")
cast:Show(); cast:SetAlpha(0.3)
vv.SetModuleEnabled("politeUI", false)
check(near(cast:GetAlpha(), 0.3), "Disabling restores the cast bar's latest native opacity")
vv.SetModuleEnabled("politeUI", true)
addon.ResetSettings()
addon.SetCondition("bottomLeft", "fadeOut", "outCombat", true)
local lateBar = frame("MultiBarBottomLeft")
Mock.Tick(1)
check(lateBar:GetAlpha() == 0, "Periodic discovery finds UI created after configuration")
addon.ResetSettings()
lateBar.forbidden = true
addon.SetCondition("bottomLeft", "fadeOut", "outCombat", true)
Mock.Tick(0.5)
check(lateBar:GetAlpha() == 1, "Forbidden frames are skipped")
lateBar.forbidden = false
addon.ResetSettings()

-- Group, chat, and quest-specific predicates.
local party = frame("PartyFrame")
Mock.units.party1, Mock.health.party1, Mock.maximum.party1 = true, 100, 100
addon.SetCondition("party", "fadeOut", "groupHealthFull", true)
Mock.Tick(0.5)
check(party:GetAlpha() == 0, "Group full-health checks use members, not player health")
Mock.health.party1 = 60; Mock.Tick(0.5)
check(party:GetAlpha() == 1, "Injured group member brings party frames back")
Mock.units.party1 = false
addon.RefreshModule(); Mock.Tick(0.5)
check(party:GetAlpha() == 1, "An empty party does not count as all resources full")
addon.ResetSettings()
addon.SetCondition("chat", "fadeOut", "chatIdle", true)
Mock.Event("CHAT_MSG_GUILD")
Mock.Tick(29.75)
check(near(chat:GetAlpha(), 0.9), "Recent chat prevents quiet-chat fading")
Mock.Tick(0.25)
check(near(chat:GetAlpha(), 0.45) and chatTab:GetAlpha() == 1, "Nested chat chrome inherits only one fade factor")
Mock.Tick(0.25)
check(chat:GetAlpha() == 0, "Quiet chat fades after 30 seconds")
box:SetFocus(); Mock.Tick(0.5)
check(near(chat:GetAlpha(), 0.9), "Typing reveals chat even without an automatic return rule")
box:ClearFocus(); Mock.Tick(0.5)
Mock.Event("CHAT_MSG_WHISPER"); Mock.Tick(0.5)
check(near(chat:GetAlpha(), 0.9), "A recent whisper can be a chat return condition")
addon.ResetSettings()
local tracker = frame("ObjectiveTrackerFrame")
Mock.watches = 2
addon.SetCondition("quests", "fadeOut", "hasQuests", true)
Mock.Tick(0.5)
check(tracker:GetAlpha() == 0, "Quest tracker conditions use watched quests")
Mock.watches = 0
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(0.5)
check(tracker:GetAlpha() == 1, "Untracking quests automatically returns the tracker")
addon.ResetSettings()

-- Profile isolation, legacy profiles, and saved preference normalization.
addon.SetCondition("player", "fadeOut", "outCombat", true)
check(vv.SaveProfile("Polite snapshot"), "Fade rules can be saved in account profiles")
addon.ResetSettings()
check(vv.LoadProfile("Polite snapshot") and addon.GetRule("player").fadeOut.outCombat, "Loading restores fade rules")
check(not vv.ProfileModified(), "Loaded fade design compares cleanly")
addon.SetCondition("player", "fadeOut", "alive", true)
check(vv.ProfileModified() and not vv.profileStore["Polite snapshot"].settings.politeUI.rules.player.fadeOut.alive,
    "Local changes never mutate saved rule selections")
local legacy = vv.Copy(vv.profileStore["Polite snapshot"])
legacy.settings.politeUI, legacy.settings.modules.politeUI = nil, nil
vv.profileStore.Legacy = legacy
check(vv.LoadProfile("Legacy") and not next(addon.db.rules) and not vv.ProfileModified(), "Older profiles upgrade to Never without becoming modified")
vv.profileStore.BadFade = vv.Copy(legacy)
vv.profileStore.BadFade.settings.politeUI = {rules={player={fadeOut=12, fadeIn={}}}}
check(not vv.LoadProfile("BadFade"), "Malformed fade profiles are rejected before applying")
addon.db.rules.player = {fadeOut={outCombat=true, invalid=true, healthFull=false}, fadeIn="bad"}
addon.db.rules.CharacterFrame = {fadeOut={outCombat=true}, fadeIn={}}
addon.InitDB()
check(addon.GetRule("player").fadeOut.outCombat and not addon.GetRule("player").fadeOut.invalid
    and addon.GetRule("player").fadeIn == nil and not addon.db.rules.CharacterFrame,
    "Saved data repairs unknown elements, invalid conditions, and malformed selectors")
addon.ResetSettings()
check(character:GetAlpha() == 1 and questLog:GetAlpha() == 1 and bank:GetAlpha() == 1 and auction:GetAlpha() == 1,
    "Manually opened windows are never included")
check(player.scripts.OnClick == click and player:IsShown(), "Native unit visibility and click scripts remain intact")
for _, spec in ipairs(addon.elements) do
    local control = addon.optionControls[spec.key .. ".fadeOut"]
    local items = Mock.Menu(control)
    local names = {}
    for i, item in ipairs(items) do names[i] = item.name end
    for _, item in ipairs(items) do
        if item.selected and item.name ~= "Never (clear selections)" then
            for _, selected in ipairs({true, false}) do
                select(spec.key, "fadeOut", item.name)
                check(item.selected() == selected, "Existing native menu entries reflect checkbox toggles")
                local refreshed = Mock.Menu(control)
                check(#refreshed == #items, "Condition selections preserve menu length")
                for i, entry in ipairs(refreshed) do check(entry.name == names[i], "Condition selections preserve logical menu order") end
            end
        end
    end
    select(spec.key, "fadeOut", "Never (clear selections)")
    check(control.selectionText == "Never", "Clear selections refreshes native selection text without rebuilding the menu")
end
addon.ResetSettings()
VV_POLITE_UI_CHECKS = checks
