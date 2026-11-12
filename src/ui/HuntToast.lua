-- HuntToast: the small "Prey in sight" toast (CF-122, boards HB01 and HB02): 340 x 62, next to the target frame, for
-- HuntAlerts.TOAST_SECONDS. A red left edge, the race's initials in a ring with the class
-- icon, the crosshair kicker, the combination and a line ("+5 PvP · keep them targeted" or "Already bagged today ·
-- no points"); hover tells "Today's quarry · …". Slides in 150 ms, fades out 400 ms (AnimationGroup, guarded: V64).
-- Placement (HB02, HuntAlerts.placement): read Blizzard's TargetFrame each time the toast opens and go above it (its
-- bottom in the lower half of the screen, the Edit Mode default) or below it, flipped when it would leave the screen,
-- at the target frame's scale; when a unit-frame mod replaced it (hidden, re-parented to a hidden frame, or its
-- events taken away), the own spot in the upper centre. A spot the player moved it to (/cf hunt move, Settings >
-- Move: a box to drag with Reset and Done) always wins. Our own frame on UIParent: nothing of Blizzard's is moved.
-- TargetFrame's methods used here are guarded (VERIFY.md V146).
local _, ns = ...

local HuntToast = {}
local Theme, Kit = ns.Theme, ns.Kit

HuntToast.WIDTH, HuntToast.HEIGHT = 340, 62
HuntToast.IN, HuntToast.OUT, HuntToast.SLIDE = 0.15, 0.4, 12

local toast, mover
local shown = {} -- for the specs: { { title, line } }
local lastPlacement -- for the specs: HuntAlerts.placement's result

local function group(region) return region.CreateAnimationGroup and region:CreateAnimationGroup() or nil end

local function uiScale()
  local s = UIParent.GetEffectiveScale and UIParent:GetEffectiveScale()
  return type(s) == "number" and s > 0 and s or 1
end

