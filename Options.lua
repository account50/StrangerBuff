-- StrangerBuff: options window (opened from the box's gear, the minimap button,
-- the addon compartment, or Esc > Options > AddOns). Only uses basic templates.
local ADDON, ns = ...

local W, H = 440, 760
local f = CreateFrame("Frame", "StrangerBuffOptions", UIParent)
f:SetSize(W, H)
f:SetPoint("CENTER")
f:SetFrameStrata("DIALOG")
f:SetScale(0.9) -- tall window: keep it on screen at any UI scale
f:SetClampedToScreen(true)
f:EnableMouse(true)
f:SetMovable(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:Hide()
tinsert(UISpecialFrames, "StrangerBuffOptions") -- Esc closes it

local bg = f:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.05, 0.05, 0.08, 0.95)
local border = f:CreateTexture(nil, "BORDER")
border:SetPoint("TOPLEFT")
border:SetPoint("TOPRIGHT")
border:SetHeight(28)
border:SetColorTexture(0.1, 0.3, 0.5, 0.9)

local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 12, -7)
title:SetText("StrangerBuff")
local ver = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
ver:SetPoint("LEFT", title, "RIGHT", 8, 0)

local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
close:SetPoint("TOPRIGHT", 0, 0)

-------------------------------------------------------------------------------
-- Widget helpers
-------------------------------------------------------------------------------
local widgets = {}   -- refreshers

local function Heading(text, x, y)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetText(text)
  return fs
end

