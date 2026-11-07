# Changelog

## 1.0.34.17

- Apply **Pin tanks, then healers** to raid-style party frames, including the player. Keep native member and pet layouts, preserve the game's order within each role, and defer sorting changes until combat ends. Turning pinning off restores native sorting.

## 1.0.34.16

- Keep enemy health bars gray when another group owns the tag, even if your group gains aggro or the Threat colors option is off.

## 1.0.34.15

- Pause Polite UI. Character settings and existing profiles retain their beta rules for later.
- Add optional **Combat focus** for enemy nameplates, with Tank and Damage / Healer modes and adjustable background size and opacity. Protected plates defer resizing until combat ends.
- Let quest tracker zones expand and collapse during combat while keeping quests tracked. Protected tracker layouts apply folds after combat.
- Keep upward-growing party frames at their saved Edit Mode position. Use standard-size buffs in combat and a thin gold border on your own buffs outside combat.

## 1.0.34.14

- Expand and collapse quest tracker zones during combat with the zone headings or `/vv tracker` commands. Folds stay in place as objectives update. If the tracker contains a protected frame, the fold applies when combat ends.

## 1.0.34.13

- Add optional **Combat focus** for enemy nameplates. Keep your target and active casts prominent in either mode. Tank mode also prioritizes shaky and lost threat.
- Shrink lower-priority combat plates to 75% size and fade them to 50% opacity by default. Adjust both values under **Nameplates > Combat focus**.

## 1.0.34.12

- Keep upward-growing party frames at their saved position when Edit Mode rounds the saved coordinates, including when the frame is scaled or the group size changes on reload.

## 1.0.34.11

- Pause portrait party layout updates while dragging the frame in Edit Mode. Apply pending changes after release so they cannot shift the frame under the cursor.

## 1.0.34.10

- Mark your buffs on portrait party frames with a solid one-pixel gold border.
- Preserve the bottom position saved in Edit Mode when upward-growing party frames reload with a different roster size. Let Edit Mode control the frame's position while you move it.

## 1.0.34.9

- Keep portrait party buff icons at their standard size in combat. The larger icons and gold borders for your buffs return after combat, when Forever exposes the caster.

## 1.0.34.8

- Draw portrait party buffs once in combat at the larger icon size. Use plain borders in combat because Forever restricts caster identity. Outside combat, use the caster's identity to highlight your buffs even when the caster unit token is missing.

## 1.0.34.7

- Hide Blizzard's portrait-hover buff popup while party buffs are enabled, keeping individual buff tooltips. Add a subtle gold glow to your buffs, including native combat buffs, within the existing two-row display.
- Add **Pin tanks, then healers** to portrait Party frames settings with **Off**, **Top**, and **Bottom** choices. Keep tanks above healers at either edge, preserve native targeting, and apply protected layout changes after combat.
- Add **Include your group's quest objectives** under **Nameplates > Quest icons**. Optionally show loot and kill needs from current party or raid members' native tooltip progress, even for quests you do not have. Save both new options in profiles.

## 1.0.34.6

- Use Blizzard's native aura container for portrait party buffs in combat, avoiding addon aura reads that Forever blocks while auras are secret. Prepare containers before combat, including hidden party slots, and keep native buff updates, counts, cooldowns, and tooltips active.
- Restore normal recovery priority and larger player buffs after combat. Combat icons use a uniform size and the client's sorting. Report native renderer readiness in `/vv party status` and skip restricted debuff reads while protected geometry cannot change.

## 1.0.34.5

- Read portrait-style party buffs through public aura instance IDs before using bulk or indexed lookups. Keep live buff icons, cooldowns, and tooltips available when combat restricts those older readers; remove expired buffs from the current instance list without changing protected frame layout.

## 1.0.34.4

- Keep party health bars in their class colors during native health and texture updates, removing the brief green flash in raid-style party frames. Apply the correction immediately in combat while preserving native health handling and color restoration when disabled.

