local vv, addon = VV_TEST_NS, VV_TEST_NS.QuestTracker
local native, container = QuestObjectiveTracker, ObjectiveTrackerFrame
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function rebuild() container:Update(); RunMockTimers() end
local function top(frame) return select(5, frame:GetPoint(1)) end
local block = native.firstBlock
local heading
for _, frame in ipairs(MockFrames) do if frame.zone then heading = frame; break end end
check(addon.db.compact == false and not addon.optionControls.compact:GetChecked(), "compact tracker defaults off")
local normalHeight, normalTop = native:GetHeight(), top(block)
local checkbox = addon.optionControls.compact
checkbox:SetChecked(true); checkbox.scripts.OnClick(checkbox); rebuild()
check(block.HeaderText.size == 9 and block.lines[1].Text.size == 7.5, "compact uses 75% of normal grouped text size")
check(heading.Text.size == 10.5 and heading.Icon:GetSize() == 18, "zone titles and buttons shrink together")
check(native:GetHeight() < normalHeight and top(block) > normalTop, "compact text and gaps fit more quest rows")
check(block.height == 20.5, "native renderer measures the smaller fonts itself")
local compactHeight = native:GetHeight()
rebuild(); rebuild()
check(native:GetHeight() == compactHeight and block.HeaderText.size == 9, "successive updates never shrink fonts or spacing again")
native:AdjustSlideAnchor(-30)
local compactTop = top(block)
native:AdjustSlideAnchor(0)
check(top(block) == compactTop, "native animation retains compact row placement")
addon.SetOption("enabled", false); rebuild()
check(block.HeaderText.size == 10.5 and block.lines[1].Text.size == 9, "ungrouped compact view scales native fonts")
check(not heading:IsShown() and block.HeaderText:GetText() == "Unknown", "ungrouped compact view preserves native titles and order")
check(top(block) == -7.5, "ungrouped compact view tightens native row spacing")
vv.SetModuleEnabled("questTracker", false); rebuild()
check(block.HeaderText.size == 14 and block.lines[1].Text.size == 12 and addon.db.compact,
    "module off restores native text while retaining compact preference")
vv.SetModuleEnabled("questTracker", true); rebuild()
check(block.HeaderText.size == 10.5, "module re-enable restores compact view")
addon.SetOption("enabled", true); rebuild()
vv.QuestTracker.HandleSlash("compact off"); rebuild()
check(not checkbox:GetChecked() and block.HeaderText.size == 12 and native:GetHeight() == normalHeight,
    "compact off restores usual grouped fonts and spacing")
vv.QuestTracker.HandleSlash("compact on"); rebuild()
check(checkbox:GetChecked(), "compact slash command synchronizes settings")
local originalCombat = InCombatLockdown
InCombatLockdown = function() return true end
block.ItemButton.protected = true
addon.SetOption("compact", false); addon.RefreshModule()
check(block.HeaderText.size == 9, "protected combat layout defers compact size changes")
block.ItemButton.protected = nil
InCombatLockdown = originalCombat
addon.RefreshModule(); rebuild()
check(block.HeaderText.size == 12, "deferred compact size restores after combat")
addon.ResetOptions(); rebuild()
check(not addon.db.compact and not addon.db.compactLog and block.HeaderText.size == 12,
    "restore defaults disables both compact preferences")
print("PASS: " .. checks .. " compact quest tracker size, spacing, settings, native order, restoration, and animation checks")
