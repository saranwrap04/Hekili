<p align="center">
<img width="192" height="192" alt="Hekili" src="images/logo.png" />
</p>

# Hekili for WoW 3.3.5a

**Your next ability, on screen, for every class.** A priority helper for World of Warcraft 3.3.5a (AzerothCore servers such as ChromieCraft).

Version 3.3.5-1.2.4 · backport by Saranwrap

> **I am not the original author of this addon.** Hekili is made by **Hekili** and its contributors (https://github.com/Hekili/hekili). This is a backport of its Wrath of the Lich King Classic version to the 3.3.5a client. Please report problems with this version [here](https://github.com/saranwrap04/Hekili/issues), not to Hekili.

---

## Features

- The next abilities to use for your class and talents, updated as you fight.
- The priority is picked from your talents (the tree with the most points).
- Big cooldowns in their own display, interrupts when your target casts.
- The key each ability is bound to on your action bars.
- AOE recommendations as soon as you hit several enemies.
- Works out of the box: no setup needed.

| Class | Priorities |
| --- | --- |
| Death Knight | Blood, Frost (two versions), Unholy |
| Druid | Balance, Feral DPS, Feral Tank |
| Hunter | Beast Mastery, Marksmanship, Survival |
| Mage | Arcane, Fire, Frost |
| Paladin | Holy, Protection, Retribution (two versions) |
| Priest | Shadow |
| Rogue | Assassination, Combat |
| Shaman | Elemental / Restoration DPS, Enhancement |
| Warlock | Affliction, Demonology, Destruction |
| Warrior | Arms, Fury, Protection |

---

## Installation

1. Close the game.
2. Download the zip (on GitHub: **Code → Download ZIP**) and open it.
3. Copy the **`Hekili`** folder into `<WoW folder>\Interface\AddOns\`. Keep its name: the addon loads from it.
4. Start the game.

**Updating:** close the game, **delete the old `Hekili` folder completely** (and any `Hekili-main` folder from an older download, so only one copy is installed), then copy in the new one. Copying over the old folder can keep old files (images in particular), and the game only loads new files after a full restart, not after `/reload`.

Do not install another version of Hekili (retail or Classic) at the same time.

---

## The displays

| Display | What it shows | Where |
| --- | --- | --- |
| **Primary** | Your rotation: the next ability (large icon) and the two after | Middle of the screen, above the player cast bar |
| **Cooldowns** | Big cooldowns (Fire Elemental Totem, Bloodlust, Icy Veins, Avenging Wrath...) | Left of Primary |
| **AOE** | The multi-target priority, in the Dual and Reactive display modes | Right of Primary |
| **Interrupts**, **Defensives** | Only when set to show separately in Toggles | Left of Primary |

- Each icon shows the key it is bound to (`1`, `S2` for Shift-2, `CF` for Ctrl-F...). Default bars, ElvUI, Bartender4 and Dominos are read, macros included.
- Messages such as "Cooldowns ON" appear in the notification panel at the top of the screen.

### Moving them

1. Out of combat, type `/hek move`. Each display shows a dark box with its name.
2. Left-click and hold a box, drag it, let go.
3. Right-click a box to open its settings.
4. Type `/hek lock` when done. Positions are saved.

---

## Toggles

| Toggle | Default | Key | |
| --- | --- | --- | --- |
| Cooldowns | On, in their own display | `Alt-Shift-R` | Big cooldowns |
| Interrupts | On | `Alt-Shift-I` | Interrupts when the target casts |
| Defensives | Off | `Alt-Shift-T` | Damage mitigation (useful for tanks) |
| Potions | Off | | Potions |
| Display mode | Automatic | `Alt-Shift-N` | Automatic, single target, AOE, dual, reactive |
| Pause | | `Alt-Shift-P` | Freeze the recommendations |

Change them in `/hek` → Toggles, with the keys, or from the minimap button (left-click).

---

## Settings

Open them with `/hek`, a right-click on the minimap button, or **Escape → Interface → AddOns → Hekili**. That page also has buttons to move or lock the displays, show or hide the minimap button and turn Hekili on or off.

- **Displays**: size, number of icons, position, keybind text, glow, border, captions, visibility.
- **Your class**: rotation (or pick it by talents), rotation options, enemy counting.
- **Priorities**: the rotations themselves, which you can copy, edit, import and export (for advanced users).
- **Abilities / Gear and Items**: turn one off, limit it to boss fights or to a number of enemies, change its toggle (Cooldowns...) or its keybind text.
- **Profiles**: one per character or shared, and one per talent group (dual spec).

---

## Commands

| Command | |
| --- | --- |
| `/hek` | Open the settings (`/hekili` works too) |
| `/hek move` · `/hek lock` | Unlock the displays to move them, lock them again |
| `/hek enable` · `/hek disable` | Turn the addon on or off |
| `/hek set` | List your class options and toggles, e.g. `/hek set cooldowns on`, `/hek set mode` |
| `/hek priority` | Show or change the rotation |
| `/hek profile` | Show or change the active profile |

---

## Notes for 3.3.5

The 3.3.5 client gives addons less information than the Classic client. What this changes:

- **Enemy count** comes from the combat log: enemies you hit, or that hit you, in the last few seconds. Nameplates cannot be read by addons on 3.3.5.
- **Haste** is your haste rating plus the common haste buffs (Bloodlust / Heroism, Icy Veins, Berserking, Power Infusion, Wrath of Air, Windfury Totem, Improved Icy Talons, Improved Moonkin Form, Swift Retribution, Blade Flurry).
- **Boss fights** are detected from the boss frames.
- **Shaman weapon imbues** are read from the weapon tooltip (English client).
- **Shaman options** (`/hek` > Shaman, or the minimap button menu): Chain Lightning on one enemy (on), Thunderstorm (off) and Fire Nova (on). Without its glyph, Thunderstorm knocks enemies back.
- Options that only exist on retail (covenants, nameplate detection, SpellFlash) are hidden.

Settings are saved in `WTF\Account\<ACCOUNT>\SavedVariables\Hekili.lua`.

---

## Links

- This version: https://github.com/saranwrap04/Hekili
- Report a problem: https://github.com/saranwrap04/Hekili/issues (`/hek` → Issue Reporting has your character data to paste in)
- WotLK sims: https://wowlegacysims.github.io/sims/wotlk/all/

## Credits

- **Hekili** and the Hekili contributors: the addon, its engine and all class priorities.
- Libraries: Ace3, LibStub, CallbackHandler, LibSharedMedia, LibDBIcon, LibDataBroker, LibDualSpec, LibRangeCheck, LibSpellRange, LibCustomGlow, LibCompress, LibDeflate, LibTranslit, LibChatAnims (3.3.5 versions from the WeakAuras WotLK and ElvUI WotLK backports).
