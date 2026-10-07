-- How much screen there is. The shell is drawn for a desk; on a narrow
-- screen (a phone held upright) its sizes give way: a panel never wider
-- than the desk between the frame's edges, and layouts that ask
-- `compact()` stack what sits side by side.
local M = {}

--- The desk's width: the screen inside the frame and any bar.
function M.desk_width()
  local _, _, w = require("bar").desk()
  return w or 1920
end

--- The desk's height.
function M.desk_height()
  local _, _, _, h = require("bar").desk()
  return h or 1080
end

--- `design`, or less: as wide as the desk leaves with `margin` each side.
function M.fit(design, margin)
  return math.max(0, math.min(design, M.desk_width() - 2 * (margin or 12)))
end

--- Whether the desk is too narrow for a page's columns side by side, or
--- upright: a phone's, at any scale.
function M.compact()
  -- Upright is a phone's however small the shell is drawn on it.
  return M.desk_width() < 1000 or M.portrait()
end

--- How wide a dashboard page is on a phone: the desk inside the frame,
--- less the drawer's padding.
function M.sheet_width()
  local theme = require("theme")
  return math.max(1, M.desk_width() - 2 * theme.BORDER - 2 * theme.ROUNDING)
end

function M.page_width()
  local panel = M.portrait() and M.sheet_width() or M.desk_width() - 2 * require("theme").BORDER
  return math.max(1, panel - 2 * 16)
end

--- How tall: the desk inside the frame, less the tabs and the padding.
function M.page_height()
  return M.desk_height() - 2 * require("theme").BORDER - 68 - 2 * 16
end

-- Each dashboard tab's own page on a desk (the drawer eases from one to
-- the next): its width and height.
local DASHBOARD = {
  overview = { 840, 439 }, media = { 1000, 400 }, battery = { 1040, 520 },
  weather = { 838, 561 },
}

--- The dashboard page of tab `key`: its width and height. On a phone every
--- tab is the desk less the tabs and a page's head (four fifths of it, the
--- rest to tap it shut), and scrolls; on a desk each tab has its own size.
function M.dashboard(key)
  local theme = require("theme")
  local TABS_H, PAD = 68, 16
  if M.compact() then
    local panel_h = math.floor((M.desk_height() - 2 * theme.BORDER) * 0.8)
    -- (Less a page's head: a phone's tabs are icons, so each page is named.)
    local P = require("themes.layouts.page")
    return M.page_width(), panel_h - TABS_H - 2 * PAD - P.HEADER_H - P.GAP
  end
  -- The big ones (performance, the terminal) take as much of the screen as
  -- sits well.
  if key == "performance" or key == "terminal" then
    local sw, sh = M.desk_width(), M.desk_height()
    return math.max(960, math.min(1400, sw - 2 * theme.BORDER - 2 * PAD - 2 * 40)),
      math.max(560, math.min(760, sh - 2 * theme.BORDER - TABS_H - 2 * PAD - 40))
  end
  local size = DASHBOARD[key] or DASHBOARD.overview
  return M.fit(size[1], 40), size[2]
end

--- Whether the screen stands upright (a phone): the workspaces run along
--- the bottom edge, and what a desk keeps on its side edges gives way.
function M.portrait()
  local s = require("morf").screens[1]
  local w, h = (s and s.width) or 1920, (s and s.height) or 1080
  return h > w
end

return M
