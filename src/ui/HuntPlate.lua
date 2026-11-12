-- HuntPlate: a 26 px red crosshair above the enemy's nameplate while today's quarry is your target (CF-122, board
-- HB02 E; works with any unit frames). Midnight limits what addons may do with nameplates, so this is fully guarded:
-- our own frame on UIParent, anchored to the plate C_NamePlate.GetNamePlateForUnit("target") gives (unverified on
-- Forever, VERIFY.md V146). A missing API or a forbidden plate shows nothing; if anchoring errors, the crosshair
-- turns itself off for the session. HuntPlate.status() tells what happened, for the launch probe's V146 line.
local _, ns = ...

local HuntPlate = {}
local Theme = ns.Theme

HuntPlate.SIZE = 26
HuntPlate.ABOVE = 2 -- pixels between the plate's top and the crosshair

local cross
local blocked = false
local status -- "attached", "no api", "no plate", "forbidden", "blocked: <error>"

local function create()
  cross = CreateFrame("Frame", nil, UIParent)
  cross:SetFrameStrata("MEDIUM")
  cross:SetSize(HuntPlate.SIZE, HuntPlate.SIZE)
  cross.icon = cross:CreateTexture(nil, "OVERLAY")
  cross.icon:SetAllPoints()
  cross.icon:SetTexture(Theme.TEXTURES.crosshair)
  cross.icon:SetVertexColor(Theme.color("prey"))
  cross:Hide()
end

function HuntPlate.hide()
  if cross then
    cross:Hide()
    pcall(cross.ClearAllPoints, cross)
  end
end

-- The target's nameplate frame, or nil and why not.
local function plate()
  if not (C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil, "no api" end
  local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, "target")
  if not ok or type(p) ~= "table" then return nil, "no plate" end
  if p.IsForbidden then
    local okF, forbidden = pcall(p.IsForbidden, p)
    if not okF or forbidden then return nil, "forbidden" end
  end
  return p
end

-- Shows the crosshair over the target's plate (on = true) or hides it. Returns the status of this try.
function HuntPlate.show(on)
  if not on or blocked then
    HuntPlate.hide()
    return status
  end
  local p, why = plate()
  if not p then
    HuntPlate.hide()
    status = why
    return status
  end
  if not cross then create() end
  local ok, err = pcall(function()
    cross:ClearAllPoints()
    cross:SetPoint("BOTTOM", p, "TOP", 0, HuntPlate.ABOVE)
    cross:Show()
  end)
  if ok then
    status = "attached"
  else
    blocked = true
    status = "blocked: " .. tostring(err)
    pcall(cross.Hide, cross)
  end
  return status
end

function HuntPlate.isShown() return cross ~= nil and cross:IsShown() end
function HuntPlate.status() return status end

-- For the specs.
function HuntPlate.reset() cross, blocked, status = nil, false, nil end

ns.HuntPlate = HuntPlate
return HuntPlate
