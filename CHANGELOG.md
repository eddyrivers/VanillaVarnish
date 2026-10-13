# Changelog

## 1.0.28

- Remove the in-game test-preview checkbox from settings and close the gap in the swing timer controls. Embedded menu previews remain available.

## 1.0.27

- Add Combo point class (compact): 10-unit combo dots at X 67 / Y 25 with gap 4, and a 161-by-10 swing-timer row at X 1 / Y 21 with gap 2, shown while swinging.

## 1.0.26

- Set Swing timer row's combo-point vertical offset to 23 and swing-timer vertical offset to 37.

## 1.0.25

- Move Default's combo points to vertical offset 24. Keep the tighter presets at 14 and use 24 when restoring combo-point defaults.

## 1.0.24

- Match preview nameplate scale to the live target so swing timers and combo points keep their in-game size and horizontal alignment. Use configured target enlargement when no readable target is visible; preserve native aura and display options.
- Add a GitHub bug-report template and keep blank reports available.

## 1.0.23

- Make swing timer and combo-point previews follow the game's Nameplates options, including native buffs, debuffs, crowd control, aura scale and spacing, health text, and cast display choices.
- Carry over the last sample type and icons displayed in the game's Nameplates menu. Keep independent preview frames so switching pages never replaces Blizzard's preview or binds live units.
- Use the game options preview scale, expand the preview area, and refresh display changes when reopening either feature page.

## 1.0.22

- Give Profiles & Presets its own settings page, with a link from the main menu and `/vv profiles` or `/vv presets` shortcuts.
- Add Default, Default (tight), and Swing timer row presets. New characters start with the new Default design; existing settings and saved profiles stay yours.
- Add Stacked and Row layouts to swing timer settings. Row shares the full width between three timers and packs visible timers to the left, with matching live previews.

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
