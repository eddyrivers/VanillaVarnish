# VanillaVarnish

Modular improvements to Blizzard's native UI for **WoW Forever 1.60.x / Interface 16001**. Combines the existing NameplateTweaks, QuestTrackerOrganizer, and PartyTweaks addons. Other WoW client families have not been validated.

Open **Settings > AddOns > VanillaVarnish**, or type **`/vv`**. The main page enables or disables whole modules. Sub-pages retain the individual feature controls. All settings save per character in `VanillaVarnishDB`.

## Modules

### Nameplates

- Range fading with separate damage and friendly spells, and configurable out-of-range opacity. Unknown or restricted range results retain native opacity.
- White loot, kill, and other quest-objective icons. Native quest/tooltip data remain the primary source. Optional QuestieDB item-drop relationships and Questie tooltip fallback retain their existing behavior, including ordinary quest ingredients and bag-count completion checks.
- Main-hand, off-hand, and ranged player swing timers beneath the hard target's nameplate, or the action target when no hard target exists. Preserves the existing rounded pixel geometry, pulse, spark, gradients, border, per-bar labels/fonts/colors/alignment, weapon handling, visibility modes, and native-template menu preview.

The Nameplates page has separate **Range check**, **Quest icons**, and **Swing timers** switches. Their detailed pages sit under the same VanillaVarnish menu. Turning the entire module off restores opacity and hides its quest icons and world swing bars without changing spell choices, feature switches, or bar settings. The settings preview remains available for configuration.

Swing-bar spacing measures the gap between bar borders: **0 makes the bars touch**. Sparks and oversized labels can extend into the gap. Hidden bars collapse without gaps; swing progress does not change spacing. Timers keep the user's UI scale through native target/combat nameplate scale animations. Nonnegative vertical offsets are minimum distances: the stack moves farther down when necessary to clear the native cast container and its artwork, with the same behavior in the menu preview. Placement stays stable during combat for the same anchor and settings instead of alternating with restricted geometry. The saved offset stays unchanged. Negative offsets retain manual placement and can overlap the nameplate or cast bar.

### Quest tracker

Organizes Blizzard's rendered quest blocks by quest-log zone/category, alphabetically, then level ascending. Equal levels sort by title and quest ID; unknown levels appear last. Preserves native quest controls, quest items, progress/timer frames, completion behavior, and other tracker modules.

- Enable or disable zone grouping independently of the module switch.
- Optional completed-first ordering, off by default.
- Click zone headings or circular + / - icons to fold or expand zones without untracking quests.
- Zone groups retain the same gap after their last visible row whether expanded or collapsed.
- Right-click a heading to track or untrack all quests in that log category.
- Expand/collapse all zones and restore tracker defaults from the settings page.
- Move and resize using Blizzard's Edit Mode.

Turning the module off restores native ordering, fonts, and visibility and preserves grouping, ordering, and collapsed-zone preferences. Protected layout changes wait until combat ends. Native ordering may briefly appear during combat updates, as in the original addon. Zone tracking menu actions remain unavailable during combat.

### Party frames

Decorates Blizzard's native party frames, preserving their artwork, health-bar height, targeting, click-casting, right-click menus, and pets.

- **Show party buffs:** only when **Use raid-style party frames is off**. Up to eight helpful auras appear seven pixels beneath mana with stack counts, cooldown swipes, and hover tooltips. Your buffs come first (including those beyond the first eight in native order) and use 19px squares; others use 14px squares. Adds vertical spacing for the row. The same toggle doubles native debuffs you can dispel and colors their borders: curse purple, poison green, magic blue, disease brown. Dispel capability comes from the client's harmful RAID aura filter.
- **Class-colored health bars:** native health bars tinted by class in both portrait-style and raid-style party frames.

Each feature has its own toggle. Turning buffs off hides the row and restores spacing and native debuff geometry. Turning class colors off restores the native color/texture state. Protected restoration waits until combat ends. Turning the whole module off preserves both choices. Raid-style party frames retain their native aura display and dimensions. Unit-frame replacements can hide the native frames; configure those addons separately.

## Installation and migration

1. Install the `VanillaVarnish` folder in `Interface/AddOns`. Fully restart WoW to discover the new addon.
2. To import existing settings, enable VanillaVarnish **alongside the originals for one login/reload**. Their saved variables must be loaded by WoW for the import to be available. For a fresh installation, keep the originals disabled.
3. Disable **NameplateTweaks**, **QuestTrackerOrganizer**, **PartyTweaks**, and any standalone **NameplateSwingTimers**, then `/reload`.
4. Configure modules through `/vv`.

Loaded legacy settings are copied into separate tables once, without changing the original saved variables or overwriting subsequent VanillaVarnish preferences. Existing swing appearance migrations remain intact. PartyTweaks had no saved options; both party features initially default on.

