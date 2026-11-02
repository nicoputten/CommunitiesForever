-- CelebrationBanner: the celebration banners on screen (CF-67; boards CB01 to CB08 in
-- docs/design/celebrations-2026-11/).
-- Yours: a long plaque with angled ends and a round medallion on the left, low in the middle of the screen, a colour
-- edge per kind, three sizes by weight. Friends': one quiet line bottom left above the chat, at most 3 stacked. Hover
-- pauses and tells what a click opens, a click opens the Doomsday tab, right-click dismisses. Motion (CB08) with
-- Ambient effects on and AnimationGroup present (V64): rise in, the medallion pops, big feats turn their rays; out:
-- fade and sink. Without them a banner appears, stays and disappears.
local _, ns = ...

local CelebrationBanner = {}
local Theme, Kit = ns.Theme, ns.Kit

CelebrationBanner.BOTTOM = 190    -- the banner's bottom above the screen's bottom (CB07)
CelebrationBanner.IN, CelebrationBanner.OUT = 0.25, 0.4
CelebrationBanner.RISE, CelebrationBanner.SINK = 16, 8
CelebrationBanner.FOLDED = 22     -- the folded line adds this to the height (CB05)
CelebrationBanner.RAYS_TURN = 24  -- seconds per turn of a big feat's rays

-- Per weight: plaque width and height, medallion, title and points text roles (CB01, CB02, CB04).
CelebrationBanner.SIZES = {
  small = { width = 400, height = 64, medal = 58, title = "celebTitleSmall", points = "celebPointsSmall" },
  medium = { width = 470, height = 80, medal = 74, title = "celebTitleMedium", points = "celebPointsMedium" },
  big = { width = 540, height = 98, medal = 92, title = "celebTitleBig", points = "celebPointsMedium" },
}

-- Edge colour per kind of moment.
CelebrationBanner.EDGES = { pve = "celebPve", pvp = "celebPvp", day = "celebDay", weekly = "celebWeekly",
                            bounty = "celebPvp", epic = "celebEpic" }

-- Medallion icons: texture and size as a share of the medallion (the boards' sizes).
local ICONS = {
  goal = { "goalDone", 28 / 58 }, emblem = { "emblem", 54 / 74 }, hourglass = { "hourglass", 48 / 74 },
  swords = { "swords", 48 / 74 }, rank = { "rank", 62 / 92 }, epic = { "epic", 71 / 92 },
}

local END = 18 -- the angled ends' width

local banner
local friendLines = {}       -- the friends' line frames (reused)
local shown, friendsShown = {}, {} -- for the specs: what was shown

local function edgeColor(edge) return CelebrationBanner.EDGES[edge] or "celebDay" end

-- A vertical gradient on a texture (unverified: Texture:SetGradient with CreateColor, V89); a plain colour without.
local function gradient(tex, topName, bottomName)
  local tr, tg, tb = Theme.color(topName)
  local br, bg, bb = Theme.color(bottomName)
  tex:SetTexture("Interface\\Buttons\\WHITE8X8")
  if tex.SetGradient and CreateColor then
    local ok = pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(br, bg, bb, 1), CreateColor(tr, tg, tb, 1))
    if ok then return end
  end
  tex:SetColorTexture(tr, tg, tb, 1)
end

-- One layer of the plaque (the edge or the face): two angled ends and the middle.
local function layer(parent, drawLayer, sub)
  local l = {}
  l.left = parent:CreateTexture(nil, drawLayer, nil, sub)
  l.left:SetTexture(Theme.TEXTURES.plaqueEnd)
  l.right = parent:CreateTexture(nil, drawLayer, nil, sub)
  l.right:SetTexture(Theme.TEXTURES.plaqueEnd)
  l.right:SetTexCoord(1, 0, 0, 1)
  l.middle = parent:CreateTexture(nil, drawLayer, nil, sub)
  return l
end

