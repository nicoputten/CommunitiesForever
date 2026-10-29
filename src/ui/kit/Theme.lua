-- Theme: the revamp's colours, fonts and sizes in one place (CF-39; values from docs/design/revamp-2026-10).
-- Every kit widget and screen takes its look from here.
local ADDON_NAME, ns = ...

local Theme = {}

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\media\\"

-- Colours as { r, g, b, a } (0..1). Names follow their use, not their hue.
local function hex(h, a)
  return { tonumber(h:sub(1, 2), 16) / 255, tonumber(h:sub(3, 4), 16) / 255, tonumber(h:sub(5, 6), 16) / 255, a or 1 }
end

Theme.COLORS = {
  panel = hex("090F1B", 0.96),      -- window background
  list = hex("050910", 0.6),        -- list column background
  input = hex("070D17"),            -- search box and inputs
  outline = hex("02050A"),          -- dark line inside the gold border, diamond outline
  border = hex("D4AF6A", 0.6),      -- window border
  divider = hex("D4AF6A", 0.18),    -- lines between areas
  titleLine = hex("D4AF6A", 0.25),  -- line under the title bar
  gold = hex("D4AF6A"),             -- accents, active tab underline, bars
  goldLight = hex("F0D08E"),        -- section headers, links
  goldPale = hex("F3DFAE"),         -- window title, active tab
  heading = hex("F3EBDA"),          -- big names and numbers
  text = hex("E6E1D6"),             -- body text
  textDim = hex("AEB6C3"),          -- secondary text
  muted = hex("8E98A8"),            -- inactive tabs, levels
  faint = hex("7E8898"),            -- footers, labels
  online = hex("7FD99A"),           -- online dots
  onlineText = hex("9BE3B0"),       -- "2 online"
  warning = hex("F0A774"),          -- a missing role
  track = hex("161E2B"),            -- empty part of bars
  hover = hex("FFFFFF", 0.04),      -- row hover
  selected = hex("D4AF6A", 0.13),   -- selected row
  white = hex("FFFFFF"),            -- faint overlays with an alpha: tiles 0.03, separators and pills 0.05
  tick = hex("070C15", 0.9),        -- tick lines on skill bars
  missing = hex("E08A4A", 0.5),     -- outline of a missing role slot
  dungeonTag = hex("8DB0FF"),       -- the DUNGEON tag on shared quests
  soon = hex("F6C29C"),             -- CF-46: a run starting within 12 hours
  discord = hex("B9BEFA"),          -- CF-46: "answered on Discord"
  pve = hex("7FD99A"),              -- CF-62: the PvE track (Doomsday)
  pvp = hex("E0625A"),              -- CF-62: the PvP track (Doomsday)
  swap = hex("9DB4FF"),             -- CF-62: the "swapped" marker; "N online fit"
  tank = hex("5B8DD6"),             -- CF-62: role icon fallbacks (a coloured square when the atlas is missing)
  heal = hex("7FD99A"),
  dps = hex("E0625A"),
  goalEdge = hex("7C6838"),         -- CF-63: an open goal box's edge (board CF63DoomBoard)
  goalFill = hex("0B111C"),         -- CF-63: an open goal box
  goalDone = hex("2A2210"),         -- CF-63: a done goal box
}

-- r, g, b, a of a colour; alpha (optional) replaces its own, e.g. Theme.color("gold", 0.16).
function Theme.color(name, alpha)
  local c = Theme.COLORS[name]
  assert(c, "unknown colour " .. tostring(name))
  return c[1], c[2], c[3], alpha or c[4]
end

-- "|cffrrggbb": the escape that colours the text after it (end it with "|r").
function Theme.rgbCode(r, g, b)
  local function byte(v) return math.floor((v or 0) * 255 + 0.5) end
  return string.format("|cff%02x%02x%02x", byte(r), byte(g), byte(b))
end

function Theme.code(name)
  return Theme.rgbCode(Theme.color(name))
end

