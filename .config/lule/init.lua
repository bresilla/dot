local lule = require("lule")

-- `c` is the finished scheme: c.colors (all 256), c.ansi (the sixteen), c.background,
-- c.foreground, c.cursor, c.accent, c.wallpaper, c.theme, c.cache. Lists count from one, so
-- c.colors[1] is colour 0.

lule.wallpaper = "~/.wallpaper"
lule.theme = "dark"
lule.palette = "pigment"
lule.contrast = "aa"

local home = lule.env("HOME") or "~"
local wal = home .. "/.cache/wal"
local logo = home .. "/.config/bresilla.svg"
local remote = "tron.netbird:" .. home .. "/.cache/"

local esc = string.char(27)

local function write(name, body)
  lule.write(wal .. "/" .. name, body)
end

-- --- the formats that are just `color<N> <hex>` -------------------------------------------------

-- Twelve of the fifteen files differ only in their syntax, so they are written as syntax rather
-- than as code: a header, a line per colour, sometimes a closing line.
local formats = {
  {
    -- shells: bash, zsh, fish
    file = "colors.sh",
    head = function(c)
      return ('foreground="%s"\nbackground="%s"\ncursor="%s"'):format(c.foreground, c.background, c.cursor)
    end,
    line = function(n, hex) return ('color%d="%s"'):format(n, hex) end,
  },
  {
    file = "colors.yml",
    head = function(c)
      return ('special:\n  background: "%s"\n  foreground: "%s"\n  cursor: "%s"\n\ncolors:'):format(
        c.background, c.foreground, c.cursor)
    end,
    line = function(n, hex) return ('  color%d: "%s"'):format(n, hex) end,
  },
  {
    file = "colors.toml",
    head = function(c)
      return ('[special]\nbackground = "%s"\nforeground = "%s"\ncursor = "%s"\n\n[colors]'):format(
        c.background, c.foreground, c.cursor)
    end,
    line = function(n, hex) return ('color%d = "%s"'):format(n, hex) end,
  },
  {
    -- polybar
    file = "colors.ini",
    head = function(c)
      return ('[colors]\n\tforeground=%s\n\tbackground=%s\n\tcursor=%s'):format(
        c.foreground, c.background, c.cursor)
    end,
    line = function(n, hex) return ('\tcolor%d=%s'):format(n, hex) end,
  },
  {
    file = "colors.scss",
    head = function(c) return ('$foreground: %s;\n$background: %s;\n'):format(c.foreground, c.background) end,
    line = function(n, hex) return ('$color%d: %s;'):format(n, hex) end,
  },
  {
    -- gtk reads @define-color
    file = "colors.css",
    head = function(c)
      return ('@define-color foreground %s;\n@define-color background %s;'):format(c.foreground, c.background)
    end,
    line = function(n, hex) return ('@define-color color%d %s;'):format(n, hex) end,
  },
  {
    -- a web page reads the custom properties
    file = "colors_def.css",
    head = function(c) return (':root {\n\t--foreground: %s;\n\t--background: %s;'):format(c.foreground, c.background) end,
    line = function(n, hex) return ('\t--color%d: %s;'):format(n, hex) end,
    tail = "}",
  },
  {
    -- rofi
    file = "colors.rasi",
    head = function(c) return ('* {\n\tforeground: %s;\n\tbackground: %s;'):format(c.foreground, c.background) end,
    line = function(n, hex) return ('\tcolor%d: %s;'):format(n, hex) end,
    tail = "}",
  },
  {
    -- kitty
    file = "colors.conf",
    head = function(c)
      return ('foreground\t%s\nbackground\t%s\ncursor\t%s\n'):format(c.foreground, c.background, c.cursor)
    end,
    line = function(n, hex) return ('color%d\t %s'):format(n, hex) end,
  },
  {
    file = "colors.vim",
    head = function(c) return ('let foreground= "%s"\nlet background= "%s"'):format(c.foreground, c.background) end,
    line = function(n, hex) return ('let color%d= "%s"'):format(n, hex) end,
  },
}

