-- RunBanner: the run reminder banners at the top of the screen (CF-63d, board
-- docs/design/cf-63-2026-10/CF63Banners.dc.html; they replace CF-48's note under the minimap). 30 minutes before
-- ("In 30 minutes"), 15 minutes before ("Invites open"; the organiser gets Invite all) and at the start ("Starting
-- now"): the dungeon's short name and "Healer · Vesgar Bloodhoof · 20:30". Gold lines above and below, a dark
-- band fading out to the sides. It fades in over 0.3 s, stays 10 s and fades out over 1 s (no fades without
-- ambient effects); a click opens the window on the run. Several wait in a queue.
local _, ns = ...

local RunBanner = {}

RunBanner.SECONDS = 10
RunBanner.FADE_IN = 0.3
RunBanner.FADE_OUT = 1
RunBanner.WIDTH = 560
RunBanner.TITLES = { soon = "In 30 minutes", invites = "Invites open", start = "Starting now" }
RunBanner.MAX_WAITING = 5

local banner
local waiting = {}
local shown = {} -- for the specs: { kind, title, name, line, invite } in order

local showNext

-- A horizontal band: transparent at the ends (16 % each), the colour between; three textures, no gradients
-- needed (SetGradient is unverified, V61).
local function band(parent, colorName, alpha, layer, height, anchor)
  local parts = {}
  for i = 1, 3 do
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(ns.Theme.color(colorName, alpha))
    parts[i] = t
  end
  local side = math.floor(RunBanner.WIDTH * 0.16)
  for i, t in ipairs(parts) do
    if height then
      t:SetHeight(height)
      t:SetPoint(anchor, parent, anchor, 0, 0)
    else
      t:SetPoint("TOP")
      t:SetPoint("BOTTOM")
    end
    if i == 1 then
      t:SetPoint("LEFT", parent, "LEFT", 0, 0)
      t:SetWidth(side)
      t:SetAlpha(0.35)
    elseif i == 2 then
      t:SetPoint("LEFT", parent, "LEFT", side, 0)
      t:SetPoint("RIGHT", parent, "RIGHT", -side, 0)
    else
      t:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
      t:SetWidth(side)
      t:SetAlpha(0.35)
    end
  end
  return parts
end

local function create()
  local Theme, Kit = ns.Theme, ns.Kit
  local b = CreateFrame("Button", nil, UIParent)
  b:SetSize(RunBanner.WIDTH, 92)
  b:SetPoint("TOP", UIParent, "TOP", 0, -96) -- below the LEVEL UP toast (CF-44, at -34)
  b:SetFrameStrata("DIALOG")
  band(b, "outline", 0.85, "BACKGROUND")
  band(b, "goldLight", 1, "BORDER", 2, "TOP")
  band(b, "goldLight", 1, "BORDER", 2, "BOTTOM")
  b.title = Theme.text(b, "small", "gold")
  b.title:SetPoint("TOP", 0, -14)
  b.name = Theme.text(b, "banner", "goldPale")
  b.name:SetPoint("TOP", b.title, "BOTTOM", 0, -4)
  b.line = Theme.text(b, "body", "text")
  b.line:SetPoint("TOP", b.name, "BOTTOM", 0, -4)
  b.invite = Kit.button(b, "Invite all", nil, "primary")
  b.invite:SetHeight(30)
  b.invite:SetPoint("TOP", b.line, "BOTTOM", 0, -8)
  if b.invite.SetMotionScriptsWhileDisabled then b.invite:SetMotionScriptsWhileDisabled(true) end
  b.invite:Hide()
  -- Fades (guarded: without AnimationGroup it just shows and hides, V64).
  local fadeIn = b.CreateAnimationGroup and b:CreateAnimationGroup()
  local inAlpha = fadeIn and fadeIn:CreateAnimation("Alpha")
  if inAlpha then
    inAlpha:SetFromAlpha(0)
    inAlpha:SetToAlpha(1)
    inAlpha:SetDuration(RunBanner.FADE_IN)
    b.fadeIn = fadeIn
  end
  local fadeOut = b.CreateAnimationGroup and b:CreateAnimationGroup()
  local outAlpha = fadeOut and fadeOut:CreateAnimation("Alpha")
  if outAlpha then
    outAlpha:SetFromAlpha(1)
    outAlpha:SetToAlpha(0)
    outAlpha:SetDuration(RunBanner.FADE_OUT)
    outAlpha:SetStartDelay(RunBanner.SECONDS - RunBanner.FADE_OUT)
    b.fadeOut = fadeOut
  end
  b:SetScript("OnClick", function(self) if self.runId then ns.MainFrame.showRun(self.runId) end end)
  b:Hide()
  banner = b
end

--[[ The third line: "Healer · Vesgar Bloodhoof · 20:30": your role, the character you go as, the start in your
clock. item = { role, char, at } (each optional). ]]
function RunBanner.line(item)
  local parts = {}
  if ns.PlannedRuns.ROLE_NAMES[item.role] then parts[#parts + 1] = ns.PlannedRuns.ROLE_NAMES[item.role] end
  if item.char then parts[#parts + 1] = tostring(item.char) end
  if item.at and date then parts[#parts + 1] = ns.PlannedRuns.clock(item.at, date) end
  return table.concat(parts, " \194\183 ")
end

function showNext()
  local item = ns.Queue.pop(waiting)
  if not item then return end
  local b = banner
  local title = RunBanner.TITLES[item.kind] or ""
  local line = RunBanner.line(item)
  b.title:SetText(title)
  b.name:SetText(item.name or "")
  b.line:SetText(line)
  b.runId = item.runId
  local invite = item.kind == "invites" and item.onInvite ~= nil
  b.invite:SetShown(invite)
  if invite then
    local combat = InCombatLockdown and InCombatLockdown()
    b.invite:SetEnabled(not combat)
    b.invite.tooltip = combat and "Not in combat" or nil
    b.invite:SetScript("OnClick", function()
      if not (InCombatLockdown and InCombatLockdown()) then item.onInvite() end
    end)
  end
  b:SetHeight(invite and 132 or 92)
  shown[#shown + 1] = { kind = item.kind, title = title, name = item.name, line = line, invite = invite }
  b:SetAlpha(1)
  b:Show()
  if ns.Kit.ambient() then
    if b.fadeIn then
      b.fadeIn:Stop()
      b.fadeIn:Play()
    end
    if b.fadeOut then
      b.fadeOut:Stop()
      b.fadeOut:Play()
    end
  end
  if b.timer then b.timer:Cancel() end
  b.timer = C_Timer.NewTimer(RunBanner.SECONDS, function()
    b.timer = nil
    b:Hide()
    showNext()
  end)
end

--[[ item = { kind = "soon" | "invites" | "start", runId, name (the short dungeon name), role, char, at,
onInvite (the organiser's Invite all, on "invites") }. Shows it now, or after the ones already waiting. ]]
function RunBanner.show(item)
  if not banner then create() end
  ns.Queue.push(waiting, item, RunBanner.MAX_WAITING)
  if not banner:IsShown() then showNext() end
end

-- For the specs: the banner frame (nil before the first), what was shown, in order.
function RunBanner.frame() return banner end
function RunBanner.shown() return shown end
function RunBanner.reset()
  if banner then banner:Hide() end
  banner, waiting, shown = nil, {}, {}
end

ns.RunBanner = RunBanner
return RunBanner
