# Development and validation

The supported client is WoW Forever 1.60.x / Interface 16001. Other client families require separate validation.

Run `python tests/run.py --lua-runtime <directory-containing-lupa>` with Lupa's Lua 5.1 runtime. If a native source snapshot is available, add `--blizzard-source <cached-native-nameplate-sources>` to exercise the real Blizzard nameplate mixins. Dependencies and source snapshots stay outside release packages.

The suite checks nameplates, combo points, swing geometry, shared previews, tracker behavior, party features, restricted API values, migration, and module switches. Mocks cannot reproduce the client's taint engine or confirm rendered textures.

Check in the supported client after reloading: all settings pages and toggles; combo points gained, spent, transferred, and cleared on rogue and druid targets; dot artwork and positioning alongside swings and casts; nameplate styles and sizes; party targeting, click-casting, buffs, and debuffs; quest grouping with secure quest items; Edit Mode; Questie present and absent. Verify saved settings after restarting and migration from actual legacy SavedVariables.

Build with `python tools/build_release.py`. The archive contains runtime sources, assets, the user guide, changelog, and font license. Tests, tools, development instructions, dependency caches, and Git metadata are excluded. Keep existing releases in version control.

Follow `AGENTS.md` for the commit and push workflow. Choose a source-code license and appropriate CurseForge game-version/flavor tags before publishing to CurseForge.
