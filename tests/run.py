"""Run Lua 5.1 regression and combined-module checks using Lupa.

Pass --lua-runtime PATH to an existing Lupa install; test dependencies are not
part of the distributable addon. Optional native sources are cached externally.
"""
import argparse
import os
import sys
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument("--lua-runtime")
parser.add_argument("--blizzard-source")
parser.add_argument("--tooltip-source", help="Optional cached Forever tooltip sources (shared.lua, tooltip.lua, optional container.lua)")
args = parser.parse_args()
if args.lua_runtime:
    sys.path.insert(0, args.lua_runtime)
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
os.chdir(ROOT)
FILES = [line.strip().replace("\\", "/") for line in (ROOT / "VanillaVarnish.toc").read_text().splitlines()
         if line.strip() and not line.startswith("#")]


def load(lua, path):
    lua.execute("assert(loadstring(...))('VanillaVarnish', VV_TEST_NS)", (ROOT / path).read_text(encoding="utf-8-sig"))


def runtime():
    lua = LuaRuntime(unpack_returned_tuples=True)
    lua.globals().VV_TEST_NS = lua.table()
    return lua


def nameplates(full=False, native=None, seed=None):
    lua = runtime()
    lua.execute((ROOT / "tests/nameplates/MockWoW.lua").read_text())
    lua.execute("C_Timer = {After=function(_, fn) fn() end}; GetBuildInfo=function() return '1.60.1', '70291', '', 16001 end")
    if native:
        lua.execute((ROOT / "tests/nameplates/NativeNameplateMock.lua").read_text())
        for module in ("enum", "constants", "frameopts", "frameoverrides", "component", "auras", "classification", "castframe", "cast", "health", "level", "unit", "driver"):
            path = Path(native) / f"{module}.lua"
            if module in ("frameoverrides", "level", "auras", "classification") and not path.exists():
                continue
            lua.execute(path.read_text(encoding="utf-8"))
        preview_source = Path(native) / "optionspreview.lua"
        if preview_source.exists():
            # Only the native preview mixin; the rest registers the game options.
            lua.execute(preview_source.read_text().split("local function GetPreviewNamePlate()")[0])
        lua.execute('Mock.cvars.nameplateSelectedScale = "1.2"; Mock.cvars.nameplateCastBarDisplay = "31"; Mock.cvars.nameplateInfoDisplay = "3"; Mock.ApplyNameplateStyle(4, 2)')
    if seed:
        lua.execute(seed)
    for path in FILES:
        if full or path in ("Core.lua", "Presets.lua", "Profiles.lua", "Settings.lua") or path.startswith("Modules/Nameplates/"):
            load(lua, path)
    lua.execute("NST_TEST_NS = VV_TEST_NS.Nameplates")
    return lua


# Parse every shipped Lua file with the actual Lua 5.1 parser.
syntax = runtime()
for path in ROOT.rglob("*.lua"):
    syntax.execute("assert(loadstring(...))", path.read_text(encoding="utf-8-sig"))
print("PASS: all Lua sources parse as Lua 5.1")

