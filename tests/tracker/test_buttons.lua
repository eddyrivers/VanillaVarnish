local vv, addon = VV_TEST_NS, VV_TEST_NS.QuestTracker
local native, container = QuestObjectiveTracker, ObjectiveTrackerFrame
local checks = 0
local function check(value, label) checks = checks + 1; assert(value, label) end
local function near(a, b) return math.abs(a - b) < 0.00001 end
local function circle(region) return region:GetWidth() * 24 / 32 end
local function rebuild() container:Update(); RunMockTimers() end
local block = native.firstBlock
local marker = block.poiButton
local heading
for _, frame in ipairs(MockFrames) do if frame.zone then heading = frame; break end end
local click, parent = marker:GetScript("OnClick"), marker:GetParent()
check(near(circle(marker.NormalTexture), heading.Icon:GetWidth()), "normal quest circle matches the zone button diameter, accounting for sprite padding")
check(near(circle(marker.PushedTexture), heading.Icon:GetWidth())
    and near(circle(marker.HighlightTexture), heading.Icon:GetWidth()), "pressed and hover circles keep the same diameter")
check(near(marker.Display.Icon:GetWidth(), 16 * 20 / 24) and near(marker.Display.Icon:GetHeight(), 10 * 20 / 24),
    "ellipsis scales with its circle, preserving native proportions")
check(marker:GetWidth() == 20 and marker:GetScript("OnClick") == click, "native hit frame and click handler are retained")
addon.SetOption("compact", true); rebuild()
check(near(circle(marker.NormalTexture), heading.Icon:GetWidth())
    and near(heading.Icon:GetWidth(), 20 * 0.9), "compact quest and zone circles use the current smaller zone diameter")
local _, _, _, x, y = marker:GetPoint(1)
local _, _, _, hx, hy = heading.Icon:GetPoint(1)
check(near(x - marker:GetWidth() / 2, hx - heading.Icon:GetWidth() / 2)
    and near(y - marker:GetHeight() / 2, hy - heading.Icon:GetHeight() / 2), "quest and zone circles share the same anchor center")
marker.complete, marker.nativeDiameter = true, 40
marker:UpdateButtonStyle()
check(near(circle(marker.NormalTexture), heading.Icon:GetWidth())
    and marker.Display.Icon.texture == "question", "completion and a larger native atlas retain a consistent circle")
check(near(marker.Display.Icon:GetWidth(), 18 * (20 * 0.9 / (40 * 0.75)))
    and near(marker.Display.Icon:GetHeight(), 22 * (20 * 0.9 / (40 * 0.75))), "question mark retains its native aspect ratio")
marker:UpdateButtonStyle(); marker:UpdateButtonStyle(); rebuild(); rebuild()
check(near(circle(marker.NormalTexture), heading.Icon:GetWidth()), "native style and tracker updates never compound the reduction")
vv.SetModuleEnabled("questTracker", false); RunMockTimers()
check(marker.NormalTexture:GetWidth() == 40 and marker.Glow:GetWidth() == 50,
    "module off restores the latest native atlas dimensions")
vv.SetModuleEnabled("questTracker", true); rebuild()
check(near(circle(marker.NormalTexture), heading.Icon:GetWidth()), "module re-enable restores matching circles")
addon.SetOption("enabled", false); rebuild()
check(near(circle(marker.NormalTexture), 20 * 0.9), "compact view without grouping keeps the same quest diameter")
addon.SetOption("compact", false); rebuild()
check(marker.NormalTexture:GetWidth() == 40, "native view restores its own marker artwork")
addon.SetOption("enabled", true); rebuild()
block:Free()
check(marker.NormalTexture:GetWidth() == 40 and marker.Display.Icon:GetWidth() == 18,
    "released native quest markers restore all artwork before pooling")
marker:SetParent(CreateFrame("Frame")); marker:UpdateButtonStyle()
check(marker.NormalTexture:GetWidth() == 40, "pooled marker hooks do not resize another owner's button")
marker:SetParent(parent)
marker.complete, marker.nativeDiameter = nil, nil
rebuild()
local originalCombat = InCombatLockdown
InCombatLockdown = function() return true end
marker.protected = true
addon.SetOption("compact", true); addon.RefreshModule()
check(near(circle(marker.NormalTexture), 20), "protected marker defers the entire compact layout during combat")
marker.protected = nil
InCombatLockdown = originalCombat
addon.RefreshModule(); rebuild()
check(near(circle(marker.NormalTexture), 20 * 0.9), "deferred marker sizing applies after combat")
addon.SetOption("compact", false); rebuild()
print("PASS: " .. checks .. " matching tracker button artwork, native styles, pooling, click ownership, and combat checks")
