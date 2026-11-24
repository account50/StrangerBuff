# StrangerBuff

A World of Warcraft: Forever addon for buffing the players around you, not only your group.

It shows a small box listing nearby friendly players who are missing one of your buffs. Click a name, or scroll the mouse wheel, and they get the buff. It also keeps track of your own buffs and reminders on a **[Me]** row.

- Built for WoW Forever, client 1.60.x, interface 16001.
- Standalone: no other addons or libraries needed.
- Works for every class. The buff list comes from your spellbook and your bags.
- Everything is set up from an options window. No slash commands needed.

## Install

The addon has to end up in a folder named exactly `StrangerBuff` inside WoW Forever's AddOns folder:

| System | Default AddOns folder |
|---|---|
| macOS | `/Applications/World of Warcraft/_forever_/Interface/AddOns` |
| Windows | `C:\Program Files (x86)\World of Warcraft\_forever_\Interface\AddOns` |

`_forever_` is the folder for WoW Forever. Don't use `_retail_` or `_classic_era_`.

### Option 1: download the ZIP

1. On the [GitHub page](https://github.com/account50/StrangerBuff), click **Code**, then **Download ZIP**.
2. Unzip it. You get a folder named `StrangerBuff-main`.
3. Rename that folder to `StrangerBuff`. The game ignores it under any other name.
4. Move it into the AddOns folder above. `StrangerBuff.toc` should sit directly inside `AddOns/StrangerBuff`, not one folder deeper.

### Option 2: clone with git

Open a terminal in the AddOns folder and run:

```bash
git clone https://github.com/account50/StrangerBuff.git
```

To update later, run `git pull` inside `AddOns/StrangerBuff`.

### Option 3: macOS install script

If you keep the source somewhere else, run this from the source folder:

```bash
./install.sh
```

It copies the addon into the default macOS AddOns folder and only touches `AddOns/StrangerBuff`. Pass a different AddOns path as the first argument if your game is installed elsewhere.

### Check that it loaded

1. **Restart the game** after a first install. After an update, typing `/reload` in chat is enough.
2. At character select, open **AddOns** and make sure **StrangerBuff** is ticked.
3. In game, you should see the StrangerBuff box on screen and a StrangerBuff button on the minimap.
4. Turn on friendly player nameplates (**Shift+V**), or the box has nobody to list.

## How to use it

1. Turn on **friendly player nameplates** (Shift+V, or Esc > Options > Nameplates). The addon finds nearby players through their nameplates.
2. The **StrangerBuff box** lists nearby friendly players who are missing one of your buffs. Their names are class-colored, and icons show what each one is missing.
3. **Click a name** to cast their next missing buff on them. Click again for the next one. While your mouse is over the box, rows hold still, and anyone who gets fully buffed stays listed as "done" until you move away.
4. **Scroll the mouse wheel** (down by default) to buff:
   - over a **name in the box**: buffs that player;
   - over a **player in the world, or their nameplate**: buffs that player, if they're missing one of your buffs;
   - **anywhere else**: buffs the top player in range.
   The wheel is only taken over while there's someone to buff and you're out of combat. The rest of the time it zooms the camera as usual.
5. If your target is a friendly player missing buffs, they're listed near the top, marked **[T]**. You're listed first, marked **[Me]**, when you're missing one of your own buffs (option).
6. A buff with 10% or less of its time left also puts that player on the list, with an amber icon (the percentage is an option; 0 turns it off). It's only offered when your rank is at least as strong as the one they have, so the cast can't fail against a more powerful buff.
7. Buffing someone from the box selects them for a moment. If you had someone selected, you go straight back to them afterwards (option).

Open the options from the gear icon on the box, the minimap button, or Esc > Options > AddOns > StrangerBuff.

Optional key bindings are under Esc > Options > Keybindings > AddOns > StrangerBuff:
- **Buff my target**: casts the next missing buff on your target. Press again for the next one.
- **Buff the next nearby player**: does the same as the mouse wheel.
- **Buff the player under my mouse**: buffs the player your cursor is over.

Macro alternatives: `/click StrangerBuffTargetButton LeftButton 1`, `/click StrangerBuffNextButton LeftButton 1`, `/click StrangerBuffMouseoverButton LeftButton 1`.

## Buffs it knows

Tick the ones you want in options. Only buffs your character has learned are listed. The best rank is read from your spellbook.

| Class | For other players | For yourself (your [Me] row) |
|---|---|---|
| Priest | Power Word: Fortitude, Divine Spirit, Shadow Protection, Fear Ward | Inner Fire, Shadowguard, Touch of Weakness |
| Druid | Mark of the Wild, Thorns | Omen of Clarity |
| Mage | Arcane Intellect, Amplify Magic, Dampen Magic | Mage Armor / Ice Armor / Frost Armor |
| Shaman | Water Breathing, Water Walking | Lightning Shield / Water Shield; Windfury / Flametongue / Rockbiter / Frostbrand Weapon |
| Warlock | Unending Breath, Detect Invisibility | Demon Armor / Demon Skin |
| Paladin | Blessings of Kings, Wisdom, Might, Light, Sanctuary, Salvation | Righteous Fury; Devotion, Retribution, Concentration, Sanctity and resistance auras |
| Hunter | | Aspects (Hawk, Monkey, Cheetah, Pack, Beast, Wild), Trueshot Aura |
| Warrior | | Battle Shout |

Buffs separated by "/" are "one at a time" sets: having any of them up counts as buffed, and the first one you've ticked is the one offered. Buffs for other players also apply to you.

### Reminders for yourself (all off until you tick them)

These also show on your [Me] row. They aren't ordinary buffs, so each is checked its own way:

| What | Counts as done when | Click does |
|---|---|---|
| Paladin seals | Any seal is up | Casts the seal you ticked |
| Warrior stances, druid forms, Shadowform | You're in a stance or form you ticked | Switches to it |
| Hunter and warlock pets | A living pet is out (ignored while mounted) | Calls or summons it |
| Mage food, water and mana gems; warlock Healthstone, Soulstone, Spellstone, Firestone | One is in your bags (or held) | Conjures it. Warlock stones and most demons need a Soul Shard. |
| Rogue poisons, per hand | That weapon has a temporary enchant | Applies your best rank of the poison you ticked |
| Food | You have "Well Fed" | Eats the food you ticked |
| Flasks and elixirs | You have the buff with the same name as the item's effect | Drinks it |

Food, flasks, elixirs and poisons are recognised from what is in your bags, so they are only listed in options while you carry them. After the addon uses an item it won't offer it again for 30 seconds. If it still can't see the effect, it stops offering that item for the session instead of using up the stack.

Left out on purpose: short combat cooldowns, sharpening stones and oils, scrolls, and Stealth.

## How it reaches a player (Forever specifics)

Measured on this client: a cast aimed at your target or at the player under your cursor works. A cast or a targeting action aimed at a nameplate slot is ignored. So for a name in the box, the addon first selects the player from your click, by name. If the client refuses every name form, it switches (for that session) to stepping through nearby friendly players, one per click, until it reaches the right one, then buffs on the next click. Options > Diagnostics shows which path was used and whether it worked.

## Rules it follows

- Any rank of a buff, or its group version (Prayer of Fortitude, Gift of the Wild, Arcane Brilliance, Greater Blessings), counts as already buffed. A buff that still has time left is never overwritten.
- A buff in its last 10% (option) is offered as a refresh, but only when your rank is at least as strong as the one they have. If theirs is stronger, or its rank can't be read, they're left alone.
- Paladins: you keep at most one of your own blessings on a player. A blessing another paladin already put on them is never recast.
- Uses a lower rank on players too low for your top rank (option).
- Divine Spirit, Arcane Intellect and Blessing of Wisdom go only to mana users (per-buff option).
- Skips dead players, players out of range (shown dimmed), and for 5 seconds anyone a cast just failed on (for example, line of sight).
- Skips PvP-flagged players while you are not flagged yourself, so you don't get flagged by accident (option). Once you're flagged too, they're buffed like anyone else.
- Out of mana: nothing is cast, and one quiet chat line tells you.
- In combat the box pauses and every button is cleared. The game hides buff data from addons in combat. Everything resumes when combat ends.

## Limitations

- **Out of combat only.** The game hides buff data from addons during combat, so the box pauses.
- **Friendly nameplates must be on.** That is the only way an addon can see who is nearby.
- **Buffing from the box changes your target for a moment.** Forever gives addons no other way to reach a player who isn't your target or under your cursor. With the default setting you're returned to your previous target.
- **English client only for items.** Food, flasks, elixirs and poisons are recognised by English names and tooltip text.
- **An addon can't cast by itself.** Every cast comes from your own click, key press or wheel scroll.

## Troubleshooting

Options > **Diagnostics** opens a copyable report: what the client lets the addon see, which buffs it found for your character, who is listed and why, and recent activity. It's also saved to `WTF/Account/<account>/SavedVariables/StrangerBuff.lua` on `/reload`.

To see Lua errors, type `/console scriptErrors 1` in game.

## License

MIT. See [LICENSE](LICENSE).
