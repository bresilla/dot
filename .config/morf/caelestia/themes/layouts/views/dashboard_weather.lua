-- The dashboard's Weather tab: the shared weather model, in the page
-- template's tiles (themes/layouts/page.lua). Now -- the condition and
-- temperature, and a wind dial where there is room --, the next hours'
-- temperature and rain, and the sun's track between sunrise and sunset;
-- three metered readings; the week ahead, each day with its range on the
-- week's scale. Drawn through the kit.

local morf = require("morf")
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
M.WIDTH, VIEW_H = responsive.dashboard("weather")
M.HEIGHT = VIEW_H
local GAP = P.GAP

function M.build(model)
  local now, temperature, today = model.now, model.temperature, model.today
  local active = model.active
  local settle = { duration = theme.duration.large, easing = theme.ease.emphasized_decel }
  local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
  local function compass_name(deg) return COMPASS[math.floor(((deg % 360) + 22.5) / 45) % 8 + 1] end

  -- ------------------------------------------------------------ sizes --
  -- Desk: Now, Next 24 h and Sun along the top; the three readings; the
  -- week filling what is left. Phone: one under the other.
  local big = theme.size.extra * 2
  local big_h = math.ceil(big * 1.15)
  local NOW_H = P.CAPTION_H + 2 * P.PAD + math.max(120, L.lh(S.body) + big_h + L.lh(S.body) + L.lh(S.label) + 4)
  local DET_H = P.CAPTION_H + 2 * P.PAD + L.lh(theme.size.large) + 14
  local NOW_W, HOURS_W, SUN_W, FORE_H
  if COMPACT then
    NOW_W, HOURS_W, SUN_W = M.WIDTH, M.WIDTH, M.WIDTH
    FORE_H = P.CAPTION_H + 2 * P.PAD + 170
  else
    NOW_W, HOURS_W, SUN_W = P.cols(M.WIDTH, 3, { 5, 4, 3 })
    FORE_H = math.max(P.CAPTION_H + 2 * P.PAD + 120, VIEW_H - NOW_H - DET_H - 2 * GAP)
  end
  local HOURS_H = COMPACT and P.CAPTION_H + 2 * P.PAD + 120 or NOW_H
  local SUN_H = COMPACT and P.CAPTION_H + 2 * P.PAD + 130 or NOW_H

  -- -------------------------------------------------------------- now --
  local nw, nh = P.tile_inner(NOW_W, NOW_H)
  local CS = math.min(110, nh - L.lh(S.micro) - 4)
  local wide = nw >= 420
  local lh = L.lh(S.micro)
  local function wind_dir() return now().wind_direction or 0 end
  local compass = L.item { width = CS, height = CS + lh + 2, visible = wide,
    kit.dial { size = CS, value = function() return active() and math.min(1, (now().wind_speed or 0) / 60) or 0 end,
      color = kit.signal("info") },
    ui.Item { width = CS, height = CS, rotation = function() return active() and wind_dir() or 0 end,
      behavior = { rotation = settle },
      ui.Path { x = CS / 2 - 6, y = 10, width = 12, height = CS / 2 - 10, view_box = { 0, 0, 12, 60 },
        d = "M6 0 L12 18 L6 13 L0 18 Z M5 16 H7 V60 H5 Z", fill_color = kit.signal("warn") } },
    L.label { x = -10, y = CS + 2, width = CS + 20, horizontal_alignment = "center", font_size = S.micro,
      text = function() local w = now() return w.wind_direction and ("Wind %s %d°"):format(compass_name(w.wind_direction), math.floor(w.wind_direction)) or "Wind --" end },
  }
  local IS = 64
  local IX = wide and CS + 20 or 0
  local TX = IX + IS + 14
  local TW = nw - TX
  local text_h = big_h + L.lh(S.body) + L.lh(S.label) + 4
  local TY = math.max(0, math.floor((nh - text_h) / 2))
  local now_tile = P.tile {
    id = "weather-now", width = NOW_W, height = NOW_H, title = "Conditions", caption_id = "weather-place",
    note = model.place,
    -- What the reading is: now, the last one known, or none yet.
    L.label { id = "weather-status", width = nw, elide = "right", color = kit.ink("hi"),
      text = function()
        local w = now()
        local word = not w.available and "Waiting for weather" or w.stale and "Last known conditions" or "Now"
        return word .. "  ·  " .. (model.date() or "")
      end },
    ui.Item { y = L.lh(S.label), width = nw, height = nh - L.lh(S.label),
      compass,
      L.item { x = IX, y = math.floor((nh - L.lh(S.label) - IS) / 2), width = IS, height = IS,
        kit.icon(function()
          local w = now()
          return w.available and model.symbol(w.code, w.is_day) or "cloud"
        end, 52, kit.signal("accent"), {
          anchors = { center_in = true }, visible = function() return now().available end }),
        kit.loading(48, kit.signal("accent"), {
          id = "weather-loading", anchors = { center_in = true },
          active = function() return active() and not now().available end,
          visible = function() return not now().available end }),
      },
      ui.Column { x = TX, y = math.max(0, TY - L.lh(S.label)), gap = 0,
        kit.text { id = "weather-temperature", width = TW, height = big_h, font_size = big, font_weight = 300,
          color = kit.ink("accent"), elide = "right",
          text = function() local w = now() return w.available and temperature(w.temperature) or "--" end },
        kit.text { id = "weather-condition", width = TW, height = L.lh(S.body), elide = "right",
          font_size = S.body, color = kit.ink("hi"),
          text = function() local w = now() return w.available and (w.condition or "") or "No weather" end },
        L.label { width = TW, elide = "right",
          text = function()
            local t = today()
            return ("Lo %s  ·  Hi %s"):format(t.low and temperature(t.low, true) or "--", t.high and temperature(t.high, true) or "--")
          end },
      },
    },
  }

  -- ------------------------------------------------------------ hours --
  local function hourly() return active() and (now().hourly or {}) or {} end
  local function temps()
    local out = {}
    for i, h in ipairs(hourly()) do out[i] = h.temperature or 0 end
    return out
  end
  local function trange()
    local lo, hi
    for _, v in ipairs(temps()) do lo = math.min(lo or v, v) hi = math.max(hi or v, v) end
    return (lo or 0) - 1, (hi or 1) + 1
  end
  local hw, hh = P.tile_inner(HOURS_W, HOURS_H)
  local RAIN_H = 16
  local HH = math.max(30, hh - L.chart_h(0) - L.lh(S.micro) - RAIN_H - 6)
  local hours = P.tile {
    id = "weather-hours", width = HOURS_W, height = HOURS_H, title = "Next 24 h",
    note = function() local _, hi = trange() return temperature(hi - 1, true) end,
    (L.chart { width = hw, height = HH, samples = 24, caption = "Temperature",
      scale = function() local _, hi = trange() return temperature(hi - 1, true) end,
      first = temps, bottom = function() return (trange()) end, top = function() local _, hi = trange() return hi end,
      columns = 6, color = kit.signal("accent") }),
    L.label { y = L.chart_h(HH) + 4, text = "Precipitation", font_size = S.micro, color = kit.stroke("mark") },
    kit.spectrum { y = L.chart_h(HH) + 4 + L.lh(S.micro), width = hw, height = RAIN_H, gap = 2, color = kit.signal("info"),
      values = function()
        local out = {}
        for i, h in ipairs(hourly()) do out[i] = (h.precipitation or 0) / 100 end
        return out
      end },
  }

  -- -------------------------------------------------------------- sun --
  local function sun_progress()
    morf.minute_clock:get()
    local t = today()
    if not (t.sunrise and t.sunset) then return 0 end
    local n = morf.time.now()
    return math.max(0, math.min(1, (n - t.sunrise) / math.max(1, t.sunset - t.sunrise)))
  end
  local uw, uh = P.tile_inner(SUN_W, SUN_H)
  local TIMES_H = L.lh(S.label) + L.lh(theme.size.normal)
  local AW = math.max(60, math.min(uw, 2 * (uh - TIMES_H - 4), 220))
  local AH = AW / 2 + 6
  local function sun(label, value, id, right)
    return ui.Column { gap = 0, anchors = right and { right = true, bottom = true } or { left = true, bottom = true },
      L.label { text = label, width = math.floor(uw / 2) - 4, horizontal_alignment = right and "right" or "left" },
      kit.text { id = id, text = value, width = math.floor(uw / 2) - 4, height = L.lh(theme.size.normal),
        font_size = theme.size.normal, color = kit.ink("hi"), horizontal_alignment = right and "right" or "left" },
    }
  end
  local sun_tile = P.tile {
    id = "weather-sun", width = SUN_W, height = SUN_H, title = "Sun",
    note = function() return ("Daylight %d%%"):format(math.floor(sun_progress() * 100 + .5)) end,
    ui.Item { width = uw, height = uh,
      ui.Item { x = math.floor((uw - AW) / 2), y = math.max(0, math.floor((uh - TIMES_H - AH) / 2)), width = AW, height = AH,
        clip = true,
        kit.gauge { size = AW, stroke = 4, from = -90, sweep = 180, gap = 0,
          value = function() return active() and sun_progress() or 0 end, color = kit.signal("warn"),
          track = kit.stroke("idle") } },
      sun("Sunrise", function() return model.clock(today().sunrise) end, "weather-sunrise", false),
      sun("Sunset", function() return model.clock(today().sunset) end, "weather-sunset", true),
    },
  }

  -- ---------------------------------------------------------- details --
  local DW = { P.cols(M.WIDTH, 3) }
  local function detail(i, label, value, level, color, id, extra)
    local w = DW[i]
    local iw = P.tile_inner(w, DET_H)
    local vs = theme.size.large
    local vw = math.floor(iw * .5)
    return P.tile {
      id = id, width = w, height = DET_H, title = label, note = extra,
      kit.text { width = vw, height = L.lh(vs), elide = "right", text = value,
        font_size = vs, font_weight = 300, color = kit.ink("hi") },
      kit.meter { x = vw + 10, y = math.floor((L.lh(vs) - 6) / 2), width = iw - vw - 10, height = 6, count = 16,
        value = function() return active() and level() or 0 end, color = color },
    }
  end
  local details = ui.Row { gap = GAP,
    detail(1, "Humidity", model.humidity, function() return (now().humidity or 0) / 100 end, kit.signal("info"), "weather-humidity"),
    detail(2, "Feels like", function() return temperature(now().feels_like) end,
      function() return math.max(0, math.min(1, ((now().feels_like or 0) + 10) / 50)) end, kit.signal("accent"), "weather-feels",
      function()
        local w = now()
        if not (w.feels_like and w.temperature) then return "Δ --" end
        return ("Δ %+.0f°"):format(w.feels_like - w.temperature)
      end),
    detail(3, "Wind", model.wind, function() return math.min(1, (now().wind_speed or 0) / 60) end, kit.signal("warn"), "weather-wind",
      function() local w = now() return w.wind_direction and compass_name(w.wind_direction) or "--" end),
  }

  -- --------------------------------------------------------- forecast --
  local fw, fh = P.tile_inner(M.WIDTH, FORE_H)
  local DAY_GAP = 8
  local CELL_W = math.floor((fw - 6 * DAY_GAP) / 7)
  local days = {}
  for i = 1, 7 do
    local function day() return model.day(i) end
    local function range() return model.range(i) end
    local hi_size = theme.size.large + 2
    local ICON_Y = L.lh(S.label) + L.lh(S.micro) + 4
    local HI_Y = ICON_Y + 34
    local LO_Y = HI_Y + L.lh(hi_size)
    local BAR_Y = ICON_Y
    local BAR_H = math.max(20, fh - BAR_Y - 22)
    local RX = CELL_W - 10
    days[#days + 1] = L.item {
      id = "weather-day-" .. i, width = CELL_W, height = fh,
      visible = function() return i == 1 or day() ~= nil end,
      L.label { width = CELL_W - 14, elide = "right", text = function() return model.day_name(i) end,
        color = i == 1 and kit.ink("accent") or kit.ink("hi") },
      L.label { y = L.lh(S.label), width = CELL_W - 14, elide = "right", font_size = S.micro,
        text = function() return model.day_date(i) end },
      kit.icon(function()
        local d = day()
        return model.symbol(d and d.code, true)
      end, 28, kit.signal("accent"), { y = ICON_Y }),
      -- The day's span on the week's scale, lit over the theme's channel.
      L.item { x = RX, y = BAR_Y, width = 6, height = BAR_H,
        kit.vmeter { width = 6, height = BAR_H, value = 0, color = kit.signal("warn") },
        ui.Item { width = 6, clip = true,
          y = function() local lo, span = range() return BAR_H * (1 - lo - span) end,
          height = function() local _, span = range() return math.max(3, BAR_H * span) end,
          behavior = { y = settle, height = settle },
          ui.Item { width = 6, height = BAR_H,
            y = function() local lo, span = range() return -BAR_H * (1 - lo - span) end,
            behavior = { y = settle },
            kit.vmeter { width = 6, height = BAR_H, value = 1, color = kit.signal("warn") } },
        },
      },
      kit.text { y = HI_Y, width = RX - 6, height = L.lh(hi_size), font_size = hi_size, font_weight = 300,
        color = kit.ink("hi"), elide = "right",
        text = function() local d = day() return d and temperature(d.high, true) or "--" end },
      L.label { y = LO_Y, width = RX - 6, elide = "right", color = kit.signal("info"),
        text = function() local d = day() return d and ("Lo " .. temperature(d.low, true)) or "" end },
      L.label { y = fh - 10 - L.lh(S.micro), width = RX - 6, elide = "right", font_size = S.micro,
        text = function() local d = day() return d and d.precipitation and ("Rain %d%%"):format(d.precipitation) or "Rain --" end },
      kit.meter { y = fh - 4, width = RX - 6, height = 4, count = 8, color = kit.signal("info"),
        value = function() local d = day() return active() and d and (d.precipitation or 0) / 100 or 0 end },
    }
  end
  local forecast = P.tile {
    id = "weather-forecast-tile", caption_id = "weather-forecast-title", width = M.WIDTH, height = FORE_H,
    title = model.forecast_title,
    ui.Row { id = "weather-forecast", gap = DAY_GAP, table.unpack(days) },
    L.label { id = "weather-forecast-empty", x = CELL_W + DAY_GAP, y = math.floor(fh / 2) - 8,
      width = fw - CELL_W - DAY_GAP, font_size = S.body, color = kit.ink("lo"), horizontal_alignment = "center",
      visible = function() return model.day(2) == nil end,
      text = function() return now().available and "No forecast for the days ahead" or "The forecast shows up once the weather loads" end },
  }

  local page
  if COMPACT then
    M.HEIGHT = NOW_H + HOURS_H + SUN_H + DET_H + FORE_H + 4 * GAP
    page = ui.Column { id = "dashboard-weather-tab", width = M.WIDTH, height = M.HEIGHT, gap = GAP,
      now_tile, hours, sun_tile, details, forecast }
  else
    M.HEIGHT = NOW_H + DET_H + FORE_H + 2 * GAP
    page = ui.Column { id = "dashboard-weather-tab", width = M.WIDTH, height = M.HEIGHT, gap = GAP,
      ui.Row { gap = GAP, now_tile, hours, sun_tile }, details, forecast }
  end
  return { page = page }
end

return M
