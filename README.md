# VanillaVarnish

A little polish for Blizzard's UI. Keep the vanilla; add the varnish.

Built for **WoW Forever 1.60.x / Interface 16001**. Other WoW clients have not been validated.

## Install

Download from [CurseForge](https://www.curseforge.com/wow/addons/vanilla-varnish), or extract an archive from [dist](https://github.com/eddyrivers/VanillaVarnish/tree/main/dist) into `Interface/AddOns`. The installed folder should be `VanillaVarnish`, with `VanillaVarnish.toc` directly inside it. Fully restart WoW after installation.

Open **Settings > AddOns > VanillaVarnish**, or type **`/vv`**. Active settings save per character. Named profiles are shared across your account. The main settings page has master switches for Nameplates, Quest tracker, Party frames, and Tooltips.

## Features

| Module | What it adds |
| --- | --- |
| Nameplates | Spell-range fading, quest icons, swing timers, combo points, threat colors, combat focus |
| Quest tracker | Zone grouping, collapsible headings, completion sorting, scrolling, and optional compact tracker and quest log views |
| Party frames | Up to 16 buffs in two rows, larger player buffs and dispellable debuffs, class-colored health bars, and friendly-spell range fading |
| Tooltips | Mouse following, configurable offsets, class/difficulty colors, immediate hover dismissal, and optional combat pause |
| Group Browser | Two-line listing rows and optional player sorting by level or class |

**Nameplates:** choose damage and friendly range spells; unreadable range results keep normal opacity. Quest loot icons include a compact bundled pfQuest Vanilla baseline, so Questie and QuestieDB are optional. Native quest objectives still control progress and completion; native tooltips identify kill and other objectives. An installed drop database can fill quests absent from the baseline. No website-derived Forever overrides are included; changed or new Forever quests may need further coverage. Enable **Include your group's quest objectives** under **Nameplates > Quest icons** to include unfinished loot and kill needs from current party or raid members, even for quests you do not have. Group progress must be supplied by the game's mob tooltip. Swing timers and combo points share a live preview. Positive X moves right; positive Y moves down. Threat colors turn fighting enemies blue when you hold aggro as a tank, or when you avoid aggro as a damage dealer or healer. Enemies tagged by another group keep gray health bars even when your group gains aggro or the Threat colors option is off.

Under **Nameplates > Combat focus**, enable the optional toggle to shrink and fade lower-priority enemies in combat. Both modes keep your target and enemies that are casting or channeling at normal size and full opacity while within range. **Tank** also prioritizes enemies you may lose or aren't holding. **Damage / Healer** prioritizes the target and active casts regardless of threat. Background plates start at **75% size** and **50% opacity**, with separate controls for each. Out-of-range fading still applies to targets and casting enemies; already fainter background plates keep their lower opacity. If cast or threat information is unavailable, fighting enemies stay prominent, with range fading still applied when available.

Both feature previews follow **Settings > Nameplates**, including style, size, health text, cast details, buffs, debuffs, crowd control, aura size, and spacing. After viewing the game's Nameplates preview, they retain its last enemy/friendly sample type and icons for the session. Before that, they show an enemy NPC sample. The preview matches a visible target's scale so timer widths and horizontal alignment reflect the in-game layout; without a target, it uses the configured target enlargement. Preview frames stay separate from live units; game options update the preview without a reload.

**Quest tracker:** use the mouse wheel or scrollbar to reach tracked quests when the list exceeds the tracker's height. Scrolling is on by default and keeps Blizzard's quest rows, clicks, and quest item buttons. The scrollbar appears only when needed; at the screen's right edge it appears to the left of the tracker. Turn **Scroll overflowing objectives** off under `/vv tracker` to restore the game's height limit. Scrolling also works with zone grouping off. Edit Mode temporarily restores the native layout for moving and resizing.

Enable **Compact view** under `/vv tracker` for quest text just 1.5 points smaller, slightly smaller zone buttons, and tighter row spacing. It also works with grouping off. The separate **Quest log** settings page has its own **Compact view** for quest log titles, objectives, and zone headings; open **Settings > AddOns > VanillaVarnish > Quest log**, or type `/vv questlog`. Both options start off, save per character and in profiles, and apply size changes after combat. Quest details keep their usual size. Each page's **Restore defaults** resets only that page.

Click a zone heading to collapse or expand it, including in combat. Collapsing a zone keeps its quests tracked. Protected layout changes wait until combat ends. Right-click outside combat to track or untrack a zone's quests. Completed sorting groups quests marked ready for turn-in (including click-to-complete quests). Quests with remaining travel or delivery instructions stay in level order.

**Party frames:** extra buffs and range fading require portrait-style party frames; class colors also support raid-style frames. Buffs include counts, cooldowns, and individual tooltips; the native portrait-hover buff popup is suppressed while extra buffs are enabled. Outside combat, active eating and drinking effects come first. Drinking icons match your larger buffs and have a one-pixel light cyan border. Your buffs follow with a one-pixel gold border, then other buffs in native order. Each row holds eight icons. In combat, Blizzard's native aura container keeps up to 16 buffs live in a single list. Combat buffs use the standard icon size and a plain border because caster identity is restricted. Personal enlargement, highlighting, and recovery priority return after combat. Portrait frames use less space with a few buffs while keeping room for all 16 in combat. Enlarged buff rows expand outside combat only when needed. Adjust **Space between members** (default `4`, range `0–40`) or enable **Grow upward from the bottom** on the Party frames page. Upward growth keeps the bottom edge fixed as members join or leave and preserves the position saved in Edit Mode across reloads. **Pin tanks, then healers** offers **Off**, **Top**, and **Bottom** for both portrait and raid-style party frames. The pinned block always displays tanks before healers at the chosen edge, with other members retaining their order. Raid-style pinning includes the player and keeps pets below the member block; horizontal groups use the leading or trailing edge. Pinning moves existing frames outside combat while Blizzard retains control of unit assignments and sorting. **Off** restores native positions. Role assignments come from the game. Layout changes apply outside combat and are included in profiles. Range fading uses the friendly spell and opacity from **Nameplates > Range check**, independently of the nameplate range switch. Only portraits and buffs fade; health, mana, and debuffs retain their opacity. No friendly spell or unavailable range means no fading. Addons that replace Blizzard's frames manage their own appearance.

**Tooltips:** item comparisons stay beside the main tooltip. Defaults are X `34`, Y `-6`; positive Y moves up. Combat pause uses the position saved in Edit Mode. Clicked chat links keep their usual placement.

**Group Browser:** open `/vv groupbrowser` and check **Compressed view**. Each listing puts the character or leader name, level, class, activity, and roles or group makeup on the first line. The second line shows playstyle and the current zone when WoW provides them. Clicks and the full hover details work as usual. **Sort players by** offers default order, highest level first, and class A–Z. It sorts inside the Players sections and works with either layout. Both preferences save with profiles.

## Commands

All VanillaVarnish commands start with `/vv`.

| Command | Action |
| --- | --- |
| `/vv` | Open settings |
| `/vv profiles`, `/vv presets` | Open Profiles & Presets |
| `/vv nameplates`, `/vv tracker`, `/vv party`, `/vv tooltips` | Open a module page |
| `/vv questlog` | Open the separate Quest log settings page |
| `/vv groupbrowser`, `/vv lfg` | Open Group Browser settings |
| `/vv <module> on`, `off`, or `toggle` | Enable or disable a whole module |
| `/vv nameplates range`, `quests`, `swings`, `combo`, or `focus` | Open a nameplate feature page |
| `/vv nameplates focus on`, `/vv nameplates focus off` | Switch combat focus |
| `/vv nameplates combo off`, `/vv nameplates threat on` | Switch an individual feature |
| `/vv nameplates range damage Moonfire` | Choose an enemy range spell; names, IDs, and links work |
| `/vv nameplates range friendly Healing Touch` | Choose a friendly range spell |
| `/vv nameplates range opacity 35` | Set nameplate and party portrait/buff out-of-range opacity to 35% |
| `/vv nameplates questie on` | Enable Questie fallback |
| `/vv nameplates groupquests on`, `/vv nameplates groupquests off` | Include or exclude group quest objectives |
| `/vv nameplates main on`, `/vv nameplates offhand off` | Switch individual swing bars |
| `/vv nameplates layout stack`, `/vv nameplates layout row` | Stack swing timers vertically or pack them into a row |
| `/vv nameplates help` | List swing appearance and nameplate commands |
| `/vv tracker group on`, `/vv tracker group off` | Switch zone grouping while preserving the module switch |
| `/vv tracker compact on`, `/vv tracker compact off` | Switch compact tracker text and spacing |
| `/vv tracker expand`, `/vv tracker collapse` | Expand or collapse all zones |
| `/vv party buffs off`, `/vv party colors on` | Switch party features |
| `/vv party range on`, `/vv party range off` | Switch party portrait and buff fading |
| `/vv party spacing 4`, `/vv party grow up`, `/vv party grow down` | Set portrait party spacing and growth direction |
| `/vv party roles off`, `/vv party roles top`, `/vv party roles bottom` | Pin tanks, then healers at the chosen edge |
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
