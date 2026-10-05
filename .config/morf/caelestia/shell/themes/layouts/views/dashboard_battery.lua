-- The dashboard's Battery tab: the shared battery model.
-- On the left the charge as a ring gauge with its draw, endurance, health
-- and heat as metered rows and a status strip; on the right four history
-- charts -- charge, draw, voltage, temperature over the last minutes -- and
-- what the cell is, in two columns. Drawn through the kit.

local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")

local S = L.SIZE
local M = {}

M.WIDTH, M.HEIGHT = 1040, 520
local GAP = 12
local LEFT_W = 320
local RIGHT_W = M.WIDTH - LEFT_W - GAP
local PAD = 20

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

  -- ---------------------------------------------------- the charge ring --
  local CAP_Y = 14
  local RING_Y = CAP_Y + L.CAPTION_H + 6
  local RING = 216
  local LIMIT_Y = RING_Y + RING + 2
  local ROWS_Y = LIMIT_Y + L.lh(S.label) + 8
  local ROW_H, ROW_GAP = 34, 6
  local STATUS_H = 40
  local function peak(field, floor)
    local p = floor
    for _, v in ipairs(model.series(field)) do if v > p then p = v end end
    return p
  end
  local function row(id, label, value, level, color, i)
    return L.row { id = id, x = PAD, y = ROWS_Y + (i - 1) * (ROW_H + ROW_GAP), width = LEFT_W - 2 * PAD,
      height = ROW_H, label = label, value = value, color = color,
      level = function() return opened() and level() or 0 end }
  end
  local percent = theme.size.extra + 14
  local left = L.card {
    id = "battery-charge-card", key = "bat-cell", header = false, width = LEFT_W, height = M.HEIGHT,
    L.caption { x = PAD, y = CAP_Y, width = LEFT_W - 2 * PAD, text = "Charge",
      note = function() return battery().status and tostring(battery().status) or "No battery" end },
    kit.ring {
      id = "battery-ring", x = math.floor((LEFT_W - RING) / 2), y = RING_Y, size = RING, sweep = 290,
      value = function() return opened() and capacity() / 100 or 0 end,
      color = function() return kit.signal(level_kind() == "ok" and "accent" or level_kind())() end,
      -- The ring prints no reading of its own (the column below is it).
      text = " ",
      ui.Column {
        anchors = { center_in = true }, gap = 0, align = "center",
        kit.icon(function() return charging() and "bolt" or "battery_full" end, 22, CHARGE, { fill = true }),
        kit.text { id = "battery-percent", height = math.ceil(percent * 1.2), font_size = percent, font_weight = 300,
          color = kit.ink("accent"), horizontal_alignment = "center",
          text = function() return present() and ("%d%%"):format(math.floor(capacity() + 0.5)) or "--" end },
        kit.text { width = math.floor(RING * .5), height = L.lh(S.body), horizontal_alignment = "center", elide = "right",
          font_size = S.body, color = kit.ink("hi"), text = function() return battery().status or "No battery" end },
      },
    },
    L.label { x = PAD, y = LIMIT_Y, width = LEFT_W - 2 * PAD, horizontal_alignment = "center", elide = "right",
      text = function()
        local b = battery()
        if not b.charge_limit or b.charge_limit >= 100 then return "No charge limit" end
        return ("Charges to %d%%%s"):format(b.charge_limit, b.charge_mode and (" · " .. b.charge_mode) or "")
      end },
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
    L.status { x = PAD, y = M.HEIGHT - PAD - STATUS_H, width = LEFT_W - 2 * PAD, height = STATUS_H,
      kind = level_kind,
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
  if theme.motion.value_flash then
    theme.motion.value_flash(left, "battery-charge", {
      x = LEFT_W - 12, y = CAP_Y, height = 32, active = opened,
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

  -- ----------------------------------------------------------- graphs --
  local IW = RIGHT_W - 2 * PAD
  local GW = math.floor((IW - 22) / 2)
  local GH = 118
  local ROW_GAP_G = 14
  local minutes = tostring(model.minutes)
  local function small(caption, scale, spec)
    spec.width, spec.height, spec.samples, spec.caption, spec.scale = GW, GH, model.samples, caption, scale
    spec.columns = 8
    return (L.chart(spec))
  end
  local grid = ui.Grid {
    columns = 2, column_gap = 22, row_gap = ROW_GAP_G,
    small("Charge  ·  " .. minutes, function() return "100%" end, {
      id = "battery-graph-charge", color = CHARGE, top = 100, hatch = true,
      first = function() return model.series("percent") end,
    }),
    small("Power  ·  " .. minutes, function(top) return ("%.1f W"):format(top) end, {
      id = "battery-graph-power", color = DRAW, floor = 5,
      first = function() return model.series("power") end,
    }),
    small("Voltage  ·  " .. minutes, function(top) return ("%.2f V"):format(top) end, {
      id = "battery-graph-voltage", color = VOLTS,
      bottom = model.voltage_bottom, top = model.voltage_top,
      first = function() return model.series("voltage") end,
    }),
    small("Temperature  ·  " .. minutes, function(top) return ("%.0f °C"):format(top) end, {
      id = "battery-graph-temperature", color = HEAT, top = 60,
      first = function() return model.series("temperature") end,
    }),
  }

  local TITLE_Y = 14
  local GRID_Y = TITLE_Y + L.title_h() + 10
  local FACTS_CAP_Y = GRID_Y + 2 * L.chart_h(GH) + ROW_GAP_G + 14
  local FACTS_Y = FACTS_CAP_Y + L.CAPTION_H + 6
  local FACT_H = math.max(16, math.min(20, math.floor((M.HEIGHT - PAD - FACTS_Y) / 5)))
  local facts_l = kit.facts({
    { "Vendor", function() return battery().vendor or "" end },
    { "Model", function() return battery().model or "" end },
    { "Technology", function() return battery().technology or "" end },
    { "Serial", function() return battery().serial or "" end },
    { "Cycles", function() return num(battery().cycles, "%d") end },
  }, GW, FACT_H)
  local facts_r = kit.facts({
    { "Voltage", function() return num(battery().voltage, "%.2f V") end },
    { "Energy now", function() return num(battery().energy, "%.1f Wh") end },
    { "Last full", function() return num(battery().energy_full, "%.1f Wh") end },
    { "Full design", function() return num(battery().energy_design, "%.1f Wh") end },
    { "Charge limit", model.limit },
  }, GW, FACT_H)

  local right = L.card {
    id = "battery-main", key = "bat-main", header = false, width = RIGHT_W, height = M.HEIGHT,
    L.title_row { x = PAD, y = TITLE_Y, width = IW, id = "battery-title", active = model.active, title = "Battery",
      key = "battery", subtitle = function()
        local b = battery()
        return (((b.vendor or "") .. " " .. (b.model or "")):gsub("^%s+", ""))
      end },
    ui.Item { x = PAD, y = GRID_Y, grid },
    L.caption { x = PAD, y = FACTS_CAP_Y, width = IW, text = "Details", note = kit.code("cellreg", "CP-##/CP-##") },
    ui.Item { id = "battery-facts", x = PAD, y = FACTS_Y, width = IW, height = 5 * FACT_H,
      facts_l, ui.Item { x = GW + 22, facts_r } },
  }

  return { page = ui.Row { id = "dashboard-battery", width = M.WIDTH, height = M.HEIGHT, gap = GAP, left, right } }
end

return M
