# Regression tests

Run the Lua 5.1 suite with `python tests/run.py --lua-runtime <directory-containing-lupa>`.

The mocks cover nameplates, threat colors, swing timers, collapsing row geometry across UI scales, combo points, previews, quest grouping, party range fading, buff wrapping/recovery priority, and native alpha restoration, tooltips, restricted API data, account profiles, built-in preset isolation, saved preferences, and module switches. Optional cached native sources exercise Blizzard's nameplate and tooltip mixins.

Review regressions also cover late nameplate removal after frame reuse, forbidden frames, restricted nested quest records, idle swing rendering, party refresh coalescing, current native color restoration, recycled debuff widgets, and malformed profile sections.

Polite UI checks cover Never defaults, AND lists, fade-in precedence, half-second alpha transitions, latched fades, hover and descendant mouse focus, propagated Escape, event grace periods, combat toggles, native alpha changes, Edit Mode, restricted resources/casting, non-mana units, auras, late frames, nested chat chrome, typing and messages, group and quest conditions, profile upgrades, and exclusion of manually opened windows.

Hardening checks use strict native health argument signatures, hidden Settings ancestors, live multi-condition changes, resource history across configuration and return states, resource boundaries, temporary opacity failures, recovery after animation completion, and diagnostic tooltips. The matrix exhausts 51,224 supported single/pair/triple selections with true/false/unavailable outcomes at each position. It also runs 4,096 resource/combat/target configurations for every subset of the reported four-condition fade-out and combat/target return lists, then exercises all 25 frame adapters through hover, toggles, replacement, and fallback discovery in one session without reloading. These mocks do not replace the in-game checks for rendering, actual API restrictions, cursor delivery, and combat taint.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, native-source options, and the in-game checks that mocks cannot replace.

For native aura-preview coverage, include `auras.lua` and `classification.lua` from Blizzard_NamePlates in the optional source cache. Add `optionspreview.lua` from Blizzard_SettingsDefinitions_Frame/Nameplates.lua to exercise the native preview sample handoff. The suite tests each aura display combination, native icon limits and scaling, changes while pages are hidden, and isolation from Blizzard's registered preview.

Native alignment checks resolve screen coordinates from Blizzard's health-bar anchors and compare live and preview timer edges, widths, and combo-point offsets across target, UI, and canvas scales in stacked and row layouts.
