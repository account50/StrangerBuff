-- StrangerBuff: Diagnostics window (Options > Diagnostics). Shows what this client
-- lets the addon read, in a copyable window, and saves it for /reload.
local ADDON, ns = ...
local S, Q = ns.S, ns.Q

local copyFrame
local function ShowCopy(titleText, text)
  if not copyFrame then
    local f = CreateFrame("Frame", "StrangerBuffDiagFrame", UIParent)
    f:SetSize(680, 440)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    tinsert(UISpecialFrames, "StrangerBuffDiagFrame")
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.9)
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.title:SetPoint("TOPLEFT", 10, -8)
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    hint:SetPoint("BOTTOMLEFT", 10, 8)
    hint:SetText("Click the text, Cmd+A then Cmd+C to copy. Also saved to SavedVariables on /reload.")
    local again = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    again:SetSize(90, 20)
    again:SetPoint("BOTTOMRIGHT", -10, 4)
    again:SetText("Refresh")
    again:SetScript("OnClick", function() ns.ShowDiagnostics() end)
    local sf = CreateFrame("ScrollFrame", "StrangerBuffDiagScroll", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 10, -30)
    sf:SetPoint("BOTTOMRIGHT", -30, 28)
    local eb = CreateFrame("EditBox", nil, sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(630)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sf:SetScrollChild(eb)
    f.edit = eb
    copyFrame = f
  end
  copyFrame.title:SetText(titleText)
  copyFrame.edit:SetText(text)
  copyFrame:Show()
end

local function ReadByIndex(unit)
  local f = C_UnitAuras and C_UnitAuras.GetAuraDataByIndex
  if type(f) ~= "function" then return "n/a" end
  local names = {}
  for i = 1, 40 do
    local ok, a = pcall(f, unit, i, "HELPFUL")
    if not ok then return "ERROR at " .. i .. ": " .. S(a) end
    if ns.IsSecret(a) then return "secret" end
    if a == nil then break end
    names[#names + 1] = (ns.IsSecret(a.name) and "<secret>" or S(a.name)) .. "@" .. (ns.IsSecret(a.sourceUnit) and "<secret>" or S(a.sourceUnit))
  end
  if #names == 0 then return "ok, no buffs" end
  return "ok: " .. table.concat(names, ", ")
end

local function UnitLine(unit)
  local okN, name = pcall(UnitName, unit)
  local okC, _, class = pcall(UnitClass, unit)
  return ("name=%s class=%s lvl=%s player=%s assist=%s pvp=%s dead=%s power=%s idSecret=%s"):format(
    okN and S(name) or "ERR", okC and S(class) or "ERR", Q(UnitLevel, unit), Q(UnitIsPlayer, unit),
    Q(UnitCanAssist, "player", unit), Q(UnitIsPVP, unit), Q(UnitIsDeadOrGhost, unit), Q(UnitPowerType, unit),
    Q(C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret, unit))
end

local function CVar(name) return Q((C_CVar and C_CVar.GetCVar) or GetCVar, name) end

function ns.ShowDiagnostics()
  local L = {}
  local function add(s) L[#L + 1] = s end
  add("== StrangerBuff v" .. ns.version .. " diagnostics @ " .. date("%Y-%m-%d %H:%M:%S"))
  local okB, ver, build, _, iface = pcall(GetBuildInfo)
  add("build: " .. (okB and (S(ver) .. "." .. S(build) .. " interface " .. S(iface)) or "ERR"))
  local okI, inInst, instType = pcall(IsInInstance)
  add("where: " .. Q(GetRealZoneText) .. " / " .. Q(GetSubZoneText) .. " instance=" .. (okI and (S(inInst) .. "/" .. S(instType)) or "ERR")
    .. " resting=" .. Q(IsResting) .. " combat=" .. S(InCombatLockdown()))
  add("secrecy: aurasSecret=" .. Q(C_Secrets and C_Secrets.ShouldAurasBeSecret))
  add("cvars: friendlyPlayerPlates=" .. CVar("nameplateShowFriendlyPlayers") .. " showFriends=" .. CVar("nameplateShowFriends")
    .. " showAll=" .. CVar("nameplateShowAll") .. " maxDistance=" .. CVar("nameplateMaxDistance")
    .. " ActionButtonUseKeyDown=" .. CVar("ActionButtonUseKeyDown"))
  if #ns.unknownEvents > 0 then add("events not available: " .. table.concat(ns.unknownEvents, ", ")) end

  add("-- my buffs:")
  local known = ns.RebuildKnown()
  if #known == 0 then add("  none") end
  for _, fam in ipairs(known) do
    local ids = {}
    for _, r in ipairs(fam.known) do ids[#ids + 1] = tostring(r.id) end
    add(("  %s: ranks %s, cast #%s, enabled=%s%s%s%s"):format(ns.FamilyName(fam), table.concat(ids, ","), S(fam.top),
      S(ns.IsEnabled(fam)), fam.self and ", self only" or "", fam.excl and (", set=" .. fam.excl) or "",
      fam.manaOnly and (", manaOnly=" .. S(ns.IsManaOnly(fam))) or ""))
  end

  add("-- settings: wheel=" .. S(ns.db.wheel) .. " (" .. S(ns.db.wheelKey) .. ") wheelHover=" .. S(ns.db.wheelHover)
    .. " skipPvP=" .. S(ns.db.skipPvP) .. " downrank=" .. S(ns.db.downrank) .. " maxRows=" .. S(ns.db.maxRows))

  add("-- box: " .. #(ns.state.list or {}) .. " listed. status: " .. S(ns.state.status))
  for _, e in ipairs(ns.state.list or {}) do
    local m = {}
    for _, x in ipairs(e.missing) do m[#m + 1] = ns.FamilyName(x.fam) .. "#" .. tostring(x.spell) .. (x.refresh and " (refresh)" or "") end
    add(("  %s%s inRange=%s needs: %s"):format(e.isTarget and "[T] " or "", e.name, S(e.inRange), table.concat(m, ", ")))
  end

  add("-- nameplates:")
  local plates = 0
  for i = 1, 40 do
    local u = "nameplate" .. i
    local okE, ex = pcall(UnitExists, u)
    if okE and ns.Bool(ex) == true then
      plates = plates + 1
      local info, why = ns.Evaluate(u)
      local verdict = info and (#info.missing .. " missing") or ("skipped: " .. S(why))
      add("  " .. u .. ": " .. UnitLine(u) .. " -> " .. verdict)
      if ns.Bool(ns.Call(UnitIsPlayer, u)) then add("      auras: " .. ReadByIndex(u)) end
    end
  end
  if plates == 0 then add("  none visible. Turn on friendly player nameplates (Shift+V) to fill the box.") end

  for _, u in ipairs({ "target", "mouseover" }) do
    local okE, ex = pcall(UnitExists, u)
    if okE and ns.Bool(ex) == true then
      local info, why = ns.Evaluate(u)
      add("-- " .. u .. ": " .. UnitLine(u) .. " -> " .. (info and (#info.missing .. " missing") or ("skipped: " .. S(why))))
      add("      auras: " .. ReadByIndex(u))
    end
  end

  add("-- recent activity:")
  for _, line in ipairs(ns.diag.log or {}) do add("  " .. line) end

  ns.diag.lastReport = L
  ShowCopy("StrangerBuff diagnostics", table.concat(L, "\n"))
end
