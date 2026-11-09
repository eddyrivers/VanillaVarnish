# Contributing

VanillaVarnish supports **WoW Forever 1.60.x / Interface 16001**. Keep changes focused, preserve per-character preferences, and avoid competing with Blizzard's secure UI or loaded standalone addons. All addon slash commands belong under `/vv`.

## Run checks

Use Python 3.11 or newer and Lupa's Lua 5.1 runtime:

```sh
python -m pip install --target .test-deps/lua-runtime lupa==2.8
python tests/run.py --lua-runtime .test-deps/lua-runtime
python -m unittest discover -s tests -p "test_*.py"
python tools/build_release.py
```

Optional native source snapshots stay in `.test-deps` or another local cache. Pass `--blizzard-source <directory>` containing the native nameplate files expected by `tests/run.py`. For tooltip checks, pass `--tooltip-source <directory>` containing `shared.lua`, `tooltip.lua`, and optionally `container.lua` from the [Forever UI source](https://github.com/Gethe/wow-ui-source/tree/forever/Interface/AddOns).

For quest watch enumeration checks, pass `--quest-source <directory>` containing an existing `tracker.lua` snapshot of `Blizzard_ObjectiveTracker/Blizzard_QuestObjectiveTracker.lua`. This runs the cached native filtering, sorting, and early-stop enumeration through the scrolling fixture. The container budget, geometry, and combat restrictions remain simulated.

For compact quest views, toggle each option independently and confirm it survives reload and profile loading. Check the gentle 1.5-point text reduction, zone buttons, spacing, wrapping, and quest item clearance with grouping on and off. All Objectives should sit directly above Quests with a small normal gap after repeated native updates, with and without overflow. Use the separate Quest log settings page (`/vv questlog`) to toggle its Compact view; check titles, objectives, zone headings, search, tracking checkboxes, click menus, scrolling to the final quest, and unchanged quest detail text. Each page's Restore defaults must leave the other page's choice unchanged. Test both views in combat and after disabling/re-enabling the module. Quest log tests simulate native pool acquisition and font measurement; confirm actual font rendering and row bounds in game.

For tracker header spacing, reload with each compact preference combination, then let quest progress, tracking changes, and zone updates refresh the tracker without opening addon settings. Repeat with enough room for all quests and with overflow. The gap above Quests must stay small without toggling Compact quest log. Native dirty updates use a saved update closure, so a test that calls only the hooked `container:Update()` does not cover this path.

For quest refresh and tracker security, accept and turn in quests in quick succession, remove a watch, and switch characters. Watched quests must stay visible without reloading. Have someone join or leave the group, level up, and move or resize the tracker in Edit Mode, including during restricted aura state. Check for aura-access errors from the scenario tracker and confirm scrolling still works. Keep the native resize handler installed throughout layout; restoring it with `SetScript` from addon code can taint later native updates. After updating from a version that replaced that handler, reload once before checking.

For tracker buttons, compare the ellipsis and ready-for-turn-in quest circles with the zone +/− circles in normal and compact views. Check their visible diameter and center line, hover and pressed effects, selected quests, and changes in completion. Quest circles should stay at the current zone button size while glyphs keep their proportions. Confirm native clicks and quest item use, fold/expand zones, disable/re-enable grouping and the module, and switch views during combat with a protected quest marker. Opening the map or quest log after untracking a quest must not inherit the tracker's smaller marker artwork.

Before release, check changed features in game after `/reload`: combat transitions, settings and saved preferences, native nameplate styles, secure quest items, and party targeting. For threat colors, check tanks holding and losing aggro, damage/healer roles, tank forms/stances, tapped or dead enemies, and the feature switch. Mocks cannot validate taint, rendered artwork, or cursor behavior.

For party range fading, cross the friendly spell's range boundary, clear the spell, and change party-frame styles. Verify portraits and buffs fade together while health, mana, and debuffs stay unchanged, including in combat.

For party layout, adjust spacing to zero and a larger value, toggle upward growth, and add/remove members. Compare no buffs, one buff, eight buffs, and sixteen buffs, including mixed standard and enlarged icons. Sparse lists should use less space; both rows must still fit. Enter combat with one buff, then gain sixteen: the full native list should fit without moving the protected party frames. Confirm the bottom edge stays fixed when growing upward and when buff rows grow or shrink, including at different UI and party scales. Pets retain clearance with buffs disabled. Move the party in Edit Mode, switch frame styles, disable the module, and reload. Spacing and growth changes made in combat should apply afterward; profiles should restore both preferences.

For role pinning, check Top, Bottom, and Off with portrait and raid-style party frames. In raid style, include the player, switch between vertical and horizontal groups, show pets, and verify targeting after role and roster changes. Horizontal groups pin at the leading or trailing edge. Change roles or pinning during combat and confirm sorting updates afterward. Turning pinning off, disabling the module, or selecting portraits should restore native compact positions. Pinning must leave native sorting and unit bindings untouched. After updating from 1.0.34.17, reload to clear any existing taint and check that native health and heal-prediction updates remain error-free.

For portrait buffs, enter combat with a full row and add/remove buffs. `/vv party status` should report `source: native container` and `native combat renderer: ready`; addon aura reads must not be needed. Check native counts, cooldowns, tooltips, click-through targeting, roster-slot reuse, disabling buffs, and restoring normal sorting after combat. The native API simulator blocks every addon aura reader during combat; it cannot replace testing the actual native container and its capability on the client.

For party buff priority, show more than eight buffs, eat and drink, and verify recovery effects appear before player buffs with correct tooltips in both rows. For profiles, save a name, change settings, load the saved snapshot, and log into a second character. Check that designs transfer, local changes do not overwrite snapshots, quest folds remain personal, and loading is disabled during combat.

For role stability, leave one party member outside an instance while the tank zones in and out. Change the tank's form or stance outside combat, then repeat in combat and leave combat. In portrait and raid-style frames, verify that pinning follows the assigned role icon, survives temporarily unavailable roles, and still updates when a member is reassigned to damage. Replace a party member and confirm the replacement does not inherit the departed member's role.

## Review regression checklist

After `/reload` on WoW Forever 1.60.x / Interface 16001:

- **Quest icons and range fading:** choose a damage spell, cross its range boundary, and move quest enemies offscreen and back. Check that loot/kill icons and opacity follow each enemy without lingering on a different unit. Complete or abandon a quest, toggle quest icons off/on, and repeat during combat.
- **Combat focus:** pull several enemies and swap targets. In Tank mode, check held enemies, shaky threat, and aggro loss. In both modes, watch casts and channels start, stop, and get interrupted. Adjust both sliders during combat, cross the range boundary, and turn the feature off. Check nameplate clicking, pooled frame restoration, and the game's target enlargement.
- **Quest tracker folds:** collapse and expand adjacent zones in combat with a tracked quest item and a progress bar. Check that both follow their rows, the quest item still works when expanded, and quest progress updates preserve the folds.
- **Quest tracker scrolling:** track enough quests in several zones to exceed the tracker height. Scroll to the last quest by wheel and scrollbar; check quest clicks, context menus, quest item use, objective updates, and row clipping at both edges. Repeat with grouping off, collapsed zones, and other objectives above and below quests. Shrink the list while scrolled to the bottom. Move, resize, and change opacity/text size in Edit Mode, then exit and reload; confirm the tracker retains its saved position and real height. At different UI scales and screen edges, confirm the scrollbar stays onscreen and disappears when the list fits. Enter and leave combat with a quest item, check protected-layout deferral, and switch scrolling and the module off/on. Mocks cannot prove live clipping, script security, quest item use, or Edit Mode rendering.
- **Party colors:** test portrait and raid-style frames, native color changes from disconnects or frame reuse, and class-color toggles. Turn colors off during combat and verify the current native appearance returns after combat ends.
- **Party auras:** apply/remove buffs and dispellable debuffs repeatedly, reorder or replace party members, and hide/show party frames. Check doubled dispellable icons, spacing, normal sizing after reuse, buff hover tooltips, targeting, and click-casting. Toggle buffs off/on in and out of combat.
- **Swing timers:** check idle bars in Always mode, then main-hand, off-hand, and ranged swings in stacked and row layouts. Change colors, gradients, sparks, and sizes while idle; clear/reselect the target and reopen both preview pages. Timers should restart cleanly and redraw immediately.
- **Profiles:** save a design, change it, reload the profile, and apply a preset. Verify settings/status, range spell fields, personal quest folds, and transfer to another character. Loading remains unavailable during combat.

## Publish a release

GitHub Actions tests and builds pushes to `main`, pull requests, and version tags. Only a pushed version tag publishes to [CurseForge](https://www.curseforge.com/wow/addons/vanilla-varnish). Manual workflow runs validate and package without publishing.

Maintainer setup: store a CurseForge author API token as the repository Actions secret `CF_API_TOKEN`. The project ID is declared in `VanillaVarnish.toc`; publishing is restricted to Forever `1.60.1` and fails if CurseForge has no exact matching game-version entry. Keep CurseForge's native automatic packager disabled to avoid duplicate uploads. Credentials belong in GitHub secrets, never source files or documentation.

1. Update the TOC version and add concise release notes to `CHANGELOG.md`.
2. Run the checks and build with `python tools/build_release.py`.
3. Commit the source, docs, and generated `dist/VanillaVarnish-<version>.zip`, then push.
4. Create and push the matching tag, for example `git tag v1.0.20` and `git push origin v1.0.20`.
5. Check the Actions run and the CurseForge file status. New projects and uploads may need moderation before becoming visible in the app.

The workflow verifies that the tag matches the TOC and that the committed ZIP matches the freshly built package. Alpha or beta suffixes in the version select the corresponding CurseForge release type; ordinary versions publish as Release.

Release archives contain runtime code, assets, the user guide, release notes, and licenses. Tests, automation, branding, local maintainer instructions, caches, and Git metadata stay out of installed packages. Retain existing archives for users who need an earlier release.

Write commit messages and documentation for the public reader: describe the behavior and its purpose, keep the useful details, and leave the debugging diary behind. A little varnish goes a long way.

## Quest-drop data

Before collecting or importing external data, verify the applicable license, website terms, automation policy and upstream provenance. Record the permission and required attribution before downloading or redistributing it. Public access and citations do not authorize scraping. If collection or reuse is prohibited or unclear, use a permitted source or obtain explicit permission from the rights holder first. Review database rights separately from the license of its hosting or generation tools.

`Modules/Nameplates/QuestDropData.lua` is a generated, ID-only projection of pfQuest Vanilla's quest-item and NPC-loot relationships. The pinned revision and input SHA-256 hashes are in `tools/data/pfquest-source.json`. Releases include the [pfQuest MIT notice](Licenses/pfQuest-MIT.txt), [upstream VMaNGOS GPL v2 notice](Licenses/VMaNGOS-GPL-2.0.txt) and [database provenance notice](Licenses/QuestDropData-NOTICES.txt). Native objectives supply counts, completion and localized names. No quest text, NPC names, map coordinates, drop rates, vendors, objects or collected player data are bundled.

The [licensing review](tools/data/pfquest-licensing.json) traces pfQuest's February 2025 input update to VMaNGOS commit `f07f7eefc4c33784d34a3d3d391b65795ca547c3`. That revision publishes GPL v2 terms; its database workflow imports `world_full_14_june_2021.7z` from `brotalnia/database` before applying migrations. No top-level license was found in the base-dump repository, and notices inside the archive have not been verified. The maintainer has chosen to retain the baseline with the known MIT/GPL notices. This does not establish complete upstream clearance or authorize new imports with unverified permissions. An extractor's MIT license does not automatically relicense its inputs, and adding a GPL notice cannot resolve a missing input grant.

Download `db/quests.lua`, `db/items.lua` and `db/refloot.lua` from the manifest's exact pfQuest revision into a local cache, preserving the `db/` paths. Then generate or verify:

```sh
python tools/build_quest_drops.py --source-directory .test-deps/pfquest-source --lua-runtime .test-deps/lua-runtime
python tools/build_quest_drops.py --source-directory .test-deps/pfquest-source --lua-runtime .test-deps/lua-runtime --check
```

Generation verifies all input hashes and runs the data tables in an empty Lua 5.1 environment. The generator includes every item objective of retained quests, even vendor-only or object-only items, so mixed quests cannot become ambiguous single-item matches. NPC lists are shared by item; reference loot is expanded and vendor relationships excluded. Lupa and upstream source caches are development dependencies, not release files.

No website-derived Forever overrides remain. Generation uses only the pinned pfQuest inputs; the prior override file and the 1.0.32 archive containing those overrides have been removed from the current tree. The Vanilla requirements are not validated Forever corrections. Never infer a new drop source from proximity, a similar NPC name, an item class, or a missing tooltip line.

An optional QuestieDB provider supplies quests absent from the bundle, and Questie's tooltip fallback is separately enabled. Native tooltip detection remains active for every quest. To check a reported discrepancy, compare the native quest objectives, the mob's native tooltip, the expected bundled IDs and a permitted source or independently observed loot. This release does not collect or upload gameplay diagnostics.
