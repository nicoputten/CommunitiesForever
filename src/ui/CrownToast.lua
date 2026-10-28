-- CrownToast: "First to finish today!" under the minimap when you take the Doomsday crown (CF-57; board
-- DD07AddonToday, part 5). A gold glow that fades in over 400 ms and slides 12 px; with Ambient effects off it just
-- appears. AnimationGroup is unverified (V64): without it the toast just appears too.
local _, ns = ...

local CrownToast = {}
local Theme, Kit = ns.Theme, ns.Kit

CrownToast.SECONDS = 10
CrownToast.FADE_IN = 0.4
CrownToast.SLIDE = 12
local WIDTH = 300

local frame, timer
local shown = {} -- for the specs: { title, line, flavour } of each toast

local function create()
  frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(WIDTH, 86)
  frame:SetFrameStrata("DIALOG")
  if MinimapCluster then
    frame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", -10, -10)
  else
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -220)
  end
  local bg = Theme.fill(frame, "panel", "BACKGROUND")
  bg:SetAllPoints()
  local glow = frame:CreateTexture(nil, "BORDER")
  glow:SetAllPoints()
  glow:SetColorTexture(Theme.color("gold", 0.14))
  frame.edges = Kit.edges(frame, "gold")
  frame.title = Theme.text(frame, "group", "heading")
  frame.title:SetPoint("TOPLEFT", 14, -12)
  frame.line = Theme.text(frame, "small", "goldLight")
  frame.line:SetPoint("TOPLEFT", 14, -34)
  frame.flavour = Theme.text(frame, "small", "textDim")
  frame.flavour:SetPoint("TOPLEFT", 14, -54)
  frame.flavour:SetWidth(WIDTH - 28)
  frame.flavour:SetJustifyH("LEFT")
  -- Fade in and slide (guarded).
  local group = frame.CreateAnimationGroup and frame:CreateAnimationGroup()
  if group then
    local alpha = group:CreateAnimation("Alpha")
    if alpha then
      alpha:SetFromAlpha(0)
      alpha:SetToAlpha(1)
      alpha:SetDuration(CrownToast.FADE_IN)
    end
    local slide = group:CreateAnimation("Translation")
    if slide then
      slide:SetOffset(0, -CrownToast.SLIDE)
      slide:SetDuration(CrownToast.FADE_IN)
    end
    frame.intro = group
  end
  frame:Hide()
end

--[[ Shows the toast: opts = { title, line, flavour }. Ambient effects off (or no animations): it just appears. ]]
function CrownToast.show(opts, ambient)
  if not frame then create() end
  frame.title:SetText(opts.title or "")
  frame.line:SetText(opts.line or "")
  frame.flavour:SetText(opts.flavour or "")
  shown[#shown + 1] = { title = opts.title, line = opts.line, flavour = opts.flavour }
  frame:SetAlpha(1)
  frame:Show()
  if frame.intro and ambient then
    frame.intro:Stop()
    frame.intro:Play()
  end
  if timer then timer:Cancel() end
  timer = C_Timer.NewTimer(CrownToast.SECONDS, function()
    timer = nil
    frame:Hide()
  end)
end

-- For the specs.
function CrownToast.frame() return frame end
function CrownToast.shown() return shown end
function CrownToast.reset() frame, timer, shown = nil, nil, {} end

ns.CrownToast = CrownToast
return CrownToast