-- Fonts: bundled Marcellus SC, Marcellus and Inter (SIL OFL), the game font as fallback.
Theme.FONT_FILES = {
  display = MEDIA .. "fonts\\MarcellusSC-Regular.ttf",
  serif = MEDIA .. "fonts\\Marcellus-Regular.ttf",
  body = MEDIA .. "fonts\\Inter-Regular.ttf",
  medium = MEDIA .. "fonts\\Inter-Medium.ttf",
  bold = MEDIA .. "fonts\\Inter-SemiBold.ttf",
}

-- Text roles: { font file, size, fallback font object }.
Theme.TEXT = {
  windowTitle = { "display", 18, "GameFontNormalLarge" },
  tab = { "display", 15, "GameFontNormal" },
  section = { "display", 15, "GameFontNormal" },
  day = { "display", 16, "GameFontNormal" },
  name = { "serif", 24, "GameFontNormalHuge" },
  group = { "serif", 14, "GameFontNormal" },
  number = { "serif", 20, "GameFontNormalLarge" },
  body = { "body", 13, "GameFontHighlight" },
  small = { "body", 12, "GameFontHighlightSmall" },
  tiny = { "body", 11, "GameFontHighlightSmall" },
  label = { "medium", 11, "GameFontHighlightSmall" },
  button = { "bold", 12, "GameFontHighlightSmall" },
  badge = { "bold", 10, "GameFontHighlightSmall" },
  chip = { "bold", 11, "GameFontHighlightSmall" }, -- CF-41: the LEVEL UP chip
}

-- Clients whose letters the bundled fonts do not have use the game font throughout.
local GAME_FONT_LOCALES = { koKR = true, zhCN = true, zhTW = true, ruRU = true }

local function useGameFont()
  return GetLocale ~= nil and GAME_FONT_LOCALES[GetLocale()] == true
end

-- Gives a FontString the role's font. FontString:SetFont with a bundled file is unverified on Forever
-- (VERIFY.md V61): when it fails, the role's game font object is used.
function Theme.font(fontString, role)
  local spec = assert(Theme.TEXT[role], "unknown text role " .. tostring(role))
  if not useGameFont() and fontString.SetFont and fontString:SetFont(Theme.FONT_FILES[spec[1]], spec[2], "") then
    return
  end
  local fallback = _G[spec[3]]
  if fallback and fontString.SetFontObject then fontString:SetFontObject(fallback) end
end

-- CF-41: whether texts use the bundled fonts (they have characters the game font lacks, such as the arrow).
function Theme.bundledFonts()
  return not useGameFont()
end

-- A FontString in the role's font and colour.
function Theme.text(parent, role, colorName, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY")
  Theme.font(fs, role)
  fs:SetTextColor(Theme.color(colorName or "text"))
  return fs
end

Theme.TEXTURES = {
  diamond = MEDIA .. "textures\\diamond.tga",
  circle = MEDIA .. "textures\\circle.tga",
  ring = MEDIA .. "textures\\ring.tga",
  shield = MEDIA .. "textures\\shield.tga",
  close = MEDIA .. "textures\\close.tga",
  gear = MEDIA .. "textures\\gear.tga",
  check = MEDIA .. "textures\\check.tga",
  shine = MEDIA .. "textures\\shine.tga",
  shadow = MEDIA .. "textures\\shadow.tga",
  arrow = MEDIA .. "textures\\arrow.tga", -- CF-40: fold arrow
  quest = MEDIA .. "textures\\quest.tga", -- CF-40: shared-quest count
}

-- Sizes (px at UI scale 1) from the design.
Theme.SIZES = {
  windowWidth = 880, windowHeight = 600, minWidth = 700, minHeight = 480,
  titleBar = 44, tabBar = 36, footer = 28, row = 28, listWidth = 270,
  portraitSmall = 20, portraitMedium = 32, portraitLarge = 52,
  button = 26, iconButton = 26,
}

-- A solid colour texture (panels, lines).
function Theme.fill(parent, colorName, layer, sublevel)
  local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel)
  t:SetColorTexture(Theme.color(colorName))
  return t
end

ns.Theme = Theme
return Theme
