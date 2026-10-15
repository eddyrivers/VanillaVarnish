# VanillaVarnish

A little polish for Blizzard's UI. Keep the vanilla; add the varnish.

Built for **WoW Forever 1.60.x / Interface 16001**. Other WoW clients have not been validated.

## Install

Download from [CurseForge](https://www.curseforge.com/wow/addons/vanilla-varnish), or extract an archive from [dist](https://github.com/eddyrivers/VanillaVarnish/tree/main/dist) into `Interface/AddOns`. The installed folder should be `VanillaVarnish`, with `VanillaVarnish.toc` directly inside it. Fully restart WoW after installation.

Open **Settings > AddOns > VanillaVarnish**, or type **`/vv`**. Active settings save per character. Named profiles are shared across your account. Each module has a master switch that preserves its feature settings when turned off.

## Features

| Module | What it adds |
| --- | --- |
| Nameplates | Spell-range fading, quest icons, swing timers, combo points, threat colors |
| Quest tracker | Quests grouped by zone, collapsible headings, and optional completed-first or completed-last sorting |
| Party frames | Up to 16 buffs in two rows, larger player buffs and dispellable debuffs, class-colored health bars, and friendly-spell range fading |
| Tooltips | Mouse following, configurable offsets, class/difficulty colors, immediate hover dismissal, and optional combat pause |
| Polite UI | Independent fade-out and fade-in rules for persistent HUD elements, with hover reveal |

**Nameplates:** choose damage and friendly range spells; unreadable range results keep normal opacity. Quest loot icons include a compact bundled pfQuest Vanilla baseline, so Questie and QuestieDB are optional. Native quest objectives still control progress and completion; native tooltips identify kill and other objectives. An installed drop database can fill quests absent from the baseline. No website-derived Forever overrides are included; changed or new Forever quests may need further coverage. Swing timers and combo points share a live preview. Positive X moves right; positive Y moves down. Threat colors turn fighting enemies blue when you hold aggro as a tank, or when you avoid aggro as a damage dealer or healer. Other situations keep the game's colors.

Both feature previews follow **Settings > Nameplates**, including style, size, health text, cast details, buffs, debuffs, crowd control, aura size, and spacing. After viewing the game's Nameplates preview, they retain its last enemy/friendly sample type and icons for the session. Before that, they show an enemy NPC sample. The preview matches a visible target's scale so timer widths and horizontal alignment reflect the in-game layout; without a target, it uses the configured target enlargement. Preview frames stay separate from live units; game options update the preview without a reload.

**Quest tracker:** click a zone heading to fold it; right-click to track or untrack its quests. Collapsing a zone keeps its quests tracked. Completed sorting groups quests marked ready for turn-in (including click-to-complete quests); quests with remaining travel or delivery instructions stay in level order. Move and resize the tracker in Edit Mode. Combat layout changes apply after combat ends.

**Party frames:** extra buffs and range fading require portrait-style party frames; class colors also support raid-style frames. Buffs include counts, cooldowns, and tooltips. Active eating and drinking effects come first, followed by your buffs, then other buffs in native order. Your buffs remain larger; each row holds eight icons. Range fading uses the friendly spell and opacity from **Nameplates > Range check**, independently of the nameplate range switch. Only portraits and buffs fade; health, mana, and debuffs retain their opacity. No friendly spell or unavailable range means no fading. Addons that replace Blizzard's frames manage their own appearance.

**Tooltips:** item comparisons stay beside the main tooltip. Defaults are X `34`, Y `-6`; positive Y moves up. Combat pause uses the position saved in Edit Mode. Clicked chat links keep their usual placement.

## Polite UI (beta)

Open **`/vv polite`** (or `/vv fade`) to let persistent parts of the interface step aside. The preset selector is a placeholder for future designs. Each grouped row has **Fade out** and **Fade in** multiselects, both starting at **Never**. Select **Never (clear selections)** to empty a list.

Every selected condition in a list must match: **AND**, rather than OR. For example, fade the **Player frame** when health is full **and** you are out of combat; return it while in combat. If both lists match, **Fade in wins**. A faded element stays faded until its return list matches. Losing the fade-out conditions alone does not bring it back. An empty fade-out list leaves the element alone; an empty fade-in list disables automatic return.

Fades take about **0.5 seconds** and reach complete transparency. **Hover always reveals** the element, including its buttons and aura icons, then lets its rules resume when you leave. Typing keeps chat visible. This settings page and Blizzard's Edit Mode reveal all affected elements. The game retains control of which frames are shown, their click behavior, and their own opacity changes.

The event return choices—enter combat, leave combat, start casting/channeling, select a new target, and press Escape—remain true for **3 seconds**, giving you time to read the returning UI. Additional selections still use AND. State conditions such as **When in combat** remain true for as long as the state lasts. Choose that state instead of the event if you want the frame visible throughout combat.

All rows offer these common state conditions: in/out of combat, having/no target, moving/standing still, mounted/not mounted, resting, casting/channeling/not casting, and alive/dead or ghost. These are the initial element-specific choices for review:

| Element | Additional choices |
| --- | --- |
| Player frame and pet frame | Health/mana full; health/mana at least 75% and increasing; health/mana below 75%; health at or below 35%; unit dead |
| Target frame | Health full, below 75%, or at/below 35%; dead; friendly; attackable |
| Target of target | Health full or below 75%; dead |
| Party and raid frames | All members at full health; all mana users at full mana; a member needs healing; a member is dead or disconnected |
| Player buffs | No buffs; buffs present; a timed buff has 30 seconds or less remaining |
| Player debuffs | No debuffs; a debuff present |
| Player cast bar | Mana full or below 75% |
| Minimap | Indoors; outdoors |
| Quest tracker | No tracked quests; tracked quests present; a tracked quest is ready to turn in |
| Experience/reputation bars | Common conditions |
| Chat windows | Quiet for 30 seconds; a message in the last 30 seconds; typing/not typing |
| Main, bottom left/right, side, and additional action bars | Common conditions |
| Pet action bar | Pet present; no pet |
| Stance/form bar, micro menu, and bag buttons | Common conditions |

"Increasing" means a resource rose within the last 3 seconds without falling since. Mana conditions apply only to units that use mana. Unavailable or restricted API data never satisfies a condition. Frames supplied by the client are discovered as they appear; replacement addon frames are outside this first pass.

Hover a condition dropdown to see **Match**, **Waiting**, or **Unavailable** beside each selection, along with the element's current status. Contradictory selections are explained there too. `/vv polite debug` prints the same condition and frame status in chat. Rules update as you change them and resume when Settings closes; no reload is needed to apply selections.

**Player frame** means the persistent portrait/health/mana HUD, and **Quest tracker** means the persistent objectives display. The character sheet, quest log window, bags themselves, bank, auction house, map, and other manually opened windows are excluded. Rules are saved per character and included in account profiles. Older profiles and built-in designs leave all fade selections at Never. Use `/vv polite off` for immediate restoration without losing your selections, or `/vv polite reset` to clear them.

This beta targets **WoW Forever 1.60.x / Interface 16001**. Automated checks cover rule behavior; in-game layout, hover, Escape delivery, and combat taint checks remain part of beta validation.

## Commands

All VanillaVarnish commands start with `/vv`.

| Command | Action |
| --- | --- |
| `/vv` | Open settings |
| `/vv profiles`, `/vv presets` | Open Profiles & Presets |
| `/vv nameplates`, `/vv tracker`, `/vv party`, `/vv tooltips` | Open a module page |
| `/vv polite`, `/vv fade` | Open Polite UI |
| `/vv polite off`, `/vv polite reset` | Restore native opacity, or clear all fade rules |
| `/vv polite debug` | Explain current fade conditions and frame status |
| `/vv <module> on`, `off`, or `toggle` | Enable or disable a whole module |
| `/vv nameplates range`, `quests`, `swings`, or `combo` | Open a nameplate feature page |
| `/vv nameplates combo off`, `/vv nameplates threat on` | Switch an individual feature |
| `/vv nameplates range damage Moonfire` | Choose an enemy range spell; names, IDs, and links work |
| `/vv nameplates range friendly Healing Touch` | Choose a friendly range spell |
| `/vv nameplates range opacity 35` | Set nameplate and party portrait/buff out-of-range opacity to 35% |
| `/vv nameplates questie on` | Enable Questie fallback |
| `/vv nameplates main on`, `/vv nameplates offhand off` | Switch individual swing bars |
| `/vv nameplates layout stack`, `/vv nameplates layout row` | Stack swing timers vertically or pack them into a row |
| `/vv nameplates help` | List swing appearance and nameplate commands |
| `/vv tracker group on`, `/vv tracker group off` | Switch zone grouping while preserving the module switch |
| `/vv tracker expand`, `/vv tracker collapse` | Expand or collapse all zones |
| `/vv party buffs off`, `/vv party colors on` | Switch party features |
| `/vv party range on`, `/vv party range off` | Switch party portrait and buff fading |
| `/vv tooltips offset 34 -6` | Set cursor offsets |
| `/vv tooltips reset`, `/vv nameplates reset` | Restore tooltip or swing defaults |
| `/vv status`, `/vv <module> status`, `/vv nameplates debug` | Show status and diagnostics |

Settings requested in combat open after combat ends. **Restore defaults** resets only its settings page; module switches stay as you set them.

## Profiles & Presets

Open `/vv` and follow **Profiles & Presets**, or use `/vv profiles`. Choose a built-in design under **Presets** and click **Apply preset** outside combat. Save your current settings as a profile first if you want to keep them.

| Preset | Design |
| --- | --- |
| Default | The starting design for new characters: stacked swing timers, combo points, and completed quests sorted last |
| Default (tight) | Bring swing timers and combo points closer to the nameplate |
| Swing timer row | Three swing timers share a 200-unit horizontal span, with swing Y at 37 and combo-point Y at 23 |
| Combo point class (compact) | Smaller combo dots offset to the right, with swing timers sharing a compact 161-unit row |

**Nameplates > Swing timers > Bar layout** offers **Stacked** and **Row** for any design. Stacked timers collapse upward; row timers collapse to the left in main-hand, off-hand, ranged order. Row width is the full three-timer span including gaps. Hidden timers leave no gaps, and visible timers keep their individual widths. The live preview follows your chosen layout.

Under **Profiles**, enter a name in **Save as**, then click **Save profile**. To use the design on another character, select it in **Load profile** and click **Load** outside combat. Profiles become available on your other characters after you reload or log out of the character that saved them. Built-in presets stay separate from your editable profiles, even when they share a name. Existing characters keep their settings until you apply a preset or load a profile.

A profile is a snapshot of VanillaVarnish's module switches and settings, including appearance, range spells, and quest sorting. Loading replaces the current character's addon settings. Later changes stay local until you save again; saving an existing name updates its snapshot. Save a new name to keep both designs. Collapsed quest zones remain specific to each character. Blizzard's Edit Mode layout and native nameplate style are managed by the game and are not stored in these profiles. Check range spells when sharing between different classes.

## Existing standalone addons

If you used NameplateTweaks, QuestTrackerOrganizer, PartyTweaks, or NameplateSwingTimers, enable them alongside VanillaVarnish for one login to import available nameplate, tracker, and swing preferences. Then disable the originals and `/reload`. Existing VanillaVarnish preferences are kept. The matching modules wait while the originals are loaded to prevent competing changes. Disable ForeverMouseTooltip before using the Tooltips module.

## Development and support

See [CONTRIBUTING.md](https://github.com/eddyrivers/VanillaVarnish/blob/main/CONTRIBUTING.md) for tests and publishing. Anyone with a GitHub account can [submit a bug report](https://github.com/eddyrivers/VanillaVarnish/issues/new/choose). Include your addon version, client build, module, reproduction steps, and any Lua error or screenshot. The bug-report template helps organize the details; blank reports are welcome too.

Original addon code is licensed under [MIT](LICENSE). Montserrat is bundled under the [SIL Open Font License](Media/Montserrat-OFL.txt); see the [upstream font](https://github.com/JulietaUla/Montserrat).
The bundled quest database retains the [pfQuest MIT notice](Licenses/pfQuest-MIT.txt) and [upstream VMaNGOS GPL v2 notice](Licenses/VMaNGOS-GPL-2.0.txt). See [database provenance and limits](Licenses/QuestDropData-NOTICES.txt); the base-dump permissions remain unresolved.
