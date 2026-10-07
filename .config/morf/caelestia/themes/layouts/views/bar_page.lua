-- The right panel's Bar page, behind the Bar tile's ">": whether the bar is
-- up (on, off, or up only on a narrow screen), which edge it is on, and how
-- it shows windows. In the page template (themes/layouts/page.lua): each a
-- section of choices that share its width.

local kit = require("kit")
local theme = require("theme")
local P = require("themes.layouts.page")

local M = {}

--- A section of choices: `id`, `title`, `group`, the choices
--- ({ key, icon, name }), what is chosen now, and how to choose.
local function choices(w, spec)
  local row = { width = P.inner(w) }
  for _, c in ipairs(spec.items) do
    row[#row + 1] = { id = spec.group .. "-" .. c[1], icon = c[2], label = c[3], group = spec.group,
      selected = function() return spec.now() == c[1] end, on_clicked = function() spec.pick(c[1]) end }
  end
  return P.section { id = spec.group, caption_id = spec.caption_id, width = w, title = spec.title, P.buttons(row) }
end

function M.build(model, w, h)
  return P.page { id = "bar-scroll", width = w, height = h,
    choices(w, { group = "bar-show", caption_id = "bar-heading-show-the-bar", title = "Show the bar",
      items = model.shows, now = model.mode, pick = model.set_mode }),
    choices(w, { group = "bar-side", caption_id = "bar-heading-position", title = "Position",
      items = model.sides, now = model.side, pick = model.set_side }),
    choices(w, { group = "bar-titles", caption_id = "bar-heading-window-titles", title = "Window titles",
      items = { { "on", "title", "Shown" }, { "off", "apps", "Icons only" } },
      now = model.titles, pick = model.set_titles }),
    kit.subtitle { width = w, wrap = true, font_size = theme.size.small, color = kit.ink("lo"),
      text = "Auto puts the bar up on a narrow screen -- a phone -- and keeps it down on a desk." },
  }
end

return M
