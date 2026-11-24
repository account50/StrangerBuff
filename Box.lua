-- StrangerBuff: the on-screen box of nearby players who need your buffs.
-- Rows are secure buttons from a fixed pool; they are only re-pointed, shown or
-- hidden out of combat.
local ADDON, ns = ...

local POOL = 20
local WIDTH, HEADER_H, ROW_H, STATUS_H = 230, 22, 20, 18
local MAX_ICONS = 6

local box = CreateFrame("Frame", "StrangerBuffBox", UIParent)
box:SetSize(WIDTH, HEADER_H + STATUS_H)
box:SetPoint("CENTER", UIParent, "CENTER", 300, 100)
box:SetClampedToScreen(true)
box:SetMovable(true)
box:SetFrameStrata("MEDIUM")
box:Hide()
ns.box = box

local bg = box:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0, 0, 0, 0.55)

-- Header: drag handle, title, count, options button
local header = CreateFrame("Button", nil, box)
header:SetPoint("TOPLEFT")
header:SetPoint("TOPRIGHT")
header:SetHeight(HEADER_H)
header:RegisterForDrag("LeftButton")
header:RegisterForClicks("RightButtonUp")
local hbg = header:CreateTexture(nil, "BACKGROUND")
hbg:SetAllPoints()
hbg:SetColorTexture(0.1, 0.3, 0.5, 0.7)
local title = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("LEFT", 6, 0)
title:SetText("StrangerBuff")
local count = header:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
count:SetPoint("LEFT", title, "RIGHT", 6, 0)

local gear = CreateFrame("Button", nil, header)
gear:SetSize(16, 16)
gear:SetPoint("RIGHT", -4, 0)
gear:SetNormalTexture("Interface\\Icons\\INV_Misc_Gear_01")
gear:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
gear:SetScript("OnClick", function() if ns.ToggleOptions then ns.ToggleOptions() end end)
gear:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:SetText("StrangerBuff options")
  GameTooltip:Show()
end)
gear:SetScript("OnLeave", function() GameTooltip:Hide() end)

header:SetScript("OnDragStart", function()
  if ns.db.locked or InCombatLockdown() then return end
  box:StartMoving()
end)
header:SetScript("OnDragStop", function()
  box:StopMovingOrSizing()
  local p, _, rp, x, y = box:GetPoint()
  ns.db.point = { p, rp, x, y }
end)
header:SetScript("OnClick", function() if ns.ToggleOptions then ns.ToggleOptions() end end)
header:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:SetText("StrangerBuff")
  GameTooltip:AddLine("Click a name to buff that player.", 1, 1, 1)
  if ns.db.wheel then GameTooltip:AddLine("Or scroll the mouse wheel to buff the top player in range.", 1, 1, 1) end
  if not ns.db.locked then GameTooltip:AddLine("Drag here to move. Right-click for options.", 0.7, 0.7, 0.7) end
  GameTooltip:Show()
end)
header:SetScript("OnLeave", function() GameTooltip:Hide() end)

local status = box:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
status:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 6, -3)
status:SetPoint("RIGHT", -6, 0)
status:SetJustifyH("LEFT")

-------------------------------------------------------------------------------
-- Row pool
-------------------------------------------------------------------------------
local rows = {}

local function RowTooltip(self)
  local e = self.entry
  if not e then return end
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText(e.name)
  if e.done then
    GameTooltip:AddLine("All buffed", 0.3, 1, 0.3)
    GameTooltip:Show()
    return
  end
  for i, m in ipairs(e.missing) do
    GameTooltip:AddLine((i == 1 and "Next: " or "Then: ") .. ns.FamilyName(m.fam)
      .. (m.refresh and "  |cffffcc55(about to expire)|r" or ""), 1, 1, 1)
  end
  if not e.inRange then GameTooltip:AddLine("Out of range", 1, 0.3, 0.3) end
  GameTooltip:AddLine("Click to buff.", 0.7, 0.7, 0.7)
  if ns.db.wheelHover then GameTooltip:AddLine("Or scroll the mouse wheel here to buff.", 0.7, 0.7, 0.7) end
  GameTooltip:Show()
end

local function RowEnter(self)
  if not InCombatLockdown() and self.entryKey then ns.SetHoverRow(self:GetName()) end
  RowTooltip(self)
end

local function RowLeave(self)
  GameTooltip:Hide()
  if not InCombatLockdown() then ns.SetHoverRow(nil) end
end

for i = 1, POOL do
  local r = CreateFrame("Button", "StrangerBuffRow" .. i, box, "SecureActionButtonTemplate")
  r:SetHeight(ROW_H)
  r:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -(i - 1) * ROW_H - 2)
  r:SetPoint("RIGHT", box, "RIGHT")
  -- Plain mouse button: no useOnKeyDown here (forcing it breaks mouse clicks on
  -- Forever). The wheel-over-a-name goes through StrangerBuffRowWheelButton instead.
  r:RegisterForClicks("AnyUp", "AnyDown")
  r:SetScript("PreClick", ns.PrepareRow)
  r:SetScript("OnEnter", RowEnter)
  r:SetScript("OnLeave", RowLeave)
  local hl = r:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.15)
  r.tag = r:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  r.tag:SetPoint("LEFT", 6, 0)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  r.name:SetPoint("LEFT", r.tag, "RIGHT", 2, 0)
  r.name:SetJustifyH("LEFT")
  r.icons = {}
  for k = 1, MAX_ICONS do
    local t = r:CreateTexture(nil, "ARTWORK")
    t:SetSize(16, 16)
    t:SetPoint("RIGHT", r, "RIGHT", -4 - (k - 1) * 18, 0)
    t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.icons[k] = t
  end
  r:Hide()
  rows[i] = r
