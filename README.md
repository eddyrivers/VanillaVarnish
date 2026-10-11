# VanillaVarnish

A little polish for Blizzard's UI. Keep the vanilla; add the varnish.

Built for **WoW Forever 1.60.x / Interface 16001**. Other WoW clients have not been validated.

## Install

Download from [CurseForge](https://www.curseforge.com/wow/addons/vanilla-varnish), or extract an archive from [dist](https://github.com/eddyrivers/VanillaVarnish/tree/main/dist) into `Interface/AddOns`. The installed folder should be `VanillaVarnish`, with `VanillaVarnish.toc` directly inside it. Fully restart WoW after installation.

Open **Settings > AddOns > VanillaVarnish**, or type **`/vv`**. Settings save per character. Each module has a master switch that preserves its feature settings when turned off.

## Features

| Module | What it adds |
| --- | --- |
| Nameplates | Spell-range fading, quest icons, swing timers, combo points, threat colors, and an optional player cast bar |
| Quest tracker | Quests grouped by zone, collapsible headings, and optional completed-first or completed-last sorting |
| Party frames | Up to eight buffs, larger player buffs and dispellable debuffs, class-colored health bars, and friendly-spell range fading |
| Tooltips | Mouse following, configurable offsets, class/difficulty colors, immediate hover dismissal, and optional combat pause |

**Nameplates:** choose damage and friendly range spells; unreadable range results keep normal opacity. Questie is optional and can supply extra quest information. Swing timers and combo points share a live preview. Positive X moves right; positive Y moves down. Threat colors turn fighting enemies blue when you hold aggro as a tank, or when you avoid aggro as a damage dealer or healer. Other situations keep the game's colors.

**Player cast bar:** optional and off by default. Shows your own casts and channels beneath your target's nameplate, using Blizzard's native cast-bar artwork and behavior. Set its X/Y offsets and width; height, icon size, and font size follow your nameplate style and size. The normal player cast bar and the target's cast bar remain available. A visible target nameplate is required; soft enemy targeting works when you have no hard target. The settings page previews your bar alongside the enabled swing timers and combo points.

**Quest tracker:** click a zone heading to fold it; right-click to track or untrack its quests. Collapsing a zone keeps its quests tracked. Move and resize the tracker in Edit Mode. Combat layout changes apply after combat ends.

**Party frames:** extra buffs and range fading require portrait-style party frames; class colors also support raid-style frames. Buffs include counts, cooldowns, and tooltips. Range fading uses the friendly spell and opacity from **Nameplates > Range check**, independently of the nameplate range switch. Only portraits and buffs fade; health, mana, and debuffs retain their opacity. No friendly spell or unavailable range means no fading. Addons that replace Blizzard's frames manage their own appearance.

**Tooltips:** item comparisons stay beside the main tooltip. Defaults are X `34`, Y `-6`; positive Y moves up. Combat pause uses the position saved in Edit Mode. Clicked chat links keep their usual placement.

## Commands

All VanillaVarnish commands start with `/vv`.

| Command | Action |
| --- | --- |
| `/vv` | Open settings |
| `/vv nameplates`, `/vv tracker`, `/vv party`, `/vv tooltips` | Open a module page |
| `/vv <module> on`, `off`, or `toggle` | Enable or disable a whole module |
| `/vv nameplates range`, `quests`, `swings`, `combo`, or `cast` | Open a nameplate feature page |
| `/vv nameplates combo off`, `/vv nameplates threat on` | Switch an individual feature |
| `/vv nameplates cast on`, `/vv nameplates cast off` | Switch the player cast bar |
| `/vv nameplates cast x 20`, `/vv nameplates cast y 90`, `/vv nameplates cast width 200` | Position and size the player cast bar; positive Y moves down |
| `/vv nameplates cast reset` | Restore player cast-bar placement without changing its switch |
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

## Existing standalone addons

If you used NameplateTweaks, QuestTrackerOrganizer, PartyTweaks, or NameplateSwingTimers, enable them alongside VanillaVarnish for one login to import available nameplate, tracker, and swing preferences. Then disable the originals and `/reload`. Existing VanillaVarnish preferences are kept. The matching modules wait while the originals are loaded to prevent competing changes. Disable ForeverMouseTooltip before using the Tooltips module.

## Development and support

See [CONTRIBUTING.md](https://github.com/eddyrivers/VanillaVarnish/blob/main/CONTRIBUTING.md) for tests and publishing. Report bugs through [GitHub Issues](https://github.com/eddyrivers/VanillaVarnish/issues), including your client build, module, reproduction steps, and any Lua error.

Code is licensed under [MIT](LICENSE). Montserrat is bundled under the [SIL Open Font License](Media/Montserrat-OFL.txt); see the [upstream font](https://github.com/JulietaUla/Montserrat).