local function placeLayer(l, inset, width, height)
  local h, e = height - 2 * inset, END - inset
  l.left:ClearAllPoints()
  l.left:SetPoint("TOPLEFT", inset, -inset)
  l.left:SetSize(e, h)
  l.right:ClearAllPoints()
  l.right:SetPoint("TOPRIGHT", -inset, -inset)
  l.right:SetSize(e, h)
  l.middle:ClearAllPoints()
  l.middle:SetPoint("TOPLEFT", END, -inset)
  l.middle:SetSize(width - 2 * END, h)
end

local function colorLayer(l, topName, bottomName)
  for _, tex in ipairs({ l.left, l.right }) do
    tex:SetTexture(Theme.TEXTURES.plaqueEnd)
    local r, g, b = Theme.color(topName)
    tex:SetVertexColor(r, g, b, 1)
    if tex.SetGradient and CreateColor then
      local br, bg, bb = Theme.color(bottomName)
      pcall(tex.SetGradient, tex, "VERTICAL", CreateColor(br, bg, bb, 1), CreateColor(r, g, b, 1))
    end
  end
  gradient(l.middle, topName, bottomName)
end

-- Animations (guarded, V64): returns the group or nil.
local function group(region) return region.CreateAnimationGroup and region:CreateAnimationGroup() or nil end

local function anim(g, kind)
  local a = g and g:CreateAnimation(kind)
  return a
end

local create

local function stopTimer()
  if banner.timer then
    banner.timer:Cancel()
    banner.timer = nil
  end
end

local function finish()
  stopTimer()
  if banner.outro then banner.outro:Stop() end
  if banner.intro then banner.intro:Stop() end
  if banner.spin then banner.spin:Stop() end
  banner:Hide()
  local done = banner.onDone
  banner.onDone = nil
  if done then done() end
end

local function leave()
  stopTimer()
  if banner.ambient and banner.outro then
    banner.outro:Stop()
    banner.outro:Play()
  else
    finish()
  end
end

local function startTimer(seconds)
  stopTimer()
  banner.endsAt = (GetTime and GetTime() or 0) + seconds
  banner.timer = C_Timer.NewTimer(seconds, function()
    banner.timer = nil
    leave()
  end)
end

