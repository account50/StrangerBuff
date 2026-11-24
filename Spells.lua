-- StrangerBuff: buff families for every class, and spellbook lookups.
--
-- A family is one buff in all its ranks:
--   ids      single-target ranks, lowest first (Classic ids; Forever keeps them)
--   levels   level each rank is learned. A rank fails on a target more than 10
--            levels below it, so we downrank for low-level players.
--   group    group / greater versions that also count as "already has it"
--   groupEq  which single-target rank each group rank is as strong as
--   self     only castable on myself: shown on my own [Me] row only
--   excl     "one at a time" set (shields, armors, aspects, auras...): having any
--            member counts; the first ENABLED member I know is the one offered
--   weapon   temporary weapon enchant, not an aura (shaman imbues, poisons)
--   kind     how to tell it is active when it is not a plain buff:
--              "form"    stance / shapeshift bar (strict: only a ticked one counts)
--              "pet"     a living pet is out
--              "conjure" the product is in my bags (items = ids, match = name test)
--   label    display name when the spell names differ per rank
--   shard    needs a Soul Shard
--   itemID   (built at run time from my bags) food, flasks/elixirs, poisons
--   multi    each rank has its own name (Detect Lesser/…/Greater Invisibility)
--   manaOnly only useful to mana users (per-buff toggle, default on)
--   blessing paladin blessing: I can only keep one of mine on a player
--   default  enabled by default
-- Ranks I haven't listed are still found: the top rank comes from the spellbook.
local ADDON, ns = ...

