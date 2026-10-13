# Regression tests

Run the Lua 5.1 suite with `python tests/run.py --lua-runtime <directory-containing-lupa>`.

The mocks cover nameplates, threat colors, swing timers, collapsing row geometry across UI scales, combo points, previews, quest grouping, party range fading, buff wrapping/recovery priority, and native alpha restoration, tooltips, restricted API data, account profiles, built-in preset isolation, saved preferences, and module switches. Optional cached native sources exercise Blizzard's nameplate and tooltip mixins.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, native-source options, and the in-game checks that mocks cannot replace.

For native aura-preview coverage, include `auras.lua` and `classification.lua` from Blizzard_NamePlates in the optional source cache. Add `optionspreview.lua` from Blizzard_SettingsDefinitions_Frame/Nameplates.lua to exercise the native preview sample handoff. The suite tests each aura display combination, native icon limits and scaling, changes while pages are hidden, and isolation from Blizzard's registered preview.
