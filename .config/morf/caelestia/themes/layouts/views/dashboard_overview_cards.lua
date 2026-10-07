-- The overview tab's cards: weather, the user, the clock, the calendar,
-- the resource rings and the player, each a tile of the page template
-- (themes/layouts/page.lua: a caption over one card) drawn through the
-- kit. Data and actions come from the dashboard model; the ids the tests
-- and the shell rely on are kept.
--
-- `K.page(W)` lays the tiles out for a page `W` wide (the dashboard's,
-- the same for every tab): on a desk two rows beside the player, filling
-- the dashboard's height; on a phone one column, a tile (or two side by
-- side) a row.
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")
local P = require("themes.layouts.page")
local responsive = require("responsive")

local S = L.SIZE

return function(model, ROW1, ROW2, GAP)
  local opened = model.opened
  local K = {}

  -- ------------------------------------------------------------ weather --
  -- Each card takes the width and height of its tile, caption included.
  function K.weather(w, h)
    local W, H = w or 275, h or ROW1
    local iw, ih = P.tile_inner(W, H)
    local function now()
      if not opened:get() then return { available = false } end
      return model.weather()
    end
    local box = math.min(64, ih)
    local big = theme.size.extra + 8
    local big_h = math.ceil(big * 1.2)
    local tx = box + 16
    local tw = iw - tx
    return P.tile {
      id = "dashboard-weather", title = "Weather", width = W, height = H, clip = true,
      L.item { y = math.floor((ih - box) / 2), width = box, height = box,
        kit.decor("brackets", { width = box, height = box, length = 8 }),
        kit.icon(function()
          local w = now()
          return w.available and model.weather_symbol(w.code, w.is_day) or "cloud"
        end, math.floor(box * 0.62), kit.signal("accent"), {
          anchors = { center_in = true }, visible = function() return now().available end }),
        kit.loading(math.floor(box * 0.56), kit.signal("accent"), {
          id = "dashboard-weather-loading", anchors = { center_in = true },
          active = function() return opened:get() and not now().available end,
          visible = function() return not now().available end }),
      },
      ui.Column { x = tx, anchors = { vertical_center = true }, gap = 2,
        kit.text { id = "dashboard-temperature", width = tw, height = big_h,
          font_size = big, font_weight = 300, color = kit.ink("accent"), elide = "right",
          text = function()
            local w = now()
            if not w.available then return "--" end
            return ("%d%s"):format(math.floor((w.temperature or 0) + 0.5), w.units and w.units.temperature or "°")
          end },
        L.label { width = tw, elide = "right", font_size = S.body, color = kit.ink("hi"),
          text = function() local w = now() return w.available and (w.condition or "") or "No weather" end },
        L.item { width = tw, height = 8,
          kit.decor("ticks", { y = 1, length = tw, count = 24, major = 6, size = 6, color = kit.stroke("idle") }) },
        L.label { width = tw, elide = "right",
          text = function()
            local w = now()
            if not w.available then return "Loading…" end
            return ("Humidity %s  ·  Wind %s"):format(w.humidity and math.floor(w.humidity + .5) .. "%" or "--",
              w.wind_speed and ("%.0f"):format(w.wind_speed) or "--")
          end },
      },
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

  function K.user(w, h)
    local W, H = w or 340, h or ROW1
    local iw, ih = P.tile_inner(W, H)
    local face = model.face
    local has_face = face ~= ""
    local AV = math.min(84, ih - 8)
    local X = AV + 20
    local RW = iw - X
    local function system() return opened:get() and model.system() or { uptime = 0 } end
    local name_size = theme.size.large
    local up_size = theme.size.normal
    local code_w = 84
    local CHIP = 82
    return P.tile {
      id = "dashboard-user", title = "User", width = W, height = H, clip = true,
      L.item { x = 4, y = math.floor((ih - AV) / 2), width = AV, height = AV,
        kit.shape { width = AV, height = AV, shape = "circle", color = kit.stroke("faint") },
        kit.icon("person", math.floor(AV * 0.48), kit.ink("lo"), { anchors = { center_in = true }, visible = not has_face, fill = true }),
        has_face and ui.Image { anchors = { fill = true }, source = face, fill_mode = "preserve_aspect_crop",
          mask = ui.Path { view_box = { 0, 0, 100, 100 }, d = kit.shape_path("circle"), fill_color = "#ffffff" } } or nil,
        kit.decor("brackets", { x = -4, y = -4, width = AV + 8, height = AV + 8, length = 10, color = kit.stroke("hot") }),
      },
      ui.Column { x = X, anchors = { vertical_center = true }, gap = 2,
        L.code("user", "UID ####", { width = RW }),
        L.item { width = RW, height = L.lh(name_size),
          kit.text { width = RW - CHIP - 8, height = L.lh(name_size), elide = "right",
            text = model.username, font_size = name_size, font_weight = 300, color = kit.ink("hi") },
          kit.chip { id = "dashboard-wm", anchors = { right = true, vertical_center = true },
            width = CHIP, text = function() return model.desktop() end },
        },
        L.item { width = RW, height = L.lh(up_size),
          kit.text { width = code_w, height = L.lh(up_size), font_size = up_size, font_weight = 300,
            color = kit.ink("accent"), text = function() return uptime_short(system().uptime) end },
          L.label { id = "dashboard-uptime", x = code_w + 4, anchors = { vertical_center = true },
            width = RW - code_w - 4, elide = "right",
            text = function()
              if not opened:get() then return "" end
              local host = system().hostname
              return (host and host ~= "") and ("up  ·  " .. host) or "up"
            end },
        },
        ui.Item { width = 1, height = 2 },
        kit.meter { width = RW, height = 4, count = 24,
          value = function() return ((tonumber(system().uptime) or 0) % 86400) / 86400 end },
        L.code("daycycle", "DAY CYCLE  ·  24 H", { width = RW }),
      },
    }
  end

  -- -------------------------------------------------------------- clock --
  function K.clock(w, h)
    local W, H = w or 111, h or ROW2
    local iw, ih = P.tile_inner(W, H)
    local function t(fmt) return function() return model.clock(fmt) end end
    -- The digits as big as the box lets them (two of them and the lines
    -- under them).
    local digits = math.max(18, math.min(theme.size.extra + 6, math.floor((ih - 120) / 2.6)))
    local dh = math.ceil(digits * 1.2)
    local CW = iw - 12
    local function line(props)
      props.width, props.horizontal_alignment, props.elide = CW, "center", "right"
      return L.label(props)
    end
    return P.tile {
      id = "dashboard-clock", title = "Clock", width = W, height = H, clip = true,
      kit.decor("ticks", { x = 0, y = 4, length = ih - 8, count = 24, major = 6, size = 6, vertical = true,
        color = kit.stroke("idle") }),
      ui.Column { x = 12, anchors = { vertical_center = true }, width = CW, gap = 0, align = "center",
        line { text = kit.code("hrs", "HRS"), font_size = S.micro, color = kit.stroke("mark") },
        kit.text { text = t("%I"), width = CW, height = dh, horizontal_alignment = "center",
          font_size = digits, font_weight = 300, color = kit.ink("hi") },
        L.item { width = 60, height = 10,
          kit.decor("ticks", { x = 0, y = 2, length = 60, count = 6, major = 3, size = 6, color = kit.stroke("mark") }) },
        kit.text { text = t("%M"), width = CW, height = dh, horizontal_alignment = "center",
          font_size = digits, font_weight = 300, color = kit.ink("accent") },
        line { text = kit.code("min", "MIN"), font_size = S.micro, color = kit.stroke("mark") },
        ui.Item { width = 1, height = 4 },
        line { text = t("%p"), font_size = S.body, color = kit.ink("accent") },
        ui.Item { width = 1, height = 4 },
        line { text = t("%a"), color = kit.ink("hi") },
        line { text = t("%b %d") },
        ui.Item { width = 1, height = 4 },
        line { text = t("Week %V"), font_size = S.micro, color = kit.stroke("mark") },
        ui.Item { width = 1, height = 3 },
        kit.meter { width = math.min(70, CW), height = 4, count = 12,
          value = function() return (tonumber(model.clock("%j")) or 0) / 365 end },
      },
    }
  end

  -- ----------------------------------------------------------- calendar --
  function K.calendar(w, h)
    local W, H = w or 380, h or ROW2
    local iw, ih = P.tile_inner(W, H)
    local CELL_W = math.floor(iw / 7)
    local GX = math.floor((iw - 7 * CELL_W) / 2)
    local month = model.calendar
    local names_y = 32
    local grid_y = names_y + L.lh(S.label) + 2
    local foot = L.lh(S.micro) + 4
    local CELL_H = math.max(14, math.floor((ih - grid_y - foot) / 6))
    local cells = {}
    for i = 1, 42 do
      local function day() return month().days[i] end
      local mark = math.max(4, math.min(CELL_W - 10, CELL_H - 2))
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
    return P.tile {
      id = "dashboard-calendar", title = "Calendar", width = W, height = H, clip = true,
      ui.MouseArea { anchors = { fill = true }, z = -1,
        on_wheel = function(_, _, _, _, _, step_y)
          if step_y ~= 0 then model.shift_month(step_y > 0 and 1 or -1) end
        end },
      ui.Item { x = GX, y = 0, width = 7 * CELL_W, height = 26,
        arrow("chevron_left", -1, "calendar-previous"),
        L.heading { scope = "dashboard.overview", level = "section", id = "calendar-title",
          anchors = { center_in = true }, font_size = theme.size.larger, text = function() return month().title end },
        ui.Item { anchors = { right = true }, width = 28, height = 26, arrow("chevron_right", 1, "calendar-next") },
      },
      ui.Row { x = GX, y = names_y, gap = 0, table.unpack(names) },
      L.item { x = GX, y = grid_y, width = 7 * CELL_W, height = 6 * CELL_H,
        kit.decor("grid", { width = 7 * CELL_W, height = 6 * CELL_H, columns = 7, rows = 6, color = kit.stroke("faint") }),
        ui.Grid { columns = 7, gap = 0, table.unpack(cells) },
      },
      L.code("calx", "SEGMENT ###/##  ·  CP-##", { x = GX, y = ih - L.lh(S.micro), width = 7 * CELL_W }),
    }
  end

  -- ---------------------------------------------------------- resources --
  function K.resources(w, h)
    local W, H = w or 113, h or ROW2
    local iw, ih = P.tile_inner(W, H)
    -- Wider than tall, the three rings stand in a row.
    local across = iw > ih
    local ring_gap = across and 16 or 6
    local size = across and math.min(math.floor((iw - 2 * ring_gap) / 3), ih)
      or math.min(iw, math.floor((ih - 2 * ring_gap) / 3))
    local function ring(label, value, id)
      return kit.ring { id = id, size = size, value = function() return (value() or 0) / 100 end, label = label,
        color = kit.level(value), sweep = 280, text_size = theme.size.normal + 1 }
    end
    return P.tile {
      id = "dashboard-resources", title = "System", width = W, height = H,
      (across and ui.Row or ui.Column) { anchors = { center_in = true }, gap = ring_gap,
        ring("CPU", model.cpu, "ring-cpu"),
        ring("Mem", model.memory, "ring-memory"),
        ring("Disk", model.storage, "ring-storage"),
      },
    }
  end

  -- -------------------------------------------------------------- media --
  function K.media(w, h)
    local W, HH = w or 200, h or (ROW1 + GAP + ROW2)
    local iw, ih = P.tile_inner(W, HH)
    -- Wide, the cover stands beside the rest rather than over it.
    local beside = iw >= 400
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
      return P.button { id = id, icon = icon, label = "", width = wide and 64 or 44, height = 34,
        on_clicked = function() model.media_control(action) end }
    end
    -- What sits under (or beside) the cover: ~250 high.
    local REST = 250
    local CS = beside and math.max(80, math.min(220, ih, iw - 260))
      or math.max(64, math.min(150, iw, ih - REST))
    local IW = beside and (iw - CS - 16) or iw
    local cover = L.item { width = CS, height = CS,
      kit.shape { x = 6, y = 6, width = CS - 12, height = CS - 12, shape = "cookie12", color = kit.stroke("faint") },
      kit.icon("art_track", math.floor(CS * 0.37), kit.ink("lo"), {
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
    local function media_state()
      local a = active()
      if a.playing then return "playing" end
      return (a.title and a.title ~= "") and "paused" or "idle"
    end
    local rest = ui.Column {
      x = beside and CS + 16 or nil, anchors = beside and { vertical_center = true } or nil,
      width = IW, gap = 6, align = "center",
      (not beside) and cover or nil,
      kit.meter { width = beside and IW or CS, height = 4, count = 25, value = progress },
      kit.text { id = "media-title", width = IW, height = L.lh(theme.size.normal), horizontal_alignment = "center",
        elide = "right", text = field("title", "Nothing playing"), font_size = theme.size.normal, color = kit.ink("accent") },
      line { text = field("album", "") },
      line { text = field("artist", ""), color = kit.ink("hi") },
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
      L.status { width = IW, height = 36,
        kind = function() return active().playing and "ok" or "info" end,
        title = L.term(function() return "media." .. media_state() end,
          function() return ({ playing = "Playing", paused = "Paused", idle = "Idle" })[media_state()] end),
        subtitle = function()
          local a = active()
          local who = a.identity or a.name
          if a.playing or (a.title and a.title ~= "") then return (who and who ~= "") and who or "Player" end
          return "Nothing to play"
        end },
    }
    -- Stacked, the whole of it centred in the card.
    local body = beside and ui.Item { width = iw, height = ih,
      ui.Item { anchors = { vertical_center = true }, width = CS, height = CS, cover }, rest }
      or ui.Item { width = iw, height = ih, ui.Item { anchors = { center_in = true },
        width = IW, height = function() return rest.layout_height or 0 end, rest } }
    return P.tile { id = "dashboard-media", title = "Media", width = W, height = HH, clip = true, body }
  end

  -- --------------------------------------------------------------- page --

  --- The overview for a page `W` wide: the node and its height.
  function K.page(W)
    local G = P.GAP
    if responsive.compact() then
      local ROW, TALL = 150, 330
      -- (Wide enough, the player's cover stands beside the rest.)
      local MEDIA = W - 2 * P.PAD >= 400 and 300 or 470
      local side, cal = P.cols(W, 2, { 1, 2.4 })
      local rings = 190
      local node = ui.Column { width = W, gap = G,
        K.user(W, ROW),
        K.weather(W, ROW),
        ui.Row { gap = G, K.clock(side, TALL), K.calendar(cal, TALL) },
        K.resources(W, rings),
        K.media(W, MEDIA),
      }
      return node, 2 * ROW + TALL + rings + MEDIA + 4 * G
    end
    -- A desk: the player down the right, the rest in two rows filling
    -- the dashboard's height.
    local _, VH = responsive.dashboard("overview")
    local H = math.max(VH, 440)
    local main, media = P.cols(W, 2, { 3, 1 })
    local top = math.max(140, math.floor((H - G) * 0.36))
    local bottom = H - G - top
    local wx, us = P.cols(main, 2, { 4, 5 })
    local ck, cal, res = P.cols(main, 3, { 1, 3, 1.15 })
    local node = ui.Row { width = W, height = H, gap = G,
      ui.Column { width = main, gap = G,
        ui.Row { gap = G, K.weather(wx, top), K.user(us, top) },
        ui.Row { gap = G, K.clock(ck, bottom), K.calendar(cal, bottom), K.resources(res, bottom) },
      },
      K.media(media, H),
    }
    return node, H
  end

  return K
end
