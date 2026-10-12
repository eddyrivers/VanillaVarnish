# Regression tests

Run the Lua 5.1 suite with `python tests/run.py --lua-runtime <directory-containing-lupa>`.

The mocks cover nameplates, threat colors, swing timers, combo points, previews, quest grouping, party range fading, buff wrapping/recovery priority, and native alpha restoration, tooltips, restricted API data, account profiles, saved preferences, and module switches. Optional cached native sources exercise Blizzard's nameplate and tooltip mixins.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, native-source options, and the in-game checks that mocks cannot replace.
