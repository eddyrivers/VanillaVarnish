# Changelog

## 1.0.21

- Fix completed quest sorting so ready-for-turn-in quests stay together at the top or bottom of each zone. Delivery and talk-to quests with remaining instructions no longer split that group, even when the game gives them a question-mark icon.
- Keep lower-level quests first within each group, and clarify the completion rule in the quest tracker options.

## 1.0.20

- Add account-wide named profiles to the main VanillaVarnish menu. Save a design, select and load it on another character, or update its saved snapshot. Module switches and settings are included; quest folds stay personal.
- Expand portrait-style party buffs to 16 icons in two rows of eight. Keep the row width compact and reserve enough space for both rows during combat.
- Prioritize active eating and drinking effects, then your buffs, then other buffs in native order. Preserve larger player buffs, cooldowns, and correct tooltips after reordering.

## 1.0.19

- Fade party portraits and buffs when members are outside the configured friendly spell's range. Uses the shared range opacity; no spell or unavailable range leaves them unchanged. Portrait-style frames only, with an independent party toggle.

## 1.0.18

- Bring every command under `/vv`, with matching help and examples.
- Add role-aware blue threat colors for fighting enemy nameplates, with a feature toggle and restoration of native colors.
- Publish version tags to CurseForge after Lua 5.1 tests and package validation pass.
- Streamline the public guide, add contributor instructions and the MIT license, and keep maintainer tooling out of release packages.

## 1.0.17

- Improve hostile tooltip level colors using native creature difficulty and recognize formatted level lines.

## Earlier releases

Introduced modular nameplates, swing timers, combo points, quest grouping and completion sorting, party buffs and class colors, and cursor-following tooltips. Older release archives remain in `dist`; detailed development history is available in Git.