local function render(c, spec)
  local out = { spec.head(c) }
  for i, hex in ipairs(c.colors) do
    out[#out + 1] = spec.line(i - 1, hex)
  end
  if spec.tail then out[#out + 1] = spec.tail end
  write(spec.file, table.concat(out, "\n") .. "\n")
end

-- --- the three that have a shape of their own ---------------------------------------------------

-- firefox
local function write_json(c)
  local out = {
    "{",
    ('\t"wallpaper": "%s",'):format(c.wallpaper),
    ('\t"theme": "%s",'):format(c.theme),
    "\t\"special\": {",
    ('\t\t"background": "%s",'):format(c.background),
    ('\t\t"foreground": "%s",'):format(c.foreground),
    ('\t\t"cursor": "%s"'):format(c.cursor),
    "\t},",
    "\t\"colors\": {",
  }
  for i, hex in ipairs(c.colors) do
    local comma = i < #c.colors and "," or ""
    out[#out + 1] = ('\t\t"color%d": "%s"%s'):format(i - 1, hex, comma)
  end
  out[#out + 1] = "\t}"
  out[#out + 1] = "}"
  write("colors.json", table.concat(out, "\n") .. "\n")
end

-- alacritty wants the sixteen split into normal and bright rather than numbered straight through
local function write_alacritty(c)
  local out = {
    ('[colors.primary]\nbackground = "%s"\nforeground = "%s"\n'):format(c.background, c.foreground),
    ('[colors.cursor]\ntext = "%s"\ncursor = "%s"\n'):format(c.background, c.foreground),
    "[colors.normal]",
  }
  for i = 1, 8 do
    out[#out + 1] = ('color%d = "%s"'):format(i - 1, c.ansi[i])
  end
  out[#out + 1] = "\n[colors.bright]"
  for i = 9, 16 do
    out[#out + 1] = ('color%d = "%s"'):format(i - 8, c.ansi[i])
  end
  write("alacritty.toml", table.concat(out, "\n") .. "\n")
end

-- neovim, awesomewm, anything else configured in lua
local function write_lua(c)
  local out = {
    "return {",
    ('  wallpaper = "%s",'):format(c.wallpaper),
    ('  theme = "%s",\n'):format(c.theme),
    "  special = {",
    ('    background = "%s",'):format(c.background),
    ('    foreground = "%s",'):format(c.foreground),
    ('    cursor = "%s",'):format(c.cursor),
    "  },\n",
    "  colors = {",
  }
  for i, hex in ipairs(c.colors) do
    out[#out + 1] = ('    color%d = "%s",'):format(i - 1, hex)
  end
  out[#out + 1] = "  },"
  out[#out + 1] = "}"
  write("colors.lua", table.concat(out, "\n") .. "\n")
end

-- --- terminals ----------------------------------------------------------------------------------

local function osc(body)
  return esc .. "]" .. body .. esc .. "\\"
end

-- The escape sequences a terminal understands as "change your palette".
local function sequences(c)
  local seq = osc("10;" .. c.foreground) .. osc("11;" .. c.background) .. osc("12;" .. c.cursor) ..
    osc("13;" .. c.background) .. osc("17;" .. c.cursor) .. osc("19;" .. c.background)
  for i, hex in ipairs(c.colors) do
    seq = seq .. osc("4;" .. (i - 1) .. ";" .. hex)
  end
  return seq
end

-- --- the rest of the desktop --------------------------------------------------------------------

local function recolour_logo(c)
  local svg = lule.read(logo)
  if svg then
    lule.write(logo, (svg:gsub('fill="#[^"]*"', 'fill="' .. c.cursor .. '"')))
  end
end

local function reload_desktop(c)
  lule.run('hyprctl hyprpaper wallpaper ",' .. c.wallpaper .. ',"')
  -- Neither is worth waiting for: one repaints an editor, the other crosses the network.
  lule.spawn("zedtheme")
  lule.spawn("scp -r " .. wal .. " " .. remote)
end

-- --- what runs, in this order -------------------------------------------------------------------

-- The plain list and the two facts that go with it, which is what everything else reads.
local function write_cache(c)
  lule.mkdir(wal)
  write("colors", table.concat(c.colors, "\n") .. "\n")
  write("theme", c.theme)
  write("wallpaper", c.wallpaper)
end

local function write_formats(c)
  for _, spec in ipairs(formats) do
    render(c, spec)
  end
end

-- Kept on disk as well as sent: a shell that starts later sources the file and comes up in the
-- right colours, and the write to every open pty recolours the ones already running.
local function recolour_terminals(c)
  local seq = sequences(c)
  write("sequences", seq)
  lule.ttys(seq)
end

lule.on.colors(write_cache)
lule.on.colors(write_formats)
lule.on.colors(write_json)
lule.on.colors(write_alacritty)
lule.on.colors(write_lua)
lule.on.colors(recolour_terminals)
lule.on.colors(recolour_logo)
lule.on.colors(reload_desktop)
