-- The dashboard's Media tab: the player as a console.
--
--   left    the cover inside the theme's ring, whose arc is the track's
--           position; the position and length under it and the player selector
--   middle  the title, artist and album over the spectrum (56 bands, one
--           path); the level monitor (a mirrored level history swept left
--           to right with a cursor); the position band with its seek; the
--           transport (previous, the position large, next, play, shuffle
--           and repeat, the length)
--   right   the lyrics as a list (the current line the lit row), the
--           frequency band readouts and the player's volume as a ring over
--           a slider
--
-- With nothing playing the middle and right give way to one framed empty
-- state: the status centred over a still silhouette of the spectrum.
--
-- Everything is drawn by the kit; the theme decides how each piece looks.
-- Cost: the spectrum is the only node that changes at 60 Hz. The level
-- history and the band readouts sample the bars at 8 Hz on a timer that
-- runs only while the tab is on screen and something plays. At rest and
-- paused nothing moves.

local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local P = require("themes.layouts.parts")
local common = require("themes.kit_common")
local L_term = P.term

local C = theme.color
local M = {}

M.WIDTH, M.HEIGHT = 1000, 350

local media = require("media_state")
local bars = media.bars
local lyrics = media.lyrics
local clamp01 = common.clamp01

-- Columns.
local AX, AW = 10, 244          -- cover
local BX, BW = 272, 396         -- signal console
local CX, CW = 686, 304         -- lyrics, bands, volume
local TOP = 30                  -- under the header strip

local HIST = 132                -- level-history samples (8 Hz: ~16 s)

local LABEL = P.role_size("label")
local LABEL_H = P.lh(LABEL)
local CAPTION_H = 16

