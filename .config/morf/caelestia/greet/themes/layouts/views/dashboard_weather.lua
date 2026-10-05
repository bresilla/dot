-- The dashboard's Weather tab: the shared weather model. The place and date over a sun-track arc between sunrise and
-- sunset; a main card with a wind dial, the condition and temperature and
-- the next hours' temperature and rain; three metered readings; and the
-- week ahead as cells, each with its range on the week's scale. Drawn
-- through the kit.

local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")

local S = L.SIZE
local M = {}

M.WIDTH, M.HEIGHT = 838, 561
local GAP = 12

function M.build(model)
  local now, temperature, today = model.now, model.temperature, model.today
  local active = model.active
  local settle = { duration = theme.duration.large, easing = theme.ease.emphasized_decel }

  -- ------------------------------------------------------------- header --
  local function sun_progress()
    morf.minute_clock:get()
    local t = today()
    if not (t.sunrise and t.sunset) then return 0 end
    local n = morf.time.now()
    return math.max(0, math.min(1, (n - t.sunrise) / math.max(1, t.sunset - t.sunrise)))
  end
  local AW = 120
  local AH = AW / 2 + 6
  local function sun(label, value, id)
    return ui.Column { gap = 0,
      L.label { text = label, width = 76 },
      kit.text { id = id, text = value, width = 76, height = L.lh(theme.size.normal), font_size = theme.size.normal,
        color = kit.ink("hi") },
    }
  end
  local place_h = L.heading_h(theme.size.extra)
  local header = L.item {
    width = M.WIDTH, height = 72,
    ui.Column { x = 14, y = 0, gap = 0,
      L.heading { active = active, id = "weather-place", text = model.place, font_size = theme.size.extra,
        width = M.WIDTH - 420, elide = "right" },
      L.label { id = "weather-date", text = model.date, font_size = S.body, color = kit.ink("hi"),
        width = M.WIDTH - 420, elide = "right" },
      L.code("wxhead", "LAT ##.## · LON #.## · ALT ##", { width = M.WIDTH - 420 }),
    },
    ui.Row { anchors = { right = true, right_margin = 6 }, y = 6, gap = 14, align = "center",
      sun("Sunrise", function() return model.clock(today().sunrise) end, "weather-sunrise"),
      ui.Item { width = AW, height = AH, clip = true,
        kit.gauge { size = AW, stroke = 4, from = -90, sweep = 180, gap = 0,
          value = function() return active() and sun_progress() or 0 end, color = kit.signal("warn"),
          track = kit.stroke("idle") },
        L.label { anchors = { horizontal_center = true }, y = AH - L.lh(S.micro) - 4, font_size = S.micro,
          color = kit.ink("hi"), width = AW - 30, horizontal_alignment = "center",
          text = function() return ("Daylight %d%%"):format(math.floor(sun_progress() * 100 + .5)) end },
      },
      sun("Sunset", function() return model.clock(today().sunset) end, "weather-sunset"),
    },
  }

  -- ----------------------------------------------------------- main card --
  local BIG_H = 180
  local CS = 120
  local function wind_dir() return now().wind_direction or 0 end
  local COMPASS = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" }
  local function compass_name(deg) return COMPASS[math.floor(((deg % 360) + 22.5) / 45) % 8 + 1] end
  local lh = L.lh(S.micro)
  local CY = 10 + L.lh(S.label) + lh
  local compass = L.item { x = 28, y = CY, width = CS, height = CS + lh + 4,
    kit.dial { size = CS, value = function() return active() and math.min(1, (now().wind_speed or 0) / 60) or 0 end,
      color = kit.signal("info") },
    ui.Item { width = CS, height = CS, rotation = function() return active() and wind_dir() or 0 end,
      behavior = { rotation = settle },
      ui.Path { x = CS / 2 - 6, y = 10, width = 12, height = CS / 2 - 10, view_box = { 0, 0, 12, 60 },
        d = "M6 0 L12 18 L6 13 L0 18 Z M5 16 H7 V60 H5 Z", fill_color = kit.signal("warn") } },
    L.label { x = CS + 3, y = CS / 2 - lh / 2, text = "E", font_size = S.micro, color = kit.stroke("mark") },
    L.label { x = -12, y = CS / 2 - lh / 2, width = 10, horizontal_alignment = "right", text = "W", font_size = S.micro,
      color = kit.stroke("mark") },
    L.label { x = CS / 2 + 6, y = -lh + 2, text = "N", font_size = S.micro, color = kit.ink("hi") },
    L.label { x = -10, y = CS + 2, width = CS + 20, horizontal_alignment = "center", font_size = S.micro,
      text = function() local w = now() return w.wind_direction and ("Wind %s %d°"):format(compass_name(w.wind_direction), math.floor(w.wind_direction)) or "Wind --" end },
  }
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
  local HW = 286
  local RAIN_H = 20
  local HH = BIG_H - 18 - L.CAPTION_H - L.CAPTION_GAP - 6 - L.lh(S.micro) - RAIN_H - 12
  local hours = L.item { x = M.WIDTH - HW - 24, y = 14, width = HW, height = BIG_H - 26,
    (L.chart { width = HW, height = HH, samples = 24, caption = "Next 24 h",
      scale = function() local _, hi = trange() return temperature(hi - 1, true) end,
      first = temps, bottom = function() return (trange()) end, top = function() local _, hi = trange() return hi end,
      columns = 6, color = kit.signal("accent") }),
    L.label { y = L.chart_h(HH) + 6, text = "Precipitation", font_size = S.micro, color = kit.stroke("mark") },
    kit.spectrum { y = L.chart_h(HH) + 6 + L.lh(S.micro), width = HW, height = RAIN_H, gap = 2, color = kit.signal("info"),
      values = function()
        local out = {}
        for i, h in ipairs(hourly()) do out[i] = (h.precipitation or 0) / 100 end
        return out
      end },
  }
  local IX, IS = 196, 76
  local TX = IX + IS + 14
  local TW = M.WIDTH - HW - 24 - 14 - TX
  local big = theme.size.extra * 2
  local big_h = math.ceil(big * 1.15)
  local cond_y = 18 + big_h
  local now_card = L.card {
    id = "weather-now", y = 84, width = M.WIDTH, height = BIG_H, header = false,
    -- What the reading is: now, the last one known, or none yet.
    L.label { id = "weather-status", x = 12, y = 8, width = 300, elide = "right", color = kit.ink("hi"),
      text = function()
        local w = now()
        local code = kit.code("wxnow", "SYS.SRP ##") or ""
        local word = not w.available and "Waiting for weather" or w.stale and "Last known conditions" or "Now"
        return word .. (code ~= "" and ("  ·  " .. code) or "")
      end },
    compass,
    L.item { x = IX, y = math.floor((BIG_H - IS) / 2), width = IS, height = IS,
      kit.decor("brackets", { width = IS, height = IS, length = 10 }),
      kit.icon(function()
        local w = now()
        return w.available and model.symbol(w.code, w.is_day) or "cloud"
      end, 56, kit.signal("accent"), {
        anchors = { center_in = true }, visible = function() return now().available end }),
      kit.loading(52, kit.signal("accent"), {
        id = "weather-loading", anchors = { center_in = true },
        active = function() return active() and not now().available end,
        visible = function() return not now().available end }),
    },
    kit.text { id = "weather-temperature", x = TX, y = 14, width = TW, height = big_h, font_size = big, font_weight = 300,
      color = kit.ink("accent"), elide = "right",
      text = function() local w = now() return w.available and temperature(w.temperature) or "--" end },
    kit.text { id = "weather-condition", x = TX + 2, y = cond_y, width = TW, height = L.lh(S.body), elide = "right",
      font_size = S.body, color = kit.ink("hi"),
      text = function() local w = now() return w.available and (w.condition or "") or "No weather" end },
    L.label { x = TX + 2, y = cond_y + L.lh(S.body) + 2, width = TW, elide = "right",
      text = function()
        local t = today()
        return ("Lo %s  ·  Hi %s"):format(t.low and temperature(t.low, true) or "--", t.high and temperature(t.high, true) or "--")
      end },
    hours,
  }

  -- ------------------------------------------------------------ details --
  local DW = math.floor((M.WIDTH - 2 * GAP) / 3)
  local DH = 60
  local function detail(label, value, level, color, id, extra)
    local vs = theme.size.large
    local vw = math.floor(DW * .46)
    return L.card {
      id = id, width = DW, height = DH, header = false,
      L.label { x = 14, y = 8, width = vw, elide = "right", text = label },
      L.label { anchors = { right = true, right_margin = 14 }, y = 8, width = DW - vw - 40, horizontal_alignment = "right",
        elide = "right", text = extra or kit.code(id, "CH-##"), font_size = S.micro, color = kit.stroke("mark") },
      kit.text { x = 14, y = 8 + L.lh(S.label), width = vw, height = L.lh(vs), elide = "right", text = value,
        font_size = vs, font_weight = 300, color = kit.ink("hi") },
      kit.meter { x = vw + 24, y = DH - 22, width = DW - vw - 38, height = 6, count = 16,
        value = function() return active() and level() or 0 end, color = color },
    }
  end
  local DY = 84 + BIG_H + GAP
  local details = ui.Row {
    y = DY, gap = GAP,
    detail("Humidity", model.humidity, function() return (now().humidity or 0) / 100 end, kit.signal("info"), "weather-humidity"),
    detail("Feels like", function() return temperature(now().feels_like) end,
      function() return math.max(0, math.min(1, ((now().feels_like or 0) + 10) / 50)) end, kit.signal("accent"), "weather-feels",
      function()
        local w = now()
        if not (w.feels_like and w.temperature) then return "Δ --" end
        return ("Δ %+.0f°"):format(w.feels_like - w.temperature)
      end),
    detail("Wind", model.wind, function() return math.min(1, (now().wind_speed or 0) / 60) end, kit.signal("warn"), "weather-wind",
      function() local w = now() return w.wind_direction and compass_name(w.wind_direction) or "--" end),
  }

  -- ----------------------------------------------------------- forecast --
  local TY = DY + DH + GAP
  local title_h = L.heading_h(theme.size.larger)
  local FY = TY + title_h + 6
  local CARD_W = (M.WIDTH - 6 * GAP) / 7
  local CARD_H = M.HEIGHT - FY
  local days = {}
  for i = 1, 7 do
    local function day() return model.day(i) end
    local function range() return model.range(i) end
    local hi_size = theme.size.large + 2
    local ICON_Y = 8 + L.lh(S.label) + L.lh(S.micro) + 6
    local HI_Y = ICON_Y + 36
    local LO_Y = HI_Y + L.lh(hi_size)
    local BAR_Y = ICON_Y
    local BAR_H = CARD_H - BAR_Y - 34
    local RX = CARD_W - 18
    days[#days + 1] = L.card {
      id = "weather-day-" .. i, header = false,
      width = CARD_W, height = CARD_H,
      visible = function() return i == 1 or day() ~= nil end,
      L.label { x = 8, y = 8, width = math.floor(CARD_W * .52), elide = "right", text = function() return model.day_name(i) end,
        color = i == 1 and kit.ink("accent") or kit.ink("hi") },
      L.label { x = 8, y = 8 + L.lh(S.label), width = CARD_W - 32, elide = "right", font_size = S.micro,
        text = function() return model.day_date(i) end },
      L.code("day" .. i, "##", { anchors = { right = true, right_margin = 6 }, y = 8, width = math.floor(CARD_W * .48) - 14,
        horizontal_alignment = "right" }),
      kit.icon(function()
        local d = day()
        return model.symbol(d and d.code, true)
      end, 30, kit.signal("accent"), { x = 8, y = ICON_Y }),
      -- The day's span on the week's scale: the theme's channel, lit over
      -- the span, beside its ruler.
      L.item { x = RX, y = BAR_Y, width = 12, height = BAR_H,
        kit.decor("ticks", { x = 8, y = 0, length = BAR_H, count = 8, major = 4, size = 4, vertical = true,
          color = kit.stroke("idle") }),
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
      kit.text { x = 8, y = HI_Y, width = RX - 12, height = L.lh(hi_size), font_size = hi_size, font_weight = 300,
        color = kit.ink("hi"), elide = "right",
        text = function() local d = day() return d and temperature(d.high, true) or "--" end },
      L.label { x = 8, y = LO_Y, width = RX - 12, elide = "right", color = kit.signal("info"),
        text = function() local d = day() return d and ("Lo " .. temperature(d.low, true)) or "" end },
      L.label { x = 8, y = CARD_H - 14 - L.lh(S.micro) - 2, width = CARD_W - 16, elide = "right", font_size = S.micro,
        text = function() local d = day() return d and d.precipitation and ("Rain %d%%"):format(d.precipitation) or "Rain --" end },
      kit.meter { x = 8, y = CARD_H - 12, width = CARD_W - 16, height = 4, count = 8, color = kit.signal("info"),
        value = function() local d = day() return active() and d and (d.precipitation or 0) / 100 or 0 end },
    }
  end

  return { page = L.item {
    id = "dashboard-weather-tab",
    width = M.WIDTH, height = M.HEIGHT,
    header,
    now_card,
    details,
    L.rule { x = 4, y = FY - 4, width = M.WIDTH - 8 },
    L.code("fc", "SEGMENT ##/##  ·  CP-##", { anchors = { right = true, right_margin = 4 }, y = TY + 4, width = 220,
      horizontal_alignment = "right" }),
    L.heading { id = "weather-forecast-title", active = active, level = "section", font_size = theme.size.larger,
      x = 14, y = TY, width = M.WIDTH - 260, text = function() return model.forecast_title() end },
    ui.Row { id = "weather-forecast", y = FY, gap = GAP, table.unpack(days) },
    L.label { id = "weather-forecast-empty", x = CARD_W + GAP + 14, y = FY + math.floor(CARD_H / 2) - 8,
      width = M.WIDTH - CARD_W - GAP - 28, font_size = S.body, color = kit.ink("lo"),
      visible = function() return model.day(2) == nil end,
      text = function() return now().available and "No forecast for the days ahead" or "The forecast shows up once the weather loads" end },
  } }
end

return M
