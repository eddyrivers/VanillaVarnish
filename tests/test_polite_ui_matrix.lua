local vv, addon = VV_TEST_NS, VV_TEST_NS.PoliteUI
local checks, combinations = 0, 0
local function check(value, message) checks = checks + 1; assert(value, message) end
vv.RegisterOptions = function() end
addon.RegisterOptions = function() end
vv.InitDB()

-- Exhaust all one-, two-, and three-condition selections for every row.
-- Check true, false, and unavailable values at every position, and
-- verify that no failing condition stops another condition from being sampled.
local originals, badID, badValue, calls = {}, nil, nil, {}
for id, item in pairs(addon.conditions) do
    local key = id
    originals[id] = item.test
    item.test = function()
        calls[key] = (calls[key] or 0) + 1
        if badID == key then return badValue end
        return true
    end
end
for _, spec in ipairs(addon.elements) do
    for _, side in ipairs({"fadeOut"}) do
        local choices = addon.Choices(spec.key, side)
        local function selection(ids)
            combinations = combinations + 1
            local rule = {fadeOut={}}
            for _, id in ipairs(ids) do rule[side][id] = true end
            addon.db.rules[spec.key] = rule
            local function verify(expected)
                calls = {}
                check(addon.Matches(spec.key, side) == expected, spec.key .. "/" .. side .. ": incorrect AND verdict")
                for _, id in ipairs(ids) do
                    check(calls[id] == 1, spec.key .. "/" .. side .. ": skipped or repeated condition " .. id)
                end
            end
            badID = nil; verify(true)
            for _, id in ipairs(ids) do
                badID, badValue = id, false; verify(false)
                badValue = nil; verify(false)
            end
            badID = nil
        end
        for i = 1, #choices do
            selection({choices[i].id})
            for j = i + 1, #choices do
                selection({choices[i].id, choices[j].id})
                for k = j + 1, #choices do selection({choices[i].id, choices[j].id, choices[k].id}) end
            end
        end
        addon.db.rules[spec.key] = nil
    end
end
for id, fn in pairs(originals) do addon.conditions[id].test = fn end

local player = CreateFrame("Frame", nil, UIParent)
PlayerFrame = player
Mock.units.player = true
function UnitHealth(...) assert(select("#", ...) == 1); return Mock.playerHealth end
function UnitHealthMax(...) assert(select("#", ...) == 1); return 100 end
function UnitPower(_, powerType) assert(powerType == 0); return Mock.playerMana end
function UnitPowerMax(_, powerType) assert(powerType == 0); return 100 end
function UnitPowerType() return 0 end
function UnitIsDeadOrGhost() return false end
function UnitCastingInfo() return nil end
function UnitChannelInfo() return nil end
Mock.Event("ADDON_LOADED", "VanillaVarnish")
Mock.Event("PLAYER_LOGIN")
local function advance(seconds)
    for _ = 1, math.ceil((seconds or 0.7) / 0.05) do Mock.Tick(0.05) end
