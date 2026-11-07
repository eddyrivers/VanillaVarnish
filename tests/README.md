# Regression tests

Run the Lua 5.1 suite with `python tests/run.py --lua-runtime <directory-containing-lupa>`.

The mocks cover nameplates, threat colors, swing timers, collapsing row geometry across UI scales, combo points, previews, quest grouping, party range fading, buff wrapping/recovery priority, and native alpha restoration, tooltips, restricted API data, account profiles, built-in preset isolation, saved preferences, and module switches. Optional cached native sources exercise Blizzard's nameplate and tooltip mixins.

Review regressions also cover late nameplate removal after frame reuse, forbidden frames, restricted nested quest records, idle swing rendering, party refresh coalescing, current native color restoration, recycled debuff widgets, and malformed profile sections. Native quest tooltip checks cover full player names and surnames, party ownership, completed objectives, and restricted or unavailable names without a bundled drop relationship.

Tracker checks include native slide-anchor updates without quest events, preserving grouped positions before the next frame, folded quest visibility, combat deferral, and native animation placement when grouping is disabled.

Native party-buff checks block all addon aura readers during combat and exercise the native container contract, a single combat list with sixteen standard-sized icons and no unverified glows, current buff updates/removals, hidden roster slots, unit reuse, tooltips/count/cooldown bindings, toggles, setup failure, and normal display restoration. These checks do not emulate the client's secure execution compartments or prove in-game rendering. Party layout checks cover portrait role pinning at either physical edge with both growth directions and combat deferral. Raid-style layout checks reject addon calls to native sorting and member setup, preserve native member tables and unit bindings, and cover the player, pets, borders, horizontal groups, anchor cycles, role changes, restricted roles, native combat refreshes, roster reuse, and native position restoration. Group quest checks cover quests absent from the local log, separate member completion, roster departures, raid members, and restricted names.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, native-source options, and the in-game checks that mocks cannot replace.

For native aura-preview coverage, include `auras.lua` and `classification.lua` from Blizzard_NamePlates in the optional source cache. Add `optionspreview.lua` from Blizzard_SettingsDefinitions_Frame/Nameplates.lua to exercise the native preview sample handoff. The suite tests each aura display combination, native icon limits and scaling, changes while pages are hidden, and isolation from Blizzard's registered preview.

Native alignment checks resolve screen coordinates from Blizzard's health-bar anchors and compare live and preview timer edges, widths, and combo-point offsets across target, UI, and canvas scales in stacked and row layouts.
