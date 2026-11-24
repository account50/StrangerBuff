-- StrangerBuff: minimap button (no libraries). Left-click: options.
-- Right-click: show/hide the box. Drag: move around the minimap.
local ADDON, ns = ...

local b = CreateFrame("Button", "StrangerBuffMinimapButton", Minimap)
b:SetSize(31, 31)
b:SetFrameStrata("MEDIUM")
b:SetFrameLevel(8)
b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
b:RegisterForDrag("LeftButton")
b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

local icon = b:CreateTexture(nil, "BACKGROUND")
icon:SetSize(20, 20)
icon:SetPoint("TOPLEFT", 6, -5)
icon:SetTexture("Interface\\Icons\\Spell_Holy_WordFortitude")
icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
local ring = b:CreateTexture(nil, "OVERLAY")
ring:SetSize(53, 53)
ring:SetPoint("TOPLEFT")
ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function Place()
  local a = math.rad(ns.db.minimapAngle or 200)
  local r = (Minimap:GetWidth() / 2) + 5
  b:ClearAllPoints()
  b:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

b:SetScript("OnDragStart", function(self)
  self:SetScript("OnUpdate", function()
    local mx, my = Minimap:GetCenter()
    local cx, cy = GetCursorPosition()
    local s = Minimap:GetEffectiveScale()
    ns.db.minimapAngle = math.deg(math.atan2(cy / s - my, cx / s - mx))
    Place()
  end)
end)
b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

b:SetScript("OnClick", function(_, button)
  if button == "RightButton" then
    if InCombatLockdown() then return end
    ns.db.hidden = not ns.db.hidden
    ns.ApplySettings()
  else
    ns.ToggleOptions()
  end
end)
b:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_LEFT")
  GameTooltip:SetText("StrangerBuff")
  GameTooltip:AddLine("Left-click: options", 1, 1, 1)
  GameTooltip:AddLine("Right-click: show / hide the box", 1, 1, 1)
  GameTooltip:Show()
end)
b:SetScript("OnLeave", function() GameTooltip:Hide() end)

function ns.UpdateMinimap()
  Place()
  if ns.db.minimapHide then b:Hide() else b:Show() end
end

ns.OnInit(ns.UpdateMinimap)