np = nameplates()
np.execute((ROOT / "tests/nameplates/test.lua").read_text())
print(f"PASS: {np.globals().NST_TEST_CHECKS} nameplate and swing regression checks")
np.execute((ROOT / "tests/nameplates/test_quest_drops.lua").read_text())
print(f"PASS: {np.globals().NST_QUEST_DROP_CHECKS} bundled quest-drop graph and behavior checks")
preview = nameplates()
preview.execute((ROOT / "tests/nameplates/test_preview.lua").read_text())
print(f"PASS: {preview.globals().NST_PREVIEW_CHECKS} menu preview checks")
combo = nameplates()
combo.execute((ROOT / "tests/nameplates/test_combo_points.lua").read_text())
print(f"PASS: {combo.globals().NST_COMBO_CHECKS} combo-point live, settings, and combined-preview checks")
spacing = nameplates()
spacing.execute((ROOT / "tests/test_swing_spacing.lua").read_text())
print(f"PASS: {spacing.globals().NST_SPACING_CHECKS} swing artwork spacing and cast-clearance checks")
melee = nameplates()
melee.execute((ROOT / "tests/test_melee_range.lua").read_text())
print("PASS: melee reach range selection, native verdicts, fallback, and restricted results")
review_nameplates = nameplates()
review_nameplates.execute((ROOT / "tests/test_review_nameplates.lua").read_text())
print(f"PASS: {review_nameplates.globals().VV_REVIEW_NAMEPLATE_CHECKS} nameplate pooling, restricted quest data, disabled scans, and idle rendering checks")
threat = nameplates()
threat.execute((ROOT / "tests/nameplates/test_threat_colors.lua").read_text())
print(f"PASS: {threat.globals().NST_THREAT_CHECKS} threat color checks for roles, tank auras, restoration, restricted data, and pooled plates")
if args.blizzard_source:
    native = nameplates(native=args.blizzard_source)
    native.execute((ROOT / "tests/nameplates/test_native_preview.lua").read_text())
    print(f"PASS: {native.globals().NST_NATIVE_PREVIEW_CHECKS} checks using cached native Blizzard sources")
    native_alignment = nameplates(native=args.blizzard_source)
    native_alignment.execute((ROOT / "tests/nameplates/test_preview_alignment.lua").read_text())
    print(f"PASS: {native_alignment.globals().NST_PREVIEW_ALIGNMENT_CHECKS} live/preview health, timer, and combo alignment checks")
    native_combo = nameplates(native=args.blizzard_source)
    native_combo.execute((ROOT / "tests/nameplates/test_combo_points.lua").read_text())
    print(f"PASS: {native_combo.globals().NST_COMBO_CHECKS} combo-point checks with native Blizzard previews")

tracker = runtime()
tracker.execute((ROOT / "tests/tracker/test_tracker.lua").read_text())

party = runtime()
party.execute((ROOT / "tests/party/mock.lua").read_text())
load(party, "Core.lua")
party.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(party, "Modules/Party/PartyTweaks.lua")
party.execute((ROOT / "tests/party/check.lua").read_text())
party.execute((ROOT / "tests/test_party_toggles.lua").read_text())
print("PASS: party regression checks, feature restoration, and combat deferral")

combat = runtime()
combat.execute((ROOT / "tests/party/mock.lua").read_text())
load(combat, "Core.lua")
combat.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(combat, "Modules/Party/PartyTweaks.lua")
combat.execute((ROOT / "tests/test_party_combat.lua").read_text())
print("PASS: party buff display with combat-restricted records and events")

access = runtime()
access.execute((ROOT / "tests/party/mock.lua").read_text())
load(access, "Core.lua")
access.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(access, "Modules/Party/PartyTweaks.lua")
access.execute((ROOT / "tests/test_party_access.lua").read_text())
print("PASS: party restricted aura lists, optional field failures, visibility, fallback, and diagnostics")

colors = runtime()
colors.execute((ROOT / "tests/party/mock.lua").read_text())
load(colors, "Core.lua")
colors.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(colors, "Modules/Party/PartyTweaks.lua")
colors.execute((ROOT / "tests/test_party_colors.lua").read_text())
print("PASS: party color toggles preserve native health state/scripts and restore restricted display values")
review_party = runtime()
review_party.execute((ROOT / "tests/party/mock.lua").read_text())
load(review_party, "Core.lua")
review_party.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(review_party, "Modules/Party/PartyTweaks.lua")
review_party.execute((ROOT / "tests/test_review_party.lua").read_text())
print(f"PASS: {review_party.globals().VV_REVIEW_PARTY_CHECKS} native party color restoration, event coalescing, and aura recycling checks")

styles = runtime()
styles.execute((ROOT / "tests/party/mock.lua").read_text())
load(styles, "Core.lua")
styles.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(styles, "Modules/Party/PartyTweaks.lua")
styles.execute((ROOT / "tests/test_party_styles.lua").read_text())
print("PASS: raid-style colors and aura suppression, player buff priority/size, native dispellable debuff size/borders/restoration")

party_range = runtime()
party_range.execute((ROOT / "tests/party/mock.lua").read_text())
load(party_range, "Core.lua")
party_range.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(party_range, "Modules/Nameplates/NameplateTweaks.lua")
load(party_range, "Modules/Party/PartyTweaks.lua")
party_range.execute((ROOT / "tests/test_party_range.lua").read_text())
print(f"PASS: {party_range.globals().VV_PARTY_RANGE_CHECKS} party range, native alpha restoration, combat, and pooling checks")

