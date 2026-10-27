-- RunToasts: the run reminder and "Starting now" notes under the minimap (CF-48; board run-start.html):
-- a title, the run, one line and one button, for 20 seconds. Just a heads-up: no answer buttons here.
local _, ns = ...

local RunToasts = {}
local Theme, Kit = ns.Theme, ns.Kit

RunToasts.SECONDS = 20
local WIDTH = 300

local frame, timer

local function create()
  frame = CreateFrame("Frame", nil, UIParent)
  frame:SetSize(WIDTH, 112)
  frame:SetFrameStrata("DIALOG")
  -- Under the minimap when the game has its cluster frame, else at the top right.
  if MinimapCluster then
    frame:SetPoint("TOPRIGHT", MinimapCluster, "BOTTOMRIGHT", -10, -10)
  else
    frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -20, -220)
  end
  local bg = Theme.fill(frame, "panel", "BACKGROUND")
  bg:SetAllPoints()
  frame.edges = Kit.edges(frame, "border")
  frame.title = Theme.text(frame, "label", "goldLight")
  frame.title:SetPoint("TOPLEFT", 14, -12)
  frame.heading = Theme.text(frame, "group", "heading")
  frame.heading:SetPoint("TOPLEFT", 14, -30)
  frame.heading:SetWidth(WIDTH - 28)
  frame.heading:SetJustifyH("LEFT")
  frame.text = Theme.text(frame, "small", "textDim")
  frame.text:SetPoint("TOPLEFT", 14, -52)
  frame.text:SetWidth(WIDTH - 28)
  frame.text:SetJustifyH("LEFT")
  frame.button = Kit.button(frame, "", nil, "primary")
  frame.button:SetPoint("BOTTOMRIGHT", -12, 10)
  frame.close = Kit.button(frame, "Close", function() RunToasts.hide() end, "ghost")
  frame.close:SetPoint("RIGHT", frame.button, "LEFT", -6, 0)
  frame:Hide()
end

--[[ opts = { title, heading, text, button = label, onClick() } ]]
function RunToasts.show(opts)
  if not frame then create() end
  frame.title:SetText((opts.title or ""):upper())
  frame.heading:SetText(opts.heading or "")
  frame.text:SetText(opts.text or "")
  frame.button:SetLabel(opts.button or "Open")
  frame.button:SetScript("OnClick", function()
    RunToasts.hide()
    if opts.onClick then opts.onClick() end
  end)
  frame:Show()
  if timer then timer:Cancel() end
  timer = C_Timer.NewTimer(RunToasts.SECONDS, function()
    timer = nil
    RunToasts.hide()
  end)
end

function RunToasts.hide()
  if frame then frame:Hide() end
end

-- For the specs.
function RunToasts.frame() return frame end

ns.RunToasts = RunToasts
return RunToasts
