-- Material geometry, typography and motion. No palette values belong here.
local M = {}

-- -------------------------------------------------------------------- type --

-- The reference sets its type in Google Sans Flex; Rubik (OFL, shipped in
-- fonts/ beside the configuration, which morf puts on the font path) stands
-- in where that is not installed. `appearance.font_file` (or
-- CAELESTIA_FONT_FILE) names a font file to load for every label instead.
M.font = "Google Sans Flex, Rubik"
M.auth_font = "Roboto"
M.icon_font = "Material Symbols Rounded"
M.mono = "CaskaydiaCove Nerd Font, JetBrainsMono Nerd Font, monospace"

-- In pixels. The reference sets type in points, which Qt draws at 4/3 of
-- a pixel each on a 96 dpi screen: these are its sizes as they land.
M.size = {
  small = 14, smaller = 15, normal = 16, larger = 17.5, large = 20, extra = 30,
}

-- ------------------------------------------------------------------ sizes --

M.BORDER = 10        -- the frame round the screen
M.LEFT = M.BORDER     -- the left edge, the workspace rail in it (the bar was 60)
M.ROUNDING = 25      -- the frame's inner corners, drawers, cards
M.SIDE_W = 430       -- a side panel's pages
M.STRIP = 20         -- the strip of a side panel its edge's pills ride out to
M.SEAM = 25          -- the fillet where a drawer meets the frame
M.PAD = 16           -- inside a drawer
M.GAP = 12           -- between cards

-- --------------------------------------------------------------- motion --

-- Material 3's curves, as cubic Béziers (the published control points).
M.ease = {
  standard = { x1 = 0.2, y1 = 0, x2 = 0, y2 = 1 },
  standard_decel = { x1 = 0, y1 = 0, x2 = 0, y2 = 1 },
  standard_accel = { x1 = 0.3, y1 = 0, x2 = 1, y2 = 1 },
  emphasized_decel = { x1 = 0.05, y1 = 0.7, x2 = 0.1, y2 = 1 },
  emphasized_accel = { x1 = 0.3, y1 = 0, x2 = 0.8, y2 = 0.15 },
  -- Material 3 Expressive's default spatial curve: out past the end by a
  -- touch and back.
  spatial = { x1 = 0.38, y1 = 1.21, x2 = 0.22, y2 = 1 },
  -- The emphasized curve: a slow start, then most of the way at once, then
  -- a long settle -- two segments (Material's own definition).
  emphasized = { spline = { 0.05, 0, 0.133333, 0.06, 0.166666, 0.4, 0.208333, 0.82, 0.25, 1, 1, 1 } },
}

-- Durations and curves fitted to films of the reference in the sandbox
-- (tools/sandbox/caelestia-motion.steps): a drawer opens on the spatial
-- curve over about 470 ms (500 here films as ~470 in the same sandbox), overshooting by about 1 % and settling, and
-- closes on the emphasized accelerate curve in about 200 ms.
M.duration = {
  small = 200, normal = 400, large = 600,
  drawer_open = 500, drawer_close = 200,
}

return M
