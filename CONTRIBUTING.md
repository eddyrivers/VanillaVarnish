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

Before release, check changed features in game after `/reload`: combat transitions, settings and saved preferences, native nameplate styles, secure quest items, and party targeting. For threat colors, check tanks holding and losing aggro, damage/healer roles, tank forms/stances, tapped or dead enemies, and the feature switch. Mocks cannot validate taint, rendered artwork, or cursor behavior.

For party range fading, cross the friendly spell's range boundary, clear the spell, and change party-frame styles. Verify portraits and buffs fade together while health, mana, and debuffs stay unchanged, including in combat.

For party buff priority, show more than eight buffs, eat and drink, and verify recovery effects appear before player buffs with correct tooltips in both rows. For profiles, save a name, change settings, load the saved snapshot, and log into a second character. Check that designs transfer, local changes do not overwrite snapshots, quest folds remain personal, and loading is disabled during combat.

For **Polite UI**, open `/vv polite` and confirm the grouped rows, two multiselects, Never defaults, and disabled preset placeholder. Fade the player frame with full health AND out-of-combat, then return it in combat; test overlap, empty lists, mana and non-mana classes, and 75% recovery thresholds. Hover transparent unit buttons, aura icons outside their container, chat tabs, and action buttons; check targeting, tooltips, and keybindings. Press Escape with its return condition selected, including while casting and in combat; the native Escape action must still work. Verify the three-second event grace, casting/channeling, party/raid styles, tracked quest updates, and chat typing/messages. Open the character sheet, quest log, bank, and auction house and confirm they remain unaffected. Enter Edit Mode, toggle the module, clear rules, and load old/new profiles. Check half-second transitions, native cast-bar fades, hidden bars, chat windows created later, and any Lua or taint errors. Unavailable protected operations should leave the native UI usable; never replace secure scripts or force hidden interaction windows to show.

## Review regression checklist

After `/reload` on WoW Forever 1.60.x / Interface 16001:

- **Quest icons and range fading:** choose a damage spell, cross its range boundary, and move quest enemies offscreen and back. Check that loot/kill icons and opacity follow each enemy without lingering on a different unit. Complete or abandon a quest, toggle quest icons off/on, and repeat during combat.
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
