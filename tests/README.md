# Regression tests

Run the Lua 5.1 suite with `python tests/run.py --lua-runtime <directory-containing-lupa>`.

The mocks cover nameplates, threat colors, swing timers, collapsing row geometry across UI scales, combo points, previews, quest grouping, party range fading, buff wrapping/recovery priority, and native alpha restoration, tooltips, restricted API data, account profiles, built-in preset isolation, saved preferences, and module switches. Optional cached native sources exercise Blizzard's nameplate and tooltip mixins.

Review regressions also cover late nameplate removal after frame reuse, forbidden frames, restricted nested quest records, idle swing rendering, party refresh coalescing, current native color restoration, recycled debuff widgets, and malformed profile sections. Native quest tooltip checks cover full player names and surnames, party ownership, completed objectives, and restricted or unavailable names without a bundled drop relationship.

Tracker checks include native slide-anchor updates without quest events, preserving grouped positions before the next frame, folded quest visibility, combat deferral, and native animation placement when grouping is disabled.

Quest-change checks begin with an empty native watch list, deliver addon events, and then simulate Blizzard's own rebuild after an item quest appears. The fixture rejects addon calls to the native dirty runner and checks that grouping, folds, and Compact view still work on the item row. Live quest-item clicks and aura security still require an in-game check.

Tracker button checks include native artwork larger than its clickable frame, normal/pressed/hover circles, proportional ellipsis and question marks, larger completion/selection atlases, centered compact headings, repeated native style updates, module restoration, pooled buttons used by another owner, and protected-marker combat deferral. The native click handlers and hit frames remain unchanged. Confirm the visible circle edges and hover/selection effects in game; texture dimensions do not emulate atlas transparency.

Compact view checks cover the 1.5-point text reduction, gentle zone button sizes and spacing, native order without grouping, repeated updates, module restoration, and protected combat deferral. Quest log checks simulate native title/objective/header pools, measure smaller fonts before native row sizing, restore pooled fonts, exercise the dedicated Quest log page and independent page resets, and defer combat changes. Header geometry checks cover extra native reserved padding, header moves at the end of native layout, and switching compact view off again; quests stay six units below the visible All Objectives header.

Native party-buff checks block all addon aura readers during combat and exercise the native container contract, a single combat list with sixteen standard-sized icons and no unverified glows, current buff updates/removals, hidden roster slots, unit reuse, tooltips/count/cooldown bindings, toggles, setup failure, and normal display restoration. These checks do not emulate the client's secure execution compartments or prove in-game rendering. Party layout checks cover adaptive buff-row heights, all sixteen combat buffs gained from a sparse starting row, mixed icon sizes, scaled frames, fixed upward anchors, portrait role pinning at either physical edge with both growth directions, and combat deferral. Raid-style layout checks reject addon calls to native sorting and member setup, preserve native member tables and unit bindings, and cover the player, pets, borders, horizontal groups, anchor cycles, role changes, restricted roles, native combat refreshes, roster reuse, and native position restoration. Group quest checks cover quests absent from the local log, separate member completion, roster departures, raid members, and restricted names.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, native-source options, and the in-game checks that mocks cannot replace.

The party layout fixture also models Edit Mode's anchor wrappers and shared snap/dirty state. Upward growth, native-anchor restoration, module toggles, and post-save refreshes must change physical anchors without writing that shared state. Native movement keeps the wrappers in place. This catches the former addon calls into Edit Mode bookkeeping; it does not emulate or prove the client's taint behavior.

Role pinning checks also cover disagreement between native enum and string roles, temporary missing or restricted roles while zoning, identity-based role retention, roster slot swaps and replacements, and real role changes after combat in portrait and raid-style layouts.

For native aura-preview coverage, include `auras.lua` and `classification.lua` from Blizzard_NamePlates in the optional source cache. Add `optionspreview.lua` from Blizzard_SettingsDefinitions_Frame/Nameplates.lua to exercise the native preview sample handoff. The suite tests each aura display combination, native icon limits and scaling, changes while pages are hidden, and isolation from Blizzard's registered preview.

Native alignment checks resolve screen coordinates from Blizzard's health-bar anchors and compare live and preview timer edges, widths, and combo-point offsets across target, UI, and canvas scales in stacked and row layouts.
