-- StrangerBuff: who needs what, and pointing secure buttons at them.
--
-- Platform rules this file follows:
--  * The addon never casts by itself. Rows, the "next" button (mouse wheel) and the
--    "target" button are SecureActionButtons; the player's click or key press casts.
--  * Attributes are only changed out of combat. In combat everything is cleared and
--    frozen, and resumes on PLAYER_REGEN_ENABLED.
--  * Each click re-resolves the player from their GUID/name right before casting
--    (PreClick), because nameplate tokens get reused as people come and go.
local ADDON, ns = ...
local Call, Bool, IsSecret = ns.Call, ns.Bool, ns.IsSecret

local MAX_PLATES = 40
local SKIP_AFTER_FAIL = 5     -- seconds to skip a player after a failed cast
local CAST_GRACE = 4          -- seconds to assume a just-cast buff landed before UNIT_AURA confirms

local state = {
  firstSeen = {},   -- [key] = GetTime() first seen on a nameplate
  skipUntil = {},   -- [key] = time
  justCast = {},    -- [key .. ":" .. famKey] = time until which we treat the buff as present
  myBlessing = {},  -- [key] = famKey of the blessing I last put on them
  attempt = nil,    -- { key, fam, t } last click we prepared
  itemTry = {},     -- [family key] = { t =, n = } last time I used that item from here
  oom = false,
  inCombat = false,
  list = {},
  status = "",
}
ns.state = state

-------------------------------------------------------------------------------
-- Unit helpers
-------------------------------------------------------------------------------
local function UnitKey(unit)
  local g = Call(UnitGUID, unit)
  if type(g) == "string" and g ~= "" then return g end
  local n, r = nil, nil
  local ok, a, b = pcall(UnitName, unit)
  if ok and not IsSecret(a) and type(a) == "string" then n = a end
  if ok and not IsSecret(b) and type(b) == "string" and b ~= "" then r = b end
  if n then return r and (n .. "-" .. r) or n end
  return nil
end
ns.UnitKey = UnitKey

local function UnitShortName(unit)
  local ok, n = pcall(UnitName, unit)
  if ok and not IsSecret(n) and type(n) == "string" then return n end
  return "?"
end

local function IsTrue(fn, ...) return Bool(Call(fn, ...)) == true end

local function IsManaUser(unit)
  local pt = Call(UnitPowerType, unit)
  if pt == 0 then return true end
  local ok, _, class = pcall(UnitClass, unit)
  if ok and not IsSecret(class) and class == "DRUID" then return true end
  return false
end

-- Why a unit can't be buffed right now, or nil if it can.
local function Ineligible(unit)
  if not IsTrue(UnitExists, unit) then return "gone" end
  if not IsTrue(UnitIsPlayer, unit) then return "not a player" end
  if IsTrue(UnitIsUnit, unit, "player") then
    -- Me: listed like anyone else when I'm missing one of my own buffs (option).
    if not ns.db.includeSelf then return "self" end
    if IsTrue(UnitIsDeadOrGhost, unit) then return "dead" end
    return nil
  end
  if not IsTrue(UnitCanAssist, "player", unit) then return "not friendly" end
  if IsTrue(UnitIsDeadOrGhost, unit) then return "dead" end
  local conn = Call(UnitIsConnected, unit)
  if conn == false then return "offline" end
  if ns.db.skipPvP and IsTrue(UnitIsPVP, unit) and not IsTrue(UnitIsPVP, "player") then return "pvp" end
  return nil
end
ns.Ineligible = Ineligible

-------------------------------------------------------------------------------
-- Aura reading. Returns present = true/false, or nil when the client won't say.
-------------------------------------------------------------------------------
local function IsMine(src)
  if src == nil or IsSecret(src) then return false end
  return IsTrue(UnitIsUnit, src, "player")
end

-- One pass over the unit's buffs by index. nil if the client blocks it.
local function Snapshot(unit)
  local f = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if type(f) ~= "function" then return nil end
  local set = {}
  for i = 1, 40 do
    local ok, a = pcall(f, unit, i, "HELPFUL")
    if not ok or IsSecret(a) then return nil end
    if a == nil then break end
    local n = a.name
    if IsSecret(n) or type(n) ~= "string" then return nil end
    local mine = IsMine(a.sourceUnit)
    set[n] = { mine = (set[n] and set[n].mine) or mine, aura = a }
  end
  return set
end

-- Temporary weapon enchant (shaman imbues): not an aura, and only readable for me.
local function WeaponEnchant(slot)
  if type(GetWeaponEnchantInfo) ~= "function" then return nil end
  local ok, mh, mhMs, _, _, oh, ohMs = pcall(GetWeaponEnchantInfo)
  if not ok then return nil end
  local has, ms = mh, mhMs
  if slot == 17 then has, ms = oh, ohMs end
  if IsSecret(has) then return nil end
  if not has then return false end
  local left = (not IsSecret(ms) and type(ms) == "number") and ms / 1000 or nil
  return true, left