ns.FAMILIES = {
  ---------------------------------------------------------------- Priest
  { key = "fort", class = "PRIEST", en = "Power Word: Fortitude", default = true,
    ids = { 1243, 1244, 1245, 2791, 10937, 10938 }, levels = { 1, 12, 24, 36, 48, 60 },
    group = { 21562, 21564 }, groupEq = { 5, 6 }, groupEn = "Prayer of Fortitude" },
  { key = "spirit", class = "PRIEST", en = "Divine Spirit", default = true, manaOnly = true,
    ids = { 14752, 14818, 14819, 27841 }, levels = { 30, 40, 50, 60 },
    group = { 27681 }, groupEq = { 4 }, groupEn = "Prayer of Spirit" },
  { key = "shadow", class = "PRIEST", en = "Shadow Protection", default = true,
    ids = { 976, 10957, 10958 }, levels = { 30, 42, 56 },
    group = { 27683 }, groupEq = { 3 }, groupEn = "Prayer of Shadow Protection" },
  { key = "fearward", class = "PRIEST", en = "Fear Ward", default = false,
    ids = { 6346 }, levels = { 20 } },
  { key = "innerfire", class = "PRIEST", en = "Inner Fire", default = true, self = true,
    ids = { 588, 7128, 602, 1006, 10951, 10952 }, levels = { 12, 20, 30, 40, 50, 60 } },
  { key = "shadowguard", class = "PRIEST", en = "Shadowguard", default = false, self = true,
    ids = { 18137, 19308, 19309, 19310, 19311, 19312 } },
  { key = "touchweak", class = "PRIEST", en = "Touch of Weakness", default = false, self = true,
    ids = { 2652, 19261, 19262, 19264, 19265, 19266 } },

  { key = "shadowform", class = "PRIEST", en = "Shadowform", default = false, self = true,
    ids = { 15473 } },

  ---------------------------------------------------------------- Druid
  { key = "motw", class = "DRUID", en = "Mark of the Wild", default = true,
    ids = { 1126, 5232, 6756, 5234, 8907, 9884, 9885 }, levels = { 1, 10, 20, 30, 40, 50, 60 },
    group = { 21849, 21850 }, groupEq = { 6, 7 }, groupEn = "Gift of the Wild" },
  { key = "thorns", class = "DRUID", en = "Thorns", default = false,
    ids = { 467, 782, 1075, 8914, 9756, 9910 }, levels = { 6, 14, 24, 34, 44, 54 } },
  { key = "omen", class = "DRUID", en = "Omen of Clarity", default = true, self = true,
    ids = { 16864 } },

  { key = "direbear", class = "DRUID", en = "Dire Bear Form", default = false, self = true, excl = "form", kind = "form",
    ids = { 9634 } },
  { key = "bear", class = "DRUID", en = "Bear Form", default = false, self = true, excl = "form", kind = "form",
    ids = { 5487 } },
  { key = "cat", class = "DRUID", en = "Cat Form", default = false, self = true, excl = "form", kind = "form",
    ids = { 768 } },
  { key = "moonkin", class = "DRUID", en = "Moonkin Form", default = false, self = true, excl = "form", kind = "form",
    ids = { 24858 } },
  { key = "travel", class = "DRUID", en = "Travel Form", default = false, self = true, excl = "form", kind = "form",
    ids = { 783 } },
  { key = "aquatic", class = "DRUID", en = "Aquatic Form", default = false, self = true, excl = "form", kind = "form",
    ids = { 1066 } },

  ---------------------------------------------------------------- Mage
  { key = "ai", class = "MAGE", en = "Arcane Intellect", default = true, manaOnly = true,
    ids = { 1459, 1460, 1461, 10156, 10157 }, levels = { 1, 14, 28, 42, 56 },
    group = { 23028 }, groupEq = { 5 }, groupEn = "Arcane Brilliance" },
  { key = "magearmor", class = "MAGE", en = "Mage Armor", default = false, self = true, excl = "magearmor",
    ids = { 6117, 22782, 22783 }, levels = { 34, 46, 58 } },
  { key = "icearmor", class = "MAGE", en = "Ice Armor", default = true, self = true, excl = "magearmor",
    ids = { 7302, 7320, 10219, 10220 }, levels = { 30, 40, 50, 60 } },
  { key = "frostarmor", class = "MAGE", en = "Frost Armor", default = true, self = true, excl = "magearmor",
    ids = { 168, 7300, 7301 }, levels = { 1, 10, 20 } },
  { key = "amplify", class = "MAGE", en = "Amplify Magic", default = false, excl = "magemagic",
    ids = { 1008, 8455, 10169, 10170 }, levels = { 18, 30, 42, 54 } },
  { key = "dampen", class = "MAGE", en = "Dampen Magic", default = false, excl = "magemagic",
    ids = { 604, 8450, 8451, 10173, 10174 }, levels = { 12, 24, 36, 48, 60 } },

  { key = "conjwater", class = "MAGE", en = "Conjure Water", default = false, self = true, kind = "conjure",
    ids = { 5504, 5505, 5506, 6127, 10138, 10139, 10140 },
    items = { 5350, 2288, 2136, 3772, 8077, 8078, 8079 },
    match = function(n) return n:find("^Conjured ") and n:find("Water") end },
  { key = "conjfood", class = "MAGE", en = "Conjure Food", default = false, self = true, kind = "conjure",
    ids = { 587, 597, 990, 6129, 10144, 10145, 28612 },
    items = { 5349, 1113, 1114, 1487, 8075, 8076, 22895 },
    match = function(n) return n:find("^Conjured ") and not n:find("Water") end },
  { key = "gemagate", class = "MAGE", en = "Conjure Mana Agate", default = false, self = true, kind = "conjure",
    ids = { 759 }, items = { 5514 }, match = function(n) return n == "Mana Agate" end },
  { key = "gemjade", class = "MAGE", en = "Conjure Mana Jade", default = false, self = true, kind = "conjure",
    ids = { 3552 }, items = { 5513 }, match = function(n) return n == "Mana Jade" end },
  { key = "gemcitrine", class = "MAGE", en = "Conjure Mana Citrine", default = false, self = true, kind = "conjure",
    ids = { 10053 }, items = { 8007 }, match = function(n) return n == "Mana Citrine" end },
  { key = "gemruby", class = "MAGE", en = "Conjure Mana Ruby", default = false, self = true, kind = "conjure",
    ids = { 10054 }, items = { 8008 }, match = function(n) return n == "Mana Ruby" end },

  ---------------------------------------------------------------- Shaman
  { key = "lshield", class = "SHAMAN", en = "Lightning Shield", default = true, self = true, excl = "shamanshield",
    ids = { 324, 325, 905, 945, 8134, 10431, 10432 }, levels = { 8, 16, 24, 32, 40, 48, 56 } },
  { key = "wshield", class = "SHAMAN", en = "Water Shield", default = false, self = true, excl = "shamanshield",
    ids = { 408510 } },
  { key = "windfury", class = "SHAMAN", en = "Windfury Weapon", default = false, self = true, excl = "imbue", weapon = true,
    ids = { 8232, 8235, 10486, 16362 } },
  { key = "flametongue", class = "SHAMAN", en = "Flametongue Weapon", default = false, self = true, excl = "imbue", weapon = true,
    ids = { 8024, 8027, 8030, 16339, 16341, 16342 } },
  { key = "rockbiter", class = "SHAMAN", en = "Rockbiter Weapon", default = false, self = true, excl = "imbue", weapon = true,
    ids = { 8017, 8018, 8019, 10399, 16314, 16315, 16316 } },
  { key = "frostbrand", class = "SHAMAN", en = "Frostbrand Weapon", default = false, self = true, excl = "imbue", weapon = true,
    ids = { 8033, 8038, 10456, 16355, 16356 } },
  { key = "waterbreath", class = "SHAMAN", en = "Water Breathing", default = false,
    ids = { 131 }, levels = { 22 } },
  { key = "waterwalk", class = "SHAMAN", en = "Water Walking", default = false,
    ids = { 546 }, levels = { 28 } },

  ---------------------------------------------------------------- Warlock
  { key = "demonarmor", class = "WARLOCK", en = "Demon Armor", default = true, self = true, excl = "lockarmor",
    ids = { 706, 1086, 11733, 11734, 11735 }, levels = { 20, 30, 40, 50, 60 } },
  { key = "demonskin", class = "WARLOCK", en = "Demon Skin", default = true, self = true, excl = "lockarmor",
    ids = { 687, 696 }, levels = { 1, 10 } },
  { key = "unendingbreath", class = "WARLOCK", en = "Unending Breath", default = false,
    ids = { 5697 }, levels = { 16 } },
  { key = "detectinvis", class = "WARLOCK", en = "Detect Invisibility", default = false, multi = true,
    ids = { 6512, 132, 11743 }, levels = { 26, 38, 50 } },

  { key = "healthstone", class = "WARLOCK", en = "Create Healthstone", label = "Healthstone", default = false, self = true,
    kind = "conjure", multi = true, shard = true,
    ids = { 6201, 6202, 5699, 11729, 11730 }, match = function(n) return n:find("Healthstone") end },
  { key = "soulstone", class = "WARLOCK", en = "Create Soulstone", label = "Soulstone", default = false, self = true,
    kind = "conjure", multi = true, shard = true,
    ids = { 693, 20752, 20755, 20756, 20757 }, match = function(n) return n:find("Soulstone") end },
  { key = "spellstone", class = "WARLOCK", en = "Create Spellstone", label = "Spellstone", default = false, self = true,
    kind = "conjure", multi = true, shard = true,
    ids = { 2362, 17727, 17728 }, match = function(n) return n:find("Spellstone") end },
  { key = "firestone", class = "WARLOCK", en = "Create Firestone", label = "Firestone", default = false, self = true,
    kind = "conjure", multi = true, shard = true,
    ids = { 6366, 17951, 17952, 17953 }, match = function(n) return n:find("Firestone") end },
  { key = "imp", class = "WARLOCK", en = "Summon Imp", default = false, self = true, excl = "pet", kind = "pet",
    ids = { 688 } },
  { key = "voidwalker", class = "WARLOCK", en = "Summon Voidwalker", default = false, self = true, excl = "pet", kind = "pet", shard = true,
    ids = { 697 } },
  { key = "succubus", class = "WARLOCK", en = "Summon Succubus", default = false, self = true, excl = "pet", kind = "pet", shard = true,
    ids = { 712 } },
  { key = "incubus", class = "WARLOCK", en = "Summon Incubus", default = false, self = true, excl = "pet", kind = "pet", shard = true,
    ids = { 713 } },
  { key = "felhunter", class = "WARLOCK", en = "Summon Felhunter", default = false, self = true, excl = "pet", kind = "pet", shard = true,
    ids = { 691 } },

  ---------------------------------------------------------------- Hunter
  { key = "hawk", class = "HUNTER", en = "Aspect of the Hawk", default = true, self = true, excl = "aspect",
    ids = { 13165, 14318, 14319, 14320, 14321, 14322, 25296 } },
  { key = "monkey", class = "HUNTER", en = "Aspect of the Monkey", default = false, self = true, excl = "aspect",
    ids = { 13163 } },
  { key = "cheetah", class = "HUNTER", en = "Aspect of the Cheetah", default = false, self = true, excl = "aspect",
    ids = { 5118 } },
  { key = "pack", class = "HUNTER", en = "Aspect of the Pack", default = false, self = true, excl = "aspect",
    ids = { 13159 } },
  { key = "beast", class = "HUNTER", en = "Aspect of the Beast", default = false, self = true, excl = "aspect",
    ids = { 13161 } },
  { key = "wild", class = "HUNTER", en = "Aspect of the Wild", default = false, self = true, excl = "aspect",
    ids = { 20043, 20190 } },
  { key = "trueshot", class = "HUNTER", en = "Trueshot Aura", default = true, self = true,
    ids = { 19506, 20905, 20906 } },

  { key = "callpet", class = "HUNTER", en = "Call Pet", default = false, self = true, excl = "pet", kind = "pet",
    ids = { 883 } },

  ---------------------------------------------------------------- Warrior
  { key = "battleshout", class = "WARRIOR", en = "Battle Shout", default = false, self = true,
    ids = { 6673, 5242, 6192, 11549, 11550, 11551, 25289 } },

  { key = "battlestance", class = "WARRIOR", en = "Battle Stance", default = false, self = true, excl = "stance", kind = "form",
    ids = { 2457 } },
  { key = "defstance", class = "WARRIOR", en = "Defensive Stance", default = false, self = true, excl = "stance", kind = "form",
    ids = { 71 } },
  { key = "berstance", class = "WARRIOR", en = "Berserker Stance", default = false, self = true, excl = "stance", kind = "form",
    ids = { 2458 } },

  ---------------------------------------------------------------- Paladin
  { key = "kings", class = "PALADIN", en = "Blessing of Kings", default = true, blessing = true,
    ids = { 20217 }, levels = { 20 },
    group = { 25898 }, groupEq = { 1 }, groupEn = "Greater Blessing of Kings" },
  { key = "wisdom", class = "PALADIN", en = "Blessing of Wisdom", default = true, blessing = true, manaOnly = true,
    ids = { 19742, 19850, 19852, 19853, 19854, 25290 }, levels = { 14, 24, 34, 44, 54, 60 },
    group = { 25894, 25918 }, groupEq = { 5, 6 }, groupEn = "Greater Blessing of Wisdom" },
  { key = "might", class = "PALADIN", en = "Blessing of Might", default = true, blessing = true,
    ids = { 19740, 19834, 19835, 19836, 19837, 19838, 25291 }, levels = { 4, 12, 22, 32, 42, 52, 60 },
    group = { 25782, 25916 }, groupEq = { 6, 7 }, groupEn = "Greater Blessing of Might" },
  { key = "light", class = "PALADIN", en = "Blessing of Light", default = false, blessing = true,
    ids = { 19977, 19978, 19979 }, levels = { 40, 50, 60 },
    group = { 25890 }, groupEq = { 3 }, groupEn = "Greater Blessing of Light" },
  { key = "sanc", class = "PALADIN", en = "Blessing of Sanctuary", default = false, blessing = true,
    ids = { 20911, 20912, 20913, 20914 }, levels = { 30, 40, 50, 60 },
    group = { 25899 }, groupEq = { 4 }, groupEn = "Greater Blessing of Sanctuary" },
  { key = "salv", class = "PALADIN", en = "Blessing of Salvation", default = false, blessing = true,
    ids = { 1038 }, levels = { 26 },
    group = { 25895 }, groupEq = { 1 }, groupEn = "Greater Blessing of Salvation" },
  { key = "rfury", class = "PALADIN", en = "Righteous Fury", default = false, self = true,
    ids = { 25780 } },
  { key = "devotion", class = "PALADIN", en = "Devotion Aura", default = false, self = true, excl = "paladinaura",
    ids = { 465, 10290, 643, 10291, 1032, 10292, 10293 } },
  { key = "retribution", class = "PALADIN", en = "Retribution Aura", default = false, self = true, excl = "paladinaura",
    ids = { 7294, 10298, 10299, 10300, 10301 } },
  { key = "concentration", class = "PALADIN", en = "Concentration Aura", default = false, self = true, excl = "paladinaura",
    ids = { 19746 } },
  { key = "sanctity", class = "PALADIN", en = "Sanctity Aura", default = false, self = true, excl = "paladinaura",
    ids = { 20218 } },
  { key = "fireaura", class = "PALADIN", en = "Fire Resistance Aura", default = false, self = true, excl = "paladinaura",
    ids = { 19891, 19899, 19900 } },
  { key = "frostaura", class = "PALADIN", en = "Frost Resistance Aura", default = false, self = true, excl = "paladinaura",
    ids = { 19888, 19897, 19898 } },
  { key = "shadowaura", class = "PALADIN", en = "Shadow Resistance Aura", default = false, self = true, excl = "paladinaura",
    ids = { 19876, 19895, 19896 } },
  { key = "sealright", class = "PALADIN", en = "Seal of Righteousness", default = false, self = true, excl = "seal",
    ids = { 21084, 20287, 20288, 20289, 20290, 20291, 20292, 20293 } },
  { key = "sealcommand", class = "PALADIN", en = "Seal of Command", default = false, self = true, excl = "seal",
    ids = { 20375, 20915, 20918, 20919, 20920 } },
  { key = "sealcrusader", class = "PALADIN", en = "Seal of the Crusader", default = false, self = true, excl = "seal",
    ids = { 21082, 20162, 20305, 20306, 20307, 20308 } },
  { key = "sealwisdom", class = "PALADIN", en = "Seal of Wisdom", default = false, self = true, excl = "seal",
    ids = { 20166, 20356, 20357 } },
  { key = "seallight", class = "PALADIN", en = "Seal of Light", default = false, self = true, excl = "seal",
    ids = { 20165, 20347, 20348, 20349 } },
  { key = "sealjustice", class = "PALADIN", en = "Seal of Justice", default = false, self = true, excl = "seal",
    ids = { 20164 } },
  { key = "sealfury", class = "PALADIN", en = "Seal of Fury", default = false, self = true, excl = "seal",
    ids = { 1311649 } },
}