end
local function bit(mask, index) return math.floor(mask / 2 ^ (index - 1)) % 2 == 1 end
local outIDs = {"healthFull", "manaFull", "outCombat", "noTarget"}
local cases = 0
-- All 16 subsets of the reported four fade-out conditions and 64 resource,
-- combat, and target states: 1,024 live configurations. Also verify return
-- and refading after state changes, all in one session without reloading.
for outMask = 0, 15 do
    for _ = 1, 1 do
        for _, health in ipairs({0, 74, 75, 100}) do
            for _, mana in ipairs({0, 74, 75, 100}) do
                for combat = 0, 1 do
                    for target = 0, 1 do
                        addon.ResetSettings()
                        Mock.playerHealth, Mock.playerMana = health, mana
                        Mock.combat, Mock.units.target = combat == 1, target == 1
                        local signals = {healthFull=health == 100, manaFull=mana == 100,
                            outCombat=combat == 0, noTarget=target == 0, inCombat=combat == 1, hasTarget=target == 1}
                        local outMatch = outMask > 0
                        for index, id in ipairs(outIDs) do
                            if bit(outMask, index) then
                                addon.SetCondition("player", "fadeOut", id, true)
                                if not signals[id] then outMatch = false end
                            end
                        end
                        advance()
                        local expected = outMatch and 0 or 1
                        check(math.abs(player:GetAlpha() - expected) < 0.00001,
                            string.format("Live matrix out=%d health=%d mana=%d combat=%d target=%d", outMask, health, mana, combat, target))
                        Mock.playerHealth, Mock.playerMana, Mock.combat, Mock.units.target = 100, 100, false, false
                        advance()
                        check(player:GetAlpha() == (outMask > 0 and 0 or 1), "All matching conditions fade without resetting the rule")
                        Mock.playerHealth, Mock.playerMana, Mock.combat, Mock.units.target = 0, 0, true, true
                        advance()
                        check(player:GetAlpha() == 1, "Losing conditions returns automatically without resetting the rule")
                        cases = cases + 1
                    end
                end
            end
        end
    end
end
addon.ResetSettings()

-- Exercise the actual adapter names for every supported HUD group, not only
-- the rule evaluator. Reuse one addon session through toggles, hover, frame
-- replacement, and fallback discovery.
local adapters = 0
local function named(name)
    local frame = CreateFrame("Frame", nil, UIParent)
    _G[name] = frame
    return frame
end
for _, spec in ipairs(addon.elements) do
    addon.ResetSettings()
    Mock.combat, Mock.units.target = false, false
    local frames = {}
    for _, name in ipairs(spec.names) do frames[#frames + 1] = named(name) end
    if spec.key == "chat" then
        frames = {named("ChatFrame1"), named("ChatFrame1Tab"), named("ChatFrame10"), named("GeneralDockManager")}
    end
    for _, id in ipairs({"outCombat", "noTarget", "alive"}) do addon.SetCondition(spec.key, "fadeOut", id, true) end
    advance()
    for _, frame in ipairs(frames) do check(frame:GetAlpha() == 0, spec.key .. ": all discovered frames fade with three AND conditions") end
    Mock.combat = true; advance()
    for _, frame in ipairs(frames) do check(frame:GetAlpha() == 1, spec.key .. ": combat breaks a fade-out condition and reveals the group") end
    Mock.units.target = true; advance()
    for _, frame in ipairs(frames) do check(frame:GetAlpha() == 1, spec.key .. ": a target keeps the group visible while no-target is selected") end
    Mock.combat, Mock.units.target = false, false
    advance()
    frames[1].mouseOver = true; advance()
    for _, frame in ipairs(frames) do check(frame:GetAlpha() == 1, spec.key .. ": hover reveals the whole group") end
    frames[1].mouseOver = false; advance()
    vv.SetModuleEnabled("politeUI", false)
    for _, frame in ipairs(frames) do check(frame:GetAlpha() == 1, spec.key .. ": disabling restores every frame") end
    vv.SetModuleEnabled("politeUI", true); advance()
    for _, frame in ipairs(frames) do check(frame:GetAlpha() == 0, spec.key .. ": re-enabling works without a reload") end
    if spec.names[1] then
        local old = frames[1]
        local replacement = named(spec.names[1])
        advance(1.8)
        check(old:GetAlpha() == 1 and replacement:GetAlpha() == 0, spec.key .. ": late replacement restores the old frame and fades the new one")
        if spec.fallback then
            _G[spec.names[1]] = nil
            local fallback = named(spec.fallback)
            advance(1.8)
            check(replacement:GetAlpha() == 1 and fallback:GetAlpha() == 0, spec.key .. ": fallback frame discovery recovers live")
        end
    end
    adapters = adapters + 1
end
addon.ResetSettings()
VV_POLITE_UI_MATRIX_CHECKS, VV_POLITE_UI_COMBINATIONS, VV_POLITE_UI_LIVE_CASES, VV_POLITE_UI_ADAPTERS = checks, combinations, cases, adapters
