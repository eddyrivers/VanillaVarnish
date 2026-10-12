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

**Nameplates:** choose damage and friendly range spells; unreadable range results keep normal opacity. Questie is optional and can supply extra quest information. Swing timers and combo points share a live preview. Positive X moves right; positive Y moves down. Threat colors turn fighting enemies blue when you hold aggro as a tank, or when you avoid aggro as a damage dealer or healer. Other situations keep the game's colors.

**Quest tracker:** click a zone heading to fold it; right-click to track or untrack its quests. Collapsing a zone keeps its quests tracked. Completed sorting groups quests marked ready for turn-in (including click-to-complete quests); quests with remaining travel or delivery instructions stay in level order. Move and resize the tracker in Edit Mode. Combat layout changes apply after combat ends.

**Party frames:** extra buffs and range fading require portrait-style party frames; class colors also support raid-style frames. Buffs include counts, cooldowns, and tooltips. Active eating and drinking effects come first, followed by your buffs, then other buffs in native order. Your buffs remain larger; each row holds eight icons. Range fading uses the friendly spell and opacity from **Nameplates > Range check**, independently of the nameplate range switch. Only portraits and buffs fade; health, mana, and debuffs retain their opacity. No friendly spell or unavailable range means no fading. Addons that replace Blizzard's frames manage their own appearance.

**Tooltips:** item comparisons stay beside the main tooltip. Defaults are X `34`, Y `-6`; positive Y moves up. Combat pause uses the position saved in Edit Mode. Clicked chat links keep their usual placement.

## Commands

All VanillaVarnish commands start with `/vv`.

| Command | Action |
| --- | --- |
| `/vv` | Open settings |
| `/vv nameplates`, `/vv tracker`, `/vv party`, `/vv tooltips` | Open a module page |
| `/vv <module> on`, `off`, or `toggle` | Enable or disable a whole module |
| `/vv nameplates range`, `quests`, `swings`, or `combo` | Open a nameplate feature page |
| `/vv nameplates combo off`, `/vv nameplates threat on` | Switch an individual feature |
| `/vv nameplates range damage Moonfire` | Choose an enemy range spell; names, IDs, and links work |
| `/vv nameplates range friendly Healing Touch` | Choose a friendly range spell |
| `/vv nameplates range opacity 35` | Set nameplate and party portrait/buff out-of-range opacity to 35% |
| `/vv nameplates questie on` | Enable Questie fallback |
| `/vv nameplates main on`, `/vv nameplates offhand off` | Switch individual swing bars |
| `/vv nameplates help` | List swing appearance and nameplate commands |
| `/vv tracker group on`, `/vv tracker group off` | Switch zone grouping while preserving the module switch |
| `/vv tracker expand`, `/vv tracker collapse` | Expand or collapse all zones |
| `/vv party buffs off`, `/vv party colors on` | Switch party features |
| `/vv party range on`, `/vv party range off` | Switch party portrait and buff fading |
| `/vv tooltips offset 34 -6` | Set cursor offsets |
| `/vv tooltips reset`, `/vv nameplates reset` | Restore tooltip or swing defaults |
| `/vv status`, `/vv <module> status`, `/vv nameplates debug` | Show status and diagnostics |

Settings requested in combat open after combat ends. **Restore defaults** resets only its settings page; module switches stay as you set them.

## Profiles

Open `/vv` and use **Profiles** on the main page. Enter a name under **Save as**, then click **Save profile**. To use the design on another character, select it in **Load profile** and click **Load** outside combat. Profiles become available on your other characters after you reload or log out of the character that saved them.

A profile is a snapshot of VanillaVarnish's module switches and settings, including appearance, range spells, and quest sorting. Loading replaces the current character's addon settings. Later changes stay local until you save again; saving an existing name updates its snapshot. Save a new name to keep both designs. Collapsed quest zones remain specific to each character. Blizzard's Edit Mode layout and native nameplate style are managed by the game and are not stored in these profiles. Check range spells when sharing between different classes.

## Existing standalone addons

If you used NameplateTweaks, QuestTrackerOrganizer, PartyTweaks, or NameplateSwingTimers, enable them alongside VanillaVarnish for one login to import available nameplate, tracker, and swing preferences. Then disable the originals and `/reload`. Existing VanillaVarnish preferences are kept. The matching modules wait while the originals are loaded to prevent competing changes. Disable ForeverMouseTooltip before using the Tooltips module.

## Development and support

See [CONTRIBUTING.md](https://github.com/eddyrivers/VanillaVarnish/blob/main/CONTRIBUTING.md) for tests and publishing. Report bugs through [GitHub Issues](https://github.com/eddyrivers/VanillaVarnish/issues), including your client build, module, reproduction steps, and any Lua error.

Code is licensed under [MIT](LICENSE). Montserrat is bundled under the [SIL Open Font License](Media/Montserrat-OFL.txt); see the [upstream font](https://github.com/JulietaUla/Montserrat).
