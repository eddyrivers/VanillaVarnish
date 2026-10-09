# Changelog

## 1.0.5

- Removed native party `UpdateMember` calls from class-color restoration. Cosmetic toggles now restore saved display properties without rebuilding unit bindings or health-update state.
- Restore saved desaturation without comparing a possibly secret boolean.
- Keep the gap between quest-zone groups constant when either zone expands or collapses; removed the conditional extra 8px gap.
- Added checks for repeated color toggles, secret display restoration, unchanged native health values/scripts, and all neighboring zone fold combinations. Client taint behavior still requires in-game verification after reloading.

## 1.0.4

- Attempt permitted display reads from restricted party aura lists; fall back to indexed aura reads if list indexing is refused.
- Keep valid buff textures visible when optional aura metadata cannot be read, and sanitize native frame visibility before branching.
- Expanded `/pt status` with module/feature/combat state, per-unit aura source and display result, and pending combat initialization.
- Added regressions for restricted lists, refused optional fields, restricted visibility, fallback reads, removal, and diagnostic output. In-game confirmation remains required.

## 1.0.3

- Fixed swing layout testing a secret native cast-artwork visibility boolean in combat. Restricted visibility now reserves clearance using readable dimensions, while readable hidden artwork is excluded.
- Added regression coverage for restricted true/false visibility, unavailable visibility getters, and live swing refreshes.

## 1.0.2

- Prevent swing-bar sparks and label outlines from overlapping adjacent swing bars by reserving their visible bounds during layout.
- Keep spacing stable as swing progress changes and collapse hidden bars without gaps.
- Automatically clear native cast containers, below-bar text/icons, and cast artwork for nonnegative vertical offsets, in game and in the settings preview. Saved offsets remain unchanged; negative offsets retain manual placement.
- Added artwork-bound checks across bar heights, spark/label sizes, gaps, visible-bar combinations, resolutions, and UI scales, plus native-style cast-clearance checks.

## 1.0.1

- Fixed party buff rendering rejecting combat-secret AuraData records before their permitted display fields reached widgets.
- Refresh known party units when UNIT_AURA supplies a restricted event token.
- Keep valid buff icons visible if a cosmetic stack-count or cooldown setter is refused.
- Added regressions covering combat-secret aura records, events, removal, and cosmetic API failures.

## 1.0.0

- Consolidated NameplateTweaks 2.0.0, QuestTrackerOrganizer 1.2.0, and PartyTweaks 1.0.1 into VanillaVarnish.
- Added one AddOns settings parent with independent Nameplates, Quest tracker, and Party frames master switches.
- Preserved existing nameplate features, swing appearance controls/previews, tracker grouping/folding, and party artwork/aura behavior.
- Added individual party buff and class-color switches with restoration of native spacing and colors.
- Added per-character VanillaVarnish settings, one-time copying of loaded legacy preferences, and safeguards against running duplicate legacy modules.
- Retained legacy feature slash commands and added `/vv` module commands.
- Centralized combat-deferred settings opening, added combined-module regression checks, and provided a clean release packager.
