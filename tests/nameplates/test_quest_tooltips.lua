local ns = NST_TEST_NS
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message)
end

Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
Enum.TooltipDataLineType = {QuestObjective = 8, QuestTitle = 17, QuestPlayer = 18}
local lineTypes = Enum.TooltipDataLineType
local plate = Mock.Plate("nameplate1")
Mock.units.nameplate1 = true
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1")
local markers = {}
for _, frame in ipairs(Mock.frames) do
    if frame.parent == plate.UnitFrame and frame.kind then markers[frame.kind] = frame end
end
Check(markers.loot and markers.kill, "Nameplate quest markers are installed")
Check(not ns.tweaksDB.questieFallback, "Native tooltip checks do not rely on Questie")

-- Reproduce the reported native tooltip with a synthetic quest ID, so no
-- bundled NPC/drop relationship can conceal a player-name matching failure.
Mock.questEntries = {{questID = 900010}}
Mock.questObjectives = {[900010] = {
    {text = "Gnarlpine Fang: 1/15", type = "item", finished = false},
    {text = "Gnarlpine Gardener slain: 1/10", type = "monster", finished = false},
}}
local first, surname = "Ada", "Lovelace"
function UnitName() return first, surname end
local function Tooltip(player, itemText, killText)
    Mock.tooltipLines = {
        {type = lineTypes.QuestTitle, leftText = "Bounty: Gnarlpine Furbolgs"},
        {type = lineTypes.QuestPlayer, leftText = player},
        {type = lineTypes.QuestObjective, leftText = itemText or "1/15 Gnarlpine Fang"},
    }
    if killText then
        Mock.tooltipLines[#Mock.tooltipLines + 1] = {type = lineTypes.QuestObjective, leftText = killText}
    end
    Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(1)
end

Tooltip("Ada Lovelace", nil, "1/10 Gnarlpine Gardener slain")
Check(markers.loot:IsShown() and markers.kill:IsShown(), "Full player names retain native loot and kill icons")
Tooltip("|cffffff00Ada Lovelace|r")
Check(markers.loot:IsShown(), "Native player-name color markup does not hide quest icons")
Tooltip("Ada")
Check(markers.loot:IsShown(), "A native first-name-only player line is still recognized")
Tooltip("Ada Moonlight", nil, "1/10 Gnarlpine Gardener slain")
Check(not markers.loot:IsShown() and not markers.kill:IsShown(), "Another surname cannot match the local player")
Tooltip("Someone Lovelace")
Check(not markers.loot:IsShown(), "A shared surname cannot match another player")
Tooltip("Ada Lovelace", "15/15 Gnarlpine Fang")
Check(not markers.loot:IsShown(), "Completed native tooltip counts do not mark loot")
Tooltip("Ada Lovelace")
Mock.questObjectives[900010][1].finished = true
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(1)
Check(not markers.loot:IsShown(), "Finished local objectives do not mark loot")
Mock.questObjectives[900010][1].finished = false

first, surname = "Ada Lovelace", "Lovelace"
Tooltip("Ada Lovelace")
Check(markers.loot:IsShown(), "An already combined name never gains a duplicate surname")
first, surname = "Ada", nil
Tooltip("Ada")
Check(markers.loot:IsShown(), "Characters without surnames retain native quest icons")

Constants = {CharacterNameSeparatorConsts = {CHARACTERNAME_SURNAME_SEPARATOR = "-"}}
first, surname = "Ada", "Lovelace"
Tooltip("Ada-Lovelace")
Check(markers.loot:IsShown(), "Player matching uses the client's surname separator")
Constants = nil

-- A party member's section must not hide the local section or donate its
-- unfinished objectives when only the local player's objective is complete.
Tooltip("Other Player", nil, "1/10 Gnarlpine Gardener slain")
Mock.tooltipLines[#Mock.tooltipLines + 1] = {type = lineTypes.QuestPlayer, leftText = "Ada Lovelace"}
Mock.tooltipLines[#Mock.tooltipLines + 1] = {type = lineTypes.QuestObjective, leftText = "1/15 Gnarlpine Fang"}
Mock.Tick(1)
Check(markers.loot:IsShown() and not markers.kill:IsShown(), "Only the local player's section supplies quest icons")
Tooltip("Ada Lovelace", "15/15 Gnarlpine Fang")
Mock.tooltipLines[#Mock.tooltipLines + 1] = {type = lineTypes.QuestPlayer, leftText = "Other Player"}
Mock.tooltipLines[#Mock.tooltipLines + 1] = {type = lineTypes.QuestObjective, leftText = "1/15 Gnarlpine Fang"}
Mock.Tick(1)
Check(not markers.loot:IsShown(), "A party member's unfinished count cannot override a completed local count")

local secret = {secret = true}
first, surname = secret, "Lovelace"
Tooltip("Ada Lovelace")
Check(not markers.loot:IsShown(), "Restricted given names cannot establish tooltip ownership")
first, surname = "Ada", secret
Tooltip("Ada Lovelace")
Check(not markers.loot:IsShown(), "Restricted surnames cannot establish full-name ownership")
surname = "Lovelace"
Tooltip(secret)
Check(not markers.loot:IsShown(), "Restricted tooltip player names remain unclassified")
UnitName = function() error("Unavailable player name") end
Tooltip("Ada Lovelace")
Check(not markers.loot:IsShown(), "Unavailable player names do not break nameplate updates")
UnitName = function() return "Ada", "Lovelace" end
Tooltip("Ada Lovelace")
Check(markers.loot:IsShown(), "Player-name availability recovers without reloading")
Mock.questEntries = {}
Mock.Event("QUEST_LOG_UPDATE"); Mock.Tick(1)
Check(not markers.loot:IsShown(), "An abandoned quest cannot leave a native loot icon")

NST_QUEST_TOOLTIP_CHECKS = checks