function create()
  banner = CreateFrame("Button", nil, UIParent)
  banner:SetFrameStrata("DIALOG")
  banner:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, CelebrationBanner.BOTTOM)
  if banner.RegisterForClicks then banner:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  banner.edge = layer(banner, "BACKGROUND", 0)
  banner.face = layer(banner, "BACKGROUND", 1)
  banner.topLine = banner:CreateTexture(nil, "BORDER")
  banner.topLine:SetTexture(Theme.TEXTURES.edgeLine)
  banner.topLine:SetHeight(3)
  banner.topLine:SetPoint("TOPLEFT", END, -1.5)
  banner.topLine:SetPoint("TOPRIGHT", -END, -1.5)
  -- The medallion: its own frame, so it can pop; rays and glow behind it.
  banner.medal = CreateFrame("Frame", nil, banner)
  banner.rays = banner:CreateTexture(nil, "BORDER", nil, 1)
  banner.rays:SetTexture(Theme.TEXTURES.rays)
  banner.rays:SetVertexColor(Theme.color("celebDay", 0.22))
  banner.glow = banner:CreateTexture(nil, "BORDER", nil, 2)
  banner.glow:SetTexture(Theme.TEXTURES.glow)
  banner.medalBg = banner.medal:CreateTexture(nil, "ARTWORK", nil, 0)
  banner.medalBg:SetTexture(Theme.TEXTURES.medal)
  banner.medalBg:SetPoint("CENTER")
  banner.medalRing = banner.medal:CreateTexture(nil, "ARTWORK", nil, 1)
  banner.medalRing:SetTexture(Theme.TEXTURES.medalRing)
  banner.medalRing:SetPoint("CENTER")
  banner.icon = banner.medal:CreateTexture(nil, "ARTWORK", nil, 2)
  banner.icon:SetPoint("CENTER")
  banner.crown = banner.medal:CreateTexture(nil, "OVERLAY")
  banner.crown:SetTexture(Theme.TEXTURES.crown)
  banner.crown:SetSize(26, 26)
  -- Texts.
  banner.kicker = Theme.text(banner, "celebKicker", "celebDay")
  banner.title = Theme.text(banner, "celebTitleMedium", "goldPale")
  banner.line = Theme.text(banner, "body", "celebLine")
  banner.folded = Theme.text(banner, "small", "textDim")
  banner.pointsText = Theme.text(banner, "celebPointsMedium", "celebDay")
  for _, fs in ipairs({ banner.kicker, banner.title, banner.line, banner.folded }) do
    fs:SetJustifyH("LEFT")
    if fs.SetWordWrap then fs:SetWordWrap(false) end
  end
  banner.badge = CreateFrame("Frame", nil, banner)
  banner.badge:SetHeight(16)
  banner.badge.bg = Theme.fill(banner.badge, "celebDay", "BACKGROUND")
  banner.badge.bg:SetAllPoints()
  banner.badge.text = Theme.text(banner.badge, "badge", "outline")
  banner.badge.text:SetPoint("CENTER")
  -- Motion (CB08).
  banner.intro = group(banner)
  local rise = anim(banner.intro, "Translation")
  local fadeIn = anim(banner.intro, "Alpha")
  if rise and fadeIn then
    rise:SetOffset(0, CelebrationBanner.RISE)
    rise:SetDuration(CelebrationBanner.IN)
    fadeIn:SetFromAlpha(0)
    fadeIn:SetToAlpha(1)
    fadeIn:SetDuration(CelebrationBanner.IN)
    banner.intro:SetScript("OnFinished", function()
      banner:ClearAllPoints()
      banner:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, CelebrationBanner.BOTTOM)
    end)
  else
    banner.intro = nil
  end
  banner.pop = group(banner.medal)
  local grow, settle = anim(banner.pop, "Scale"), anim(banner.pop, "Scale")
  if grow and settle and grow.SetScaleFrom then
    grow:SetScaleFrom(0.8, 0.8)
    grow:SetScaleTo(1.05, 1.05)
    grow:SetDuration(0.2)
    grow:SetOrder(1)
    settle:SetScaleFrom(1.05, 1.05)
    settle:SetScaleTo(1, 1)
    settle:SetDuration(0.1)
    settle:SetOrder(2)
  else
    banner.pop = nil
  end
  banner.outro = group(banner)
  local sink = anim(banner.outro, "Translation")
  local fadeOut = anim(banner.outro, "Alpha")
  if sink and fadeOut then
    sink:SetOffset(0, -CelebrationBanner.SINK)
    sink:SetDuration(CelebrationBanner.OUT)
    fadeOut:SetFromAlpha(1)
    fadeOut:SetToAlpha(0)
    fadeOut:SetDuration(CelebrationBanner.OUT)
    banner.outro:SetScript("OnFinished", finish)
  else
    banner.outro = nil
  end
  banner.spin = group(banner.rays)
  local turn = anim(banner.spin, "Rotation")
  if turn and turn.SetDegrees then
    turn:SetDegrees(-360)
    turn:SetDuration(CelebrationBanner.RAYS_TURN)
    banner.spin:SetLooping("REPEAT")
  else
    banner.spin = nil
  end
  -- Mouse (CB08): hover pauses, a click opens, right-click dismisses.
  banner:SetScript("OnEnter", function(self)
    if self.timer and self.endsAt then
      self.remaining = math.max(1, self.endsAt - (GetTime and GetTime() or 0))
      stopTimer()
    end
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:SetText(self.view == "feats" and "Click to open Feats" or "Click to open Doomsday")
      GameTooltip:Show()
    end
  end)
  banner:SetScript("OnLeave", function(self)
    if GameTooltip then GameTooltip:Hide() end
    if self:IsShown() and not self.timer and self.remaining then
      startTimer(self.remaining)
      self.remaining = nil
    end
  end)
  banner:SetScript("OnClick", function(self, button)
    if button ~= "RightButton" and self.onClick then self.onClick(self.view) end
    if GameTooltip then GameTooltip:Hide() end
    finish()
  end)
  banner:Hide()
