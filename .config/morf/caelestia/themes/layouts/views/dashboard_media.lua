-- The dashboard's Media tab: the player as a console, in the page
-- template's tiles (themes/layouts/page.lua) -- each a caption over one
-- card, the page the dashboard's one size (responsive.dashboard):
--
--   Player       the cover inside the theme's ring, whose arc is the
--                track's position; the position and length under it and
--                the player selector at its foot
--   Now playing  the title, artist and album over the spectrum (56 bands,
--                one path); the level monitor (a mirrored level history
--                swept left to right with a cursor); the position band with
--                its seek; the transport
--   Lyrics       the lyrics as a list, the current line the lit row
--   Signal       the frequency band readouts and the player's volume as a
--                ring over a slider
--
-- On a desk the tiles stand in three columns the page's height (Lyrics over
-- Signal in the third); on a phone one under the other, the page's width.
-- With nothing playing one tile over Now playing, Lyrics and Signal's place
-- says so: the status centred over a still silhouette of the spectrum.
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
local T = require("themes.layouts.page")
local common = require("themes.kit_common")
local L_term = P.term

local C = theme.color
local M = {}

local media = require("media_state")
local bars = media.bars
local lyrics = media.lyrics
local clamp01 = common.clamp01

local responsive = require("responsive")
local COMPACT = responsive.compact()
local W, VIEW_H = responsive.dashboard("media")
M.WIDTH = W

local GAP, PAD, CAP = T.GAP, T.PAD, T.CAPTION_H
local CAPTION_H = 16            -- a caption inside a tile (kit.caption)
local HIST = 132                -- level-history samples (8 Hz: ~16 s)
local LABEL = P.role_size("label")
local LABEL_H = P.lh(LABEL)
local LROW = math.max(20, P.lh(theme.size.small))
local RING = 100                -- the volume ring
local SEL_H = 26                -- the player selector
local FACTS_H = 34              -- position and length
-- The Signal tile: the band readouts beside the volume ring, the slider
-- under them.
local SIG_H = CAP + 2 * PAD + RING + 8 + 22

-- --------------------------------------------------------------- tiles --
-- Where each tile stands: { x, y, w, h }. Nothing playing takes the place
-- of Now playing, Lyrics and Signal together.
local TILE = {}
if COMPACT then
  local A_H = CAP + 2 * PAD + 212 + 16 + FACTS_H + 10 + SEL_H
  local B_H = CAP + 2 * PAD + 290
  local L_H = CAP + 2 * PAD + 5 * LROW + 8
  local y = 0
  TILE.player = { 0, y, W, A_H } y = y + A_H + GAP
  TILE.track = { 0, y, W, B_H } y = y + B_H + GAP
  TILE.lyrics = { 0, y, W, L_H } y = y + L_H + GAP
  TILE.signal = { 0, y, W, SIG_H } y = y + SIG_H
  TILE.nothing = { 0, TILE.track[2], W, y - TILE.track[2] }
  M.HEIGHT = y
else
  local H = math.max(400, VIEW_H)
  local AW, BW, CW = T.cols(W, 3, { 1, 1.45, 1.1 })
  local BX, CX = AW + GAP, AW + GAP + BW + GAP
  TILE.player = { 0, 0, AW, H }
  TILE.track = { BX, 0, BW, H }
  TILE.lyrics = { CX, 0, CW, H - SIG_H - GAP }
  TILE.signal = { CX, H - SIG_H, CW, SIG_H }
  TILE.nothing = { BX, 0, BW + GAP + CW, H }
  M.HEIGHT = H
end
--- A tile's inner box (the card less its padding, under the caption).
local function inner(key) local t = TILE[key] return T.tile_inner(t[3], t[4]) end
--- Where a tile's inner box starts on the page.
local function origin(key) local t = TILE[key] return t[1] + PAD, t[2] + CAP + PAD end
--- The tile `key` on the page: `spec` as P.tile's, placed.
local function place(key, spec)
  local t = TILE[key]
  spec.width, spec.height = t[3], t[4]
  return ui.Item { x = t[1], y = t[2], width = t[3], height = t[4], visible = spec.visible, T.tile(spec) }