local function Check(parent, label, x, y, get, set, tip)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(24, 24)
  cb:SetPoint("TOPLEFT", x, y)
  local fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  fs:SetText(label)
  cb.label = fs
  cb:SetScript("OnClick", function(self)
    set(self:GetChecked() and true or false)
    ns.ApplySettings()
  end)
  if tip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText(label)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
  end
  cb.refresh = function() cb:SetChecked(get() and true or false) end
  widgets[#widgets + 1] = cb
  return cb
end

-- Button that cycles through choices: { {value, label}, ... }
local function Cycle(label, x, y, choices, get, set)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y - 5)
  fs:SetText(label)
  local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  b:SetSize(190, 22)
  b:SetPoint("TOPLEFT", x + 150, y)
  local function idx()
    local v = get()
    for i, c in ipairs(choices) do if c[1] == v then return i end end
    return 1
  end
  b:SetScript("OnClick", function()
    local i = idx() % #choices + 1
    set(choices[i][1])
    b:SetText(choices[i][2])
    ns.ApplySettings()
  end)
  b.refresh = function() b:SetText(choices[idx()][2]) end
  widgets[#widgets + 1] = b
  return b
end

-- [-] value [+]
local function Stepper(label, x, y, min, max, step, fmt, get, set)
  local fs = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", x, y - 5)
  fs:SetText(label)
  local minus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  minus:SetSize(24, 22)
  minus:SetPoint("TOPLEFT", x + 150, y)
  minus:SetText("-")
  local val = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  val:SetPoint("LEFT", minus, "RIGHT", 8, 0)
  val:SetWidth(40)
  local plus = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
  plus:SetSize(24, 22)
  plus:SetPoint("LEFT", val, "RIGHT", 8, 0)
  plus:SetText("+")
  local holder = {}
  holder.refresh = function() val:SetText(fmt:format(get())) end
  local function bump(d)
    local v = math.floor((get() + d) / step + 0.5) * step
    v = math.max(min, math.min(max, v))
    set(v)
    holder.refresh()
    ns.ApplySettings()
  end
  minus:SetScript("OnClick", function() bump(-step) end)
  plus:SetScript("OnClick", function() bump(step) end)
  widgets[#widgets + 1] = holder
  return holder
end

-------------------------------------------------------------------------------
-- Layout
-------------------------------------------------------------------------------
local db = function() return ns.db end
local y = -40

Heading("Buffs to give", 14, y)
local buffHint = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
buffHint:SetPoint("TOPRIGHT", -16, y - 2)
buffHint:SetText("scroll for more")

-- Scrollable list: one row per buff this character knows.
local LIST_H, ROW_H = 150, 24
local scroll = CreateFrame("ScrollFrame", "StrangerBuffOptionsScroll", f, "UIPanelScrollFrameTemplate")
scroll:SetPoint("TOPLEFT", 14, y - 18)
scroll:SetSize(W - 28 - 24, LIST_H)
local listBg = f:CreateTexture(nil, "BORDER")
listBg:SetPoint("TOPLEFT", scroll, -2, 2)
listBg:SetPoint("BOTTOMRIGHT", scroll, 24, -2)
listBg:SetColorTexture(0, 0, 0, 0.35)
local buffArea = CreateFrame("Frame", nil, scroll)
buffArea:SetSize(W - 28 - 24, LIST_H)
scroll:SetScrollChild(buffArea)

local buffRows = {} -- [family key] = { check =, mana =, note =, icon = }
local noBuffs = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
noBuffs:SetPoint("TOPLEFT", scroll, 6, -6)
noBuffs:SetWidth(W - 70)
noBuffs:SetJustifyH("LEFT")
noBuffs:SetText("This character doesn't know any buffs StrangerBuff handles yet. They appear here as you learn them.")

local SET_LABEL = {
  shamanshield = "one shield at a time",
  imbue = "one weapon imbue",
  magearmor = "one armor at a time",
  magemagic = "one at a time",
  lockarmor = "one armor at a time",
  aspect = "one aspect at a time",
  paladinaura = "one aura at a time",
  seal = "one seal at a time",
  stance = "the stance to be in",
  form = "the form to be in",
  pet = "one pet",
  food = "one food buff",
  mhpoison = "main hand",
  ohpoison = "off hand",
}

local function BuildBuffList()
  for _, r in pairs(buffRows) do
    r.check:Hide()
    if r.mana then r.mana:Hide() end
  end
  local known = ns.RebuildKnown()
  noBuffs:SetShown(#known == 0)
  buffHint:SetShown(#known * ROW_H > LIST_H)
  for i, fam in ipairs(known) do
    local r = buffRows[fam.key]
    if not r then
      r = {}
      local tip
      if fam.itemID then
        tip = "An item in your bags. Clicking your [Me] row uses one. It is listed here while you carry it."
      elseif fam.kind == "form" then
        tip = "Reminds you on your [Me] row when you are not in this stance or form. If you tick several, the first one in this list is used."
      elseif fam.kind == "pet" then
        tip = "Reminds you on your [Me] row when you have no pet out (not while mounted)."
      elseif fam.kind == "conjure" then
        tip = "Reminds you on your [Me] row when you have none in your bags."
      elseif fam.excl then
        tip = "Part of a set where only one can be active. If you tick several, the first one in this list that you know is used. Having any of them up counts as buffed."
      elseif fam.self then
        tip = "A buff for yourself. It shows on your own [Me] row."
      end
      r.check = Check(buffArea, ns.FamilyName(fam), 0, 0,
        function() return ns.IsEnabled(fam) end,
        function(v) ns.db.buffs[fam.key] = v end, tip)
      r.icon = r.check:CreateTexture(nil, "ARTWORK")
      r.icon:SetSize(16, 16)
      r.icon:SetPoint("LEFT", r.check, "RIGHT", 2, 0)
      r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
      r.check.label:ClearAllPoints()
      r.check.label:SetPoint("LEFT", r.icon, "RIGHT", 4, 0)
      r.note = r.check:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      r.note:SetPoint("LEFT", r.check.label, "RIGHT", 6, 0)
      local note = fam.excl and SET_LABEL[fam.excl] or (fam.itemID and "item") or (fam.kind == "conjure" and "keep in bags")
        or (fam.self and "self") or nil
      r.note:SetText(note and ("(" .. note .. ")") or "")
      if fam.manaOnly then
        r.mana = Check(buffArea, "only mana users", 0, 0,
          function() return ns.IsManaOnly(fam) end,
          function(v) ns.db.manaOnly[fam.key] = v end,
          "Skip warriors and rogues, who get nothing from this buff.")
        r.mana:SetSize(18, 18)
        r.mana.label:SetFontObject("GameFontHighlightSmall")
      end
      buffRows[fam.key] = r
    end
    r.icon:SetTexture(ns.FamilyIcon(fam))
    r.check:ClearAllPoints()
    r.check:SetPoint("TOPLEFT", 2, -(i - 1) * ROW_H)
    r.check:Show()
    r.check.refresh()
    if r.mana then
      r.mana:ClearAllPoints()
      r.mana:SetPoint("TOPLEFT", 252, -(i - 1) * ROW_H - 3)
      r.mana:Show()
      r.mana.refresh()
    end
  end
  buffArea:SetHeight(math.max(LIST_H, #known * ROW_H))
end

y = y - 180
Heading("Who to buff", 14, y)
Check(f, "Skip PvP-flagged players, unless I'm flagged too", 14, y - 18,
  function() return db().skipPvP end, function(v) db().skipPvP = v end,
  "Buffing a PvP-flagged player flags you for PvP. While you're not flagged, they're left off the list. Once you're flagged yourself there's nothing to protect, so they're listed and buffed like anyone else.")
Check(f, "Use a lower rank on low-level players", 14, y - 42,
  function() return db().downrank end, function(v) db().downrank = v end,
  "A rank more than 10 levels above the player fails, so pick the highest rank that works.")
Check(f, "Show my target at the top", 14, y - 66,
  function() return db().showTarget end, function(v) db().showTarget = v end,
  "If your target is a friendly player missing buffs, list them first, marked [T].")
Check(f, "Include myself", 230, y - 66,
  function() return db().includeSelf end, function(v) db().includeSelf = v end,
  "List yourself, marked [Me], when you're missing one of your own buffs.")
Stepper("Re-buff under % left", 14, y - 94, 0, 50, 5, "%d",
  function() return db().refreshPct end, function(v) db().refreshPct = v end)

y = y - 128
Heading("Casting", 14, y)
Check(f, "Mouse wheel buffs the top player in range", 14, y - 18,
  function() return db().wheel end, function(v) db().wheel = v end,
  "Only while someone in the box needs a buff, you're out of combat, and the box is showing. The rest of the time the wheel zooms the camera as usual.")
Cycle("Wheel direction", 14, y - 46, {
  { "MOUSEWHEELDOWN", "Wheel down" },
  { "MOUSEWHEELUP", "Wheel up" },
  { "SHIFT-MOUSEWHEELDOWN", "Shift + wheel down" },
  { "CTRL-MOUSEWHEELDOWN", "Ctrl + wheel down" },
  { "ALT-MOUSEWHEELDOWN", "Alt + wheel down" },
}, function() return db().wheelKey end, function(v) db().wheelKey = v end)
Check(f, "Mouse wheel over a name buffs that player", 14, y - 74,
  function() return db().wheelHover end, function(v) db().wheelHover = v end,
  "Hover a name in the box and scroll to buff that player. Clicking a name buffs them too.")
Check(f, "Mouse wheel over a player in the world buffs them", 14, y - 98,
  function() return db().wheelMouseover end, function(v) db().wheelMouseover = v end,
  "Point at a friendly player (or their nameplate) who is missing one of your buffs and scroll. If they need nothing, the wheel works as usual.")
Check(f, "Return to my previous target after buffing", 14, y - 122,
  function() return db().restoreTarget end, function(v) db().restoreTarget = v end,
  "Buffing someone from the box has to select them for a moment. With this on, you go straight back to whoever you had selected.")
Check(f, "Mouse wheel still zooms the camera while buffing", 14, y - 146,
  function() return db().wheelZoom end, function(v) db().wheelZoom = v end,
  "A wheel scroll that buffs someone also zooms the camera, as if the addon weren't using the wheel. Turn off to have those scrolls only buff.")

y = y - 182
Heading("Box", 14, y)
Check(f, "Show the box", 14, y - 18,
  function() return not db().hidden end, function(v) db().hidden = not v end)
Check(f, "Lock position", 220, y - 18,
  function() return db().locked end, function(v) db().locked = v end)
Check(f, "Hide when nobody needs buffs", 14, y - 42,
  function() return db().hideWhenEmpty end, function(v) db().hideWhenEmpty = v end)
Check(f, "Hide in cities and inns", 220, y - 42,
  function() return db().hideResting end, function(v) db().hideResting = v end)
Check(f, "Minimap button", 14, y - 66,
  function() return not db().minimapHide end, function(v) db().minimapHide = not v end)
Stepper("Max rows", 14, y - 94, 1, 20, 1, "%d",
  function() return db().maxRows end, function(v) db().maxRows = v end)
Stepper("Scale", 14, y - 120, 0.5, 2.0, 0.05, "%.2f",
  function() return db().scale end, function(v) db().scale = v end)

-- Footer
local keys = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
keys:SetPoint("BOTTOMLEFT", 14, 40)
keys:SetWidth(W - 28)
keys:SetJustifyH("LEFT")
keys:SetText("Key bindings for \"Buff my target\" and \"Buff the next nearby player\": Esc > Options > Keybindings > AddOns > StrangerBuff.")

local diag = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
diag:SetSize(120, 22)
diag:SetPoint("BOTTOMLEFT", 12, 10)
diag:SetText("Diagnostics")
diag:SetScript("OnClick", function() if ns.ShowDiagnostics then ns.ShowDiagnostics() end end)

local reset = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
reset:SetSize(140, 22)
reset:SetPoint("LEFT", diag, "RIGHT", 8, 0)
reset:SetText("Reset box position")
reset:SetScript("OnClick", function()
  if InCombatLockdown() then return end
  ns.db.point = nil
  ns.box:ClearAllPoints()
  ns.box:SetPoint("CENTER", UIParent, "CENTER", 300, 100)
end)

local done = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
done:SetSize(80, 22)
done:SetPoint("BOTTOMRIGHT", -12, 10)
done:SetText("Done")
done:SetScript("OnClick", function() f:Hide() end)

f:SetScript("OnShow", function()
  ver:SetText("v" .. ns.version)
  BuildBuffList()
  for _, w in ipairs(widgets) do if w.refresh then w.refresh() end end
end)

-------------------------------------------------------------------------------
function ns.ApplySettings()
  if ns.ApplyBoxLayout then ns.ApplyBoxLayout() end
  if ns.UpdateMinimap then ns.UpdateMinimap() end
  ns.state.skipUntil = {}
  ns.MarkDirty()
end

function ns.ToggleOptions()
  if f:IsShown() then f:Hide() else f:Show() end
end

-- Esc > Options > AddOns > StrangerBuff: a small page with a button to this window.
ns.OnInit(function()
  if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
  local page = CreateFrame("Frame")
  page.name = "StrangerBuff"
  local t = page:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  t:SetPoint("TOPLEFT", 16, -16)
  t:SetText("StrangerBuff")
  local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  b:SetSize(200, 26)
  b:SetPoint("TOPLEFT", 16, -50)
  b:SetText("Open StrangerBuff options")
  b:SetScript("OnClick", function()
    if HideUIPanel and SettingsPanel then pcall(HideUIPanel, SettingsPanel) end
    f:Show()
  end)
  pcall(function()
    local cat = Settings.RegisterCanvasLayoutCategory(page, "StrangerBuff")
    Settings.RegisterAddOnCategory(cat)
  end)
end)
