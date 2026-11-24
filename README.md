# StrangerBuff (WoW Forever, interface 16001)

Buff the random players around you, not only your group. This is a standalone addon. It doesn't need any other addon or library.

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

- Any rank of a buff, or its group version (Prayer of Fortitude, Gift of the Wild, Arcane Brilliance, Greater Blessings), counts as already buffed. It never overwrites someone else's buff.
- Paladins: you keep at most one of your own blessings on a player. A blessing another paladin already put on them is never recast.
- Uses a lower rank on players too low for your top rank (option).
- Divine Spirit, Arcane Intellect and Blessing of Wisdom go only to mana users (per-buff option).
- Skips dead players, players out of range (shown dimmed), PvP-flagged players unless you're already flagged (option), and for 5 seconds anyone a cast just failed on (for example, line of sight).
- Out of mana: nothing is cast, and one quiet chat line tells you.
- In combat the box pauses and every button is cleared. The game hides buff data from addons in combat. Everything resumes when combat ends.

## Troubleshooting

Options > **Diagnostics** opens a copyable report of what the client lets the addon see. It's also saved to `WTF/Account/<account>/SavedVariables/StrangerBuff.lua` on /reload.

## Install

Copy this folder into your WoW Forever `Interface/AddOns` folder as `StrangerBuff`, or clone it there:

```bash
git clone https://github.com/account50/StrangerBuff.git
```

On macOS with the default install location, `./install.sh` copies a working copy into the game folder. It only touches `AddOns/StrangerBuff`. Then `/reload`, or restart the game if the addon is new.
