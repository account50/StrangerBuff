-- StrangerBuff: namespace, safe-value helpers, settings, event dispatch.
local ADDON, ns = ...

ns.name = ADDON
ns.version = "?"
do
  local getMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  if getMeta then
    local ok, v = pcall(getMeta, ADDON, "Version")
    if ok and type(v) == "string" then ns.version = v end
  end
end

-------------------------------------------------------------------------------
-- Secret-value safety. Forever can hand addons "secret" values that error when
-- compared, concatenated or used in arithmetic. Everything goes through these.
-------------------------------------------------------------------------------
local issecret = issecretvalue or function() return false end

function ns.IsSecret(v)
  local ok, r = pcall(issecret, v)
  return ok and r == true
end

function ns.S(v)
  if ns.IsSecret(v) then return "<secret>" end
  if v == nil then return "nil" end
  local ok, s = pcall(tostring, v)
  if ok and type(s) == "string" then return s end
  return "<?>"
end

-- true / false / nil (nil = secret)
function ns.Bool(v)
  if ns.IsSecret(v) then return nil end
  return v and true or false
end

-- Call fn(...) safely; returns the first result as a plain (non-secret) value or nil.
function ns.Call(fn, ...)
  if type(fn) ~= "function" then return nil end
  local ok, r = pcall(fn, ...)
  if not ok or ns.IsSecret(r) then return nil end
  return r
end

-- Same, but describes the result as a string (for diagnostics).
function ns.Q(fn, ...)
  if type(fn) ~= "function" then return "n/a" end
  local ok, r = pcall(fn, ...)
  if not ok then return "ERR(" .. ns.S(r) .. ")" end
  return ns.S(r)
end

local PREFIX = "|cff66ccffStrangerBuff|r: "
function ns.Print(...)
  local parts = {}
  for i = 1, select("#", ...) do parts[#parts + 1] = ns.S((select(i, ...))) end
  DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. table.concat(parts, " "))
end

-- Small persisted debug log (shown by the Diagnostics button).
function ns.Log(msg)
  local d = ns.diag
  if not d then return end
  d.log = d.log or {}
  table.insert(d.log, date("%H:%M:%S") .. " " .. msg)
  while #d.log > 200 do table.remove(d.log, 1) end
end

-------------------------------------------------------------------------------
-- Settings (per character)
-------------------------------------------------------------------------------
ns.DEFAULTS = {
  buffs = {},            -- [familyKey] = true/false; nil means "use family default"
  manaOnly = {},         -- [familyKey] = true/false; nil means "use family default"
  skipPvP = true,
  downrank = true,
  showTarget = true,
  includeSelf = true,    -- list me when I'm missing one of my own buffs
  refreshPct = 10,       -- also list buffs with this % or less of their time left (0 = off)
  restoreTarget = true,  -- after buffing someone from the box, go back to my previous target
  locked = false,
  hidden = false,
  hideWhenEmpty = false,
  hideResting = false,
  maxRows = 10,
  scale = 1.0,
  wheel = true,          -- wheel anywhere buffs the top player in range
  wheelHover = true,     -- wheel over a name buffs that player
  wheelMouseover = true, -- wheel over a player in the world (or their nameplate) buffs them
  wheelKey = "MOUSEWHEELDOWN",
  minimapAngle = 200,
  minimapHide = false,
  point = nil,           -- { point, relPoint, x, y }
}

local function merge(dst, src)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      merge(dst[k], v)
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

-------------------------------------------------------------------------------
-- Events. Handlers run under pcall; errors still reach the normal error
-- handler (visible with scriptErrors 1) without breaking other handlers.
-------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
local handlers = {}
ns.unknownEvents = {}

function ns.On(event, fn)
  if not handlers[event] then
    local ok = pcall(eventFrame.RegisterEvent, eventFrame, event)
    if not ok then
      ns.unknownEvents[#ns.unknownEvents + 1] = event
      return false
    end
    handlers[event] = {}
  end
  table.insert(handlers[event], fn)
  return true
end

eventFrame:SetScript("OnEvent", function(_, event, ...)
  local list = handlers[event]
  if not list then return end
  for i = 1, #list do
    local ok, err = pcall(list[i], event, ...)
    if not ok then geterrorhandler()(err) end
  end
end)

-- Modules register init functions; they run once at PLAYER_LOGIN after settings load.
ns.inits = {}
function ns.OnInit(fn) table.insert(ns.inits, fn) end

ns.On("ADDON_LOADED", function(_, name)
  if name ~= ADDON then return end
  StrangerBuffCharDB = StrangerBuffCharDB or {}
  StrangerBuffDiag = StrangerBuffDiag or {}
  StrangerBuffCharDB.clickMethod = nil  -- removed settings: a click on a name always buffs directly
  StrangerBuffCharDB.clickTargets = nil
  merge(StrangerBuffCharDB, ns.DEFAULTS)
  ns.db = StrangerBuffCharDB
  ns.diag = StrangerBuffDiag
end)

ns.On("PLAYER_LOGIN", function()
  for i = 1, #ns.inits do
    local ok, err = pcall(ns.inits[i])
    if not ok then geterrorhandler()(err) end
  end
  ns.Log("loaded v" .. ns.version)
end)

-------------------------------------------------------------------------------
-- Entry points that don't need typing: minimap button, addon compartment,
-- Esc > Options > AddOns. /sbuff still works for anyone who prefers it.
-------------------------------------------------------------------------------
function StrangerBuff_OnCompartmentClick()
  if ns.ToggleOptions then ns.ToggleOptions() end
end

SLASH_STRANGERBUFF1 = "/sbuff"
SLASH_STRANGERBUFF2 = "/strangerbuff"
SlashCmdList.STRANGERBUFF = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "diag" or msg == "probe" or msg == "debug" then
    if ns.ShowDiagnostics then ns.ShowDiagnostics() end
  else
    if ns.ToggleOptions then ns.ToggleOptions() end
  end
end

-- Key bindings (Esc > Options > Keybindings > AddOns > StrangerBuff)
BINDING_HEADER_STRANGERBUFF = "StrangerBuff"
_G["BINDING_NAME_CLICK StrangerBuffTargetButton:LeftButton"] = "Buff my target (next missing buff)"
_G["BINDING_NAME_CLICK StrangerBuffNextButton:LeftButton"] = "Buff the next nearby player"
_G["BINDING_NAME_CLICK StrangerBuffMouseoverButton:LeftButton"] = "Buff the player under my mouse"
