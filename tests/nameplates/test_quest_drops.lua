local ns = NST_TEST_NS
local checks = 0
local function Check(value, message)
    checks = checks + 1
    assert(value, message)
end
local function Objective(itemID, count, required, finished, text)
    return {itemID = itemID, type = "item", numFulfilled = count,
        numRequired = required, finished = finished or false, text = text}
end
local savedNames, savedCounts = Mock.itemNames, Mock.itemCounts
Mock.itemNames, Mock.itemCounts = {}, {}

-- A vanilla mixed quest works without any external provider. Finished item
-- objectives do not hide other items, and unrelated drop sources stay clear.
local stew = {Objective(729, 3, 3, true), Objective(730, 1, 3),
    Objective(731, 0, 3), Objective(732, 0, 3)}
Mock.itemCounts = {[729] = 3, [730] = 1, [731] = 0, [732] = 0}
local sources = ns.QuestDropSources(38, stew, false)
Check(sources[46] and sources[454], "Westfall murlocs and goretusks supply unfinished ingredients")
Check(not sources[1109], "Completed vulture meat does not mark fleshrippers")
Check(not sources[1998], "Unrelated spiders do not supply stew ingredients")
stew[2].finished = true
sources = ns.QuestDropSources(38, stew, false)
Check(not sources[46] and sources[454], "Finishing one item preserves another ingredient's icon")
Check(not next(ns.QuestDropSources(38, stew, true)), "Completed quests never use the baseline")

-- Localized matching uses client names, not shipped English strings or
-- assumed objective order. Keep the vendor-only objective in cardinality.
Mock.itemNames = {[2886] = "Cote de sanglier", [2894] = "Malt"}
Mock.itemCounts = {[2886] = 0, [2894] = 0}
local ribs = {Objective(nil, 0, 1, false, "Malt: 0/1"),
    Objective(nil, 0, 6, false, "Cote de sanglier: 0/6")}
sources = ns.QuestDropSources(384, ribs, false)
Check(sources[1125] and not sources[1247], "Translated ribs match out of order; a malt vendor is not loot")
Mock.itemNames = {}
Check(not next(ns.QuestDropSources(384, {ribs[1]}, false)),
    "A mixed quest cannot guess that its sole visible objective is the drop item")
Mock.itemNames[2886] = "Cote de sanglier"
Check(ns.QuestDropSources(384, ribs, false)[1125], "Client name arrival repairs the mixed objective match")

-- A baseline quest supplies an existing drop relationship; native amounts
-- remain authoritative rather than a copied static required count.
Mock.itemCounts = {[772] = 2}
Check(ns.QuestDropSources(60, {Objective(772, 2, 3)}, false)[40],
    "Native required counts control needed candle drops without Questie")
Mock.itemCounts[772] = 3
Check(not next(ns.QuestDropSources(60, {Objective(772, 2, 3)}, false)),
    "Inventory completion hides sources before objective text catches up")
Mock.itemCounts[772], Mock.itemNames[772] = 0, "Large Candle"
Check(not next(ns.QuestDropSources(60, {Objective(nil, 0, 3, false, "Different item: 0/3")}, false)),
    "A cached mismatched name cannot guess a changed single-item requirement")
Mock.itemNames[772] = nil
Check(not next(ns.QuestDropSources(60, {Objective(999999, 0, 3)}, false)),
    "A readable conflicting native item ID wins over single-item cardinality")

-- The baseline no longer includes website-derived Forever overrides. Keep
-- the actual vanilla requirements, without claiming they are Forever fixes.
Check(ns.QuestDropData.quests[92110] == nil, "The website-derived new quest is absent")
Check(ns.QuestDropData.items[22637] == nil, "The website-derived idol sources are absent")
Check(not next(ns.QuestDropData.reviewed), "No website-reviewed quest flags remain")
local zg = ns.QuestDropData.quests[8184]
Check(#zg == 3 and zg[1] == 18331 and zg[2] == 19724 and zg[3] == 19813,
    "ZG retains the pinned pfQuest requirements without Forever overrides")

-- Source snapshots contain no progress, and relationships are shared without
-- per-quest duplication. Validate the whole generated graph after TOC load.
local quests, items, links = 0, 0, 0
for questID, required in pairs(ns.QuestDropData.quests) do
    quests = quests + 1
    Check(type(questID) == "number" and questID > 0 and #required > 0, "Valid quest ID and objectives")
    for _, itemID in ipairs(required) do Check(type(itemID) == "number" and itemID > 0, "Valid item ID") end
end
for itemID, npcs in pairs(ns.QuestDropData.items) do
    items = items + 1
    local seen = {}
    for _, npcID in ipairs(npcs) do
        links = links + 1
        Check(type(npcID) == "number" and npcID > 0 and not seen[npcID], "Distinct positive NPC sources")
        seen[npcID] = true
    end
end
Check(quests == 1335 and items == 1183 and links == 25876, "Only the pinned pfQuest baseline loaded")
Mock.itemNames, Mock.itemCounts = savedNames, savedCounts
NST_QUEST_DROP_CHECKS = checks
