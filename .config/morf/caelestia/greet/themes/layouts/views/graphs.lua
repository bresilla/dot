-- The dashboard's graph language, after Mission Center: a bordered box on a
-- faint grid, the first series filled under its line, the second a dashed
-- line, the newest sample at the right edge; a caption over it; readings as
-- a small label over a large value; facts as label and value lines.
--
--   local graphs = require("graphs")
--   graphs.graph { width, height, color = fn, first = fn -> list, second = fn,
--                  top = n | fn, bottom = n, grid = false, columns, rows, id }
--   graphs.captioned(caption, scale_fn, spec)
--   graphs.stat(label, value_fn, mark ("solid" | "dashed" | nil), color_fn, width)
--   graphs.stats({ stat, ... }, width)   graphs.facts({ { label, value }, ... }, width)

local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local channel = require("lib.util.channel")

local C = theme.color
local V = {}
function V.new(samples)
  local M = {SAMPLES=samples}

  local grid_path=morf.geometry.graph_grid

  --- A graph; returns the node and its `top` function (the value at the top).
  function M.graph(spec)
    local w, h = spec.width, spec.height
    local color = spec.color
    -- The value at the bottom: a number, or a function for one that moves.
    local function bottom()
      if type(spec.bottom) == "function" then return spec.bottom() end
      return spec.bottom or 0
    end
    -- Each series a data channel the paths draw (a function's lists are
    -- copied in while the graph lives).
    local first, feed_first = channel.from(spec.first)
    local second, feed_second
    if spec.second then second, feed_second = channel.from(spec.second) end
    local function top()
      if type(spec.top) == "function" then return math.max(bottom() + 1e-9, spec.top()) end
      if spec.top then return spec.top end
      local peak = math.max(bottom(), first:peak() or 0, second and second:peak() or 0)
      return math.max(peak * 1.15, bottom() + (spec.floor or 1))
    end
    local function plot(kind)
      return function() return { kind = kind, samples = M.SAMPLES, bottom = bottom(), top = top() } end
    end
    local function clear() return color():alpha(0) end
    local box = {
      id = spec.id,
      width = w, height = h, radius = 3, clip = true,
      color = function() return color():alpha(0.06) end,
      border_width = 1,
      border_color = function() return color():alpha(0.85) end,
    }
    if spec.grid ~= false then
      box[#box + 1] = ui.Path {
        width = w, height = h, view_box = { 0, 0, w, h },
        d = grid_path(w, h, spec.columns or 12, spec.rows or 6),
        stroke_color = function() return color():alpha(0.14) end, stroke_width = 1, fill_color = clear,
      }
    end
    box[#box + 1] = ui.Path {
      width = w, height = h, view_box = { 0, 0, w, h },
      series = first.id, plot = plot("area"),
      fill_color = function() return color():alpha(0.28) end,
    }
    box[#box + 1] = ui.Path {
      width = w, height = h, view_box = { 0, 0, w, h },
      series = first.id, plot = plot("line"),
      stroke_color = color, fill_color = clear, stroke_width = 1.5, stroke_join = "round",
    }
    if spec.second then
      box[#box + 1] = ui.Path {
        width = w, height = h, view_box = { 0, 0, w, h },
        series = second.id, plot = plot("line"),
        stroke_color = color, fill_color = clear, stroke_width = 1.5, stroke_join = "round", dash = { 5, 4 },
      }
    end
    local node = kit.surface(box)
    feed_first(node)
    if feed_second then feed_second(node) end
    return node, top
  end

  --- A graph with its caption over it, left, and its scale, right.
  function M.captioned(caption, scale, spec)
    local box, top = M.graph(spec)
    return ui.Column {
      gap = 4,
      ui.Item {
        width = spec.width, height = 18,
        kit.heading { text = caption, active = spec.active, level = "caption", width = spec.width - 72, font_size = theme.size.small, color = function() return C.onSurfaceVariant end },
        kit.text {
          anchors = { right = true }, font_size = theme.size.small,
          text = function() return scale(top()) end,
          color = function() return C.onSurfaceVariant end,
        },
      },
      box,
    }
  end

  --- A reading: a small label over a large value, with a mark beside it when
  --- a graph draws it.
  function M.stat(label, value, mark, color, width)
    width = width or 300
    local column = ui.Column {
      gap = 0, width = width / 2 - 6,
      kit.text { text = label, font_size = theme.size.small, color = function() return C.onSurfaceVariant end },
      kit.text { text = value, font_size = theme.size.large, font_weight = 600, width = width / 2 - 14, elide = "right" },
    }
    if not mark then return column end
    return ui.Row {
      gap = 6,
      kit.surface {
        width = 2, height = 40, radius = 1,
        color = function() return color():alpha(mark == "dashed" and 0.5 or 1) end,
      },
      column,
    }
  end

  function M.stats(items)
    return ui.Grid { columns = 2, column_gap = 12, row_gap = 18, table.unpack(items) }
  end

  --- What a device is: label, value lines (a value may be a function).
  function M.facts(rows, width)
    width = width or 300
    local column = { gap = 9 }
    for _, row in ipairs(rows) do
      column[#column + 1] = ui.Row {
        gap = 8,
        kit.text { text = row[1], width = 136, font_size = theme.size.small, color = function() return C.onSurfaceVariant end },
        kit.text { text = row[2], width = width - 144, elide = "right", font_size = theme.size.small },
      }
    end
    return ui.Column(column)
  end

  return M
end
return V