party_priority = runtime()
party_priority.execute((ROOT / "tests/party/mock.lua").read_text())
load(party_priority, "Core.lua")
party_priority.execute("VV_TEST_NS.RegisterOptions = function() end; VV_TEST_NS.InitDB()")
load(party_priority, "Modules/Party/PartyTweaks.lua")
party_priority.execute((ROOT / "tests/test_party_buff_priority.lua").read_text())
print(f"PASS: {party_priority.globals().VV_PARTY_PRIORITY_CHECKS} party buff capacity, recovery priority, wrapping, locale, and tooltip checks")

tooltip = runtime()
tooltip.execute((ROOT / "tests/tooltips/mock.lua").read_text())
if args.tooltip_source:
    for filename in ("shared.lua", "tooltip.lua"):
        tooltip.execute((Path(args.tooltip_source) / filename).read_text(encoding="utf-8-sig"))
    tooltip.execute("GameTooltip.SetWorldCursor=GameTooltipDataMixin.SetWorldCursor")
    container = Path(args.tooltip_source) / "container.lua"
    if container.is_file():
        source = container.read_text(encoding="utf-8-sig")
        start = source.index("function ContainerFrameItemButton_CalculateItemTooltipAnchors(")
        end = source.index("\nfunction ContainerFrameExtendedItemButton_OnEnter(", start)
        tooltip.execute(source[start:end])
tooltip.execute("Mock.WatchNativeSetup()")
for path in FILES:
    if path == "Core.lua" or path.startswith("Modules/Tooltips/"):
        load(tooltip, path)
tooltip.execute("VV_TEST_NS.RegisterOptions=function() end; VV_TEST_NS.Tooltips.RegisterOptions=function() end")
tooltip.execute((ROOT / "tests/tooltips/test.lua").read_text())
print("PASS: tooltip same-frame refreshes, bag setup order, immediate hover dismissal, offsets, combat/Edit Mode, colors, restricted values, persistence, and conflicts")

combined = nameplates(full=True)
combined.execute((ROOT / "tests/test_integration.lua").read_text())
print("PASS: combined TOC load, namespace isolation, shared menu, master switches, and persistence")

profiles = nameplates(full=True)
profiles.execute((ROOT / "tests/test_profiles.lua").read_text())
print(f"PASS: {profiles.globals().VV_PROFILE_CHECKS} account profiles, cross-character loading, isolation, controls, and combat checks")

presets = nameplates(full=True)
presets.execute((ROOT / "tests/test_presets.lua").read_text())
print(f"PASS: {presets.globals().VV_PRESET_CHECKS} built-in defaults, preset/profile isolation, collapsing row geometry, controls, and combat checks")
if args.blizzard_source:
    native_presets = nameplates(full=True, native=args.blizzard_source)
    native_presets.execute((ROOT / "tests/test_presets.lua").read_text())
    print(f"PASS: {native_presets.globals().VV_PRESET_CHECKS} preset and row checks with native Blizzard previews")

swing_import = nameplates(full=True, seed='NameplateSwingTimersDB = {appearanceVersion=9, width=191, y=71}')
swing_import.execute('''
Mock.Event("ADDON_LOADED", "VanillaVarnish")
assert(VV_TEST_NS.Nameplates.db.width == 191 and VV_TEST_NS.Nameplates.db.y == 71)
assert(VV_TEST_NS.Nameplates.db ~= NameplateSwingTimersDB)
''')

