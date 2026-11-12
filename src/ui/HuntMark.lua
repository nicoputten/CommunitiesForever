-- HuntMark: the prey mark on the target frame (CF-122, boards HB01 and HB02): a red crosshair ring over the target's
-- portrait and a "Prey" tag under it, while today's quarry is your target; a grey ring when it is already bagged
-- today. Our own frame, parented to UIParent and anchored to the target frame's portrait: nothing of Blizzard's is
-- moved, re-parented or hooked, so nothing protected is touched in combat (anchoring our frame to theirs is allowed).
-- It follows Edit Mode moves (anchored to the portrait) and scaling (the target frame's scale against UIParent's).
-- TargetFrame and TargetFrame.TargetFrameContainer.Portrait are unverified on Forever (VERIFY.md V146): every lookup
-- is guarded. HB02: only when Blizzard's target frame is in use (HuntToast.targetFrame: not replaced by a unit-frame
-- mod) and its portrait is found; otherwise no mark (the nameplate crosshair still shows, ui/HuntPlate.lua).
local _, ns = ...

local HuntMark = {}
local Theme = ns.Theme

HuntMark.SIZE = 76        -- the ring (the board's 62 px portrait plus the ticks)
HuntMark.PORTRAIT = 62    -- the board's portrait size the ring is drawn for

local mark
local shownKind -- "open" / "bagged" / nil, for the specs

-- The target frame's portrait (Retail layout), or nil.
local function portrait()
  local tf = rawget(_G, "TargetFrame")
  local container = tf and tf.TargetFrameContainer
  return container and container.Portrait or rawget(_G, "TargetFramePortrait")
end

local function create()
  mark = CreateFrame("Frame", nil, UIParent)
  mark:SetFrameStrata("MEDIUM")
  mark:SetSize(HuntMark.SIZE, HuntMark.SIZE)
  mark.ring = mark:CreateTexture(nil, "OVERLAY")
  mark.ring:SetAllPoints()
  mark.ring:SetTexture(Theme.TEXTURES.preyMark)
  -- The "Prey" tag: the only part that takes the mouse (its tooltip), small, under the portrait.
  mark.tag = CreateFrame("Frame", nil, mark)
  mark.tag:SetHeight(15)
  mark.tag.bg = Theme.fill(mark.tag, "preyBorder", "BACKGROUND")
  mark.tag.bg:SetAllPoints()
  mark.tag.edges = ns.Kit.edges(mark.tag, "prey")
  mark.tag.text = Theme.text(mark.tag, "badge", "white")
  mark.tag.text:SetPoint("CENTER")
  mark.tag.text:SetText(string.upper(ns.HuntAlerts.MARK_TAG))
  mark.tag:SetWidth((mark.tag.text.GetStringWidth and mark.tag.text:GetStringWidth() or 30) + 12)
  mark.tag:SetPoint("BOTTOMRIGHT", mark, "BOTTOMRIGHT", -12, -8)
  if mark.tag.EnableMouse then mark.tag:EnableMouse(true) end
  mark.tag:SetScript("OnEnter", function(self)
    if not GameTooltip then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(ns.HuntAlerts.MARK_TIP)
    GameTooltip:Show()
  end)
  mark.tag:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  mark:Hide()
end

-- Places the ring over the portrait (sized to it). False without Blizzard's target frame in use or its portrait.
local function place()
  local rect = ns.HuntToast.targetFrame()
  local p = rect and portrait()
  if not p then return false end
  local w = p.GetWidth and p:GetWidth()
  local size = type(w) == "number" and w > 0 and w * HuntMark.SIZE / HuntMark.PORTRAIT or HuntMark.SIZE
  if mark.SetScale then mark:SetScale(rect.scale or 1) end
  mark:ClearAllPoints()
  mark:SetSize(size, size)
  mark:SetPoint("CENTER", p, "CENTER", 0, 0)
  return true
end

-- Shows the mark for kind "open" (red) or "bagged" (grey); nil hides it.
function HuntMark.show(kind)
  if kind ~= "open" and kind ~= "bagged" then return HuntMark.hide() end
  if not mark then create() end
  local ok, placed = pcall(place)
  if not (ok and placed) then return HuntMark.hide() end
  local color = kind == "bagged" and "preyBagged" or "prey"
  mark.ring:SetVertexColor(Theme.color(color))
  mark.tag.bg:SetColorTexture(Theme.color(kind == "bagged" and "track" or "preyBorder"))
  mark:Show()
  shownKind = kind
end

function HuntMark.hide()
  if mark then mark:Hide() end
  shownKind = nil
end

-- For the specs.
function HuntMark.shown() return shownKind end
function HuntMark.frame() return mark end
function HuntMark.reset() mark, shownKind = nil, nil end

ns.HuntMark = HuntMark
return HuntMark