end

-- Which family is the active stance / form (nil if none)?
local function ActiveForm()
  local n = Call(GetNumShapeshiftForms)
  if type(n) ~= "number" then return nil, false end
  for i = 1, n do
    local ok, _, active, _, spellID = pcall(GetShapeshiftFormInfo, i)
    if ok and Bool(active) == true and type(spellID) == "number" and not IsSecret(spellID) then
      return ns.FamilyOfSpell(spellID), true
    end
  end
  return nil, true
end

local function PetIsOut()
  if IsTrue(IsMounted) then return true end -- pets hide while mounted; don't nag
  return IsTrue(UnitExists, "pet") and not IsTrue(UnitIsDeadOrGhost, "pet")
end

-- present (true/false/nil), mine (bool), aura data (when present)
local function HasFamily(unit, fam, snap)
  if fam.weapon then
    local has, left = WeaponEnchant(fam.slot)
    if has == nil then return nil, false end
    if not has then return false, false end
    -- Total time (imbues 5 min, poisons 30) is all we need to spot one running out.
    return true, true, { duration = fam.dur or 300, expirationTime = left and (GetTime() + left) or 0 }
  end
  if fam.kind == "form" then
    local active, ok = ActiveForm()
    if ok then return active == fam, true end
    -- no stance bar API: fall through to the buff list
  elseif fam.kind == "pet" then
    return PetIsOut(), true
  elseif fam.kind == "conjure" then
    return ns.HasProduct(fam), true
  end
  local names = ns.FamilyAuraNames(fam)
  if snap then
    for i = 1, #names do
      local hit = snap[names[i]]
      if hit then return true, hit.mine, hit.aura end
    end
    return false, false
  end
  local f = C_UnitAuras and C_UnitAuras.GetAuraDataBySpellName
  if type(f) ~= "function" then return nil, false end
  local unknown = false
  for i = 1, #names do
    local ok, a = pcall(f, unit, names[i], "HELPFUL")
    if not ok or IsSecret(a) then
      unknown = true
    elseif a then
      return true, IsMine(a.sourceUnit), a
    end
  end
  if unknown then return nil, false end
  return false, false
end

-- Is this buff in its last few percent (option, default 10%)?
local function Expiring(a)
  local pct = ns.db.refreshPct or 0
  if pct <= 0 or type(a) ~= "table" then return false end
  local d, e = a.duration, a.expirationTime
  if IsSecret(d) or IsSecret(e) or type(d) ~= "number" or type(e) ~= "number" then return false end
  if d <= 0 or e <= 0 then return false end -- no duration: permanent (auras, aspects)
  return (e - GetTime()) <= d * pct / 100
end

local function IndexOf(list, v)
  for i = 1, #(list or {}) do if list[i] == v then return i end end
  return nil
end

-- Would my `spell` replace the buff they have? A weaker rank can't overwrite a
-- stronger one ("a more powerful spell is already active"), so only offer a
-- refresh when my rank is at least as strong as theirs. Unknown: don't offer.
-- Buffs only I can put on myself are always mine to refresh.
local function CanRefresh(fam, a, spell)
  if fam.self then return true end
  local id = a.spellId
  if IsSecret(id) or type(id) ~= "number" then return false end
  local mineIdx = IndexOf(fam.ids, spell)
  local theirs = IndexOf(fam.ids, id)
  if not theirs then
    local g = IndexOf(fam.group, id)
    theirs = g and fam.groupEq and fam.groupEq[g] or nil
  end
  if not mineIdx or not theirs then return false end
  return mineIdx >= theirs
end

-------------------------------------------------------------------------------
-- What does this unit need from me?
-------------------------------------------------------------------------------
local BLESSING_ORDER_MANA = { "kings", "wisdom", "might", "light", "sanc", "salv" }
local BLESSING_ORDER_PHYS = { "kings", "might", "wisdom", "light", "sanc", "salv" }

