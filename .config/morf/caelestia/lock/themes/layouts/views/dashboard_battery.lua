-- The dashboard's Battery tab: the shared battery model.
-- On the left the charge as a ring gauge with its draw, endurance, health
-- and heat as metered rows and a status strip; on the right four history
-- charts -- charge, draw, voltage, temperature over the last minutes -- and
-- what the cell is, in two columns. Drawn through the kit.

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")
local P = require("themes.layouts.page")

local S = L.SIZE
local M = {}

-- The dashboard's page (the same for every tab), the tiles fitted to it.
local responsive = require("responsive")
local COMPACT = responsive.compact()
local VIEW_H
M.WIDTH, VIEW_H = responsive.dashboard("battery")
M.HEIGHT = VIEW_H
local GAP = P.GAP

function M.build(model)
  local opened, battery_state, battery, charging = model.active, model.state, model.battery, model.charging
  local num, duration_text = model.number, model.duration
  local CHARGE, DRAW, VOLTS, HEAT = kit.signal("accent"), kit.signal("warn"), kit.signal("info"), kit.signal("alert")
  local function capacity() return battery().capacity or 0 end
  local function present() return battery().capacity ~= nil end
  local function level_kind()
    if charging() then return "info" end
    local c = capacity()
    return c <= 10 and "alert" or c <= 25 and "warn" or "ok"
  end
  local function peak(field, floor)
    local p = floor
    for _, v in ipairs(model.series(field)) do if v > p then p = v end end
    return p
  end

  -- ------------------------------------------------------------ sizes --
  -- Desk: Charge over Readings on the left; History over Details and
  -- Health on the right, the lot the page's height. Phone: one under the
  -- other, each the page's width.
  local ROW_H, ROW_GAP = 30, 6
  local FACT_H = 20
  local READ_H = P.CAPTION_H + 2 * P.PAD + 4 * ROW_H + 3 * ROW_GAP
  local LOW_H = P.CAPTION_H + 2 * P.PAD + 5 * FACT_H
  local LEFT_W, RIGHT_W, CHARGE_H, HISTORY_H, DETAILS_W, HEALTH_W
  if COMPACT then
    LEFT_W, RIGHT_W = M.WIDTH, M.WIDTH
    CHARGE_H, HISTORY_H = 300, P.CAPTION_H + 2 * P.PAD + 2 * L.chart_h(96) + GAP
    DETAILS_W, HEALTH_W = M.WIDTH, M.WIDTH
  else
    LEFT_W, RIGHT_W = P.cols(M.WIDTH, 2, { 1, 2 })
    CHARGE_H = VIEW_H - GAP - READ_H
    HISTORY_H = VIEW_H - GAP - LOW_H
    DETAILS_W, HEALTH_W = P.cols(RIGHT_W, 2, { 2, 1 })
  end
  local HEALTH_H = COMPACT and P.CAPTION_H + 2 * P.PAD + 44 or LOW_H

  -- ----------------------------------------------------------- charge --
  local cw, ch = P.tile_inner(LEFT_W, CHARGE_H)
  local limit_h = L.lh(S.label)
  local RING = math.max(80, math.min(cw, ch - limit_h - 6, 240))
  local percent = math.max(theme.size.large, math.min(theme.size.extra + 14, math.floor(RING / 5)))
  local charge = P.tile {
    id = "battery-charge-card", width = LEFT_W, height = CHARGE_H, title = "Charge",
    note = function() return battery().status and tostring(battery().status) or "No battery" end,
    kit.ring {
      id = "battery-ring", x = math.floor((cw - RING) / 2), y = math.max(0, math.floor((ch - limit_h - 6 - RING) / 2)),
      size = RING, sweep = 290,
      value = function() return opened() and capacity() / 100 or 0 end,
      color = function() return kit.signal(level_kind() == "ok" and "accent" or level_kind())() end,
      -- The ring prints no reading of its own (the column below is it).
      text = " ",
      ui.Column {
        anchors = { center_in = true }, gap = 0, align = "center",
        kit.icon(function() return charging() and "bolt" or "battery_full" end, 20, CHARGE, { fill = true }),
        kit.text { id = "battery-percent", height = math.ceil(percent * 1.2), font_size = percent, font_weight = 300,
          color = kit.ink("accent"), horizontal_alignment = "center",
          text = function() return present() and ("%d%%"):format(math.floor(capacity() + 0.5)) or "--" end },
        kit.text { width = math.floor(RING * .5), height = L.lh(S.body), horizontal_alignment = "center", elide = "right",
          font_size = S.body, color = kit.ink("hi"), text = function() return battery().status or "No battery" end },
      },
    },
    L.label { y = ch - limit_h, width = cw, horizontal_alignment = "center", elide = "right",
      text = function()
        local b = battery()
        if not b.charge_limit or b.charge_limit >= 100 then return "No charge limit" end
        return ("Charges to %d%%%s"):format(b.charge_limit, b.charge_mode and (" · " .. b.charge_mode) or "")
      end },
  }
  if theme.motion.value_flash then
    theme.motion.value_flash(charge, "battery-charge", {
      x = LEFT_W - 12, y = 0, height = 32, active = opened,
      read = function()
        local b = battery()
        return { capacity = b.capacity, status = b.status }
      end,
      changed = function(before, now)
        return before.status ~= now.status or
          (before.capacity and now.capacity and math.abs(now.capacity - before.capacity) >= 5)
      end,
      cooldown = 3000,
    })
  end

  -- --------------------------------------------------------- readings --
  local rw = P.tile_inner(LEFT_W, READ_H)
  local function row(id, label, value, level, color, i)
    return L.row { id = id, y = (i - 1) * (ROW_H + ROW_GAP), width = rw,
      height = ROW_H, label = label, value = value, color = color,
      level = function() return opened() and level() or 0 end }
  end
  local readings = P.tile {
    id = "battery-readings", width = LEFT_W, height = READ_H, title = "Readings",
    row("battery-power", "Power", function() return num(battery().power, "%.1f W") end,
      function() return (battery().power or 0) / math.max(5, peak("power", 5)) end, DRAW, 1),
    row("battery-lasts", function() return charging() and "Full in" or "Lasts" end, function()
      local s = battery_state()
      return duration_text(charging() and s.time_to_full or s.time_left)
    end, function()
      local s = battery_state()
      local secs = charging() and s.time_to_full or s.time_left
      return math.min(1, (secs or 0) / (10 * 3600))
    end, CHARGE, 2),
    row("battery-health", "Health", function() return num(battery().health, "%.0f %%") end,
      function() return (battery().health or 0) / 100 end, CHARGE, 3),
    row("battery-temperature", "Temperature", function() return num(battery().temperature, "%.1f °C") end,
      function() return (battery().temperature or 0) / 60 end, HEAT, 4),
  }

  -- ---------------------------------------------------------- history --
  local hw, hh = P.tile_inner(RIGHT_W, HISTORY_H)
  local GW = math.floor((hw - GAP) / 2)
  local GH = math.max(40, math.floor((hh - GAP) / 2) - L.chart_h(0))
  local minutes = tostring(model.minutes)
  local function small(caption, scale, spec)
    spec.width, spec.height, spec.samples, spec.caption, spec.scale = GW, GH, model.samples, caption, scale
    spec.columns = 8
    return (L.chart(spec))
  end
  local history = P.tile {
    id = "battery-main", width = RIGHT_W, height = HISTORY_H, title = "History", note = minutes,
    ui.Grid {
      columns = 2, column_gap = GAP, row_gap = GAP,
      small("Charge", function() return "100%" end, {
        id = "battery-graph-charge", color = CHARGE, top = 100, hatch = true,
        first = function() return model.series("percent") end,
      }),
      small("Power", function(top) return ("%.1f W"):format(top) end, {
        id = "battery-graph-power", color = DRAW, floor = 5,
        first = function() return model.series("power") end,
      }),
      small("Voltage", function(top) return ("%.2f V"):format(top) end, {
        id = "battery-graph-voltage", color = VOLTS,
        bottom = model.voltage_bottom, top = model.voltage_top,
        first = function() return model.series("voltage") end,
      }),
      small("Temperature", function(top) return ("%.0f °C"):format(top) end, {
        id = "battery-graph-temperature", color = HEAT, top = 60,
        first = function() return model.series("temperature") end,
      }),
    },
  }

  -- ---------------------------------------------------------- details --
  local dw = P.tile_inner(DETAILS_W, LOW_H)
  local FW = math.floor((dw - GAP) / 2)
  local facts_l = kit.facts({
    { "Vendor", function() return battery().vendor or "" end },
    { "Model", function() return battery().model or "" end },
    { "Technology", function() return battery().technology or "" end },
    { "Serial", function() return battery().serial or "" end },
    { "Cycles", function() return num(battery().cycles, "%d") end },
  }, FW, FACT_H)
  local facts_r = kit.facts({
    { "Voltage", function() return num(battery().voltage, "%.2f V") end },
    { "Energy now", function() return num(battery().energy, "%.1f Wh") end },
    { "Last full", function() return num(battery().energy_full, "%.1f Wh") end },
    { "Full design", function() return num(battery().energy_design, "%.1f Wh") end },
    { "Charge limit", model.limit },
  }, FW, FACT_H)
  local details = P.tile {
    id = "battery-details", caption_id = "battery-title", width = DETAILS_W, height = LOW_H, title = "Details",
    note = function()
      local b = battery()
      return (((b.vendor or "") .. " " .. (b.model or "")):gsub("^%s+", ""))
    end,
    ui.Item { id = "battery-facts", width = dw, height = 5 * FACT_H, facts_l, ui.Item { x = FW + GAP, facts_r } },
  }

  -- ----------------------------------------------------------- health --
  local sw = P.tile_inner(HEALTH_W, HEALTH_H)
  local health = P.tile {
    id = "battery-state", width = HEALTH_W, height = HEALTH_H, title = "Health",
    L.status { width = sw, height = 44, kind = level_kind,
      title = L.term(function() return "battery." .. level_kind() end, function()
        local k = level_kind()
        return k == "info" and "Charging" or k == "alert" and "Very low" or k == "warn" and "Low" or "Good"
      end),
      subtitle = function()
        if not present() then return "No battery" end
        return charging() and "Plugged in  ·  " .. num(battery().power, "%.1f W")
          or tostring(battery().status or "No battery") .. "  ·  " .. num(battery().energy, "%.1f Wh")
      end },
  }

  if COMPACT then
    local page = ui.Column { id = "dashboard-battery", width = M.WIDTH, gap = GAP,
      charge, readings, history, details, health }
    M.HEIGHT = CHARGE_H + READ_H + HISTORY_H + LOW_H + HEALTH_H + 4 * GAP
    page.height = M.HEIGHT
    return { page = page }
  end
  M.HEIGHT = VIEW_H
  return { page = ui.Row { id = "dashboard-battery", width = M.WIDTH, height = M.HEIGHT, gap = GAP,
    ui.Column { gap = GAP, charge, readings },
    ui.Column { gap = GAP, history, ui.Row { gap = GAP, details, health } },
  } }
end

return M
