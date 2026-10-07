-- The right panel's Power page, behind the battery row's ">": everything
-- about power in one place -- the battery (charge, state, time left, draw),
-- the power profile, the battery's health and how it is charged, and the way
-- to the dashboard's Battery tab for its graphs. In the page template
-- (themes/layouts/page.lua).

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local P = require("themes.layouts.page")

local M = {}

function M.build(model, w, h)
  local first = model.battery
  local inner = P.inner(w)
  local function active()
    local value = model.profile()
    return value == "" and "balanced" or value
  end

  -- The battery: its charge large, its state and what that means in time,
  -- and the charge as the theme's fill bar, the charge limit marked on it.
  local summary = P.section { id = "power-summary", width = w, title = "Charge",
    ui.Item { width = inner, height = 96,
      kit.icon(function()
        local b = first()
        if b.status == "Charging" then return "battery_charging_full" end
        local pct = b.capacity or 0
        if pct > 90 then return "battery_full" end
        if pct > 50 then return "battery_5_bar" end
        if pct > 20 then return "battery_3_bar" end
        return "battery_alert"
      end, 40, kit.ink("accent"), { x = 0, y = 8, fill = true }),
      kit.text {
        id = "power-percent", x = 52, y = 0, font_size = theme.size.extra, font_weight = 700,
        text = function() return ("%d%%"):format(math.floor((first().capacity or 0) + 0.5)) end,
      },
      kit.subtitle { x = 52, y = 44, width = inner - 52, elide = "right", color = kit.ink("lo"),
        text = model.summary },
      ui.Item {
        y = 80, width = inner, height = 12,
        kit.fill { width = inner, height = 12, color = kit.signal("accent"),
          value = function() return math.max(0, math.min(1, (first().capacity or 0) / 100)) end },
        kit.surface {
          width = 2, height = 12,
          x = function() return inner * (first().charge_limit or 100) / 100 - 1 end,
          visible = function() local l = first().charge_limit return l ~= nil and l < 100 end,
          color = kit.ink("hi"),
        },
      },
    },
  }

  -- The power profile: three choices, and what the chosen one is for.
  local choices = { width = inner }
  for _, p in ipairs(model.PROFILES) do
    choices[#choices + 1] = { id = "power-profile-" .. p.id, icon = p.icon, label = p.name, group = "power-profile",
      selected = function() return active() == p.id end, on_clicked = function() model.select(p.id) end }
  end
  local function hint()
    for _, p in ipairs(model.PROFILES) do if p.id == active() then return p.hint end end
    return ""
  end
  local profile = P.section { id = "power-profiles", caption_id = "power-heading-power-mode", width = w,
    title = "Power mode",
    P.buttons(choices),
    kit.subtitle { id = "power-profile-note", width = inner, wrap = true, font_size = theme.size.small,
      color = kit.ink("lo"),
      text = function()
        local note = model.profile_note and model.profile_note()
        if note and note ~= "Choose how the system balances energy and speed." then return note end
        local message = model.message and model.message:get() or ""
        if message ~= "" then return message end
        return hint()
      end },
  }

  -- The battery's health, and how it is charged -- set by the firmware
  -- (and root), shown here; its graphs are the dashboard's.
  local rows = {}
  for _, entry in ipairs(model.FACTS) do rows[#rows + 1] = { entry.name, entry.value } end
  local health = P.section { id = "power-health", caption_id = "power-heading-battery", width = w, title = "Battery",
    kit.facts(rows, inner, 30),
    P.buttons { width = inner,
      { id = "power-open-battery", icon = "monitoring", label = "Battery graphs and details",
        on_clicked = model.open_battery } },
  }

  return P.page { id = "power-scroll", width = w, height = h, summary, profile, health }
end

return M
