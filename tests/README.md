# Development and validation

The supported client is WoW Forever 1.60.x / Interface 16001. Other client families require separate validation.

Run `python tests/run.py --lua-runtime <directory-containing-lupa>` with Lupa's Lua 5.1 runtime. If a native source snapshot is available, add `--blizzard-source <cached-native-nameplate-sources>` to exercise the real Blizzard nameplate mixins. Add `--tooltip-source <cached-native-tooltip-sources>` for Forever's `shared.lua` (Blizzard_SharedXML/SharedTooltipTemplates.lua) and `tooltip.lua` (Blizzard_GameTooltip/Mainline/GameTooltip.lua) from the [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns). These checks load the native anchor helper and world-hover departure/fade path. Dependencies and source snapshots stay outside release packages.

The suite checks nameplates, combo points, swing geometry, shared previews, tracker behavior (including Off/top/bottom completion sorting, dropdown selection, and preference migration), party features, tooltip anchors/colors/fades/combat pause, restricted API values, migration, and module switches. Mocks cannot reproduce the client's taint engine, cursor tracking/clamping, or rendered textures.

Check in the supported client after reloading: all settings pages and toggles; combo points gained, spent, transferred, and cleared on rogue and druid targets; dot artwork and positioning alongside swings and casts; nameplate styles and sizes; party targeting, click-casting, buffs, and debuffs; quest grouping with secure quest items; Edit Mode; Questie present and absent. Verify saved settings after restarting and migration from actual legacy SavedVariables.

For Tooltips, disable ForeverMouseTooltip and reload. Check movement and X/Y offsets on mobs, players (including surnames), world objects, spells, bags, inventory, auras, and settings controls at different UI scales and screen edges. Check item comparisons, native fades and instant hide, direct transitions between hover targets, and class/difficulty colors without changing guild or quest text. Move the HUD tooltip in Edit Mode, enable combat pause, and verify current/new hover tips use that location throughout combat and resume following afterward. Check master and feature toggles, saved preferences, and restricted combat tooltips without Lua errors or blocked actions.

Build with `python tools/build_release.py`. The archive contains runtime sources, assets, the user guide, changelog, and font license. Tests, tools, development instructions, dependency caches, and Git metadata are excluded. Keep existing releases in version control.

Follow `AGENTS.md` for the commit and push workflow. Choose a source-code license and appropriate CurseForge game-version/flavor tags before publishing to CurseForge.