While an original addon is loaded, the corresponding VanillaVarnish module stays inactive to avoid duplicate hooks, bars, or layouts. A standalone NameplateSwingTimers only blocks the bundled swing timers. The settings menu and `/vv status` explain these conflicts. The original addon directories are not changed.

If VanillaVarnish has already initialized its defaults before the old settings are loaded, later enabling the originals will not replace the new preferences. Import with both enabled on the initial load, or configure the new addon manually.

## Commands

| Command | Action |
| --- | --- |
| `/vv` or `/vanillavarnish` | Open the shared settings menu |
| `/vv nameplates`, `/vv tracker`, `/vv party` | Open a module page |
| `/vv nameplates on`, `/vv tracker off`, `/vv party toggle` | Control a whole module, preserving its feature choices |
| `/vv status` | Show module state and legacy conflicts |
| `/nt` | Open Nameplates settings; existing nameplate commands remain supported |
| `/nt range on`, `/nt quests off`, `/nt swings on` | Individual nameplate feature switches |
| `/nt range damage Moonfire`, `/nt range friendly Healing Touch` | Set range spells; names, IDs, and links work |
| `/nt range opacity 35`, `/nt questie on` | Range opacity and optional Questie fallback |
| `/nt main on`, `/nt offhand off`, `/nt ranged toggle` | Individual weapon bars |
| `/nt swings`, `/nt help`, `/nt status`, `/nt debug` | Swing settings, full command help, and diagnostics |
| `/qto` or `/qlo` | Open Quest tracker settings |
| `/qto on`, `/qto off`, `/qto expand`, `/qto collapse`, `/qto status` | Original quest tracker commands |
| `/pt` or `/partytweaks` | Original party frame diagnostics |
| `/pt options`, `/pt buffs off`, `/pt colors on` | Party settings and individual feature switches |

Module-prefixed feature commands also work, such as `/vv nameplates swings off`, `/vv tracker collapse`, and `/vv party buffs off`. Legacy slash aliases are registered only when their original addon is not loaded. Bare `/vv tracker on` controls the entire module; `/qto on` controls its saved grouping choice. Settings requests during combat open the latest requested page after combat ends.

All original swing commands remain available through `/nt`: `show`, `width`, `height`, `x`, `y`, `gap`, `borderradius`, `bordercolor`, `borderalpha`, `gradientleft`, `gradientright`, `color`, `effect`, `effectalpha`, `spark`, `sparksize`, `sparkalpha`, `label`, `labelfont`, `labelsize`, `labelcolor`, `labelalign`, `preview`, `colors`, and `reset`. `/nt reset` restores only swing settings; the tracker reset restores only tracker settings. Neither changes module switches.

## Validation and release

The source repository is [eddyrivers/VanillaVarnish](https://github.com/eddyrivers/VanillaVarnish). Source, assets, tests, tools, and existing release archives in `dist/` are versioned together. Completed major changes are validated, committed, and pushed directly to `main`; see `AGENTS.md` for the project workflow.

Run `python tests/run.py --lua-runtime <directory-containing-lupa>` with Python and Lupa's Lua 5.1 runtime. Optional `--blizzard-source <cached-native-nameplate-sources>` adds checks against real Blizzard nameplate mixins. Dependencies are external and are not shipped in the release archive.

Tests cover existing range/quest/swing behavior, settings controls, pixel geometry, previews, tracker sorting/folding/pooling/restoration, party auras, restricted display values, module toggles, combat deferral, namespace isolation, migration, and legacy conflicts. Mocks do not reproduce the client's taint engine.

Before submission, check in the actual supported client: all settings pages, toggles in/out of combat, grouped/collapsed quests with secure quest items, Edit Mode, party targeting/click-casting/tooltips/pets, pooled frames, hard/soft targets, and Questie present/absent. Confirm saved choices survive a full restart and perform a migration from real legacy SavedVariables. Choose the project's source-code license and the appropriate CurseForge game-version/flavor tags before publishing; this package does not claim Retail/TBC/Wrath compatibility.

`/pt status` reports whether the party module and buffs are enabled, combat state, each initialized unit's aura source and display result, and any refused API call. Frames first discovered during combat wait until combat ends for their protected layout to be initialized.

`python tools/build_release.py` creates `dist/VanillaVarnish-1.0.6.zip` with a single `VanillaVarnish` root folder, runtime sources, assets, README, changelog, and the font license. Tests, tools, cached sources, and Python binaries are excluded.

Montserrat is bundled under the SIL Open Font License; see `Media/Montserrat-OFL.txt`. [Upstream font](https://github.com/JulietaUla/Montserrat).
