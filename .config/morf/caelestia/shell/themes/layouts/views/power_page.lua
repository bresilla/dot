-- The right panel's Power page, behind the battery row's ">": everything
-- about power in one place -- the battery (charge, state, time left, draw),
-- the power profile, the battery's health and how it is charged, and the way
-- to the dashboard's Battery tab for its graphs.

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local rows = require("themes.layouts.rows")

local C = theme.color
local M = {}

function M.build(model, w, h)
  local viewport, viewport_node, viewport_t, viewport_ctl
  local first = model.battery
  local function active()
    local value = model.profile()
    return value == "" and "balanced" or value
  end

  local function card(height, props)
    props.width, props.height, props.radius = w, height, 22
    return kit.card(props)
  end
  local function label(text_value, y)
    return kit.heading { viewport = function() return viewport end, id = "power-heading-" .. text_value:lower():gsub("%s+", "-"), scope = "settings.power", level = "section", x = 18, y = y, text = text_value, font_size = theme.size.small,
      color = function() return C.onSurfaceVariant end }
  end

  -- The battery: its charge large, its state and what that means in time.
  local summary = card(132, {
    id = "power-summary",
    kit.icon(function()
      local b = first()
      if b.status == "Charging" then return "battery_charging_full" end
      local pct = b.capacity or 0
      if pct > 90 then return "battery_full" end
      if pct > 50 then return "battery_5_bar" end
      if pct > 20 then return "battery_3_bar" end
      return "battery_alert"
    end, 40, kit.ink("accent"), { x = 18, y = 20, fill = true }),
    kit.text {
      id = "power-percent", x = 70, y = 14, font_size = theme.size.extra, font_weight = 700,
      text = function() return ("%d%%"):format(math.floor((first().capacity or 0) + 0.5)) end,
    },
    kit.subtitle {
      x = 70, y = 56, width = w - 90, elide = "right",
      color = kit.ink("lo"),
      text = model.summary,
    },
    -- The charge, as the theme's fill bar, the charge limit marked on it.
    ui.Item {
      x = 18, y = 96, width = w - 36, height = 12,
      kit.fill { width = w - 36, height = 12, color = kit.signal("accent"),
        value = function() return math.max(0, math.min(1, (first().capacity or 0) / 100)) end },
      kit.surface {
        width = 2, height = 12,
        x = function() return (w - 36) * (first().charge_limit or 100) / 100 - 1 end,
        visible = function() local l = first().charge_limit return l ~= nil and l < 100 end,
        color = kit.ink("hi"),
      },
    },
  })

  -- The power profile: three choices, each with what it is for.
  local buttons = {}
  local bw = (w - 36 - 16) / 3
  for _, p in ipairs(model.PROFILES) do
    local function on() return active() == p.id end
    local ink = rows.ink(on, true, C.onSurface)
    local area
    area = kit.action {
      id = "power-profile-" .. p.id,
      width = bw, height = 78, cursor = "pointer",
      on_clicked = function() model.select(p.id) end,
      ui.Column {
        anchors = { center_in = true }, gap = 2, align = "center",
        kit.icon(p.icon, 24, rows.ink(on, true, C.onSurfaceVariant)),
        kit.menu_label { text = p.name, font_size = theme.size.small, font_weight = 600,
          width = bw - 10, elide = "right", horizontal_alignment = "center",
          color = ink },
        kit.subtitle { text = p.hint, font_size = theme.size.small - 3,
          width = bw - 10, elide = "right", horizontal_alignment = "center",
          color = function() return on() and ink():alpha(0.8) or C.onSurfaceVariant end },
      },
    }
    ui.reparent(kit.state_surface { id = "power-profile-" .. p.id .. "-shape", area = area, on = on,
      height = 78, tone = "primary", z = -1 }, area)
    buttons[#buttons + 1] = area
  end
  local profile = card(136, {
    id = "power-profiles",
    label("Power mode", 14),
    ui.Row { x = 18, y = 40, gap = 8, table.unpack(buttons) },
  })

  -- The battery's health, and how it is charged -- set by the firmware
  -- (and root), shown here.
  local rows = {}
  for _, entry in ipairs(model.FACTS) do rows[#rows + 1] = { entry.name, entry.value } end
  local facts = kit.facts(rows, w - 36, 30)
  facts.x, facts.y = 18, 40
  local health = card(236, {
    id = "power-health",
    label("Battery", 14),
    facts,
  })

  -- The graphs are the dashboard's.
  local more_area = kit.pill {
    id = "power-open-battery", width = w, height = 52,
    icon = "monitoring", label = "Battery graphs and details",
    on_clicked = model.open_battery,
    color = function() return C.secondaryContainer end,
    ink = function() return C.onSecondaryContainer end,
  }

  viewport_node, viewport, viewport_t, viewport_ctl = kit.scroll({
    id = "power-scroll", width = w, height = h, clip = true,
    ui.Column { gap = 12, width = w, summary, profile, health, more_area },
  })
  return viewport_node
end

return M