function M.build(ctx)
  local active, something, playing = media.active, media.something, media.playing
  local on_screen = media.watch(ctx)
  local control = media.control
  local field = media.field
  local fraction = media.fraction(on_screen)
  local accent = kit.signal("accent")

  -- ------------------------------------------------------------ sampler --
  -- The level history and the band readouts: 8 Hz off the 60 Hz bars,
  -- only while the tab is up and the music plays.
  local history = morf.signal("caelestia.media.history", { at = 0, values = {} })
  local bands = morf.signal("caelestia.media.bands", { low = 0, high = 0, dlow = 0, dhigh = 0 })
  local ring_buf, cursor = {}, 0
  for i = 1, HIST do ring_buf[i] = 0 end
  local sampler
  local function sample()
    local b = bars:get()
    local n = #b
    local low, high, all = 0, 0, 0
    if n > 0 then
      local cut = math.max(1, n // 4)
      for i = 1, n do
        local v = b[i] or 0
        all = all + v
        if i <= cut then low = low + v elseif i > n // 2 then high = high + v end
      end
      low, high, all = low / cut, high / (n - n // 2), all / n
    end
    cursor = cursor % HIST + 1
    ring_buf[cursor] = clamp01(all * 1.6)
    local values = {}
    for i = 1, HIST do values[i] = ring_buf[i] end
    history:set({ at = cursor, values = values })
    local prev = bands:get()
    bands:set({ low = low * 100, high = high * 100, dlow = low * 100 - prev.low, dhigh = high * 100 - prev.high })
  end
  morf.effect("caelestia.media.sample", function()
    local run = on_screen() and playing()
    if run and not sampler then sampler = morf.timer(125, sample, true)
    elseif not run and sampler then sampler:cancel() sampler = nil end
  end)

  -- --------------------------------------------------------- header --
  local function state_key() return playing() and "playing" or something() and "paused" or "idle" end
  local STATE_WORD = { playing = "Playing", paused = "Paused", idle = "Idle" }
  local header = kit.header {
    x = 10, y = 2, width = M.WIDTH - 20, key = "media.signal", title = "Playback",
    status = L_term(function() return "media." .. state_key() end, function() return STATE_WORD[state_key()] end),
    color = function() return (playing() and kit.signal("ok") or kit.signal("info"))() end,
  }

  -- ------------------------------------------------------ A: the cover --
  local RS = 212                       -- the ring's box
  local RX, RY = AX + math.floor((AW - RS) / 2), TOP + CAPTION_H + 6
  local COVER = 152
  local c = RS / 2
  local art = function() return require("lib.util.remote").file(active().art_url) end
  -- The artwork sits behind the instrument, cropped to its round centre.
  local ring = ui.Item {
    id = "media-reticle", x = RX - AX, y = RY, width = RS, height = RS,
    ui.Item { id = "media-cover-aperture", x = c - COVER / 2, y = c - COVER / 2, width = COVER, height = COVER,
      mask = ui.Sdf { anchors = { fill = true },
        ui.SdfShape { shape = "circle", anchors = { fill = true } } },
      ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end },
      ui.Image { id = "media-tab-cover", anchors = { fill = true }, fill_mode = "preserve_aspect_crop",
        source = art, visible = function() return art() ~= "" end },
      kit.icon("art_track", 64, kit.ink("lo"), {
        anchors = { center_in = true }, visible = function() return art() == "" end }),
    },
    kit.ring { id = "media-ring-position", size = RS, value = function() return something() and fraction() or 0 end,
      sweep = 360, text = function() return "" end },
  }
  local FACTS_Y = RY + RS + 6
  local cover_col = ui.Item {
    id = "media-cover-column", x = AX, y = 0, width = AW, height = M.HEIGHT,
    kit.caption { y = TOP, width = AW, text = "Player", note = kit.code("media.cover", "###/##-##") },
    P.decor_box("brackets", { x = RX - AX - 6, y = RY - 4, width = RS + 12, height = RS + 8, length = 8,
      color = kit.stroke("idle") }),
    ring,
    ui.Item { y = FACTS_Y, width = AW, height = 2 * 17,
      kit.facts({
        { "Position", function() return media.duration(active().position) end },
        { "Length", function() return media.duration(active().length) end },
      }, AW, 17),
    },
  }

  -- --------------------------------------------------- player selector --
  local players_open = morf.signal("caelestia.media.players_open", false)
  local players = media.players
  local function player_name(p)
    if not p then return "" end
    return (p.identity and p.identity ~= "") and p.identity or (p.name or "")
  end
  local ROW_H = math.max(22, P.lh(theme.size.small))
  local SY, SH = 312, 26
  -- The player selector is a kit combo box (lib.kit.composites): a press,
  -- Space, Return or Alt+Down opens the players over it, the arrows and
  -- Return or a press choose, Escape closes. The chevron beside it opens
  -- it too.
  local combo
  local more_area = P.icon_button {
    area = ctx.area, id = "media-player-more", x = AX + AW - SH, y = SY, width = SH, height = SH, size = 18,
    name = "Choose a player",
    icon = function() return players_open:get() and "expand_less" or "expand_more" end,
    on_clicked = function() if combo then combo.toggle() end end,
  }
  local function player_items()
    local out = {}
    for i, p in ipairs(players()) do out[i] = { label = player_name(p), name = p.name } end
    return out
  end
  local select_area
  select_area, combo = require("lib.kit.composites").combo_box {
    id = "media-player", x = AX, y = SY, width = AW - SH - 4, height = SH, variant = "select",
    icon = "video_library", text_size = theme.size.small, item_height = ROW_H, list_width = AW,
    placement = "top-start", except = { more_area }, visible_items = 5,
    item_id = function(i) return "media-player-" .. i end,
    accessible_name = "Player",
    items = player_items,
    current = function()
      local name = active().name
      for i, p in ipairs(players()) do if p.name == name then return i end end
      return 0
    end,
    on_changed = function(_, item) control("set_active", item.name) end,
    header = function()
      return kit.caption { width = AW - 12, text = "Players", note = kit.code("media.players", "BRIDGE - A") }
    end,
    on_opened = function() players_open:set(true) end,
    on_closed = function() players_open:set(false) end,
  }
  kit.hover(select_area, function(hovered) return accent():alpha(hovered and .18 or .08) end, P.control_round(SH))

  -- ----------------------------------------------- nothing playing --
  -- One framed region over the middle and right columns: the status
  -- centred, over a still silhouette of the spectrum (a fixed curve, one
  -- path; nothing moves) on the theme's grid.
  local EMB = 52
  local NW, NH = M.WIDTH - BX - 10, M.HEIGHT - TOP - 4
  local SIL_H = 86
  local SIL_W = NW - 64
  local silhouette = {}
  for i = 1, 56 do
    local t = (i - 1) / 55
    silhouette[i] = .1 + .5 * math.exp(-((t - .22) / .16) ^ 2) + .32 * math.exp(-((t - .62) / .2) ^ 2)
      + .05 * math.sin(i * 1.7) ^ 2
  end
  local TEXT_W = NW - 80
  local STACK_H = EMB + 12 + P.heading_h(theme.size.extra) + 4 + LABEL_H
  local STACK_Y = math.max(16, math.floor((NH - SIL_H - 24 - STACK_H) / 2))
  local nothing = ui.Item {
    id = "media-nothing",
    x = BX, y = TOP, width = NW, height = NH,
    visible = function() return not something() end,
    kit.panel { width = NW, height = NH },
    kit.emblem { kind = "info", x = math.floor((NW - EMB) / 2), y = STACK_Y, size = EMB },
    kit.heading { id = "media-empty-title", x = 40, y = STACK_Y + EMB + 12, width = TEXT_W,
      height = P.heading_h(theme.size.extra), level = "title", horizontal_alignment = "center",
      font_size = theme.size.extra, text = "Nothing playing", active = on_screen,
      visible = function() return not something() end },
    kit.label { x = 40, y = STACK_Y + EMB + 12 + P.heading_h(theme.size.extra) + 4, width = TEXT_W,
      horizontal_alignment = "center", elide = "right",
      text = "Play something and it shows up here" },
    ui.Item { x = 32, y = NH - SIL_H - 20, width = SIL_W, height = SIL_H,
      P.decor_box("grid", { width = SIL_W, height = SIL_H, columns = 14, rows = 3, color = kit.stroke("faint") }),
      kit.spectrum { width = SIL_W, height = SIL_H, values = silhouette, gap = 3,
        color = function() return accent():alpha(.22) end },
    },
    P.decor_box("ticks", { x = 32, y = NH - 16, length = SIL_W, count = 28, major = 4, size = 5, flip = true }),
  }

  -- ----------------------------------------------- B: signal console --
  local TITLE_SIZE = theme.size.large
  local TITLE_Y = TOP + CAPTION_H + 2
  local TITLE_H = P.lh(TITLE_SIZE)
  local META_Y = TITLE_Y + TITLE_H
  local META_H = P.lh(theme.size.small)

  -- The spectrum: one path of bars over the theme's grid, its scale at
  -- the right and a ruler under it.
  local SPY = META_Y + META_H + 6
  local SPW, SPH = BW - 34, 56
  local spectrum = ui.Item {
    id = "media-visualiser", x = BX, y = SPY, width = BW, height = SPH + 8,
    P.decor_box("grid", { width = SPW, height = SPH, columns = 8, rows = 4, color = kit.stroke("faint") }),
    kit.spectrum { id = "media-spectrum", width = SPW, height = SPH, channel = bars,
      color = accent, gap = 2 },
    P.decor_box("scale", { x = SPW + 4, y = 0, height = SPH, count = 12, major = 6, size = 6, flip = true,
      color = kit.stroke("idle") }),
    P.decor_box("ticks", { y = SPH + 2, length = SPW, count = 28, major = 4, size = 5, flip = true }),
  }

  -- The level monitor: a mirrored strip of the level history, swept from
  -- left to right; the cursor marks the newest sample.
  local LMY = SPY + SPH + 10
  local LMW, LMH = BW, 24
  local level = ui.Item {
    id = "media-level-monitor", x = BX, y = LMY, width = LMW, height = CAPTION_H + 2 + LMH,
    kit.caption { width = LMW, text = "Level", note = kit.code("media.lm", "BUF ##/##") },
    ui.Item { y = CAPTION_H + 2, width = LMW, height = LMH,
      kit.spectrum { id = "media-level-history", width = LMW, height = LMH, mirror = true, gap = 1,
        values = function() return history:get().values end, color = kit.signal("ok") },
      kit.surface { id = "media-level-cursor", y = -2, width = 1, height = LMH + 4, color = kit.ink("hi"),
        x = function() return history:get().at / HIST * LMW end,
        visible = function() return history:get().at > 0 end },
    },
  }

  -- The position: the theme's skin of the kit's seek bar.
  local PCY = LMY + CAPTION_H + 2 + LMH + 6
  local PCW, PCH = BW, 34
  local position_chart = ui.Item {
    x = BX, y = PCY, width = PCW, height = CAPTION_H + PCH,
    kit.caption { width = PCW, text = "Position",
      note = function()
        local a = active()
        if not a.length or a.length <= 0 then return "" end
        return "−" .. media.duration(math.max(0, a.length - (a.position or 0)))
      end },
    ui.Item { id = "media-progress", y = CAPTION_H, width = PCW, height = PCH,
      kit.media_progress { id = "media-seek", width = PCW, value = fraction, seek = media.seek,
        active = on_screen, playing = playing },
    },
  }

  -- Transport: previous, the position large, next, play, shuffle, repeat
  -- and the length.
  local TY = PCY + CAPTION_H + PCH + 8
  local TH = 40
  local LOOPS = { none = "playlist", playlist = "track", track = "none" }
  local POS_SIZE = theme.size.extra
  local transport = ui.Row {
    id = "media-controls", x = BX, y = TY, height = TH, gap = 4, align = "center",
    P.icon_button { area = ctx.area, id = "media-tab-previous", width = 36, height = 36, icon = "skip_previous",
      on_clicked = function() control("previous") end },
    kit.text { id = "media-position", width = 92, horizontal_alignment = "center", height = P.lh(POS_SIZE),
      vertical_alignment = "center",
      text = function() return media.duration(active().position) end,
      font_size = POS_SIZE, font_weight = 300, color = accent },
    P.icon_button { area = ctx.area, id = "media-tab-next", width = 36, height = 36, icon = "skip_next",
      on_clicked = function() control("next") end },
    ui.Item { width = 4, height = 1 },
    P.icon_button { area = ctx.area, id = "media-tab-play", width = 64, height = 36, strong = true, size = 24,
      icon = function() return playing() and "pause" or "play_arrow" end,
      on_clicked = function() control("play_pause") end },
    ui.Item { width = 4, height = 1 },
    P.icon_button { area = ctx.area, id = "media-shuffle", width = 36, height = 36, icon = "shuffle", size = 20,
      on_clicked = function() control("set_shuffle", not active().shuffle) end,
      on = function() return active().shuffle end, ignored = function() return active().ignores_shuffle end },
    P.icon_button { area = ctx.area, id = "media-repeat", width = 36, height = 36, size = 20,
      icon = function() return active().loop == "track" and "repeat_one" or "repeat" end,
      on_clicked = function() control("set_loop", LOOPS[active().loop or "none"] or "none") end,
      on = function() return (active().loop or "none") ~= "none" end,
      ignored = function() return active().ignores_loop end },
    ui.Item { width = 4, height = 1 },
    kit.text { id = "media-length", width = 52, horizontal_alignment = "right", elide = "left",
      text = function() return media.duration(active().length) end, font_size = theme.size.small,
      color = kit.ink("lo") },
  }

  local track = ui.Item {
    id = "media-track",
    width = M.WIDTH, height = M.HEIGHT,
    visible = something,
    kit.caption { x = BX, y = TOP, width = BW, text = "Now playing",
      note = kit.code("media.track", "EXT. ##-###") },
    kit.heading { id = "media-tab-title", x = BX, y = TITLE_Y, width = BW, height = TITLE_H, elide = "right",
      level = "title", text = field("title"), font_size = TITLE_SIZE, active = on_screen },
    ui.Row { x = BX, y = META_Y, height = META_H, gap = 8, align = "center",
      kit.text { id = "media-tab-artist", width = math.floor(BW * .55) - 8, elide = "right", text = field("artist"),
        font_size = theme.size.small, color = accent },
      kit.text { id = "media-tab-album", width = math.floor(BW * .45), elide = "right", text = field("album"),
        font_size = theme.size.small, color = kit.ink("lo") },
    },
    spectrum,
    level,
    position_chart,
    transport,
  }

  -- ------------------------------------------------- C: lyrics + bands --
  local function lyrics_status()
    local f = lyrics()
    return f and f.status:get() or "none"
  end
  local LROW = math.max(20, P.lh(theme.size.small))
  local LY = TOP + CAPTION_H + 6
  local function lyric_row(offset)
    local now = offset == 0
    return ui.Item {
      width = CW, height = LROW,
      kit.surface { anchors = { fill = true }, radius = P.control_round(LROW),
        color = function() return now and accent():alpha(.18) or accent():alpha(0) end },
      kit.text { x = 8, anchors = { vertical_center = true }, width = CW - 8 - 56, elide = "right",
        text = function()
          local f = lyrics()
          if not f then return "" end
          local line = f.lines:get()[f.index:get() + offset]
          return line and line.text or ""
        end,
        font_size = theme.size.small, font_weight = now and 500 or 400,
        color = function() return now and kit.ink("hi")() or kit.ink("lo")() end,
        opacity = now and 1 or (math.abs(offset) == 1 and .8 or .5) },
      kit.label { anchors = { right = true, right_margin = 6 }, y = math.floor((LROW - LABEL_H) / 2), width = 44,
        horizontal_alignment = "right", text = kit.code("lyric" .. offset, "L##.#") },
    }
  end
  local LIST_H = 5 * LROW + 4
  local function searching() return lyrics_status() == "searching" end
  local band = function(key) return function() return bands:get()[key] end end
  local READ = math.floor(P.role_size("hero") * .72)
  local function band_readout(label, y, key, dkey)
    return ui.Item { y = y, width = 150, height = 44,
      kit.label { text = label, color = kit.ink("hi") },
      ui.Row { y = LABEL_H - 2, gap = 6, align = "center",
        kit.readout { value = function() return ("%.0f"):format(band(key)()) end, size = READ,
          color = kit.signal("info") },
        kit.icon(function() return band(dkey)() >= 0 and "arrow_drop_up" or "arrow_drop_down" end, 20,
          kit.signal("info")),
      },
    }
  end
  local vol = function() return clamp01(active().volume or 0) end
  local BANDS_Y = LY + LIST_H + 6
  local RING = 100
  local VOL_Y = BANDS_Y + CAPTION_H + 4 + RING + 6
  local side = ui.Item {
    id = "media-lyrics",
    x = CX, width = CW, height = M.HEIGHT,
    visible = something,
    kit.heading { id = "media-lyrics-title", x = 0, y = TOP - 2, width = CW - 40, level = "caption",
      active = on_screen, text = function()
        local s = lyrics_status()
        return s == "synced" and "Lyrics · synced" or s == "plain" and "Lyrics · plain" or "Lyrics"
      end },
    P.icon_button { area = ctx.area, id = "media-lyrics-menu", x = CW - 30, y = TOP - 4, width = 30, height = 22,
      size = 18, icon = "more_vert" },
    P.rule { y = LY - 4, width = CW },
    ui.Column {
      x = 0, y = LY, gap = 1,
      visible = function() local s = lyrics_status() return s == "synced" or s == "plain" end,
      lyric_row(-2), lyric_row(-1), lyric_row(0), lyric_row(1), lyric_row(2),
    },
    ui.Item {
      id = "media-no-lyrics", x = 0, y = LY, width = CW, height = LIST_H,
      visible = function() local s = lyrics_status() return s ~= "synced" and s ~= "plain" end,
      kit.panel { width = CW, height = LIST_H },
      kit.status { x = 12, y = math.floor((LIST_H - 40) / 2), width = CW - 72, size = 40,
        kind = function() return searching() and "info" or "warn" end,
        title = function() return searching() and "Searching" or "No lyrics" end,
        subtitle = function() return searching() and "Looking for lyrics" or "No match found" end },
      kit.loading(36, accent, {
        id = "media-lyrics-loading", x = CW - 50, y = math.floor((LIST_H - 36) / 2),
        active = function() return ctx.opened() and searching() end,
        visible = searching,
      }),
    },
    kit.caption { y = BANDS_Y, width = CW, text = "Frequency bands", note = kit.code("media.band", "EXT. S - ##") },
    band_readout("Low", BANDS_Y + CAPTION_H + 6, "low", "dlow"),
    band_readout("High", BANDS_Y + CAPTION_H + 6 + 50, "high", "dhigh"),
    P.rule { x = 156, y = BANDS_Y + CAPTION_H + 6, height = RING, strength = "faint" , width = 1},
    kit.ring { x = CW - RING - 16, y = BANDS_Y + CAPTION_H + 4, size = RING, value = vol,
      text = function() return ("%d"):format(math.floor(vol() * 100 + .5)) end, label = "Volume" },
    ui.Row { id = "media-volume", x = 0, y = VOL_Y, gap = 8, align = "center",
      kit.icon(function()
        local v = vol()
        return v <= 0 and "volume_off" or v < 0.5 and "volume_down" or "volume_up"
      end, 18, kit.ink("lo")),
      kit.slider {
        id = "media-volume-slider", width = CW - 26, height = 22, value = vol,
        set = function(v) control("set_volume", clamp01(v)) end,
      },
    },
  }

  return ui.Item {
    id = "dashboard-media-tab",
    width = M.WIDTH, height = M.HEIGHT,
    header,
    cover_col,
    nothing,
    track,
    side,
    select_area,
    more_area,
  }
end

-- Built as the module loads, with its own instruction budget.
M.page = M.build(require("dashboard_state").context(2))

return M