ns.FAMILY_BY_KEY = {}
ns.FAMILY_BY_SPELL = {}
ns.EXCL = {} -- [set name] = { families in list order }
local STATIC_EXCL = {}
for _, fam in ipairs(ns.FAMILIES) do
  ns.FAMILY_BY_KEY[fam.key] = fam
  for _, id in ipairs(fam.ids) do ns.FAMILY_BY_SPELL[id] = fam end
  if fam.excl then
    STATIC_EXCL[fam.excl] = STATIC_EXCL[fam.excl] or {}
    table.insert(STATIC_EXCL[fam.excl], fam)
  end
end
for k, v in pairs(STATIC_EXCL) do ns.EXCL[k] = v end

-------------------------------------------------------------------------------
-- Names and icons
-------------------------------------------------------------------------------
local function nameFromAPI(id)
  if C_Spell and C_Spell.GetSpellName then
    local ok, n = pcall(C_Spell.GetSpellName, id)
    if ok and type(n) == "string" and not ns.IsSecret(n) and n ~= "" then return n end
  end
  if C_Spell and C_Spell.GetSpellInfo then
    local ok, info = pcall(C_Spell.GetSpellInfo, id)
    if ok and type(info) == "table" and type(info.name) == "string" and not ns.IsSecret(info.name) then return info.name end
  end
  if GetSpellInfo then
    local ok, n = pcall(GetSpellInfo, id)
    if ok and type(n) == "string" and not ns.IsSecret(n) then return n end
  end
  return nil