end

-- Lays the banner out for a moment (Celebrations.fold's banner).
local function layout(b)
  local size = CelebrationBanner.SIZES[b.weight] or CelebrationBanner.SIZES.medium
  local edge = edgeColor(b.edge)
  local height = size.height + (b.folded and CelebrationBanner.FOLDED or 0)
  banner:SetSize(size.width, height)
  placeLayer(banner.edge, 0, size.width, height)
  placeLayer(banner.face, 1.5, size.width, height)
  colorLayer(banner.edge, edge, "celebBronze")
  colorLayer(banner.face, "plaqueTop", "plaqueBottom")
  banner.topLine:SetVertexColor(Theme.color(edge))
  -- Medallion: left -10, centred; rays and glow for big ones.
  local m = size.medal
  banner.medal:SetSize(m + 7, m + 7)
  banner.medal:ClearAllPoints()
  banner.medal:SetPoint("CENTER", banner, "LEFT", -10 + m / 2, 0)
  banner.medalBg:SetSize(m + 7, m + 7)
  banner.medalRing:SetSize(m + 7, m + 7)
  banner.medalRing:SetVertexColor(Theme.color(edge))
  local icon = ICONS[b.icon] or ICONS.emblem
  banner.icon:SetTexture(Theme.TEXTURES[icon[1]])
  banner.icon:SetSize(math.floor(m * icon[2] + 0.5), math.floor(m * icon[2] + 0.5))
  banner.crown:ClearAllPoints()
  banner.crown:SetPoint("TOPLEFT", banner, "TOPLEFT", 25, 14)
  if b.crown then banner.crown:Show() else banner.crown:Hide() end
  local big = b.weight == "big"
  banner.rays:ClearAllPoints()
  banner.rays:SetPoint("CENTER", banner.medal, "CENTER", 9, 0)
  banner.rays:SetSize(142, 142)
  banner.glow:ClearAllPoints()
  banner.glow:SetPoint("CENTER", banner.medal, "CENTER")
  banner.glow:SetSize(m + 44, m + 44)
  banner.glow:SetVertexColor(Theme.color(edge, 0.7))
  if big then banner.rays:Show() banner.glow:Show() else banner.rays:Hide() banner.glow:Hide() end
  -- Texts: left of them the medallion, right 26 px; the points on the right.
  local left, right = m + 16, 26
  Theme.font(banner.title, size.title)
  Theme.font(banner.pointsText, size.points)
  banner.kicker:SetTextColor(Theme.color(edge))
  banner.pointsText:SetTextColor(Theme.color(edge))
  banner.kicker:SetText(string.upper(b.kicker or ""))
  banner.title:SetText(b.title or "")
  local line = b.line or ""
  if b.kind == "day" and b.dayPoints then
    line = ns.Celebrations.dayLine(b.dayPoints, b.streak,
      "|T" .. Theme.TEXTURES.flame .. ":12:12|t")
  end
  banner.line:SetText(line)
  banner.folded:SetText(b.folded or "")
  banner.pointsText:SetText(b.points or "")
  banner.pointsText:ClearAllPoints()
  banner.pointsText:SetPoint("RIGHT", banner, "RIGHT", -right, 0)
  local measured = banner.pointsText.GetStringWidth and banner.pointsText:GetStringWidth() or 40
  local pointsWidth = b.points and (measured + 14) or 0
  local textWidth = size.width - left - right - pointsWidth
  local lines = { banner.kicker, banner.title, banner.line }
  if b.folded then lines[#lines + 1] = banner.folded end
  local heights = { kicker = 15, title = size.height >= 80 and (size.height >= 98 and 32 or 27) or 22, line = 17,
                    folded = 18 }
  local total = heights.kicker + heights.title + heights.line + (b.folded and heights.folded or 0)
  local y = -(height - total) / 2
  for _, fs in ipairs(lines) do
    fs:ClearAllPoints()
    fs:SetPoint("TOPLEFT", banner, "TOPLEFT", left, y)
    fs:SetWidth(textWidth)
    y = y - (fs == banner.kicker and heights.kicker or fs == banner.title and heights.title
      or fs == banner.line and heights.line or heights.folded)
  end
  if b.badge then
    banner.badge.text:SetText(b.badge)
    banner.badge:SetWidth((banner.badge.text.GetStringWidth and banner.badge.text:GetStringWidth() or 100) + 14)
    local titleWidth = banner.title.GetStringWidth and banner.title:GetStringWidth() or 0
    banner.badge:ClearAllPoints()
    banner.badge:SetPoint("LEFT", banner.title, "LEFT", math.min(titleWidth, textWidth - 130) + 8, 2)
    banner.badge:Show()
  else
    banner.badge:Hide()
  end
end

--[[ Shows a banner (Celebrations.fold's result) at once, replacing one on screen. opts = { ambient, scale,
onClick(view), onDone }. It stays Celebrations.SECONDS[weight] (5 s for the Preview). ]]
function CelebrationBanner.show(b, opts)
  if not banner then create() end
  opts = opts or {}
  if banner:IsShown() then
    stopTimer()
    if banner.outro then banner.outro:Stop() end
    banner.onDone = nil
  end
  layout(b)
  shown[#shown + 1] = b
  banner.view, banner.onClick, banner.onDone = b.view, opts.onClick, opts.onDone
  banner.ambient, banner.remaining = opts.ambient == true, nil
  banner:SetScale(opts.scale or 1)
  banner:SetAlpha(1)
  banner:ClearAllPoints()
  if banner.ambient and banner.intro then
    banner:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, CelebrationBanner.BOTTOM - CelebrationBanner.RISE)
  else
    banner:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, CelebrationBanner.BOTTOM)
  end
  banner:Show()
  if banner.ambient then
    if banner.intro then banner.intro:Stop() banner.intro:Play() end
    if banner.pop then banner.pop:Stop() banner.pop:Play() end
    if banner.spin and b.weight == "big" then banner.spin:Play() end
  end
  startTimer(ns.Celebrations.SECONDS[b.weight] or 5)
end

function CelebrationBanner.isShown() return banner ~= nil and banner:IsShown() end

-- Dismisses the banner now (as a right-click).
function CelebrationBanner.dismiss() if CelebrationBanner.isShown() then finish() end end

-- ===== Friends' lines (CB06) =====

local function placeFriends()
  for _, f in ipairs(friendLines) do
    if f:IsShown() then
      f:ClearAllPoints()
      if ChatFrame1 then
        f:SetPoint("BOTTOMLEFT", ChatFrame1, "TOPLEFT", -4, 36 + (f.slot - 1) * 40)
      else
        f:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 12, 320 + (f.slot - 1) * 40)
      end
    end
  end
