# Regression tests

Run the Lua 5.1 suite with `python tests/run.py --lua-runtime <directory-containing-lupa>`.

The mocks cover nameplates, threat colors, swing timers, combo points, player cast-bar binding and placement, previews, quest grouping, party range fading and native alpha restoration, tooltips, restricted API data, saved preferences, and module switches. Optional cached native sources exercise Blizzard's nameplate, casting, and tooltip mixins, including player casts/channels and every nameplate style/size.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for setup, native-source options, and the in-game checks that mocks cannot replace.