end
ns.SpellNameFromAPI = nameFromAPI

function ns.SpellIcon(spell)
  if C_Spell and C_Spell.GetSpellTexture then
    local ok, t = pcall(C_Spell.GetSpellTexture, spell)
    if ok and t and not ns.IsSecret(t) then return t end
  end
  if GetSpellTexture then
    local ok, t = pcall(GetSpellTexture, spell)
    if ok and t and not ns.IsSecret(t) then return t end
  end
  return "Interface\\Icons\\INV_Misc_QuestionMark"
end

function ns.FamilyIcon(fam)
  if fam.itemID then
    if C_Item and C_Item.GetItemIconByID then
      local ok, t = pcall(C_Item.GetItemIconByID, fam.itemID)
      if ok and t then return t end
    end
    return "Interface\\Icons\\INV_Misc_QuestionMark"
  end
  return ns.SpellIcon(fam.top or fam.ids[1])
end

function ns.FamilyName(fam)
  fam._name = fam._name or fam.label or nameFromAPI(fam.ids[1]) or fam.en
  return fam._name
end

function ns.FamilyGroupName(fam)
  if not fam.group then return nil end
  fam._groupName = fam._groupName or nameFromAPI(fam.group[1]) or fam.groupEn
  return fam._groupName
end

-- Every aura name that means "they have this buff".
function ns.FamilyAuraNames(fam)
  if fam._auraNames then return fam._auraNames end
  local list, seen = {}, {}
  local function add(n)
    if n and not seen[n] then seen[n] = true list[#list + 1] = n end
  end
  add(ns.FamilyName(fam))
  if fam.multi then
    for _, id in ipairs(fam.ids) do add(nameFromAPI(id)) end
  end
  add(ns.FamilyGroupName(fam))
  fam._auraNames = list
  return list
end

-- Which family does a cast spell belong to (any rank, listed or not)?
function ns.FamilyOfSpell(spellID)
  local fam = ns.FAMILY_BY_SPELL[spellID]
  if fam then return fam end
  local n = nameFromAPI(spellID)
  if not n then return nil end
  ns._famByName = ns._famByName or {}
  if ns._famByName[n] == nil then
    local found = false
    for _, f in ipairs(ns.FAMILIES) do
      if (nameFromAPI(f.ids[1]) or f.en) == n then found = f break end
    end
    ns._famByName[n] = found
  end
  return ns._famByName[n] or nil
end

-------------------------------------------------------------------------------
-- What do I know?
-------------------------------------------------------------------------------
function ns.IsKnown(id)
  local tries = { IsPlayerSpell, IsSpellKnown, C_SpellBook and C_SpellBook.IsSpellKnown }
  for i = 1, #tries do
    if type(tries[i]) == "function" then
      local ok, r = pcall(tries[i], id)
      if ok and ns.Bool(r) == true then return true end
    end
  end
  return false
end

-- Spellbook scan: [spell name] = { ids in book order (lowest rank first) }.
-- This is how ranks I didn't list (or Forever-only ranks) are found.
local function ScanSpellbook()
  local byName = {}
  local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player
  if not (C_SpellBook and C_SpellBook.GetSpellBookItemName and C_SpellBook.GetSpellBookItemType and bank) then return byName end
  for i = 1, 1000 do
    local okN, name = pcall(C_SpellBook.GetSpellBookItemName, i, bank)
    if not okN or name == nil then break end
    local okT, _, id = pcall(C_SpellBook.GetSpellBookItemType, i, bank)
    if okT and type(name) == "string" and not ns.IsSecret(name) and type(id) == "number" and not ns.IsSecret(id) and ns.IsKnown(id) then
      byName[name] = byName[name] or {}
      table.insert(byName[name], id)
    end
  end
  return byName
end

local function RankNumber(id)
  if not (C_Spell and C_Spell.GetSpellSubtext) then return nil end
  local ok, sub = pcall(C_Spell.GetSpellSubtext, id)
  if not ok or type(sub) ~= "string" or ns.IsSecret(sub) then return nil end
  return tonumber(sub:match("(%d+)"))
end

-- Rebuild the list of families I can cast.
--   fam.known = ranks I know, lowest first: { id =, level = }
--   fam.top   = the best rank to cast (id), or the spell name if only that is known
function ns.RebuildKnown()
  local book = ScanSpellbook()
  local known = {}
  for _, fam in ipairs(ns.FAMILIES) do
    local ranks, have = {}, {}
    for i, id in ipairs(fam.ids) do
      if ns.IsKnown(id) then
        ranks[#ranks + 1] = { id = id, level = fam.levels and fam.levels[i] or 1 }
        have[id] = true
      end
    end
    -- Ranks in my spellbook under this name that the table doesn't list.
    if not fam.multi then
      local extra = book[nameFromAPI(fam.ids[1]) or fam.en]
      if extra then
        local best, bestRank = nil, -1
        for order, id in ipairs(extra) do
          if not have[id] then
            local r = RankNumber(id) or order
            if r > bestRank then best, bestRank = id, r end
          end
        end
        if best then
          -- Use it when I know no listed rank, or when it is provably a higher rank.
          local last = ranks[#ranks]
          local lastRank = last and RankNumber(last.id)
          local realRank = RankNumber(best)
          if not last or (lastRank and realRank and realRank > lastRank) then
            ranks[#ranks + 1] = { id = best, level = last and last.level or 1 }
          end
        end
      end
    end
    fam.known = #ranks > 0 and ranks or nil
    fam.top = fam.known and ranks[#ranks].id or nil
    if fam.known then known[#known + 1] = fam end
  end
  -- Food, flasks/elixirs and poisons found in my bags.
  for k in pairs(ns.EXCL) do ns.EXCL[k] = nil end
  for k, v in pairs(STATIC_EXCL) do ns.EXCL[k] = v end
  if ns.ItemFamilies then
    for _, fam in ipairs(ns.ItemFamilies()) do
      known[#known + 1] = fam
      ns.FAMILY_BY_KEY[fam.key] = fam
      if fam.excl then
        ns.EXCL[fam.excl] = ns.EXCL[fam.excl] or {}
        table.insert(ns.EXCL[fam.excl], fam)
      end
    end
  end
  ns.known = known
  return known
end

function ns.IsEnabled(fam)
  local v = ns.db and ns.db.buffs[fam.key]
  if v == nil then return fam.default and true or false end
  return v
end

function ns.IsManaOnly(fam)
  if not fam.manaOnly then return false end
  local v = ns.db and ns.db.manaOnly[fam.key]
  if v == nil then return true end
  return v
end

-------------------------------------------------------------------------------
-- Bags: food, flasks / elixirs and poisons are recognised from what I carry,
-- not from a fixed list, so Forever-only items work too.
--   food    tooltip says it makes you "well fed"      -> buff "Well Fed"
--   flask   name contains Flask or Elixir             -> buff named like its use effect
--   poison  (rogues) name contains Poison             -> weapon enchant, per hand
-------------------------------------------------------------------------------
local bagCount = {}   -- [itemID] = how many I carry
local itemClass = {}  -- [itemID] = { name =, kind = "food"/"flask"/"poison"/false, aura =, base =, rank = }
local itemFams = {}   -- [family key] = family (kept so options rows and timers stay attached)

function ns.BagCount(id) return bagCount[id] or 0 end

function ns.ScanBags()
  for k in pairs(bagCount) do bagCount[k] = nil end
  if not (C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo) then return end
  for bag = 0, 4 do
    local okN, n = pcall(C_Container.GetContainerNumSlots, bag)
    if okN and type(n) == "number" then
      for slot = 1, n do
        local ok, info = pcall(C_Container.GetContainerItemInfo, bag, slot)
        if ok and type(info) == "table" and type(info.itemID) == "number" then
          bagCount[info.itemID] = (bagCount[info.itemID] or 0) + (tonumber(info.stackCount) or 1)
        end
      end
    end
  end
end

local function ItemName(id)
  if C_Item and C_Item.GetItemNameByID then
    local ok, n = pcall(C_Item.GetItemNameByID, id)
    if ok and type(n) == "string" and n ~= "" then return n end
  end
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
  return nil -- not cached yet; GET_ITEM_INFO_RECEIVED triggers another look
end

local function ItemUseSpell(id)
  local f = (C_Item and C_Item.GetItemSpell) or GetItemSpell
  if type(f) ~= "function" then return nil end
  local ok, n = pcall(f, id)
  if ok and type(n) == "string" and n ~= "" then return n end
  return nil
end

local function TooltipMentions(id, needle)
  if not (C_TooltipInfo and C_TooltipInfo.GetItemByID) then return false end
  local ok, data = pcall(C_TooltipInfo.GetItemByID, id)
  if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
  for _, line in ipairs(data.lines) do
    local t = line.leftText
    if type(t) == "string" and not ns.IsSecret(t) and t:lower():find(needle, 1, true) then return true end
  end
  return false
end

local ROMAN = { I = 1, II = 2, III = 3, IV = 4, V = 5, VI = 6, VII = 7, VIII = 8, IX = 9, X = 10 }

local function Classify(id)
  local c = itemClass[id]
  if c then return c end
  local name = ItemName(id)
  if not name then return nil end
  c = { name = name, kind = false }
  local use = ItemUseSpell(id)
  if use then
    local _, class = UnitClass("player")
    if name:find("Poison") and class == "ROGUE" then
      c.kind = "poison"
      local base, numeral = name:match("^(.-)%s+([IVX]+)$")
      c.base, c.rank = base or name, numeral and ROMAN[numeral] or 0
    elseif name:find("Flask") or name:find("Elixir") then
      c.kind, c.aura = "flask", use
    elseif TooltipMentions(id, "well fed") then
      c.kind = "food"
    end
  end
  itemClass[id] = c
  return c
end

-- Does any carried (or held) item satisfy a "conjure" family?
function ns.HasProduct(fam)
  for _, id in ipairs(fam.items or {}) do
    if (bagCount[id] or 0) > 0 then return true end
  end
  if fam.match then
    for id in pairs(bagCount) do
      local c = Classify(id)
      if c and fam.match(c.name) then return true end
    end
    -- Spellstones and firestones are held in a hand once made.
    for _, slot in ipairs({ 16, 17, 18 }) do
      local ok, id = pcall(GetInventoryItemID, "player", slot)
      local n = ok and type(id) == "number" and ItemName(id)
      if n and fam.match(n) then return true end
    end
  end
  return false
end

local function Fam(key, fields)
  local f = itemFams[key] or { key = key, ids = {}, self = true, default = false, dynamic = true, known = {} }
  for k, v in pairs(fields) do f[k] = v end
  itemFams[key] = f
  return f
end

-- Families for what is in my bags right now, sorted by name.
function ns.ItemFamilies()
  local out, poisons = {}, {}
  for id, n in pairs(bagCount) do
    local c = n > 0 and Classify(id)
    if c and c.kind == "food" then
      out[#out + 1] = Fam("food:" .. id, { _name = c.name, itemID = id, excl = "food", _auraNames = { "Well Fed" }, sort = "1" .. c.name })
    elseif c and c.kind == "flask" then
      out[#out + 1] = Fam("item:" .. id, { _name = c.name, itemID = id, _auraNames = { c.aura }, oneShot = true, sort = "2" .. c.name })
    elseif c and c.kind == "poison" then
      local best = poisons[c.base]
      if not best or c.rank > best.rank then poisons[c.base] = { id = id, rank = c.rank } end
    end
  end
  for base, best in pairs(poisons) do
    out[#out + 1] = Fam("poison:" .. base .. ":16", { _name = base .. " (main hand)", itemID = best.id, excl = "mhpoison",
      weapon = true, slot = 16, dur = 1800, sort = "3" .. base })
    out[#out + 1] = Fam("poison:" .. base .. ":17", { _name = base .. " (off hand)", itemID = best.id, excl = "ohpoison",
      weapon = true, slot = 17, dur = 1800, sort = "4" .. base })
  end
  table.sort(out, function(a, b) return a.sort < b.sort end)
  return out
end

-- The macro that uses a bag item (on a weapon for poisons).
function ns.ItemMacro(fam, replacing)
  local text = "/use item:" .. fam.itemID
  if fam.slot then
    text = text .. "\n/use " .. fam.slot
    -- Replacing a poison that is still on the weapon asks for confirmation.
    if replacing then text = text .. "\n/click StaticPopup1Button1" end
  end
  return text
end