end

local function friendFrame()
  for _, f in ipairs(friendLines) do
    if not f:IsShown() then return f end
  end
  local f = CreateFrame("Button", nil, UIParent)
  f:SetFrameStrata("DIALOG")
  f:SetHeight(34)
  f.bg = Theme.fill(f, "friendLine", "BACKGROUND")
  f.bg:SetAllPoints()
  f.edge = f:CreateTexture(nil, "BORDER")
  f.edge:SetPoint("TOPLEFT")
  f.edge:SetPoint("BOTTOMLEFT")
  f.edge:SetWidth(2)
  f.portrait = Kit.portrait(f, 22)
  f.portrait:SetPoint("LEFT", 8, 0)
  f.text = Theme.text(f, "small", "celebLine")
  f.text:SetPoint("LEFT", f.portrait, "RIGHT", 8, 0)
  if f.RegisterForClicks then f:RegisterForClicks("LeftButtonUp", "RightButtonUp") end
  f:SetScript("OnEnter", function(self)
    if GameTooltip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:SetText("Click to open Doomsday")
      GameTooltip:Show()
    end
  end)
  f:SetScript("OnLeave", function() if GameTooltip then GameTooltip:Hide() end end)
  f:SetScript("OnClick", function(self, button)
    if button ~= "RightButton" and self.onClick then self.onClick("board") end
    if GameTooltip then GameTooltip:Hide() end
    self.close()
  end)
  f:Hide()
  friendLines[#friendLines + 1] = f
  return f
end

-- "<friend> <character> · completed the day": the friend in pale, the character in class colour.
function CelebrationBanner.friendText(l)
  local text = Theme.code("heading") .. tostring(l.name) .. "|r"
  if l.charName then
    text = text .. " " .. Theme.rgbCode(Kit.classColor(l.classFile)) .. tostring(l.charName) .. "|r"
  end
  return text .. " \194\183 " .. tostring(l.text)
end

function CelebrationBanner.friendsShown()
  local n = 0
  for _, f in ipairs(friendLines) do
    if f:IsShown() then n = n + 1 end
  end
  return n
end

--[[ Shows a friend's line (Celebrations.friendMoments' line) above the others, for FRIEND_SECONDS. opts = { ambient,
onClick(view), onDone }. Returns false when FRIEND_STACK lines already show. ]]
function CelebrationBanner.showFriend(l, opts)
  opts = opts or {}
  if CelebrationBanner.friendsShown() >= ns.Celebrations.FRIEND_STACK then return false end
  local used = {}
  for _, other in ipairs(friendLines) do
    if other:IsShown() then used[other.slot] = true end
  end
  local f = friendFrame()
  f.slot = 1
  while used[f.slot] do f.slot = f.slot + 1 end
  f.edge:SetColorTexture(Theme.color(edgeColor(l.edge)))
  f.portrait:SetClass(l.classFile)
  f.portrait:SetOnline(false)
  local text = CelebrationBanner.friendText(l)
  f.text:SetText(text)
  f:SetWidth((f.text.GetStringWidth and f.text:GetStringWidth() or 200) + 50)
  f.onClick = opts.onClick
  friendsShown[#friendsShown + 1] = text
  if f.timer then f.timer:Cancel() end
  f.close = function()
    if f.timer then f.timer:Cancel() f.timer = nil end
    if f.fade then f.fade:Stop() end
    f:Hide()
    if opts.onDone then opts.onDone() end
  end
  f:SetAlpha(1)
  f:Show()
  placeFriends()
  f.timer = C_Timer.NewTimer(ns.Celebrations.FRIEND_SECONDS, function()
    f.timer = nil
    if opts.ambient and f.fade then
      f.fade:Stop()
      f.fade:Play()
    else
      f.close()
    end
  end)
  if f.fade == nil then
    local g = group(f)
    local a = anim(g, "Alpha")
    if a then
      a:SetFromAlpha(1)
      a:SetToAlpha(0)
      a:SetDuration(CelebrationBanner.OUT)
      g:SetScript("OnFinished", function() f.close() end)
      f.fade = g
    else
      f.fade = false
    end
  end
  return true
end

-- For the specs.
function CelebrationBanner.frame() return banner end
function CelebrationBanner.friendFrames() return friendLines end
function CelebrationBanner.shown() return shown end
function CelebrationBanner.friendTexts() return friendsShown end
function CelebrationBanner.reset() banner, friendLines, shown, friendsShown = nil, {}, {}, {} end

ns.CelebrationBanner = CelebrationBanner
return CelebrationBanner
