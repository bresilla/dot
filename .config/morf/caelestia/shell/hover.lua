-- Opening a drawer by touching the frame's edge where it lives.
--
-- A thin strip on the frame's border -- the bottom edge under the
-- launcher, the right edge beside the sidebar, the left edge beside the
-- left panel (the sides' pills under them) -- opens its
-- drawer after a short dwell, including at the outermost pixel.
-- A drawer opened this way shuts again
-- once the pointer has left the strip and every panel that belongs to it,
-- after a moment's grace for the crossing from the edge onto the panel. One
-- opened by a key or a verb stays until it is shut.

local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local config = require("config")

local M = {}

-- How long the pointer may be off both the strip and the panel before a
-- drawer opened by hover shuts: enough to cross the frame's seam.
local GRACE_MS = 120
local OPEN_MS = 600
-- How far into the opening a side strip reaches: near the edge is enough.
local NEAR = 8

--- A strip on one edge that opens `opts.drawer` on hover. Options:
--- `name`, `drawer`, `edge` ("top", "bottom", "right" or "left"), `length` (a
--- function: the strip's length along the edge), `from` (for the sides: a
--- function, where the strip starts down the edge; the bottom one is
--- centred), `panels` (the panels that keep it
--- open; the drawer's own by default), `setting` (a boolean setting that
--- turns it off). Returns the node to place over the whole screen.
function M.edge(opts)
  local d = opts.drawer
  local panels = opts.panels or { d.panel }
  local strip
  if opts.edge == "bottom" or opts.edge == "top" then
    strip = ui.MouseArea {
      id = opts.name .. "-trigger",
      anchors = { [opts.edge] = true, horizontal_center = true },
      width = opts.length, height = theme.BORDER,
    }
  elseif opts.edge == "left" then
    -- Near the edge, not only on it: a little way into the opening.
    strip = ui.MouseArea {
      id = opts.name .. "-trigger",
      x = 0, y = opts.from,
      width = theme.LEFT + NEAR, height = opts.length,
    }
  else
    strip = ui.MouseArea {
      id = opts.name .. "-trigger",
      anchors = { right = true }, y = opts.from or 0,
      width = theme.BORDER + NEAR, height = opts.length,
    }
  end

  local by_hover = false
  local opening, closing
  local function enabled()
    return (not opts.enabled or opts.enabled())
      and (not opts.setting or config.get(opts.setting))
  end
  local function on_strip() return strip.hovered end
  local function cancel_open()
    if opening then opening:cancel() opening = nil end
  end
  local function cancel_close()
    if closing then closing:cancel() closing = nil end
  end
  local function open()
    cancel_open()
    cancel_close()
    by_hover = true
    d.set(true)
  end
  local function over()
    if on_strip() then return true end
    for _, panel in ipairs(panels) do
      if type(panel) == "function" then panel = panel() end
      if panel and panel.contains_pointer then return true end
    end
    return false
  end

  morf.effect("caelestia.hover." .. opts.name, function()
    local is_open = d.open:get()
    if not is_open then by_hover = false end
    if not enabled() then cancel_open() cancel_close() return end
    -- Only the strip opens it; the panels keep it open. (Shut some other
    -- way with the pointer still on a panel, it stays shut.)
    if not is_open then
      cancel_close()
      if on_strip() then
        if not opening then
          opening = morf.timer(OPEN_MS, function()
            opening = nil
            if enabled() and on_strip() and not d.open:get() then open() end
          end, false)
        end
      else
        cancel_open()
      end
      return
    end
    cancel_open()
    if over() then
      cancel_close()
    elseif by_hover and not closing then
      closing = morf.timer(opts.grace_ms or GRACE_MS, function()
        closing = nil
        if by_hover and not over() then
          by_hover = false
          d.set(false)
        end
      end, false)
    end
  end)
  -- The strip sits on the frame's border, inside the screen.
  return ui.Item {
    anchors = { fill = true, left_margin = opts.edge == "left" and 0 or theme.LEFT,
      right_margin = opts.edge == "top" and theme.BORDER or 0 },
    strip,
  }
end

return M