--[[ Blizzard's target frame when it is in use, in UIParent units: { left, bottom, top, scale } (scale: its own
against UIParent's), or nil when it is missing or a unit-frame mod replaced it. ]]
function HuntToast.targetFrame()
  local tf = rawget(_G, "TargetFrame")
  if not tf then return nil end
  local ok, rect = pcall(function()
    local parent = tf.GetParent and tf:GetParent()
    if parent and parent.IsShown and not parent:IsShown() then return nil end -- re-parented to a hidden frame
    if tf.IsEventRegistered and not tf:IsEventRegistered("PLAYER_TARGET_CHANGED") then return nil end
    if UnitExists and UnitExists("target") and tf.IsVisible and not tf:IsVisible() then return nil end
    local l, b, t = tf:GetLeft(), tf:GetBottom(), tf:GetTop()
    if type(l) ~= "number" or type(b) ~= "number" or type(t) ~= "number" then return nil end
    local own = tf.GetEffectiveScale and tf:GetEffectiveScale()
    local k = type(own) == "number" and own > 0 and own / uiScale() or 1
    return { left = l * k, bottom = b * k, top = t * k, scale = k }
  end)
  return ok and rect or nil
end

-- Where the toast goes now (HuntAlerts.placement), with its scale.
local function placementNow(saved)
  local rect = not saved and HuntToast.targetFrame() or nil
  local s = rect and rect.scale or 1
  local p = ns.HuntAlerts.placement({ saved = saved, frame = rect, width = HuntToast.WIDTH * s,
    height = HuntToast.HEIGHT * s, screen = { width = UIParent:GetWidth(), height = UIParent:GetHeight() } })
  return p, s
end

-- Anchors the toast (dx: shifted left before the slide in); saved: the player's spot or nil.
local function place(dx, saved)
  local p, s = placementNow(saved)
  lastPlacement = p
  if toast.SetScale then toast:SetScale(s) end
  toast:ClearAllPoints()
  toast:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", (p.x + (dx or 0)) / s, p.y / s)
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
    toast.intro:SetScript("OnFinished", function() pcall(place, 0, toast.saved) end)
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

--[[ Shows the toast: texts = HuntAlerts.toastText (kicker, title, line, tip), opts = { initials, classFile, ambient,
saved = { x, y } (the player's spot) }. It replaces one already showing. ]]
function HuntToast.show(texts, opts)
  opts = opts or {}
  if not toast then create() end
  finish()
  toast.saved = opts.saved
  pcall(place, 0, opts.saved)
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
    pcall(place, -HuntToast.SLIDE, opts.saved)
    toast.intro:Stop()
    toast.intro:Play()
  end
  local this = toast
  toast.timer = C_Timer.NewTimer(ns.HuntAlerts.TOAST_SECONDS, function()
    if toast ~= this then return end -- reset in between (specs)
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

-- ===== Moving (HB02 D) =====

local function createMover()
  mover = CreateFrame("Frame", nil, UIParent)
  mover:SetFrameStrata("DIALOG")
  mover:SetSize(HuntToast.WIDTH, HuntToast.HEIGHT)
  mover.fill = mover:CreateTexture(nil, "BACKGROUND")
  mover.fill:SetAllPoints()
  mover.fill:SetColorTexture(Theme.color("goldLight", 0.12))
  mover.edges = Kit.edges(mover, "goldLight")
  mover.label = Theme.text(mover, "button", "goldPale")
  mover.label:SetPoint("CENTER")
  mover.label:SetText("Hunt alerts")
  if mover.SetMovable then mover:SetMovable(true) end
  if mover.SetClampedToScreen then mover:SetClampedToScreen(true) end
  if mover.EnableMouse then mover:EnableMouse(true) end
  if mover.RegisterForDrag then mover:RegisterForDrag("LeftButton") end
  mover:SetScript("OnDragStart", function(self) self:StartMoving() end)
  mover:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local x, y = self:GetLeft(), self:GetBottom()
    if type(x) == "number" and type(y) == "number" and self.onSave then self.onSave({ x = x, y = y }) end
  end)
  -- The small panel: title, "Drag to move", Reset and Done.
  local panel = CreateFrame("Frame", nil, mover)
  panel:SetSize(230, 84)
  panel:SetPoint("TOPLEFT", mover, "BOTTOMLEFT", 0, -8)
  panel.bg = Theme.fill(panel, "panel", "BACKGROUND")
  panel.bg:SetAllPoints()
  panel.edges = Kit.edges(panel, "goalEdge")
  panel.title = Theme.text(panel, "section", "goldLight")
  panel.title:SetPoint("TOPLEFT", 12, -10)
  panel.title:SetText("Hunt alerts")
  panel.hint = Theme.text(panel, "small", "textDim")
  panel.hint:SetPoint("TOPLEFT", 12, -32)
  panel.hint:SetText("Drag to move")
  mover.reset = Kit.button(panel, "Reset", function()
    if mover.onReset then mover.onReset() end
    HuntToast.placeMover(nil)
  end)
  mover.reset:SetPoint("BOTTOMLEFT", 12, 10)
  mover.done = Kit.button(panel, "Done", function() HuntToast.stopMoving() end, "primary")
  mover.done:SetPoint("LEFT", mover.reset, "RIGHT", 6, 0)
  mover.panel = panel
  mover:Hide()
end

-- Puts the box where the toast would show now (saved: the player's spot or nil: automatic).
function HuntToast.placeMover(saved)
  if not mover then return end
  local p = placementNow(saved)
  mover:ClearAllPoints()
  mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
end

-- Shows the box to drag. opts = { saved = { x, y } or nil, onSave(spot), onReset() }.
function HuntToast.startMoving(opts)
  opts = opts or {}
  if not mover then createMover() end
  mover.onSave, mover.onReset = opts.onSave, opts.onReset
  HuntToast.placeMover(opts.saved)
  mover:Show()
end

function HuntToast.stopMoving()
  if mover then mover:Hide() end
end

function HuntToast.isMoving() return mover ~= nil and mover:IsShown() end

-- For the specs.
function HuntToast.shown() return shown end
function HuntToast.frame() return toast end
function HuntToast.mover() return mover end
function HuntToast.placement() return lastPlacement end
function HuntToast.reset() toast, mover, shown, lastPlacement = nil, nil, {}, nil end

ns.HuntToast = HuntToast
return HuntToast
