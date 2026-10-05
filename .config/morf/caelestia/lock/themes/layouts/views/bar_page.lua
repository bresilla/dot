-- The right panel's Bar page, behind the Bar tile's ">": whether the bar is
-- up (on, off, or up only on a narrow screen), and which edge it is on.

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local rows = require("themes.layouts.rows")

local C = theme.color
local M = {}

local function choice(id, icon, name, on, pick, width)
  return rows.choice {
    id = id, width = width, height = 70, on = on, tone = "primary", tile = true, on_clicked = pick,
    -- One of a card's choices: "bar-show-*", "bar-side-*", "bar-titles-*".
    group = id:match("^(bar%-%a+)%-"),
    ui.Column {
      anchors = { center_in = true }, gap = 4, align = "center",
      kit.icon(icon, 22, rows.ink(on, true, C.onSurfaceVariant)),
      kit.menu_label { text = name, font_size = theme.size.small, font_weight = 600,
        width = width - 8, elide = "right", horizontal_alignment = "center",
        color = rows.ink(on, true) },
    },
  }
end

function M.build(model, w, h)
  local viewport, viewport_node, viewport_t, viewport_ctl
  local function card(height, children)
    children.width, children.height = w, height
    return kit.card(children)
  end
  local function label(text) return kit.heading { viewport = function() return viewport end, id = "bar-heading-" .. text:lower():gsub("%s+", "-"), scope = "settings.bar", level = "section", x = 18, y = 14, text = text, font_size = theme.size.small,
    color = function() return C.onSurfaceVariant end } end

  local shows = model.shows
  local show_buttons = {}
  local sw = (w - 36 - 16) / 3
  for _, s in ipairs(shows) do
    show_buttons[#show_buttons + 1] = choice("bar-show-" .. s[1], s[2], s[3], function()
      return model.mode() == s[1]
    end, function() model.set_mode(s[1]) end, sw)
  end

  local sides = model.sides
  local side_buttons = {}
  local bw = (w - 36 - 24) / 4
  for _, s in ipairs(sides) do
    side_buttons[#side_buttons + 1] = choice("bar-side-" .. s[1], s[2], s[3],
      function() return model.side() == s[1] end, function() model.set_side(s[1]) end, bw)
  end

  viewport_node, viewport, viewport_t, viewport_ctl = kit.scroll({
    id = "bar-scroll", width = w, height = h, clip = true,
    ui.Column {
      gap = 12, width = w,
      card(128, {
        id = "bar-show",
        label("Show the bar"),
        ui.Row { x = 18, y = 42, gap = 8, table.unpack(show_buttons) },
      }),
      card(128, {
        id = "bar-position",
        label("Position"),
        ui.Row { x = 18, y = 42, gap = 8, table.unpack(side_buttons) },
      }),
      card(128, {
        id = "bar-titles",
        label("Window titles"),
        ui.Row { x = 18, y = 42, gap = 8,
          choice("bar-titles-on", "title", "Shown", function() return model.titles() == "on" end,
            function() model.set_titles("on") end, (w - 36 - 8) / 2),
          choice("bar-titles-off", "apps", "Icons only", function() return model.titles() == "off" end,
            function() model.set_titles("off") end, (w - 36 - 8) / 2),
        },
      }),
      kit.subtitle {
        width = w, wrap = true, font_size = theme.size.small,
        color = function() return C.onSurfaceVariant end,
        text = "Auto puts the bar up on a narrow screen -- a phone -- and keeps it down on a desk.",
      },
    },
  })
  return viewport_node
end

return M
