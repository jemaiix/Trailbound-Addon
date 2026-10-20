# Trailbound

**Quality-of-life tools for World of Warcraft: Forever. Made by Jemai.**

Trailbound brings everyday helpers into one addon: manage junk, check your alts' gold and inventory, plan training and crafts, track your progress, and arrange the displays you use. A shared brown-and-gold interface keeps the options and addon windows consistent.

Open **`/tb`** or **`/trailbound`** to choose the features you want. The settings are grouped by what you are doing, with a search field to help you find individual options.

## Features

### Bags, vendors and characters

- Account gold totals and saved views of your characters' bags and banks.
- Junk lists, vendor selling and manual removal of items from the junk list.
- Bag movement from the header and reagent slots in the combined backpack, with a distinct colour for empty reagent slots.
- Remembered full-name mail recipients.

### Quests, training and professions

- Configurable quest acceptance, turn-in and vendor helpers.
- Class spell and profession recipe catalogues, including level or skill requirements and trainer costs when recorded.
- Compact crafting profit estimates inside supported profession windows: material costs, vendor returns and estimated auction proceeds after fees.
- Material searches with the quantities needed for a craft.
- Gathering reminders, minimap node icons and additional highlights where the client exposes the required information.

### Combat and recovery

- Customizable weapon and wand swing timers with smooth progress.
- Mana recovery and food/drink timers.
- Buff and class reminders, plus timed notices for supported important buffs received from other players.
- Configurable action rings with character-specific bindings and macros you can place on action bars.

### Experience, travel and interface

- A compact experience display with rested XP and completed-quest XP estimates.
- A movable level-times window showing recorded milestones in total `/played` time.
- Flight-path timing that learns routes as you fly them.
- Edit mode for arranging Trailbound displays, plus movement for supported game windows.
- Chat appearance options, shorter channel labels, class/race icons and copyable URLs.
- Saved addon profiles, minimap options and other interface conveniences.

## Installation

Trailbound targets **WoW: Forever**, interface **16001**. Compatibility with other WoW editions is not established.

1. Download a Trailbound release ZIP and extract it.
2. Place the `Trailbound` folder inside your game's `Interface/AddOns` directory.
3. Confirm the layout is `Interface/AddOns/Trailbound/Trailbound.toc` rather than an extra nested folder.
4. Restart the game if this is a new installation, enable Trailbound in the addon list, and open `/tb`.

For an existing installation, replace the addon files and use `/rl` or `/reload`.

**Upgrading from ForeverAssist:** keep the small, metadata-only `ForeverAssist` folder enabled while migrating old characters. It imports their existing saved data; it does not run the old addon. Log into each old character and log out normally before removing that migration folder. Do not run the old full ForeverAssist addon alongside Trailbound.

## Useful commands

| Command | Opens or performs |
| --- | --- |
| `/tb` or `/trailbound` | Main options |
| `/tb edit` | Toggle display edit mode |
| `/tb rings` | Action ring editor |
| `/tb levels` | Toggle the level-times window |
| `/tb gold` | Gold report |
| `/tb bags` | Saved account inventory |
| `/tb bank` | Bank window |
| `/tb professions` | Profession catalogue |
| `/tb junk` | Junk manager |
| `/tb profiles` | Addon profiles |
| `/tb version` | Installed version information |
| `/tb maildebug` | Mail-window diagnostics |

The `/rl` shortcut reloads the interface when that command has not already been claimed by another addon or the client.

## Prices and saved information

Auctionator and TradeSkillMaster are **optional** price sources. Trailbound can also use prices it remembers from auction-house observations and vendor reagent costs learned at merchants. Unknown prices remain unknown; profit figures are estimates, not guaranteed sale results.

Account inventory and gold displays use saved character records. Log into each character to update its information; offline bags and banks are snapshots rather than live views. Visit trainers to record prices and requirements. Level history starts with milestones Trailbound can actually observe, and flight estimates improve after completed trips.

Your settings, character records and remembered prices are saved by WoW under **`WTF`**, separately from the addon files. The release ZIP does **not** include the author's character saves or personal settings. Back up your `WTF` folder before manually changing saved data.

## Beta status and feedback

Trailbound is being developed against the Forever beta. Client updates and other addons can affect individual features. The mail recipient header button is currently being investigated; its latest visibility changes still need in-game confirmation. If it is missing, open Send Mail and include the output of `/tb maildebug` in your report.

When reporting a problem, include your Trailbound version (`/tb version`), the steps to reproduce it, any Lua error text, and a screenshot when the issue is visual. Mention other addons that modify the same window.