end

local function ClearRow(r)
  ns.ClearButton(r, "1")
end

local function ClassColor(class)
  local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
  if c then return c.r, c.g, c.b end
  return 1, 1, 1
end

-------------------------------------------------------------------------------
-- Render (out of combat only). Returns whether the box is visible.
-------------------------------------------------------------------------------
function ns.ApplyBoxLayout()
  if InCombatLockdown() then return end
  box:SetScale(ns.db.scale or 1)
  local p = ns.db.point
  if p then
    box:ClearAllPoints()
    box:SetPoint(p[1], UIParent, p[2], p[3], p[4])
  end
end

-- While the mouse is over the box, rows keep their slots so the name under the
-- cursor doesn't change between "click to target" and "click to buff". Players
-- who no longer need anything stay as a "done" row until the mouse leaves.
local shownKeys = {}

local function Stabilize(list)
  if not (box:IsShown() and box:IsMouseOver()) or #shownKeys == 0 then return list end
  local byKey = {}
  for _, e in ipairs(list) do byKey[e.key] = e end
  local out, used = {}, {}
  for _, prev in ipairs(shownKeys) do
    local e = byKey[prev.key]
    if e then
      out[#out + 1] = e
    else
      out[#out + 1] = { key = prev.key, name = prev.name, class = prev.class, missing = {}, inRange = true, done = true }
    end
    used[prev.key] = true
  end
  for _, e in ipairs(list) do
    if not used[e.key] then out[#out + 1] = e end
  end
  return out
end

function ns.RenderBox(list, statusText)
  if InCombatLockdown() then return box:IsShown() end
  local db = ns.db
  list = Stabilize(list)
  local n = math.min(#list, db.maxRows or 10, POOL)
  wipe(shownKeys)
  for i = 1, n do shownKeys[i] = { key = list[i].key, name = list[i].name, class = list[i].class } end
  local active = 0
  for i = 1, #list do if not list[i].done then active = active + 1 end end

  for i = 1, POOL do
    local r = rows[i]
    local e = (i <= n) and list[i] or nil
    r.entry = e
    if e then
      r.entryKey = e.key
      r.tag:SetText(e.isSelf and "|cff66ccff[Me]|r " or (e.isTarget and "|cffffd100[T]|r " or ""))
      r.name:SetText(e.done and (e.name .. "  |cff40ff40done|r") or e.name)
      r.name:SetTextColor(ClassColor(e.class))
      for k = 1, MAX_ICONS do
        local m = e.missing[k]
        if m then
          r.icons[k]:SetTexture(m.spell and ns.SpellIcon(m.spell) or ns.FamilyIcon(m.fam))
          -- amber tint: they have it, but it's about to run out
          if m.refresh then r.icons[k]:SetVertexColor(1, 0.75, 0.3) else r.icons[k]:SetVertexColor(1, 1, 1) end
          r.icons[k]:Show()
        else
          r.icons[k]:Hide()
        end
      end
      r:SetAlpha((e.inRange and not e.done) and 1 or 0.45)
      r:Show()
    else
      r.entryKey = nil
      ClearRow(r)
      r:Hide()
    end
  end

  if n > 0 then
    status:Hide()
    count:SetText("(" .. active .. ")")
    box:SetHeight(HEADER_H + n * ROW_H + 4)
  else
    status:SetText(statusText or "")
    status:Show()
    count:SetText("")
    box:SetHeight(HEADER_H + STATUS_H + 4)
  end

  local show = not db.hidden
  if show and db.hideResting and IsResting() then show = false end
  if show and db.hideWhenEmpty and n == 0 then show = false end
  -- Keep the wheel's "hovered row" in sync even if a row was hidden under the
  -- cursor without an OnLeave, and refresh an open row tooltip.
  local hovered = nil
  if show then
    for i = 1, n do
      if rows[i]:IsMouseOver() then hovered = rows[i] break end
    end
  end
  ns.SetHoverRow(hovered and hovered:GetName() or nil)
  if hovered and GameTooltip:IsShown() and GameTooltip:GetOwner() == hovered then RowTooltip(hovered) end
  if show then box:Show() else box:Hide() end
  return show
end

-- Combat: called from PLAYER_REGEN_DISABLED, the last moment changes are allowed.
function ns.EnterCombatBox()
  wipe(shownKeys)
  for i = 1, POOL do
    ClearRow(rows[i])
    rows[i].entryKey = nil
    rows[i]:Hide()
  end
  status:SetText("Paused in combat")
  status:Show()
  count:SetText("")
  box:SetHeight(HEADER_H + STATUS_H + 4)
end

function ns.LeaveCombatBox() end

ns.OnInit(function()
  ns.ApplyBoxLayout()
end)
