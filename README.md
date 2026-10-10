# VanillaVarnish

A few finishing touches for Blizzard's UI on **WoW Forever 1.60.x / Interface 16001**.

Open **Settings > AddOns > VanillaVarnish**, or type **`/vv`**. Choose which modules to enable on the main page, then adjust their features on the other pages. Your settings save per character, and turning a module off keeps your choices.

## Nameplates

- **Range check:** fade units beyond the range of your chosen damage or friendly spell. Choose how faint their nameplates become. Melee abilities use melee reach; when range is unavailable, opacity stays unchanged.
- **Quest icons:** white icons mark units you need to loot, defeat, or interact with. Questie can help identify item drops and fill in missing quest information when installed.
- **Swing timers:** follow main-hand, off-hand, and ranged swings beneath your target's nameplate. Without a selected target, timers can follow your action target. A subtle pale gold highlight warms each bar as it fills; pulse strength defaults to 35%. Adjust each bar's appearance, labels, and visibility.
- **Combo points:** five circles on your selected target fill red as you earn points. For rogues and druids in Cat Form. They use Blizzard's personal resource artwork. Adjust dot size, spacing, and horizontal or vertical position on the **Combo points** page.

Each feature has a switch on the **Nameplates** page. The **Swing timers** and **Combo points** pages share a live nameplate preview showing both enabled features, so you can arrange them together. The preview remains available when the module is off.

Positive horizontal offsets move right; positive vertical offsets move down. Combo circles stay in fixed slots as you earn or spend points; at zero points, all five circles are empty. Swing timers move down as needed to clear the cast bar when their vertical offset is 0 or higher. Negative offsets allow overlap. A spacing value of 0 makes bars or dots touch; swing sparks and large labels may extend into the gap.

## Quest tracker

Group tracked quests by zone, with lower-level quests first. The **Completed quest sorting** dropdown offers **Off**, **Completed on top**, or **Completed on bottom** within each zone. Off keeps level sorting; the other choices retain level/title order within the completed and incomplete groups. It defaults to Off, and an existing completed-first preference becomes Completed on top.

- Click a zone heading or its + / - button to expand or collapse it.
- Right-click a heading to track or untrack quests in that zone.
- Expand or collapse every zone from the settings page.
- Move and resize the tracker in Blizzard's Edit Mode.

Collapsing a zone keeps its quests tracked. Turning grouping off returns to the game's usual tracker. Layout changes made in combat apply when combat ends; zone tracking actions are unavailable during combat.

## Party frames

- **Show party buffs:** show up to eight buffs beneath mana, with yours first and larger. Also enlarge debuffs you can dispel and color their borders by type: purple for curses, green for poison, blue for magic, and brown for disease. Requires **Use raid-style party frames** to be turned off.
- **Class-colored health bars:** use each member's class color in either party-frame style.

Buffs include stack counts, cooldowns, and hover tooltips. Some layout changes take effect after combat. If another addon replaces Blizzard's party frames, configure those frames in that addon.

## Tooltips

Open **`/vv tooltips`** for mouse following and colors. The module and mouse following start enabled; turn either off to keep the usual hover placement. Enabled hover tooltips disappear immediately when hovering ends.

- **Follow the mouse:** keep hover tooltips for mobs, players, spells, bag items, auras, and other controls beside the cursor, including tooltips normally anchored to a button. Item comparisons stay attached to the main item tooltip.
- **Horizontal / vertical offset:** adjust the native cursor anchor from -500 to 500 UI units. Positive X moves right; positive Y moves up. Defaults are X **34**, Y **-6**.
- **Color unit names, classes, and levels:** player names, including Forever surnames, and class text use class colors. Hostile levels use Classic difficulty colors: red, orange, yellow, green, or gray. Restricted information keeps its native colors. Enabled by default.
- **Pause mouse following in combat:** put hover tooltips at the position saved in Blizzard's Edit Mode while in combat, then resume mouse following when combat ends. Disabled by default. Unit colors and immediate hiding still apply.

Clicked chat links and embedded tooltip panels retain their own placement. The module uses native cursor tracking and secure hooks, with fresh settings; it does not import ForeverMouseTooltip. If **ForeverMouseTooltip** is loaded, disable it and `/reload` to activate VV's Tooltips module.

## Installation

1. Place the `VanillaVarnish` folder in `Interface/AddOns`.
2. Fully restart WoW so the addon appears in the AddOns list.
3. Enable VanillaVarnish and open `/vv`.

The [1.0.17 release archive](https://github.com/eddyrivers/VanillaVarnish/blob/main/dist/VanillaVarnish-1.0.17.zip) contains the installable folder. Other WoW client families have not been validated.

### Importing settings from the original addons

On your first VanillaVarnish login, enable it alongside **NameplateTweaks**, **QuestTrackerOrganizer**, **PartyTweaks**, and any standalone **NameplateSwingTimers** you used. After logging in, disable the originals and type `/reload`.

Existing nameplate, swing, and tracker preferences are copied once. The originals must be enabled for WoW to load their saved settings. If VanillaVarnish has already saved its own preferences, it keeps those instead. Party features start enabled.

While an original addon is enabled, its matching VanillaVarnish module stays inactive. Standalone NameplateSwingTimers only blocks swing timers. The settings page tells you which addon to disable.

## Commands

| Command | Action |
| --- | --- |
| `/vv` or `/vanillavarnish` | Open settings |
| `/vv nameplates`, `/vv tracker`, `/vv party`, `/vv tooltips` | Open a module page |
| `/vv nameplates on`, `/vv tracker off`, `/vv party toggle`, `/vv tooltips off` | Switch a module on or off |
| `/vv tooltips offset 34 -6` | Set horizontal and vertical cursor offsets |
| `/vv tooltips reset` | Restore tooltip feature defaults |
| `/nt range`, `/nt quests`, `/nt swings`, `/nt combo` | Open a nameplate feature page |
| `/nt range on`, `/nt quests off`, `/nt swings on`, `/nt combo on` | Switch a nameplate feature on or off |
| `/nt range damage Moonfire`, `/nt range friendly Healing Touch` | Choose range spells; names, IDs, and links work |
| `/nt range opacity 35` | Set out-of-range opacity to 35% |
| `/nt questie on` | Use Questie for extra quest information |
| `/nt main on`, `/nt offhand off`, `/nt ranged toggle` | Switch individual swing bars on or off |
| `/nt help` | List swing appearance and other nameplate commands |
| `/qto` or `/qlo` | Open quest tracker settings |
| `/qto on`, `/qto off` | Switch zone grouping on or off |
| `/qto expand`, `/qto collapse` | Expand or collapse all zones |
| `/pt options`, `/pt buffs off`, `/pt colors on` | Open party settings or switch features |
| `/vv status`, `/nt status`, `/nt debug`, `/pt status` | Show status and troubleshooting information |

Feature commands also work after a module name, such as `/vv nameplates combo off` or `/vv tracker collapse`. Settings requested in combat open after combat ends. Legacy aliases such as `/nt` are available when their original addon is disabled.

**Restore defaults** on the Swing timers, Combo points, Quest tracker, or Tooltips page resets only that page's settings. `/nt reset` resets swing settings. Module switches stay as you set them.

[Source repository](https://github.com/eddyrivers/VanillaVarnish). Montserrat is bundled under the SIL Open Font License; see `Media/Montserrat-OFL.txt` and the [upstream font](https://github.com/JulietaUla/Montserrat).