# Import uses loaded globals only, copies nested tables, and never rewrites them.
migration = nameplates(full=True, seed='''
NameplateTweaksDB = {markers=false, damage="Moonfire", swingTimers={appearanceVersion=9, width=191, bars={main={enabled=false}}}}
QuestTrackerOrganizerDB = {enabled=false, completedFirst=true, collapsed={Westfall=true}}
''')
migration.execute('''
Mock.Event("ADDON_LOADED", "VanillaVarnish")
local vv = VV_TEST_NS
assert(vv.db.nameplates.markers == false and vv.db.nameplates.swingTimers.width == 191)
assert(vv.db.questTracker.completedSort == "top" and vv.db.questTracker.completedFirst == nil and vv.db.questTracker.collapsed.Westfall)
assert(vv.db.nameplates ~= NameplateTweaksDB and vv.db.nameplates.swingTimers.bars ~= NameplateTweaksDB.swingTimers.bars)
assert(vv.db.questTracker.collapsed ~= QuestTrackerOrganizerDB.collapsed)
vv.db.nameplates.swingTimers.width = 207
NameplateTweaksDB.swingTimers.width = 240
vv.InitDB()
assert(vv.db.nameplates.swingTimers.width == 207 and NameplateTweaksDB.markers == false)
assert(QuestTrackerOrganizerDB.completedFirst == true)
vv.db.questTracker.completedSort = "bottom"
vv.db.questTracker.completedFirst = true
vv.InitDB()
assert(vv.db.questTracker.completedSort == "bottom" and vv.db.questTracker.completedFirst == nil)
''')
for old_value, expected in (("true", "top"), ("false", "off")):
    completion = nameplates(full=True, seed=f"VanillaVarnishDB = {{questTracker={{completedFirst={old_value}}}}}")
    completion.execute(f"VV_TEST_NS.InitDB(); assert(VV_TEST_NS.db.questTracker.completedSort == '{expected}'); assert(VV_TEST_NS.db.questTracker.completedFirst == nil)")
conflict = nameplates(full=True, seed='''
C_AddOns = {IsAddOnLoaded=function(name) return name == "NameplateTweaks" or name == "QuestTrackerOrganizer" or name == "PartyTweaks" or name == "NameplateSwingTimers" end}
NameplateTweaksDB = {markers=false}
SlashCmdList.NAMEPLATETWEAKS = function() return "original" end
''')
conflict.execute('''
Mock.Event("ADDON_LOADED", "VanillaVarnish"); Mock.Event("PLAYER_LOGIN")
assert(not VV_TEST_NS.IsModuleEnabled("nameplates") and not VV_TEST_NS.IsModuleEnabled("questTracker") and not VV_TEST_NS.IsModuleEnabled("party"))
assert(VV_TEST_NS.swingConflict and VV_TEST_NS.db.nameplates.markers == false)
assert(SlashCmdList.NAMEPLATETWEAKS() == "original")
''')
print("PASS: migration copies settings once; legacy addon conflicts suppress duplicate changes")

disabled = nameplates(full=True, seed='''
VanillaVarnishDB = {modules={nameplates=false, questTracker=false, party=false}}
''')
disabled.execute('''
Mock.Event("ADDON_LOADED", "VanillaVarnish"); Mock.Event("PLAYER_LOGIN")
local vv = VV_TEST_NS
local plate = Mock.Plate("nameplate1")
Mock.plates.target, Mock.units.target, Mock.units.nameplate1 = plate, true, true
Mock.Event("NAME_PLATE_UNIT_ADDED", "nameplate1"); Mock.Event("PLAYER_TARGET_CHANGED")
assert(Mock.Stack(plate) == nil)
vv.SetModuleEnabled("nameplates", true)
Mock.Event("PLAYER_SWING", 3, Enum.PlayerSwingType.MainHand)
assert(Mock.Stack(plate):IsShown())
vv.Nameplates.SetFeature("swingsEnabled", false)
assert(not Mock.Stack(plate):IsShown())
vv.SetModuleEnabled("nameplates", false); vv.SetModuleEnabled("nameplates", true)
assert(not Mock.Stack(plate):IsShown() and not vv.Nameplates.tweaksDB.swingsEnabled)
''')
reordered = nameplates(full=True)
reordered.execute('''
-- Dispatch in reverse frame order to catch implicit startup dependencies.
for index = #Mock.frames, 1, -1 do
    local frame = Mock.frames[index]
    if frame.events.ADDON_LOADED and frame.scripts.OnEvent then
        frame.scripts.OnEvent(frame, "ADDON_LOADED", "VanillaVarnish")
    end
end
Mock.Event("PLAYER_LOGIN")
assert(VV_TEST_NS.Nameplates.tweaksDB == VV_TEST_NS.db.nameplates)
assert(VV_TEST_NS.Nameplates.db == VV_TEST_NS.db.nameplates.swingTimers)
assert(#Mock.categories == 10)
''')
print("PASS: modules disabled at startup can be enabled later; initialization is independent of event dispatch order")