## 1.0.34.3

- Tighten portrait-style party frames by measuring the buff area against the native bars and reducing the default gap between members to four UI units. Keep room for both buff rows and native pets.
- Add **Space between members** and **Grow upward from the bottom** to Party frames settings. Upward growth keeps the bottom edge fixed as members join or leave. Save both preferences in profiles and defer protected layout changes until combat ends.

## 1.0.34.2

- Recognize the player's full name, including their surname, in native quest tooltips. Restore missing loot and kill icons when the tooltip displays a full name while continuing to exclude other players' objectives.

## 1.0.34.1

- Keep quest titles in their grouped rows when native tracker animations reposition the first quest. Prevent quests from overlapping zone headings during updates unrelated to quest progress or folding zones.

## 1.0.34

- Added a small built-in quest database to help show loot icons without Questie.
- Loot icons follow your quest progress and the items in your bags, disappearing when you have enough. The addon still uses the game’s tooltips to find quest objectives.

## 1.0.32

This archive has been withdrawn; use 1.0.34 or later.

- Show quest loot icons from a compact bundled pfQuest baseline without requiring Questie or QuestieDB. Native objectives and tooltips still control progress and completion.
- Review Forever's Zul'Gurub enchant requirements and add My First Real Potion. Match each item objective separately, wait for localized item names when necessary, and exclude vendor and object sources from hostile loot markers.
- Include the pfQuest license and reproducible data-generation tools with pinned source checksums. New Forever drop sources still require verification.

## 1.0.31

- Tighten the gap between dagger and loot quest icons to six screen pixels, accounting for transparent artwork padding and nameplate scaling.

## 1.0.30

- Keep quest icons and range fading attached to the correct unit when nameplate frames are recycled. Skip forbidden frames and safely handle restricted quest and tooltip records.
- Stop scanning quest data when quest icons are disabled or no nameplates are active. Reuse unchanged swing-bar artwork while timers are idle.
- Restore the latest native party health colors when class colors are disabled, and clear debuff sizing and placement before aura frames are reused.
- Coalesce party refresh requests and ignore aura events for unrelated units while keeping party buff updates immediate.
- Reject malformed profile sections before loading, keep profile status usable with damaged records, and clear invalid saved range spells.

## 1.0.29

- Add a dedicated **Profiles & Presets** page, linked from the main menu and available through `/vv profiles` or `/vv presets`. Save your own designs and load account-wide profiles from one place.
- Add four built-in presets:
  - **Default:** the new starting design, with stacked swing timers at Y 37, combo points at Y 24, and completed quests sorted last.
  - **Default (tight):** bring stacked swing timers to Y 5 and combo points to Y 14.
  - **Swing timer row:** three timers share a 200-unit row, with swing timers at Y 37 and combo points at Y 23.
  - **Combo point class (compact):** 10-unit combo dots at X 67 / Y 25 with gap 4; a 161-by-10 swing-timer row at X 1 / Y 21 with gap 2, shown while swinging.
- Add **Stacked** and **Row** layouts to swing timer settings. Visible timers collapse upward or pack to the left in weapon order. Row width is the full three-timer span; individual timer widths stay steady when another timer disappears.
- Expand the shared swing-timer and combo-point previews to use native nameplate artwork and the game's Nameplates display options, including buffs, debuffs, crowd control, aura size and spacing, health text, and cast details. After viewing the game's preview, both addon pages retain its sample type and icons for the session.
- Match preview scale and horizontal alignment to the live target while keeping swing timers at their normal UI size. Without a visible target, previews use the configured target enlargement.
- Simplify swing timer settings by removing the in-game test-preview checkbox. Embedded menu previews remain available and update as you adjust settings.
- Add a [GitHub bug-report template](https://github.com/eddyrivers/VanillaVarnish/issues/new/choose), with blank reports available too.

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
