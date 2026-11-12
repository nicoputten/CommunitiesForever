-- HuntToast: the small "Prey in sight" toast (CF-122, board HB01): 340 x 62, just under the target frame, away from
-- the screen's centre, for HuntAlerts.TOAST_SECONDS. A red left edge, the race's initials in a ring with the class
-- icon, the crosshair kicker, the combination and a line ("+5 PvP · keep them targeted" or "Already bagged today ·
-- no points"); hover tells "Today's quarry · …". Slides in 150 ms, fades out 400 ms (AnimationGroup, guarded: V64).
-- Our own frame on UIParent, anchored to TargetFrame (unverified, VERIFY.md V146; without it, the board's spot).
local _, ns = ...

local HuntToast = {}
local Theme, Kit = ns.Theme, ns.Kit

HuntToast.WIDTH, HuntToast.HEIGHT = 340, 62
HuntToast.IN, HuntToast.OUT, HuntToast.SLIDE = 0.15, 0.4, 12
HuntToast.BELOW = 6                       -- pixels under the target frame
HuntToast.FALLBACK = { x = 270, y = -112 } -- the board's spot on a 1920 x 1080 screen, without TargetFrame

local toast
local shown = {} -- for the specs: { { title, line } }

local function group(region) return region.CreateAnimationGroup and region:CreateAnimationGroup() or nil end

-- Anchors the toast (dx: shifted left before the slide in).
local function place(dx)
  dx = dx or 0
  toast:ClearAllPoints()
  local tf = rawget(_G, "TargetFrame")
  if tf then
    toast:SetPoint("TOPLEFT", tf, "BOTTOMLEFT", 8 + dx, -HuntToast.BELOW)
  else
    toast:SetPoint("TOPLEFT", UIParent, "TOPLEFT", HuntToast.FALLBACK.x + dx, HuntToast.FALLBACK.y)
  end
end

local function finish()
  if toast.timer then toast.timer:Cancel() toast.timer = nil end
  if toast.outro then toast.outro:Stop() end
  toast:Hide()
end

local function create()
  toast = CreateFrame("Frame", nil, UIParent)
  toast:SetFrameStrata("HIGH")
  toast:SetSize(HuntToast.WIDTH, HuntToast.HEIGHT)
  toast.face = toast:CreateTexture(nil, "BACKGROUND")
  toast.face:SetAllPoints()
  toast.face:SetTexture("Interface\\Buttons\\WHITE8X8")
  local r, g, b, a = Theme.color("preyFace")
  local er, eg, eb, ea = Theme.color("preyFaceEnd")
  toast.face:SetColorTexture(r, g, b, a)
  if toast.face.SetGradient and CreateColor then -- unverified gradient (V89): a plain face without it
    pcall(toast.face.SetGradient, toast.face, "HORIZONTAL", CreateColor(r, g, b, a), CreateColor(er, eg, eb, ea))
  end
  toast.edges = Kit.edges(toast, "preyBorder")
  toast.left = Theme.fill(toast, "prey", "BORDER")
  toast.left:SetPoint("TOPLEFT")
  toast.left:SetPoint("BOTTOMLEFT")
  toast.left:SetWidth(4)
  -- The big faint crosshair behind, top right.
  toast.ghost = toast:CreateTexture(nil, "BORDER", nil, 1)
  toast.ghost:SetTexture(Theme.TEXTURES.crosshair)
  toast.ghost:SetVertexColor(Theme.color("prey", 0.14))
  toast.ghost:SetSize(110, 110)
  toast.ghost:SetPoint("TOPRIGHT", 18, 24)
  -- The race's ring with its initials, the class icon at its lower right.
  toast.medal = toast:CreateTexture(nil, "ARTWORK")
  toast.medal:SetTexture(Theme.TEXTURES.circle)
  toast.medal:SetVertexColor(Theme.color("preyMedal"))
  toast.medal:SetSize(36, 36)
  toast.medal:SetPoint("LEFT", 14, 2)
  toast.medalRing = toast:CreateTexture(nil, "ARTWORK", nil, 1)
  toast.medalRing:SetTexture(Theme.TEXTURES.ring)
  toast.medalRing:SetVertexColor(Theme.color("goldLight"))
  toast.medalRing:SetAllPoints(toast.medal)
  toast.initials = Theme.text(toast, "small", "goldPale")
  toast.initials:SetPoint("CENTER", toast.medal, "CENTER", 0, 0)
  toast.class = Kit.portrait(toast, 20)
  toast.class:SetPoint("CENTER", toast.medal, "BOTTOMRIGHT", -2, 2)
  -- Texts.
  toast.kickerIcon = toast:CreateTexture(nil, "ARTWORK")
  toast.kickerIcon:SetTexture(Theme.TEXTURES.crosshair)
  toast.kickerIcon:SetVertexColor(Theme.color("prey"))
  toast.kickerIcon:SetSize(12, 12)
  toast.kickerIcon:SetPoint("TOPLEFT", 66, -9)
  toast.kicker = Theme.text(toast, "badge", "prey")
  toast.kicker:SetPoint("LEFT", toast.kickerIcon, "RIGHT", 6, 0)
  toast.title = Theme.text(toast, "celebTitleSmall", "goldPale")
  toast.title:SetPoint("TOPLEFT", 66, -23)
  toast.line = Theme.text(toast, "tiny", "preyLine")
  toast.line:SetPoint("TOPLEFT", 66, -44)
  for _, fs in ipairs({ toast.kicker, toast.title, toast.line }) do
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
  end
  if toast.EnableMouse then toast:EnableMouse(true) end
  toast:SetScript("OnEnter", function(self)
    if not (GameTooltip and self.tip) then return end
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    GameTooltip:SetText(self.tip)
    GameTooltip:Show()
  end)
  toast:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  -- Motion: slide in from the left, fade out.
  toast.intro = group(toast)
  local slide = toast.intro and toast.intro:CreateAnimation("Translation")
  local fadeIn = toast.intro and toast.intro:CreateAnimation("Alpha")
  if slide and fadeIn then
    slide:SetOffset(HuntToast.SLIDE, 0)
    slide:SetDuration(HuntToast.IN)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(HuntToast.IN)
    toast.intro:SetScript("OnFinished", function() pcall(place) end)
  else
    toast.intro = nil
  end
  toast.outro = group(toast)
  local fadeOut = toast.outro and toast.outro:CreateAnimation("Alpha")
  if fadeOut then
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(HuntToast.OUT)
    toast.outro:SetScript("OnFinished", finish)
  else
    toast.outro = nil
  end
  toast:Hide()
end

--[[ Shows the toast: texts = HuntAlerts.toastText (kicker, title, line, tip), opts = { initials, classFile, ambient }.
It replaces one already showing. ]]
function HuntToast.show(texts, opts)
  opts = opts or {}
  if not toast then create() end
  finish()
  pcall(place)
  toast.kicker:SetText(string.upper(texts.kicker or ""))
  toast.title:SetText(texts.title or "")
  toast.line:SetText(texts.line or "")
  toast.tip = texts.tip
  toast.initials:SetText(opts.initials or "")
  toast.class:SetClass(opts.classFile)
  toast:SetAlpha(1)
  toast:Show()
  shown[#shown + 1] = { title = texts.title, line = texts.line }
  if opts.ambient and toast.intro then
    pcall(place, -HuntToast.SLIDE)
    toast.intro:Stop()
    toast.intro:Play()
  end
  toast.timer = C_Timer.NewTimer(ns.HuntAlerts.TOAST_SECONDS, function()
    toast.timer = nil
    if opts.ambient and toast.outro then
      toast.outro:Stop()
      toast.outro:Play()
    else
      finish()
    end
  end)
end

function HuntToast.isShown() return toast ~= nil and toast:IsShown() end

-- For the specs.
function HuntToast.shown() return shown end
function HuntToast.frame() return toast end
function HuntToast.reset() toast, shown = nil, {} end

ns.HuntToast = HuntToast
return HuntToast
