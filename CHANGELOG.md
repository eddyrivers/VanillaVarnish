# Changelog

## 1.0.19

- Fade party portraits and buffs when members are outside the configured friendly spell's range. Uses the shared range opacity; no spell or unavailable range leaves them unchanged. Portrait-style frames only, with an independent party toggle.
- Add an optional player cast bar attached to the target's nameplate. Reuses Blizzard's cast-bar template for casts, channels, interrupts, and nameplate style/size changes; the target's own cast bar stays intact.
- Give the player cast bar a live preview, horizontal and vertical offsets, and adjustable width. Height follows the selected nameplate style. Disabled by default; enable it with `/vv nameplates cast on`.

## 1.0.18

- Bring every command under `/vv`, with matching help and examples.
- Add role-aware blue threat colors for fighting enemy nameplates, with a feature toggle and restoration of native colors.
- Publish version tags to CurseForge after Lua 5.1 tests and package validation pass.
- Streamline the public guide, add contributor instructions and the MIT license, and keep maintainer tooling out of release packages.

## 1.0.17

- Improve hostile tooltip level colors using native creature difficulty and recognize formatted level lines.

## Earlier releases

Introduced modular nameplates, swing timers, combo points, quest grouping and completion sorting, party buffs and class colors, and cursor-following tooltips. Older release archives remain in `dist`; detailed development history is available in Git.
