-- The overview tab's cards: weather, the user, the clock, the calendar,
-- the resource rings and the player, each a captioned card drawn through
-- the kit. Data and actions come from the dashboard model; the ids
-- the tests and the shell rely on are kept.
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")

local S = L.SIZE

return function(model, ROW1, ROW2, GAP)
  local opened = model.opened
  local K = {}
  local TOP = 10 + L.CAPTION_H + 6          -- under a card's caption strip

  --- A card's caption strip: the title, and the theme's code as its note
  --- where the card has room for one.
  local function strip(w, title, key)
    return L.caption { x = 10, y = 8, width = w - 20, text = title,
      note = w >= 180 and kit.code(key, "SD.###/##") or nil }
  end

  -- ------------------------------------------------------------ weather --
  function K.weather()
    local W = 275
    local function now()
      if not opened:get() then return { available = false } end
      return model.weather()
    end
    local big = theme.size.extra + 8
    local big_h = math.ceil(big * 1.2)
    local tx = 90
    local cond_y = TOP - 4 + big_h
    local ticks_y = cond_y + L.lh(S.body) + 2
    return kit.card {
      id = "dashboard-weather", width = W, height = ROW1,
      strip(W, "Weather", "wx"),
      L.item { x = 12, y = TOP + 2, width = 64, height = 64,
        kit.decor("brackets", { width = 64, height = 64, length = 8 }),
        kit.icon(function()
          local w = now()
          return w.available and model.weather_symbol(w.code, w.is_day) or "cloud"
        end, 40, kit.signal("accent"), {
          anchors = { center_in = true }, visible = function() return now().available end }),
        kit.loading(36, kit.signal("accent"), {
          id = "dashboard-weather-loading", anchors = { center_in = true },
          active = function() return opened:get() and not now().available end,
          visible = function() return not now().available end }),
      },
      kit.text { id = "dashboard-temperature", x = tx, y = TOP - 6, width = W - tx - 12, height = big_h,
        font_size = big, font_weight = 300, color = kit.ink("accent"), elide = "right",
        text = function()
          local w = now()
          if not w.available then return "--" end
          return ("%d%s"):format(math.floor((w.temperature or 0) + 0.5), w.units and w.units.temperature or "°")
        end },
      L.label { x = tx, y = cond_y, width = W - tx - 12, elide = "right", font_size = S.body, color = kit.ink("hi"),
        text = function() local w = now() return w.available and (w.condition or "") or "No weather" end },
      kit.decor("ticks", { x = tx, y = ticks_y, length = W - tx - 12, count = 24, major = 6, size = 6,
        color = kit.stroke("idle") }),
      L.label { x = tx, y = ticks_y + 8, width = W - tx - 12, elide = "right",
        text = function()
          local w = now()
          if not w.available then return "Loading…" end
          return ("Humidity %s  ·  Wind %s"):format(w.humidity and math.floor(w.humidity + .5) .. "%" or "--",
            w.wind_speed and ("%.0f"):format(w.wind_speed) or "--")
        end },
    }
  end

  -- --------------------------------------------------------------- user --
  --- The uptime short: "3d 4h", "4h 12m", "12m".
  local function uptime_short(seconds)
    seconds = math.floor(tonumber(seconds) or 0)
    local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
    if d > 0 then return ("%dd %dh"):format(d, h) end
    if h > 0 then return ("%dh %dm"):format(h, m) end
    return ("%dm"):format(m)
  end

  function K.user()
    local W = 340
    local face = model.face
    local has_face = face ~= ""
    local AV = 84
    local X = 14 + AV + 16
    local RW = W - X - 12
    local function system() return opened:get() and model.system() or { uptime = 0 } end
    local name_size = theme.size.large
    local name_y = TOP - 2 + L.lh(S.micro)
    local up_y = name_y + L.lh(name_size) + 2
    local up_size = theme.size.normal
    local code_w = 84
    local meter_y = up_y + L.lh(up_size) + 4
    return kit.card {
      id = "dashboard-user", width = W, height = ROW1,
      strip(W, "User", "op"),
      L.item { x = 14, y = TOP + 2, width = AV, height = AV,
        kit.shape { width = AV, height = AV, shape = "circle", color = kit.stroke("faint") },
        kit.icon("person", 40, kit.ink("lo"), { anchors = { center_in = true }, visible = not has_face, fill = true }),
        has_face and ui.Image { anchors = { fill = true }, source = face, fill_mode = "preserve_aspect_crop",
          mask = ui.Path { view_box = { 0, 0, 100, 100 }, d = kit.shape_path("circle"), fill_color = "#ffffff" } } or nil,
        kit.decor("brackets", { x = -4, y = -4, width = AV + 8, height = AV + 8, length = 10, color = kit.stroke("hot") }),
      },
      L.code("user", "UID ####", { x = X, y = TOP - 2, width = RW - 90 }),
      kit.text { x = X, y = name_y, width = RW - 92, height = L.lh(name_size), elide = "right",
        text = model.username, font_size = name_size, font_weight = 300, color = kit.ink("hi") },
      kit.chip { id = "dashboard-wm", x = W - 12 - 82, y = name_y + math.floor((L.lh(name_size) - 13) / 2),
        width = 82, text = function() return model.desktop() end },
      kit.text { x = X, y = up_y, width = code_w, height = L.lh(up_size), font_size = up_size, font_weight = 300,
        color = kit.ink("accent"), text = function() return uptime_short(system().uptime) end },
      L.label { id = "dashboard-uptime", x = X + code_w + 4, y = up_y + math.floor((L.lh(up_size) - L.lh(S.label)) / 2),
        width = RW - code_w - 4, elide = "right",
        text = function()
          if not opened:get() then return "" end
          local host = system().hostname
          return (host and host ~= "") and ("up  ·  " .. host) or "up"
        end },
      kit.meter { x = X, y = meter_y, width = RW, height = 4, count = 24,
        value = function() return ((tonumber(system().uptime) or 0) % 86400) / 86400 end },
      L.code("daycycle", "DAY CYCLE  ·  24 H", { x = X, y = meter_y + 7, width = RW }),
    }
  end

  -- -------------------------------------------------------------- clock --
  function K.clock()
    local W = 111
    local function t(fmt) return function() return model.clock(fmt) end end
    local digits = theme.size.extra + 6
    local dh = math.ceil(digits * 1.2)
    local function line(props)
      props.width, props.horizontal_alignment, props.elide = W - 26, "center", "right"
      return L.label(props)
    end
    return kit.card {
      id = "dashboard-clock", width = W, height = ROW2,
      strip(W, "Clock", "clk"),
      kit.decor("ticks", { x = 8, y = TOP + 4, length = ROW2 - TOP - 26, count = 24, major = 6, size = 6, vertical = true,
        color = kit.stroke("idle") }),
      ui.Column { x = 18, y = TOP + 2, width = W - 26, gap = 0, align = "center",
        line { text = kit.code("hrs", "HRS"), font_size = S.micro, color = kit.stroke("mark") },
        kit.text { text = t("%I"), width = W - 26, height = dh, horizontal_alignment = "center",
          font_size = digits, font_weight = 300, color = kit.ink("hi") },
        L.item { width = 60, height = 10,
          kit.decor("ticks", { x = 0, y = 2, length = 60, count = 6, major = 3, size = 6, color = kit.stroke("mark") }) },
        kit.text { text = t("%M"), width = W - 26, height = dh, horizontal_alignment = "center",
          font_size = digits, font_weight = 300, color = kit.ink("accent") },
        line { text = kit.code("min", "MIN"), font_size = S.micro, color = kit.stroke("mark") },
        ui.Item { width = 1, height = 6 },
        line { text = t("%p"), font_size = S.body, color = kit.ink("accent") },
        ui.Item { width = 1, height = 6 },
        line { text = t("%a"), color = kit.ink("hi") },
        line { text = t("%b %d") },
        ui.Item { width = 1, height = 4 },
        line { text = t("Week %V"), font_size = S.micro, color = kit.stroke("mark") },
        ui.Item { width = 1, height = 3 },
        kit.meter { width = 70, height = 4, count = 12,
          value = function() return (tonumber(model.clock("%j")) or 0) / 365 end },
      },
    }
  end

  -- ----------------------------------------------------------- calendar --
  function K.calendar()
    local W = 380
    local CELL_W = 50
    local month = model.calendar
    local head_y = TOP
    local names_y = head_y + 30
    local grid_y = names_y + L.lh(S.label) + 2
    local CELL_H = math.floor((ROW2 - grid_y - 10 - L.lh(S.micro)) / 6)
    local cells = {}
    for i = 1, 42 do
      local function day() return month().days[i] end
      local mark = math.min(CELL_W - 10, CELL_H - 2)
      cells[#cells + 1] = ui.Item {
        width = CELL_W, height = CELL_H,
        -- Today's mark blooms in each time the dashboard opens.
        kit.shape { anchors = { center_in = true }, width = mark, height = mark,
          shape = function() return opened:get() and "cookie9" or "circle" end, duration = 700,
          color = function() return kit.signal("accent")():alpha(.3) end, visible = function() return day().today end },
        kit.text { anchors = { center_in = true }, font_size = theme.size.normal - 2,
          text = function() return tostring(day().day) end,
          color = function()
            local d = day()
            if d.today then return kit.ink("accent")() end
            if not d.current then return kit.stroke("mark")() end
            if d.weekend then return kit.signal("info")() end
            return kit.ink("hi")()
          end },
      }
    end
    local names = {}
    for i, n in ipairs { "Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat" } do
      names[#names + 1] = ui.Item { width = CELL_W, height = L.lh(S.label),
        L.label { width = CELL_W, horizontal_alignment = "center", text = n,
          color = (i == 1 or i == 7) and kit.signal("info") or kit.ink("lo") } }
    end
    local function arrow(icon, delta, id)
      return kit.hover(kit.action {
        id = id, width = 28, height = 26, cursor = "pointer",
        accessible_name = delta < 0 and "Previous month" or "Next month",
        on_clicked = function() model.shift_month(delta) end,
        kit.icon(icon, 20, kit.ink("accent"), { anchors = { center_in = true } }),
      }, function(hovered) return hovered and kit.signal("accent")():alpha(.15) or kit.signal("accent")():alpha(0) end, 13)
    end
    return L.card {
      id = "dashboard-calendar", width = W, height = ROW2, header = false,
      ui.MouseArea { anchors = { fill = true }, z = -1,
        on_wheel = function(_, _, _, _, _, step_y)
          if step_y ~= 0 then model.shift_month(step_y > 0 and 1 or -1) end
        end },
      strip(W, "Calendar", "cal"),
      ui.Item { x = 15, y = head_y, width = W - 30, height = 26,
        arrow("chevron_left", -1, "calendar-previous"),
        L.heading { scope = "dashboard.overview", level = "section", id = "calendar-title",
          anchors = { center_in = true }, font_size = theme.size.larger, text = function() return month().title end },
        ui.Item { anchors = { right = true }, width = 28, height = 26, arrow("chevron_right", 1, "calendar-next") },
      },
      ui.Row { x = 15, y = names_y, gap = 0, table.unpack(names) },
      L.item { x = 15, y = grid_y, width = 7 * CELL_W, height = 6 * CELL_H,
        kit.decor("grid", { width = 7 * CELL_W, height = 6 * CELL_H, columns = 7, rows = 6, color = kit.stroke("faint") }),
        ui.Grid { columns = 7, gap = 0, table.unpack(cells) },
      },
      L.code("calx", "SEGMENT ###/##  ·  CP-##", { x = 15, y = ROW2 - 6 - L.lh(S.micro), width = W - 30 }),
    }
  end

  -- ---------------------------------------------------------- resources --
  function K.resources()
    local W = 113
    local size = math.min(W - 24, math.floor((ROW2 - TOP - 8 - 2 * 4) / 3))
    local function ring(label, value, id)
      return kit.ring { id = id, size = size, value = function() return (value() or 0) / 100 end, label = label,
        color = kit.level(value), sweep = 280, text_size = theme.size.normal + 1 }
    end
    return kit.card {
      id = "dashboard-resources", width = W, height = ROW2,
      strip(W, "System", "res"),
      ui.Column { anchors = { horizontal_center = true }, y = TOP, gap = 4,
        ring("CPU", model.cpu, "ring-cpu"),
        ring("Mem", model.memory, "ring-memory"),
        ring("Disk", model.storage, "ring-storage"),
      },
    }
  end

  -- -------------------------------------------------------------- media --
  function K.media()
    local W = 200
    local IW = W - 28
    local active = model.player
    local function field(name, fallback)
      return function()
        local v = active()[name]
        if type(v) == "table" then v = table.concat(v, ", ") end
        return (v and v ~= "") and v or fallback
      end
    end
    -- Followed only while the dashboard is open: shut, the position
    -- ticking every second would repaint every output for nothing.
    local progress = (function()
      local last = 0
      return function()
        if not opened:get() then return last end
        local a = active()
        if not a.length or a.length <= 0 then last = 0 return 0 end
        last = math.min(1, (a.position or 0) / a.length)
        return last
      end
    end)()
    local function button(icon, action, id, wide)
      return kit.hover(kit.action {
        id = id, width = wide and 64 or 44, height = 34, cursor = "pointer",
        accessible_name = ({ previous = "Previous track", next = "Next track", play_pause = "Play or pause" })[action],
        on_clicked = function() model.media_control(action) end,
        kit.icon(icon, 20, kit.ink("accent"), { anchors = { center_in = true } }),
      }, function(hovered) return hovered and kit.signal("accent")():alpha(.16) or kit.signal("accent")():alpha(.06) end, 17)
    end
    local CS = 150
    local cover = L.item { width = CS, height = CS,
      kit.shape { x = 6, y = 6, width = CS - 12, height = CS - 12, shape = "cookie12", color = kit.stroke("faint") },
      kit.icon("art_track", 56, kit.ink("lo"), {
        anchors = { center_in = true }, visible = function() return model.artwork() == "" end }),
      ui.Image { id = "media-cover", x = 6, y = 6, width = CS - 12, height = CS - 12, fill_mode = "preserve_aspect_crop",
        source = function() return model.artwork() end, visible = function() return model.artwork() ~= "" end,
        mask = ui.Path { view_box = { 0, 0, 100, 100 }, d = kit.shape_path("cookie12"), fill_color = "#ffffff" } },
      kit.decor("brackets", { width = CS, height = CS, length = 14, color = kit.stroke("hot") }),
    }
    local function line(props)
      props.width, props.horizontal_alignment, props.elide = IW, "center", "right"
      return L.label(props)
    end
    local status_h = 36
    local P_term = L.term
    local function media_state()
      local a = active()
      if a.playing then return "playing" end
      return (a.title and a.title ~= "") and "paused" or "idle"
    end
    return kit.card {
      id = "dashboard-media", width = W, height = ROW1 + GAP + ROW2,
      strip(W, "Media", "aud"),
      ui.Column { anchors = { horizontal_center = true }, y = TOP + 2, gap = 6, align = "center",
        cover,
        kit.meter { width = CS, height = 4, count = 25, value = progress },
        ui.Item { width = 1, height = 2 },
        kit.text { id = "media-title", width = IW, height = L.lh(theme.size.normal), horizontal_alignment = "center",
          elide = "right", text = field("title", "Nothing playing"), font_size = theme.size.normal, color = kit.ink("accent") },
        line { text = field("album", "") },
        line { text = field("artist", ""), color = kit.ink("hi") },
        ui.Item { width = 1, height = 2 },
        ui.Row { gap = 6, align = "center",
          button("skip_previous", "previous", "media-previous"),
          button(function() return active().playing and "pause" or "play_arrow" end, "play_pause", "media-play", true),
          button("skip_next", "next", "media-next"),
        },
        L.item { width = IW, height = 8 + L.lh(S.micro),
          kit.decor("ticks", { width = IW, length = IW, count = 34, major = 5, size = 6, color = kit.stroke("idle") }),
          L.label { y = 8, width = IW - 40, font_size = S.micro, color = kit.ink("hi"), text = function()
              local a = active()
              local function mmss(s) s = math.floor(tonumber(s) or 0) return ("%02d:%02d"):format(s // 60, s % 60) end
              return opened:get() and a.length and a.length > 0 and (mmss(a.position) .. " / " .. mmss(a.length))
                or "--:-- / --:--"
            end },
          L.code("feed", "CH ##", { anchors = { right = true }, y = 8, width = 40, horizontal_alignment = "right" }),
        },
        L.status { width = IW, height = status_h,
          kind = function() return active().playing and "ok" or "info" end,
          title = P_term(function() return "media." .. media_state() end,
            function() return ({ playing = "Playing", paused = "Paused", idle = "Idle" })[media_state()] end),
          subtitle = function()
            local a = active()
            local who = a.identity or a.name
            if a.playing or (a.title and a.title ~= "") then return (who and who ~= "") and who or "Player" end
            return "Nothing to play"
          end },
      },
    }
  end

  return K
end