local function PickRank(fam, unit)
  local ranks = fam.known
  if not ranks or #ranks == 0 then return nil end
  local top = ranks[#ranks].id
  if not ns.db.downrank then return top end
  local lvl = Call(UnitLevel, unit)
  if type(lvl) ~= "number" or lvl <= 0 then return top end
  for i = #ranks, 1, -1 do
    if ranks[i].level - 10 <= lvl then return ranks[i].id end
  end
  return nil -- every rank I know is too high for them
end

-- Returns { key =, missing = { {fam=, spell=, refresh=}... } } or nil, reason
function ns.Evaluate(unit)
  local why = Ineligible(unit)
  if why then return nil, why end
  local key = UnitKey(unit)
  if not key then return nil, "unknown identity" end
  local now = GetTime()
  if (state.skipUntil[key] or 0) > now then return nil, "recently failed" end

  local isSelf = IsTrue(UnitIsUnit, unit, "player")
  local snap = Snapshot(unit)
  local mana = IsManaUser(unit)
  local missing = {}
  local unreadable = false

  -- Does this family apply to this unit at all?
  local function applies(fam)
    if fam.self and not isSelf then return false end
    if fam.broken then return false end
    if fam.shard and ns.BagCount(6265) == 0 then return false end -- no Soul Shard
    if fam.itemID and ns.BagCount(fam.itemID) == 0 then return false end
    if ns.IsManaOnly(fam) and not mana then return false end
    return true
  end
  local function justCast(fam) return (state.justCast[key .. ":" .. fam.key] or 0) >= now end
  local function offer(fam, refresh, aura)
    if fam.itemID then
      -- An item from my bags. Never offer it again right after using it: if I
      -- can't see its effect, repeated clicks would eat through the stack.
      local try = state.itemTry[fam.key]
      if try then
        if now - try.t < 30 then return end
        -- Flasks and elixirs act instantly, so one unseen use is proof enough.
        -- Eating or applying a poison can be interrupted: allow a second try.
        if try.n >= (fam.oneShot and 1 or 2) then
          fam.broken = true
          ns.Log("can't tell whether " .. ns.FamilyName(fam) .. " is active after using it; not tracking it this session")
          ns.Print("can't tell whether " .. ns.FamilyName(fam) .. " is active, so it won't be offered again this session.")
          return
        end
      end
      missing[#missing + 1] = { fam = fam, macro = ns.ItemMacro(fam, refresh), refresh = refresh or nil }
      return
    end
    local spell = PickRank(fam, unit)
    if not spell then return end
    if refresh and not CanRefresh(fam, aura, spell) then return end
    missing[#missing + 1] = { fam = fam, spell = spell, refresh = refresh or nil }
  end

  -- "One at a time" sets: having any member counts; offer the first enabled one I know.
  local function evalSet(set)
    local wanted
    for _, m in ipairs(set) do
      if m.known and ns.IsEnabled(m) and applies(m) then wanted = m break end
    end
    if not wanted then return end
    for _, m in ipairs(set) do
      if justCast(m) then return end
    end
    for _, m in ipairs(set) do
      if (not m.self) or isSelf then
        local has, _, aura = HasFamily(unit, m, snap)
        if has == nil then unreadable = true return end
        -- Stances and forms are strict: being in one I didn't tick doesn't count.
        if has and m.kind == "form" and not ns.IsEnabled(m) then has = false end
        if has then
          state.itemTry[m.key] = nil
          -- They have one of the set. Refresh it only if it is one I offer. Where one
          -- check answers for the whole set (weapon, pet, Well Fed) we can't tell
          -- which member it is, so the one to renew is the one I picked.
          local shared = m.weapon or m.kind == "pet" or m.excl == "food"
          local r = shared and wanted or m
          if r.known and ns.IsEnabled(r) and applies(r) and Expiring(aura) then offer(r, true, aura) end
          return
        end
        if m.weapon or m.kind == "pet" or m.excl == "food" then break end -- one check answers for the whole set
      end
    end
    offer(wanted)
  end

  local setsDone = {}
  for _, fam in ipairs(ns.known or {}) do
    if fam.blessing then
      -- handled together below
    elseif fam.excl then
      if not setsDone[fam.excl] then
        setsDone[fam.excl] = true
        evalSet(ns.EXCL[fam.excl])
        if unreadable then return nil, "unreadable" end
      end
    elseif ns.IsEnabled(fam) and applies(fam) then
      local has, _, aura = HasFamily(unit, fam, snap)
      if has == nil then return nil, "unreadable" end
      if has then state.itemTry[fam.key] = nil end
      if not justCast(fam) then
        if not has then
          offer(fam)
        elseif Expiring(aura) then
          offer(fam, true, aura)
        end
      end
    end
  end

  -- Blessings: I can only keep one of mine on a player, and never overwrite
  -- the same blessing from another paladin.
  local order = mana and BLESSING_ORDER_MANA or BLESSING_ORDER_PHYS
  local done, candidate, renew, renewAura = false, nil, nil, nil
  for _, k in ipairs(order) do
    local fam = ns.FAMILY_BY_KEY[k]
    if fam and fam.known and ns.IsEnabled(fam) and applies(fam) then
      local has, mine, aura = HasFamily(unit, fam, snap)
      if has == nil then return nil, "unreadable" end
      if justCast(fam) then done = true end
      if has and (mine or state.myBlessing[key] == k) then
        -- My blessing is on them: done, unless it is about to run out.
        if Expiring(aura) and not renew then renew, renewAura = fam, aura else done = true end
      end
      if not has and not candidate then candidate = fam end
    end
  end
  if not done then
    if renew then
      offer(renew, true, renewAura)
    elseif candidate then
      offer(candidate)
    end
  end

  return { key = key, missing = missing }
end

function ns.InRange(spell, unit)
  local r = Call(C_Spell and C_Spell.IsSpellInRange, spell, unit)
  if r == false then return false end
  return true -- true, or the client can't tell
end

local function CanAfford(spell)
  if not (C_Spell and C_Spell.IsSpellUsable) then return true end
  local ok, usable, noMana = pcall(C_Spell.IsSpellUsable, spell)
  if not ok or IsSecret(noMana) then return true end
  return not noMana
end

local function OnCooldown(spell)
  local cd = Call(C_Spell and C_Spell.GetSpellCooldown, spell)
  if type(cd) ~= "table" then return false end
  local okS, start = pcall(function() return cd.startTime end)
  local okD, dur = pcall(function() return cd.duration end)
  if not okS or not okD or IsSecret(start) or IsSecret(dur) then return false end
  if type(start) ~= "number" or type(dur) ~= "number" or dur <= 0 then return false end
  return (start + dur - GetTime()) > 0.05
end

-------------------------------------------------------------------------------
-- Building the list
-------------------------------------------------------------------------------
-- Find a unit token for a remembered player. Order matters on Forever: actions
-- aimed at "target" or "mouseover" work, but actions aimed at a nameplateN slot
-- are silently ignored by the client. So a nameplate token is the last resort.
local function FindUnitByKey(key)
  if not key then return nil end
  if UnitKey("player") == key then return "player" end
  if UnitKey("target") == key then return "target" end
  if UnitKey("mouseover") == key then return "mouseover" end
  for i = 1, MAX_PLATES do
    local u = "nameplate" .. i
    if IsTrue(UnitExists, u) and UnitKey(u) == key then return u end
  end
  return nil
end
ns.FindUnitByKey = FindUnitByKey

function ns.BuildList()
  local list, byKey, unreadable, seenAny = {}, {}, 0, 0
  local now = GetTime()

  local function consider(unit, isTarget, isSelf)
    local info, why = ns.Evaluate(unit)
    if why == "unreadable" then unreadable = unreadable + 1 end
    if not info then return end
    seenAny = seenAny + 1
    if #info.missing == 0 then return end
    if byKey[info.key] then
      if isTarget then byKey[info.key].isTarget = true end
      return
    end
    state.firstSeen[info.key] = state.firstSeen[info.key] or now
    local okC, _, class = pcall(UnitClass, unit)
    local e = {
      key = info.key,
      unit = unit,
      name = UnitShortName(unit),
      class = (okC and not IsSecret(class)) and class or nil,
      missing = info.missing,
      inRange = ns.InRange(info.missing[1].spell, unit),
      isTarget = isTarget,
      isSelf = isSelf,
      seen = state.firstSeen[info.key],
    }
    byKey[info.key] = e
    list[#list + 1] = e
  end

  if ns.db.includeSelf then consider("player", false, true) end
  if ns.db.showTarget and IsTrue(UnitExists, "target") then consider("target", true) end
  for i = 1, MAX_PLATES do
    local u = "nameplate" .. i
    if IsTrue(UnitExists, u) then consider(u, false) end
  end

  table.sort(list, function(a, b)
    if a.isSelf ~= b.isSelf then return a.isSelf and true or false end
    if a.isTarget ~= b.isTarget then return a.isTarget and true or false end
    if a.inRange ~= b.inRange then return a.inRange and true or false end
    if a.seen ~= b.seen then return (a.seen or 0) > (b.seen or 0) end
    return a.name < b.name
  end)

  local status
  if #(ns.known or {}) == 0 then
    status = "You don't know any buffs StrangerBuff handles"
  elseif #list > 0 then
    status = nil
  elseif unreadable > 0 and seenAny == 0 then
    status = "The game is hiding buffs here"
  else
    status = "Nobody nearby needs your buffs"
  end
  return list, status
end

-------------------------------------------------------------------------------
-- Preparing a secure button right before the click lands (PreClick).
-------------------------------------------------------------------------------
-- sfx is "" for the hidden buttons and "1" for box rows. A row keeps its plain
-- "unit" attribute pointing at its player: that is what makes the game treat the
-- player as "mouseover" while the cursor is on the row. So a row's click action
-- lives in type1 / spell1 / unit1, which the secure template reads first for a
-- left click.
local function ClearButton(btn, sfx)
  sfx = sfx or ""
  btn:SetAttribute("type" .. sfx, nil)
  btn:SetAttribute("spell" .. sfx, nil)
  btn:SetAttribute("unit" .. sfx, nil)
  btn:SetAttribute("macrotext" .. sfx, nil)
end
ns.ClearButton = ClearButton

local function OomNotice()
  if not state.oom then
    state.oom = true
    ns.Print("not enough mana to buff right now.")
  end
end

-- Activity log line per attempt (a mouse click arrives as down + up; log it once).
local lastPrep, lastPrepT = nil, 0
local function LogPrep(btn, text)
  local line = (btn:GetName() or "?") .. ": " .. text
  local now = GetTime()
  if line == lastPrep and now - lastPrepT < 1 then return end
  lastPrep, lastPrepT = line, now
  ns.Log(line)
end

-------------------------------------------------------------------------------
-- Reaching a player who is neither my target nor under my cursor.
--
-- Measured on Forever: a cast aimed at "target" or "mouseover" works; a cast or
-- TargetUnit aimed at a nameplateN token is silently ignored. So for a player in
-- the box we first have to make them the target, from the player's own click:
--   "name"  : one macro that tries several /target forms for Forever's two-part
--             names, then casts at the target.
--   "cycle" : if no name form works, each click runs /targetfriendplayer until
--             the right player is targeted; the next click then casts.
-- Which one works is detected at run time (per session) and logged.
-------------------------------------------------------------------------------
local reach = { mode = "name", ok = 0, fail = 0, pending = nil }
ns.reach = reach

local function NameParts(unit)
  local ok, n, r = pcall(UnitName, unit)
  if not ok or IsSecret(n) or type(n) ~= "string" or n == "" then return nil end
  if r and not IsSecret(r) and type(r) == "string" and r ~= "" then return n, r end
  return n, nil
end

-- "/cast" needs a spell name; add the rank only when we deliberately downrank.
local function CastName(fam, spell)
  local name = ns.FamilyName(fam)
  local top = fam.known and fam.known[#fam.known].id
  if spell ~= top and C_Spell and C_Spell.GetSpellSubtext then
    local sub = Call(C_Spell.GetSpellSubtext, spell)
    if type(sub) == "string" and sub ~= "" then return name .. "(" .. sub .. ")" end
  end
  return name
end

local function TargetMacro(unit, fam, spell, restore)
  local first, last = NameParts(unit)
  if not first then return nil end
  -- /cleartarget first: if every form fails there is no target, so the cast line
  -- can't land on whoever I had selected before.
  local lines = { "/cleartarget" }
  if last then
    lines[#lines + 1] = "/targetexact " .. first .. " " .. last
    lines[#lines + 1] = "/target [noexists] " .. first .. " " .. last
    lines[#lines + 1] = "/target [noexists] " .. first .. "-" .. last
  else
    lines[#lines + 1] = "/targetexact " .. first
  end
  lines[#lines + 1] = "/target [noexists] " .. first
  local cast = "/cast [@target,help,nodead] " .. CastName(fam, spell)
  -- Go back to whoever I had selected. /cleartarget (above) parks them as the
  -- "last target"; this returns to them once the cast has been sent.
  if restore then cast = cast .. "\n/targetlasttarget" end
  local text = table.concat(lines, "\n") .. "\n" .. cast
  -- Stay under the classic 255-character macro limit: drop optional forms first.
  while #text > 250 and #lines > 3 do
    table.remove(lines, #lines - 1)
    text = table.concat(lines, "\n") .. "\n" .. cast
  end
  return text
end

-- After a targeting click, see whether it reached the right player. With
-- "return to previous target" the final target proves nothing, so success is any
-- of: the target passed through them, the buff landed, or they are the target.
local function WatchReach(key, name)
  local now = GetTime()
  if reach.pending and now - reach.pending.t < 0.3 then return end -- same physical click
  local p = { key = key, t = now, hit = false }
  reach.pending = p
  C_Timer.After(1.0, function()
    if reach.pending ~= p then return end
    reach.pending = nil
    local hit = p.hit or UnitKey("target") == key
    if reach.mode == "name" then
      if hit then
        reach.fail = 0
        if not ns.db.reachOK then ns.Log("targeting by name works on this client") end
        ns.db.reachOK = true
      else
        reach.fail = reach.fail + 1
        ns.Log("targeting by name did not reach " .. name .. " (" .. reach.fail .. " in a row)")
        -- Known to work here before: tolerate more misses (out of sight, moved away...).
        if reach.fail >= (ns.db.reachOK and 6 or 3) then
          reach.mode = "cycle"
          ns.db.reachOK = nil
          ns.Log("name targeting isn't working; switching to cycling through nearby friendly players")
          ns.Print("selecting players by name isn't working. Clicking a name now steps through nearby friendly players until it reaches them, then buffs.")
        end
      end
    elseif hit then
      ns.Log("cycling reached " .. name)
    end
    ns.MarkDirty()
  end)
end

-- Point btn at `unit` with its first missing buff.
-- reachable: this button may change my target to get to the player.
local function Prepare(btn, unit, sfx, reachable)
  if InCombatLockdown() then return false end
  sfx = sfx or ""
  ClearButton(btn, sfx)
  if not unit then
    LogPrep(btn, "player not found, nothing cast")
    return false
  end
  local info, why = ns.Evaluate(unit)
  if not info or #info.missing == 0 then
    LogPrep(btn, "nothing to cast on unit=" .. unit .. " (" .. (why or "has everything") .. ")")
    return false
  end
  local m = info.missing[1]
  local name = UnitShortName(unit)

  if unit ~= "target" and unit ~= "mouseover" and unit ~= "player" then
    -- A nameplate token: the client ignores actions aimed at it.
    if not reachable then
      LogPrep(btn, "can't reach " .. name .. " (unit=" .. unit .. ")")
      return false
    end
    if reach.mode == "cycle" then
      btn:SetAttribute("type" .. sfx, "macro")
      btn:SetAttribute("macrotext" .. sfx, "/targetfriendplayer")
      LogPrep(btn, "cycle friendly players, looking for " .. name)
      WatchReach(info.key, name)
      return true
    end
    if OnCooldown(m.spell) then return false end
    if not CanAfford(m.spell) then OomNotice() return false end
    local restore = ns.db.restoreTarget and IsTrue(UnitExists, "target")
    local text = TargetMacro(unit, m.fam, m.spell, restore)
    if not text then
      LogPrep(btn, "can't read " .. unit .. "'s name")
      return false
    end
    state.oom = false
    btn:SetAttribute("type" .. sfx, "macro")
    btn:SetAttribute("macrotext" .. sfx, text)
    state.attempt = { key = info.key, fam = m.fam, t = GetTime(), name = name }
    LogPrep(btn, "target " .. name .. " by name, then cast: " .. text:gsub("\n", " | "))
    WatchReach(info.key, name)
    return true
  end

  if m.macro then
    -- Use an item from my bags (food, flask, poison).
    btn:SetAttribute("type" .. sfx, "macro")
    btn:SetAttribute("macrotext" .. sfx, m.macro)
    local try = state.itemTry[m.fam.key]
    if not (try and GetTime() - try.t < 1) then -- a click arrives as down + up: count it once
      state.itemTry[m.fam.key] = { t = GetTime(), n = (try and try.n or 0) + 1 }
    end
    LogPrep(btn, "use " .. ns.FamilyName(m.fam) .. ": " .. m.macro:gsub("\n", " | "))
    return true
  end
  if OnCooldown(m.spell) then return false end -- global cooldown: do nothing, don't count it as a failure
  if not CanAfford(m.spell) then OomNotice() return false end
  state.oom = false
  btn:SetAttribute("type" .. sfx, "spell")
  btn:SetAttribute("spell" .. sfx, m.spell)
  btn:SetAttribute("unit" .. sfx, unit)
  state.attempt = { key = info.key, fam = m.fam, t = GetTime(), name = name }
  LogPrep(btn, ("cast %s #%s on %s via unit=%s"):format(ns.FamilyName(m.fam), tostring(m.spell), name, unit))
  return true
end

-- Click on a name in the box: cast that player's next missing buff on them.
-- The cursor is on the row, so the player is normally "mouseover" (see above).
function ns.PrepareRow(btn)
  if InCombatLockdown() then return end
  Prepare(btn, FindUnitByKey(btn.entryKey), "1", true)
end

-- Mouse wheel / "next" binding: first in-range player on a fresh list.
function ns.PrepareNext(btn)
  if InCombatLockdown() then return end
  local list = ns.BuildList()
  for _, e in ipairs(list) do
    if e.inRange then
      local unit = FindUnitByKey(e.key)
      -- Without name targeting, only a player who is already my target or under
      -- my cursor can be reached from here.
      local direct = (unit == "target" or unit == "mouseover" or unit == "player")
      if unit and (direct or reach.mode == "name") and Prepare(btn, unit, "", true) then return end
    end
  end
  ClearButton(btn)
end

-- Target key binding.
function ns.PrepareTarget(btn)
  if InCombatLockdown() then return end
  Prepare(btn, "target")
end

-- Player under the mouse cursor in the world (or their nameplate).
function ns.PrepareMouseover(btn)
  if InCombatLockdown() then return end
  Prepare(btn, "mouseover")
end

local function MakeHiddenButton(name, prepare)
  local b = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
  b:RegisterForClicks("AnyUp", "AnyDown")
  b:SetAttribute("useOnKeyDown", true) -- mouse wheel only sends a key-down
  b:SetScript("PreClick", prepare)
  b:Hide()
  return b
end

ns.targetButton = MakeHiddenButton("StrangerBuffTargetButton", ns.PrepareTarget)
ns.nextButton = MakeHiddenButton("StrangerBuffNextButton", ns.PrepareNext)
ns.mouseoverButton = MakeHiddenButton("StrangerBuffMouseoverButton", ns.PrepareMouseover)

-- Wheel over a name in the box: cast on that row's player.
local hoverButton = nil -- name of the box row under the cursor
ns.rowWheelButton = MakeHiddenButton("StrangerBuffRowWheelButton", function(btn)
  if InCombatLockdown() then return end
  local row = hoverButton and _G[hoverButton]
  Prepare(btn, row and FindUnitByKey(row.entryKey), "", true)
end)

-------------------------------------------------------------------------------
-- Mouse wheel binding (only while someone needs a buff, only out of combat)
-------------------------------------------------------------------------------
-- Three uses, one binding owner, in this priority:
--   hovering a row in the box        -> wheel clicks that row (buffs that player)
--   hovering a player in the world   -> wheel clicks the mouseover button (buffs them)
--   anywhere else                    -> wheel clicks the "next" button (top player in range)
local wheelOwner = CreateFrame("Frame", "StrangerBuffWheelOwner", UIParent)
local wheelBoundTo = nil
local wantNext = false
local mouseoverNeeds = false

function ns.UpdateWheel(want)
  if want ~= nil then wantNext = want end
  if InCombatLockdown() then return end
  local btn, click
  if hoverButton and ns.db.wheelHover then
    btn, click = "StrangerBuffRowWheelButton", "LeftButton"
  elseif mouseoverNeeds and ns.db.wheelMouseover then
    btn, click = "StrangerBuffMouseoverButton", "LeftButton"
  elseif wantNext and ns.db.wheel then
    btn, click = "StrangerBuffNextButton", "LeftButton"
  end
  local sig = btn and (ns.db.wheelKey .. ">" .. btn) or nil
  if sig == wheelBoundTo then return end
  ClearOverrideBindings(wheelOwner)
  if btn then SetOverrideBindingClick(wheelOwner, true, ns.db.wheelKey, btn, click) end
  wheelBoundTo = sig
end

-- Called by rows on enter/leave (name of the row button, or nil).
function ns.SetHoverRow(name)
  hoverButton = name
  ns.UpdateWheel(nil)
end

-- Does the player under the cursor need one of my buffs?
local function CheckMouseover()
  if InCombatLockdown() then return end
  local needs = false
  if ns.db.wheelMouseover and IsTrue(UnitExists, "mouseover") then
    local info = ns.Evaluate("mouseover")
    needs = (info and #info.missing > 0) and true or false
  end
  if needs ~= mouseoverNeeds then
    mouseoverNeeds = needs
    ns.UpdateWheel(nil)
  end
end
ns.CheckMouseover = CheckMouseover

-------------------------------------------------------------------------------
-- Cast results
-------------------------------------------------------------------------------
ns.On("UNIT_SPELLCAST_SUCCEEDED", function(_, unit, _, spellID)
  if unit ~= "player" or IsSecret(spellID) then return end
  local a = state.attempt
  local fam = a and ns.FamilyOfSpell(spellID)
  if not (a and fam and fam == a.fam and GetTime() - a.t < 10) then return end
  if reach.pending and reach.pending.key == a.key then reach.pending.hit = true end
  state.justCast[a.key .. ":" .. fam.key] = GetTime() + CAST_GRACE
  if fam.blessing then state.myBlessing[a.key] = fam.key end
  ns.Log("buffed " .. a.name .. " with " .. ns.FamilyName(fam))
  state.attempt = nil
  ns.MarkDirty()
end)

-- Errors that mean "not yet", not "can't buff this person".
local NOT_A_FAILURE = {}
for _, g in ipairs({ "SPELL_FAILED_NOT_READY", "ERR_SPELL_COOLDOWN", "ERR_ABILITY_COOLDOWN",
  "SPELL_FAILED_SPELL_IN_PROGRESS", "ERR_GENERIC_NO_TARGET", "SPELL_FAILED_NO_POWER", "ERR_OUT_OF_MANA" }) do
  if type(_G[g]) == "string" then NOT_A_FAILURE[_G[g]] = true end
end

local function Failed(reason)
  local a = state.attempt
  if not a or GetTime() - a.t > 2 then return end
  if type(reason) == "string" and not IsSecret(reason) and NOT_A_FAILURE[reason] then return end
  state.skipUntil[a.key] = GetTime() + SKIP_AFTER_FAIL
  ns.Log("failed on " .. a.name .. ": " .. ns.S(reason) .. " (skipping " .. SKIP_AFTER_FAIL .. "s)")
  state.attempt = nil
  ns.MarkDirty()
end

ns.On("UNIT_SPELLCAST_FAILED", function(_, unit, _, spellID)
  if unit ~= "player" or IsSecret(spellID) then return end
  local a = state.attempt
  if a and ns.FamilyOfSpell(spellID) == a.fam then Failed("cast failed") end
end)
ns.On("UI_ERROR_MESSAGE", function(_, _, msg) Failed(msg) end)

-------------------------------------------------------------------------------
-- Refresh loop
-------------------------------------------------------------------------------
local dirty = true
function ns.MarkDirty() dirty = true end

local function Refresh()
  if state.inCombat or InCombatLockdown() then return end
  dirty = false
  if ns.bagsChanged then
    ns.bagsChanged = false
    ns.ScanBags()
    ns.RebuildKnown()
  end
  local list, status = ns.BuildList()
  state.list, state.status = list, status
  -- Only take the wheel when scrolling could actually buff someone.
  local anyInRange = false
  for _, e in ipairs(list) do
    if e.inRange and (reach.mode == "name" or e.isTarget or e.isSelf) then anyInRange = true break end
  end
  local visible = ns.RenderBox and ns.RenderBox(list, status)
  CheckMouseover() -- also catches the hovered player getting buffed
  ns.UpdateWheel(anyInRange and visible ~= false)
end
ns.Refresh = Refresh

local acc = 0
local ticker = CreateFrame("Frame")
ticker:SetScript("OnUpdate", function(_, elapsed)
  -- The game sends no event when the cursor leaves a player, so watch for it
  -- every frame (cheap) and hand the wheel back right away.
  if mouseoverNeeds and not state.inCombat and not IsTrue(UnitExists, "mouseover") then CheckMouseover() end
  acc = acc + elapsed
  -- Range changes as you move, so refresh at least every 0.5s; sooner when something changed.
  if (dirty and acc > 0.15) or acc > 0.5 then
    acc = 0
    Refresh()
  end
end)

ns.On("NAME_PLATE_UNIT_ADDED", function(_, unit)
  local k = (type(unit) == "string" and not IsSecret(unit)) and UnitKey(unit)
  if k and not state.firstSeen[k] then state.firstSeen[k] = GetTime() end
  dirty = true
end)
ns.On("NAME_PLATE_UNIT_REMOVED", function() dirty = true end)
ns.On("PLAYER_TARGET_CHANGED", function()
  dirty = true
  if reach.pending and UnitKey("target") == reach.pending.key then reach.pending.hit = true end
  ns.Log("target is now " .. (IsTrue(UnitExists, "target") and UnitShortName("target") or "nobody"))
end)
ns.On("ADDON_ACTION_BLOCKED", function(_, addon, fn) if addon == ADDON then ns.Log("BLOCKED " .. ns.S(fn)) end end)
ns.On("ADDON_ACTION_FORBIDDEN", function(_, addon, fn) if addon == ADDON then ns.Log("FORBIDDEN " .. ns.S(fn)) end end)
ns.On("UPDATE_MOUSEOVER_UNIT", function() CheckMouseover() end)
ns.On("UNIT_AURA", function(_, unit)
  if type(unit) == "string" and not IsSecret(unit) and (unit == "target" or unit:find("^nameplate")) then dirty = true end
end)
ns.On("PLAYER_UPDATE_RESTING", function() dirty = true end)
ns.On("UNIT_POWER_UPDATE", function(_, unit) if unit == "player" and state.oom then dirty = true end end)

local function Rescan()
  ns.RebuildKnown()
  dirty = true
end
local function BagsChanged() ns.bagsChanged = true dirty = true end
ns.On("BAG_UPDATE_DELAYED", BagsChanged)
ns.On("GET_ITEM_INFO_RECEIVED", BagsChanged)
ns.On("UNIT_PET", function(_, unit) if unit == "player" then dirty = true end end)
ns.On("UPDATE_SHAPESHIFT_FORM", function() dirty = true end)
ns.On("UPDATE_SHAPESHIFT_FORMS", function() dirty = true end)
ns.On("UNIT_INVENTORY_CHANGED", function(_, unit) if unit == "player" then dirty = true end end)
ns.On("PLAYER_MOUNT_DISPLAY_CHANGED", function() dirty = true end)
ns.On("SPELLS_CHANGED", Rescan)
ns.On("LEARNED_SPELL_IN_TAB", Rescan)
ns.On("PLAYER_LEVEL_UP", Rescan)

-- Combat: clear every secure button and the wheel binding at the last moment we're
-- allowed to (PLAYER_REGEN_DISABLED fires just before lockdown), then freeze.
ns.On("PLAYER_REGEN_DISABLED", function()
  state.inCombat = true
  if not InCombatLockdown() then
    ClearButton(ns.targetButton)
    ClearButton(ns.nextButton)
    ClearButton(ns.mouseoverButton)
    ClearButton(ns.rowWheelButton)
    hoverButton = nil
    mouseoverNeeds = false
    ns.UpdateWheel(false)
    if ns.EnterCombatBox then ns.EnterCombatBox() end
  end
end)
ns.On("PLAYER_REGEN_ENABLED", function()
  state.inCombat = false
  if ns.LeaveCombatBox then ns.LeaveCombatBox() end
  dirty = true
end)

ns.OnInit(function()
  ns.ScanBags()
  ns.RebuildKnown()
  state.inCombat = InCombatLockdown() and true or false
  dirty = true
end)