end

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

  local function state_key() return playing() and "playing" or something() and "paused" or "idle" end
  local STATE_WORD = { playing = "Playing", paused = "Paused", idle = "Idle" }
  local state_note = L_term(function() return "media." .. state_key() end, function() return STATE_WORD[state_key()] end)

  -- ----------------------------------------------------- Player: the cover --
  local AW, AH = inner("player")
  local RS = math.floor(math.max(120, math.min(260, AW - 12, AH - FACTS_H - SEL_H - 34)))
  local COVER = math.floor(RS * .72)
  local c = RS / 2
  -- The ring, its facts under it, centred in what the selector leaves.
  local GROUP_H = RS + 8 + 8 + FACTS_H
  local GY = math.max(0, math.floor((AH - SEL_H - 10 - GROUP_H) / 2))
  local RX, RY = math.floor((AW - RS) / 2), GY + 4
  local art = function() return require("lib.util.remote").file(active().art_url) end
  -- The artwork sits behind the instrument, cropped to its round centre.
  local ring = ui.Item {
    id = "media-reticle", x = RX, y = RY, width = RS, height = RS,
    ui.Item { id = "media-cover-aperture", x = c - COVER / 2, y = c - COVER / 2, width = COVER, height = COVER,
      mask = ui.Sdf { anchors = { fill = true },
        ui.SdfShape { shape = "circle", anchors = { fill = true } } },
      ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end },
      ui.Image { id = "media-tab-cover", anchors = { fill = true }, fill_mode = "preserve_aspect_crop",
        source = art, visible = function() return art() ~= "" end },
      kit.icon("art_track", math.floor(COVER * .42), kit.ink("lo"), {
        anchors = { center_in = true }, visible = function() return art() == "" end }),
    },
    kit.ring { id = "media-ring-position", size = RS, value = function() return something() and fraction() or 0 end,
      sweep = 360, text = function() return "" end },
  }
  local player_tile = place("player", { id = "media-cover-column", title = "Player", note = state_note,
    P.decor_box("brackets", { x = RX - 6, y = RY - 4, width = RS + 12, height = RS + 8, length = 8,
      color = kit.stroke("idle") }),
    ring,
    ui.Item { y = RY + RS + 12, width = AW, height = FACTS_H,
      kit.facts({
        { "Position", function() return media.duration(active().position) end },
        { "Length", function() return media.duration(active().length) end },
      }, AW, 17),
    },
  })

  -- --------------------------------------------------- player selector --
  -- (On the page, over the Player tile's foot: its list opens over it.)
  local players_open = morf.signal("caelestia.media.players_open", false)
  local players = media.players
  local function player_name(p)
    if not p then return "" end
    return (p.identity and p.identity ~= "") and p.identity or (p.name or "")
  end
  local ROW_H = math.max(22, P.lh(theme.size.small))
  local AX0, AY0 = origin("player")
  local SX, SY = AX0, AY0 + AH - SEL_H
  -- The player selector is a kit combo box (lib.kit.composites): a press,
  -- Space, Return or Alt+Down opens the players over it, the arrows and
  -- Return or a press choose, Escape closes. The chevron beside it opens
  -- it too.
  local combo
  local more_area = P.icon_button {
    area = ctx.area, id = "media-player-more", x = SX + AW - SEL_H, y = SY, width = SEL_H, height = SEL_H, size = 18,
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
    id = "media-player", x = SX, y = SY, width = AW - SEL_H - 4, height = SEL_H, variant = "select",
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
  kit.hover(select_area, function(hovered) return accent():alpha(hovered and .18 or .08) end, P.control_round(SEL_H))

  -- ----------------------------------------------- nothing playing --
  -- One tile over Now playing, Lyrics and Signal: the status centred, over
  -- a still silhouette of the spectrum (a fixed curve, one path; nothing
  -- moves) on the theme's grid.
  local NW, NH = inner("nothing")
  local EMB = 52
  local SIL_H = math.max(40, math.min(86, math.floor(NH * .28)))
  local SIL_W = NW - 32
  local silhouette = {}
  for k = 1, 56 do
    local t = (k - 1) / 55
    silhouette[k] = .1 + .5 * math.exp(-((t - .22) / .16) ^ 2) + .32 * math.exp(-((t - .62) / .2) ^ 2)
      + .05 * math.sin(k * 1.7) ^ 2
  end
  local TEXT_W = NW - 32
  local TITLE_EX = P.heading_h(theme.size.extra)
  local STACK_H = EMB + 12 + TITLE_EX + 4 + LABEL_H
  local STACK_Y = math.max(8, math.floor((NH - SIL_H - 28 - STACK_H) / 2))
  local nothing = place("nothing", { id = "media-nothing", title = "Now playing", note = state_note,
    visible = function() return not something() end,
    kit.emblem { kind = "info", x = math.floor((NW - EMB) / 2), y = STACK_Y, size = EMB },
    kit.heading { id = "media-empty-title", x = 16, y = STACK_Y + EMB + 12, width = TEXT_W,
      height = TITLE_EX, level = "title", horizontal_alignment = "center",
      font_size = theme.size.extra, text = "Nothing playing", active = on_screen,
      visible = function() return not something() end },
    kit.label { x = 16, y = STACK_Y + EMB + 12 + TITLE_EX + 4, width = TEXT_W,
      horizontal_alignment = "center", elide = "right",
      text = "Play something and it shows up here" },
    ui.Item { x = 16, y = NH - SIL_H - 14, width = SIL_W, height = SIL_H,
      P.decor_box("grid", { width = SIL_W, height = SIL_H, columns = 14, rows = 3, color = kit.stroke("faint") }),
      kit.spectrum { width = SIL_W, height = SIL_H, values = silhouette, gap = 3,
        color = function() return accent():alpha(.22) end },
    },
    P.decor_box("ticks", { x = 16, y = NH - 12, length = SIL_W, count = 28, major = 4, size = 5, flip = true }),
  })

  -- ---------------------------------------------- Now playing: console --
  local BW, BH = inner("track")
  local TITLE_SIZE = theme.size.large
  local TITLE_H = P.lh(TITLE_SIZE)
  local META_Y = TITLE_H
  local META_H = P.lh(theme.size.small)
  -- From the foot up: the transport, the position, the level; the
  -- spectrum takes what is left under the title.
  local TH = 40
  local TY = BH - TH
  local PCH = 34
  local PCY = TY - 8 - (CAPTION_H + PCH)
  local LMH = 24
  local LMY = PCY - 8 - (CAPTION_H + 2 + LMH)
  local SPY = META_Y + META_H + 8
  local SPW = BW - 34
  local SPH = math.max(36, LMY - 10 - 8 - SPY)

  -- The spectrum: one path of bars over the theme's grid, its scale at
  -- the right and a ruler under it.
  local spectrum = ui.Item {
    id = "media-visualiser", y = SPY, width = BW, height = SPH + 8,
    P.decor_box("grid", { width = SPW, height = SPH, columns = 8, rows = 4, color = kit.stroke("faint") }),
    kit.spectrum { id = "media-spectrum", width = SPW, height = SPH, channel = bars,
      color = accent, gap = 2 },
    P.decor_box("scale", { x = SPW + 4, y = 0, height = SPH, count = 12, major = 6, size = 6, flip = true,
      color = kit.stroke("idle") }),
    P.decor_box("ticks", { y = SPH + 2, length = SPW, count = 28, major = 4, size = 5, flip = true }),
  }

  -- The level monitor: a mirrored strip of the level history, swept from
  -- left to right; the cursor marks the newest sample.
  local level = ui.Item {
    id = "media-level-monitor", y = LMY, width = BW, height = CAPTION_H + 2 + LMH,
    kit.caption { width = BW, text = "Level", note = kit.code("media.lm", "BUF ##/##") },
    ui.Item { y = CAPTION_H + 2, width = BW, height = LMH,
      kit.spectrum { id = "media-level-history", width = BW, height = LMH, mirror = true, gap = 1,
        values = function() return history:get().values end, color = kit.signal("ok") },
      kit.surface { id = "media-level-cursor", y = -2, width = 1, height = LMH + 4, color = kit.ink("hi"),
        x = function() return history:get().at / HIST * BW end,
        visible = function() return history:get().at > 0 end },
    },
  }

  -- The position: the theme's skin of the kit's seek bar.
  local position_chart = ui.Item {
    y = PCY, width = BW, height = CAPTION_H + PCH,
    kit.caption { width = BW, text = "Position",
      note = function()
        local a = active()
        if not a.length or a.length <= 0 then return "" end
        return "−" .. media.duration(math.max(0, a.length - (a.position or 0)))
      end },
    ui.Item { id = "media-progress", y = CAPTION_H, width = BW, height = PCH,
      kit.media_progress { id = "media-seek", width = BW, value = fraction, seek = media.seek,
        active = on_screen, playing = playing },
    },
  }

  -- Transport, centred: previous, the position large, next, play, shuffle,
  -- repeat and the length (the position narrower and the length left out
  -- where the tile is narrow).
  local LOOPS = { none = "playlist", playlist = "track", track = "none" }
  local POS_SIZE = theme.size.extra
  local FIXED = 244
  local SHOW_LENGTH = BW >= FIXED + 64 + 64
  local POS_W = math.max(56, math.min(92, BW - FIXED - (SHOW_LENGTH and 64 or 0)))
  local transport = ui.Item { y = TY, width = BW, height = TH,
    ui.Row {
      id = "media-controls", anchors = { horizontal_center = true, vertical_center = true }, height = TH, gap = 4,
      align = "center",
      P.icon_button { area = ctx.area, id = "media-tab-previous", width = 36, height = 36, icon = "skip_previous",
        on_clicked = function() control("previous") end },
      kit.text { id = "media-position", width = POS_W, horizontal_alignment = "center", height = P.lh(POS_SIZE),
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
      SHOW_LENGTH and ui.Item { width = 4, height = 1 } or nil,
      SHOW_LENGTH and kit.text { id = "media-length", width = 52, horizontal_alignment = "right", elide = "left",
        text = function() return media.duration(active().length) end, font_size = theme.size.small,
        color = kit.ink("lo") } or nil,
    },
  }

  local track = place("track", { id = "media-track", title = "Now playing", note = state_note,
    visible = something,
    kit.heading { id = "media-tab-title", y = 0, width = BW, height = TITLE_H, elide = "right",
      level = "title", text = field("title"), font_size = TITLE_SIZE, active = on_screen },
    ui.Row { y = META_Y, height = META_H, gap = 8, align = "center",
      kit.text { id = "media-tab-artist", width = math.floor(BW * .55) - 8, elide = "right", text = field("artist"),
        font_size = theme.size.small, color = accent },
      kit.text { id = "media-tab-album", width = math.floor(BW * .45), elide = "right", text = field("album"),
        font_size = theme.size.small, color = kit.ink("lo") },
    },
    spectrum,
    level,
    position_chart,
    transport,
  })

  -- ------------------------------------------------------------ Lyrics --
  local function lyrics_status()
    local f = lyrics()
    return f and f.status:get() or "none"
  end
  local LW, LH = inner("lyrics")
  local function lyric_row(offset)
    local now = offset == 0
    return ui.Item {
      width = LW, height = LROW,
      kit.surface { anchors = { fill = true }, radius = P.control_round(LROW),
        color = function() return now and accent():alpha(.18) or accent():alpha(0) end },
      kit.text { x = 8, anchors = { vertical_center = true }, width = LW - 8 - 56, elide = "right",
        text = function()
          local f = lyrics()
          if not f then return "" end
          local line = f.lines:get()[f.index:get() + offset]
          return line and line.text or ""
        end,
        font_size = theme.size.small, font_weight = now and 500 or 400,
        color = function() return now and kit.ink("hi")() or kit.ink("lo")() end,
        opacity = now and 1 or (math.abs(offset) == 1 and .8 or math.max(.25, .7 - .15 * math.abs(offset))) },
      kit.label { anchors = { right = true, right_margin = 6 }, y = math.floor((LROW - LABEL_H) / 2), width = 44,
        horizontal_alignment = "right", text = kit.code("lyric" .. offset, "L##.#") },
    }
  end
  -- As many lines either side of the current one as the tile holds.
  local SIDE = math.max(1, math.min(5, math.floor((LH / (LROW + 1) - 1) / 2)))
  local list = { gap = 1, visible = function() local st = lyrics_status() return st == "synced" or st == "plain" end }
  for offset = -SIDE, SIDE do list[#list + 1] = lyric_row(offset) end
  local LIST_H = (2 * SIDE + 1) * (LROW + 1) - 1
  list.y = math.max(0, math.floor((LH - LIST_H) / 2))
  local function searching() return lyrics_status() == "searching" end
  local lyrics_tile = place("lyrics", { id = "media-lyrics", visible = something,
    title = function()
      local st = lyrics_status()
      return st == "synced" and "Lyrics · synced" or st == "plain" and "Lyrics · plain" or "Lyrics"
    end,
    ui.Column(list),
    ui.Item {
      id = "media-no-lyrics", width = LW, height = LH,
      visible = function() local st = lyrics_status() return st ~= "synced" and st ~= "plain" end,
      kit.status { x = 0, y = math.floor((LH - 40) / 2), width = LW - 56, size = 40,
        kind = function() return searching() and "info" or "warn" end,
        title = function() return searching() and "Searching" or "No lyrics" end,
        subtitle = function() return searching() and "Looking for lyrics" or "No match found" end },
      kit.loading(36, accent, {
        id = "media-lyrics-loading", x = LW - 40, y = math.floor((LH - 36) / 2),
        active = function() return ctx.opened() and searching() end,
        visible = searching,
      }),
    },
  })

  -- ------------------------------------------------------------ Signal --
  local GW = inner("signal")
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
  local signal_tile = place("signal", { id = "media-signal", title = "Signal", visible = something,
    band_readout("Low", 2, "low", "dlow"),
    band_readout("High", 52, "high", "dhigh"),
    P.rule { x = 156, y = 0, height = RING, strength = "faint", width = 1 },
    kit.ring { x = GW - RING, y = 0, size = RING, value = vol,
      text = function() return ("%d"):format(math.floor(vol() * 100 + .5)) end, label = "Volume" },
    ui.Row { id = "media-volume", x = 0, y = RING + 8, gap = 8, align = "center",
      kit.icon(function()
        local v = vol()
        return v <= 0 and "volume_off" or v < 0.5 and "volume_down" or "volume_up"
      end, 18, kit.ink("lo")),
      kit.slider {
        id = "media-volume-slider", width = GW - 26, height = 22, value = vol,
        set = function(v) control("set_volume", clamp01(v)) end,
      },
    },
  })

  return ui.Item {
    id = "dashboard-media-tab",
    width = M.WIDTH, height = M.HEIGHT,
    player_tile,
    nothing,
    track,
    lyrics_tile,
    signal_tile,
    select_area,
    more_area,
  }
end

-- Built as the module loads, with its own instruction budget.
M.page = M.build(require("dashboard_state").context(2))

return M
