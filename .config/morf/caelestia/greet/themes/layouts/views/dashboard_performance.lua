-- The dashboard's Performance tab: the machine's devices down the left --
-- the processor, memory, every drive, network interface, GPU and fan, each a
-- channel row with its reading and level -- over a resource-mix radar; and
-- the one picked on the right as an instrument bay. Its left column a ring
-- gauge with two satellite gauges, a NOW / AVG / PEAK triplet, its channel
-- meters and a status strip; its charts in the middle (for the processor a
-- per-core number grid and a core-clock spectrum as well); its readouts over
-- what it is on the right.
--
-- A drive's page lists its logical units: the partitions and the volumes
-- (LVM, LUKS) built on them, each with its mounts, size and traffic. A GPU
-- that is powered down is shown as that and not read: reading it would
-- wake it.
--
-- Values ease when they change and the picked page's gauges sweep in from
-- zero as it is shown; nothing moves at rest. The page shrinks to a screen
-- smaller than it (the columns and charts take the room that is left).

local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local L = require("themes.layouts.parts")

local S = L.SIZE
local M = {}

-- The page: at most 1400 x 760, less on a screen without the room (the
-- drawer's frame, padding, tabs and seams around it).
do
  local sw, sh = L.screen()
  M.WIDTH = math.max(960, math.min(1400, sw - 2 * theme.BORDER - 2 * 16 - 2 * 40))
  M.HEIGHT = math.max(560, math.min(760, sh - 2 * theme.BORDER - 68 - 2 * 16 - 40))
end
local GAP = 12
local SIDE_W = M.WIDTH >= 1300 and 300 or 264
local MAIN_W = M.WIDTH - SIDE_W - GAP
local TITLE_Y = 12
local TOP = TITLE_Y + L.title_h() + 8            -- under the title row
local INNER = MAIN_W - 40
local LW = INNER >= 1000 and 250 or 220          -- the gauges
local RW = INNER >= 1000 and 258 or 220          -- the readouts
local LX = 20
local MX = LX + LW + 22
local MW = INNER - LW - RW - 40                   -- the charts
local RX = MX + MW + 18
local BOTTOM = M.HEIGHT - 20
local COL_H = BOTTOM - TOP
local ROW_H = 48
local RADAR_H = M.HEIGHT >= 700 and 214 or 184

local function pct(v) return ("%d%%"):format(math.floor((tonumber(v) or 0) + .5)) end

function M.build(model)
  morf.effect("material.performance.present", function() model.present(model.selected:get()) end)
  local opened = model.active
  local cpu, memory, temps = model.cpu, model.memory, model.temps
  local history, list, selected, on = model.history, model.list, model.selected, model.on
  local rate_text, size_text, ghz = model.rate, model.size, model.ghz
  local info = model.info
  local threads = math.max(1, info.logical or 1)

  --- Shown: the page of `kind` is up and the drawer open. A gauge reads
  --- zero while its page is hidden, so it sweeps in when picked.
  local function live(kind) return function() return opened() and on(kind)() end end

  local function peak_of(values, floor)
    local peak = floor or 0
    for _, v in ipairs(values or {}) do if v > peak then peak = v end end
    return peak
  end

  -- -------------------------------------------------------------- pages --

  --- The left column every page wears: `ring` { value (0..1), text, label,
  --- caption, color, text_size }, `minis` (two { value, text, label }),
  --- `triplet` { series, top, format, title }, `status` { kind, title,
  --- subtitle }, `channels` ({ label, value }) and their title.
  local STATUS_H = 40
  local TRIPLET_H = 74
  local FLEX = COL_H - (L.CAPTION_H + 6) - 12 - 10 - 14 - 12 - TRIPLET_H - 12 - STATUS_H - 8
  -- The channel meters keep a useful height (CHAN_MIN: their caption and
  -- labels and a 40 px column); the ring gives way to them on a short page.
  local CHAN_MIN = 8 + 2 * (L.lh(S.micro) + 6) + 40
  local MINI = math.min(104, math.floor((LW - 30) / 2), math.floor(FLEX * 0.24))
  local RING = math.max(120, math.min(236, LW - 10, math.floor(FLEX * 0.56), FLEX - MINI - CHAN_MIN))
  local CHAN_H = FLEX - RING - MINI
  local function left_column(kind, spec)
    local up = live(kind)
    local nodes = { x = LX, y = TOP, width = LW, height = COL_H }
    local y = 0
    nodes[#nodes + 1] = L.caption { width = LW, text = spec.ring.caption or "Primary load",
      note = kit.code(kind, "SET #.##") }
    y = L.CAPTION_H + 6
    nodes[#nodes + 1] = kit.ring {
      id = "performance-ring-" .. kind, x = math.floor((LW - RING) / 2), y = y, size = RING,
      value = function() return up() and spec.ring.value() or 0 end,
      text = spec.ring.text, text_size = spec.ring.text_size or math.floor(RING * (spec.ring.text and .13 or .18)),
      label = spec.ring.label,
      color = spec.ring.color or kit.level(function() return spec.ring.value() * 100 end),
    }
    y = y + RING + 12
    nodes[#nodes + 1] = L.rule { y = y, width = LW, strength = "faint" }
    y = y + 10
    for i, mini in ipairs(spec.minis) do
      nodes[#nodes + 1] = kit.mini_ring { x = i == 1 and 6 or LW - 6 - MINI, y = y, size = MINI,
        value = function() return up() and mini.value() or 0 end, text = mini.text, label = mini.label,
        text_size = mini.text_size and math.min(mini.text_size, math.floor(MINI * .13)) or math.floor(MINI * .2),
        color = mini.color or kit.signal("info") }
    end
    nodes[#nodes + 1] = kit.decor("ticks", { x = LW / 2 - 1, y = y + 6, length = MINI - 12, count = 12, major = 4,
      size = 8, vertical = true, color = kit.stroke("idle") })
    y = y + MINI + 14 + 12
    nodes[#nodes + 1] = kit.triplet { y = y, width = LW, series = spec.triplet.series, top = spec.triplet.top,
      format = spec.triplet.format, title = spec.triplet.title, font_size = spec.triplet.font_size }
    y = y + TRIPLET_H + 12
    local chans = spec.channels
    if chans and CHAN_H >= 56 then
      local n = #chans
      local slot = math.min(34, math.floor((LW - 8) / math.max(1, n)))
      local mw = math.max(4, math.min(12, slot - 6))
      local x0 = math.floor((LW - slot * n) / 2)
      local lh = L.lh(S.micro)
      local box = { y = y, width = LW, height = CHAN_H - 8,
        kit.panel { width = LW, height = CHAN_H - 8 },
        L.label { x = 6, y = 3, width = LW - 60, elide = "right", text = spec.channels_title or "Channels",
          font_size = S.micro, color = kit.ink("hi") },
        L.code("chan" .. kind, "## CH", { anchors = { right = true, right_margin = 6 }, y = 3, width = 50,
          horizontal_alignment = "right" }),
      }
      local mh = CHAN_H - 8 - (lh + 6) - (lh + 6)
      for i, c in ipairs(chans) do
        local x = x0 + (i - 1) * slot + (slot - mw) / 2
        box[#box + 1] = kit.vmeter { x = x, y = lh + 6, width = mw, height = mh,
          value = function() return up() and c.value() or 0 end,
          color = kit.level(function() return c.value() * 100 end) }
        if slot >= 18 or i % 2 == 1 then
          box[#box + 1] = L.label { x = x0 + (i - 1) * slot - 8, y = CHAN_H - 8 - lh - 3, width = slot + 16,
            horizontal_alignment = "center", text = c.label, font_size = S.micro }
        end
      end
      nodes[#nodes + 1] = ui.Item(box)
    end
    nodes[#nodes + 1] = L.status { y = COL_H - STATUS_H, width = LW, height = STATUS_H,
      kind = spec.status.kind, title = spec.status.title, subtitle = spec.status.subtitle }
    return L.item(nodes)
  end

  local STAT_H, STAT_GAP = 56, 10
  local function right_column(kind)
    local stats = model.readouts[kind].stats
    local cw = math.floor((RW - 10) / 2)
    local cells = { y = L.CAPTION_H + 6, width = RW, height = math.ceil(#stats / 2) * (STAT_H + STAT_GAP) }
    for i, row in ipairs(stats) do
      cells[#cells + 1] = kit.stat { x = ((i - 1) % 2) * (cw + 10), y = math.floor((i - 1) / 2) * (STAT_H + STAT_GAP),
        width = cw, height = STAT_H, label = row.label, value = row.value, mark = row.mark,
        color = row.mark == "dashed" and kit.signal("info") or nil }
    end
    local fy = cells.y + cells.height + 8
    local facts = model.readouts[kind].facts
    local row_h = math.max(16, math.min(20, math.floor((COL_H - fy - L.CAPTION_H - 6) / math.max(1, #facts))))
    return ui.Item {
      x = RX, y = TOP, width = RW, height = COL_H, clip = true,
      L.caption { width = RW, text = "Readings", note = kit.code("ro" .. kind, "##-BIT USAW") },
      ui.Item(cells),
      L.caption { y = fy, width = RW, text = "Details", note = kit.code("dr" .. kind, "CP-##/CP-##") },
      ui.Item { y = fy + L.CAPTION_H + 6, kit.facts(facts, RW, row_h, math.floor(RW * .52)) },
    }
  end

  local function page(kind, title, subtitle, contents)
    table.insert(contents, 1, L.title_row { x = 20, y = TITLE_Y, width = INNER, id = "performance-title-" .. kind,
      active = live(kind), title = title, subtitle = subtitle, key = "perf" .. kind })
    contents.visible = on(kind)
    contents.width, contents.height = MAIN_W, M.HEIGHT
    return L.item(contents)
  end

  -- A load's state in plain words; the theme may say it its own way.
  local LOAD_TITLE = { alert = "Heavy load", warn = "Busy", ok = "Normal", asleep = "Asleep" }
  local LOAD_NOTE = { alert = "Close to its limit", warn = "Working hard", ok = "Running smoothly",
    asleep = "Powered down  ·  not read" }
  local function load_status(state)
    return {
      kind = function() local k = state() return k == "asleep" and "info" or k end,
      title = L.term(function() return "load." .. state() end, function() return LOAD_TITLE[state()] end),
      subtitle = L.term(function() return "load.note." .. state() end, function() return LOAD_NOTE[state()] end),
    }
  end
  local function stress(value_fn, warn, alert)
    warn, alert = warn or 70, alert or 90
    return load_status(function() local v = value_fn() return v >= alert and "alert" or v >= warn and "warn" or "ok" end)
  end

  local function minutes(section)
    return ("%d min"):format(math.floor(model.samples * model.intervals[section] / 60000 + 0.5))
  end
  local function chart(spec)
    spec.samples = model.samples
    return (L.chart(spec))
  end
  local CH = L.CAPTION_H + L.CAPTION_GAP          -- a chart's caption

  -- ---------------------------------------------------------------- cpu --
  local cols = threads <= 4 and threads or threads <= 16 and 4 or threads <= 36 and 6 or 8
  local rows_n = math.ceil(threads / cols)
  local GRID_H = math.min(214, math.floor(COL_H * .34))
  local cell_gap = 8
  local cell_w = math.floor((MW - (cols - 1) * cell_gap) / cols)
  local cell_h = math.min(52, math.floor((GRID_H - (rows_n - 1) * cell_gap) / rows_n))
  local cells = { y = L.CAPTION_H + 6, width = MW, height = rows_n * (cell_h + cell_gap) }
  local up_cpu = live("cpu")
  local function core(i) return function()
    if not up_cpu() then return 0 end
    local c = cpu().cores[i + 1]
    if type(c) == "table" then return c.usage or 0 end
    return tonumber(c) or 0
  end end
  for i = 0, threads - 1 do
    cells[#cells + 1] = kit.cell {
      id = "performance-core-" .. i, x = (i % cols) * (cell_w + cell_gap), y = math.floor(i / cols) * (cell_h + cell_gap),
      width = cell_w, height = cell_h, value = core(i), label = tostring(i),
    }
  end
  local grid_bottom = cells.y + cells.height
  local function clocks()
    if not up_cpu() then return {} end
    local out, top = {}, math.max(1, info.max_mhz or 1)
    for _, c in ipairs(cpu().cores) do out[#out + 1] = (type(c) == "table" and c.frequency or 0) / top end
    return out
  end
  local CHART_Y = grid_bottom + 10
  local SPEC_H = COL_H >= 600 and 70 or 52
  local cpu_chart_h = COL_H - CHART_Y - CH - 18 - (CH + SPEC_H)
  local cpu_page = page("cpu", "CPU", function() return model.cpu_name(info.model) end, {
    left_column("cpu", {
      ring = { caption = "Processor load", value = function() return (cpu().usage or 0) / 100 end, label = "Load" },
      minis = {
        { label = "Temp", value = function() return (temps().cpu or 0) / 100 end,
          text = function() local t = temps().cpu return t and ("%d°"):format(math.floor(t + .5)) or "--" end,
          color = kit.level(function() return temps().cpu or 0 end, 75, 90) },
        { label = "Clock", value = function() return (cpu().frequency or 0) / math.max(1, info.max_mhz or 1) end,
          text = function() return ("%.1f"):format((cpu().frequency or 0) / 1000) end },
      },
      triplet = { title = "Utilization " .. minutes("cpu"), series = function() return history("cpu") end,
        top = function() return 100 end, format = pct },
      status = stress(function() return cpu().usage or 0 end),
      channels_title = "Per core", channels = (function()
        local out = {}
        for i = 0, threads - 1 do out[#out + 1] = { label = tostring(i), value = function() return core(i)() / 100 end } end
        return out
      end)(),
    }),
    ui.Item {
      x = MX, y = TOP, width = MW, height = COL_H,
      L.caption { id = "performance-utilization-title", width = MW, text = ("Cores  ·  %d threads"):format(threads),
        note = function() return pct(cpu().usage) .. " avg" end },
      ui.Item(cells),
      chart { y = CHART_Y, id = "performance-cpu-graph", caption = "Utilization  ·  " .. minutes("cpu"),
        scale = function() return "100%" end, width = MW - 10, height = cpu_chart_h, top = 100, hatch = true,
        first = function() return history("cpu") end, columns = 10 },
      L.section { y = COL_H - CH - SPEC_H, width = MW, height = CH + SPEC_H, text = "Core clock",
        note = function() return ghz(cpu().frequency) end,
        kit.spectrum { width = MW, height = SPEC_H - 8, values = clocks, gap = 10,
          color = function() return kit.signal("info")():alpha(.45) end },
        kit.decor("ticks", { y = SPEC_H - 6, length = MW, count = threads * 2, major = 2, size = 6,
          color = kit.stroke("idle") }),
      },
    },
    right_column("cpu"),
  })
  if theme.motion.value_flash then
    theme.motion.value_flash(cpu_page, "performance-cpu", {
      x = MAIN_W - 12, y = TOP, height = 32,
      active = live("cpu"),
      read = function() return cpu().usage end,
      changed = function(before, now) return (before < 70 and now >= 70) or math.abs(now - before) >= 20 end,
    })
  end

  -- ------------------------------------------------------------- memory --
  local function composition()
    local m = memory()
    local total = math.max(1, m.total or 1)
    local used = (m.used or 0) / total
    local cached = math.min(1 - used, (m.cached or 0) / total)
    return used, cached
  end
  local up_mem = live("memory")
  local COMP_H = CH + 14 + 6 + 6 + 8 + L.lh(S.label)
  local mem_charts = COL_H - COMP_H - 2 * CH - 16 - 18
  local mem_chart_h = math.floor(mem_charts * .64)
  local swap_chart_h = mem_charts - mem_chart_h
  local function legend(label, color)
    return ui.Row { gap = 6, align = "center",
      ui.Rect { width = 10, height = 8, color = color },
      L.label { text = label },
    }
  end
  local memory_page = page("memory", "Memory", function() return size_text(memory().total) end, {
    left_column("memory", {
      ring = { caption = "Memory in use", value = function() return (memory().percent or 0) / 100 end, label = "Used" },
      minis = {
        { label = "Swap", value = function()
            local s = memory().swap return (s.used or 0) / math.max(1, s.total or 1) end,
          text = function() local s = memory().swap return pct(100 * (s.used or 0) / math.max(1, s.total or 1)) end },
        { label = "Cache", value = function() local _, c = composition() return c end,
          text = function() local _, c = composition() return pct(c * 100) end },
      },
      triplet = { title = "Memory " .. minutes("memory"), series = function() return history("memory") end,
        top = function() return 100 end, format = pct },
      status = stress(function() return memory().percent or 0 end, 80, 92),
      channels = {
        { label = "Used", value = function() return (composition()) end },
        { label = "Cache", value = function() local _, c = composition() return c end },
        { label = "Avail", value = function() local m = memory() return (m.available or 0) / math.max(1, m.total or 1) end },
        { label = "Commit", value = function() local m = memory() return (m.committed or 0) / math.max(1, m.commit_limit or m.total or 1) end },
        { label = "Swap", value = function() local x = memory().swap return (x.used or 0) / math.max(1, x.total or 1) end },
      },
    }),
    ui.Item {
      x = MX, y = TOP, width = MW, height = COL_H,
      chart { id = "performance-memory-graph", caption = "Memory usage  ·  " .. minutes("memory"),
        scale = function() return size_text(memory().total) end, width = MW - 10, height = mem_chart_h, top = 100,
        hatch = true, first = function() return history("memory") end },
      chart { y = CH + mem_chart_h + 16, id = "performance-swap-graph", caption = "Swap usage  ·  " .. minutes("memory"),
        scale = function() return size_text(memory().swap.total) end, width = MW - 10, height = swap_chart_h, top = 100,
        first = function() return history("swap") end, color = kit.signal("info") },
      L.section { y = COL_H - COMP_H, width = MW, height = COMP_H, caption_id = "performance-memory-composition-title",
        text = "Memory composition",
        note = function() return size_text(memory().used) .. " / " .. size_text(memory().total) end,
        ui.Item { id = "performance-memory-composition", width = MW, height = 26,
          kit.fill { width = MW, height = 14, value = function() return up_mem() and (composition()) or 0 end },
          kit.meter { y = 20, width = MW, height = 6, count = math.floor(MW / 8), color = kit.signal("info"),
            value = function() local _, c = composition() return up_mem() and c or 0 end },
        },
        ui.Row { y = 34, gap = 18,
          legend(function() local u = composition() return "In use " .. pct(u * 100) end, kit.signal("accent")),
          legend(function() local _, c = composition() return "Cached " .. pct(c * 100) end, kit.signal("info")),
          legend(function() return "Free " .. size_text(memory().available) end, kit.stroke("mark")),
        },
      },
    },
    right_column("memory"),
  })
  if theme.motion.value_flash then
    theme.motion.value_flash(memory_page, "performance-memory", {
      x = MAIN_W - 12, y = TOP, height = 32,
      active = live("memory"),
      read = function() return memory().percent end,
      changed = function(before, now) return (before < 85 and now >= 85) or math.abs(now - before) >= 15 end,
    })
  end

  -- -------------------------------------------------------------- drive --
  local drive_ref, the_drive, units, unit = model.drive_ref, model.the_drive, model.units, model.unit
  local function drive_peak()
    local r = drive_ref()
    local d = the_drive()
    return math.max(peak_of(history("disk:" .. r .. ":read"), 1), peak_of(history("disk:" .. r .. ":write"), 1),
      d.read_rate or 0, d.write_rate or 0) * 1.15
  end
  local drive_chart_h = math.min(150, math.floor((COL_H - 2 * CH - 32 - 120) / 2))
  local units_y = 2 * (CH + drive_chart_h + 16)
  local UNIT_H = 30
  local drive_page = page("drive", function()
    local d = the_drive()
    return ("%s (%s)"):format(d.kind or "Drive", d.name or "")
  end, function() return the_drive().model or "" end, {
    left_column("drive", {
      ring = { caption = "Active time", value = function() return (the_drive().busy or 0) / 100 end, label = "Busy" },
      minis = {
        { label = "Read", value = function() return (the_drive().read_rate or 0) / math.max(1024, drive_peak()) end,
          text = function() return rate_text(the_drive().read_rate) end, text_size = 12 },
        { label = "Write", value = function() return (the_drive().write_rate or 0) / math.max(1024, drive_peak()) end,
          text = function() return rate_text(the_drive().write_rate) end, text_size = 12 },
      },
      triplet = { title = "Active " .. minutes("drives"), series = function() return history("disk:" .. drive_ref() .. ":busy") end,
        top = function() return 100 end, format = pct },
      status = stress(function() return the_drive().busy or 0 end),
      channels = {
        { label = "Busy", value = function() return (the_drive().busy or 0) / 100 end },
        { label = "Read", value = function() return (the_drive().read_rate or 0) / math.max(1024, drive_peak()) end },
        { label = "Write", value = function() return (the_drive().write_rate or 0) / math.max(1024, drive_peak()) end },
      },
    }),
    ui.Item {
      x = MX, y = TOP, width = MW, height = COL_H,
      chart { id = "performance-drive-active", caption = "Active time  ·  " .. minutes("drives"),
        scale = function() return "100%" end, width = MW - 10, height = drive_chart_h, top = 100, hatch = true,
        first = function() return history("disk:" .. drive_ref() .. ":busy") end },
      chart { y = CH + drive_chart_h + 16, id = "performance-drive-throughput", caption = "Read / write  ·  " .. minutes("drives"),
        scale = rate_text, width = MW - 10, height = drive_chart_h, floor = 1024,
        first = function() return history("disk:" .. drive_ref() .. ":read") end,
        second = function() return history("disk:" .. drive_ref() .. ":write") end },
      L.section { y = units_y, width = MW, height = COL_H - units_y, caption_id = "performance-logical-units-title",
        text = "Partitions and volumes", note = function() local n = #(the_drive().units or {})
          return ("%d unit%s"):format(n, n == 1 and "" or "s") end,
        (kit.scroll({
          width = MW, height = COL_H - units_y - CH, clip = true,
          ui.Repeater {
            as = "column", gap = 4, width = MW, model = units.rows,
            delegate = function(row)
              local function u() return unit(row.name) end
              local name_w = math.floor(MW * .26)
              local io_w = math.floor(MW * .4)
              return L.item { id = "performance-unit-" .. row.name, width = MW, height = UNIT_H,
                kit.text { x = function() return 10 + 14 * math.max(0, (u().depth or 1) - 1) end,
                  y = math.floor((UNIT_H - L.lh(S.body)) / 2), width = name_w - 10, height = L.lh(S.body),
                  elide = "right", font_size = S.body, color = kit.ink("hi"),
                  text = function() return u().label or row.name end },
                kit.text { x = name_w + 10, y = math.floor((UNIT_H - L.lh(S.label)) / 2), width = MW - name_w - io_w - 30,
                  height = L.lh(S.label), font_size = S.label, color = kit.ink("lo"), elide = "right", text = function()
                    local x = u()
                    if x.swap then return "swap" end
                    return #x.mounts > 0 and table.concat(x.mounts, "  ") or "not mounted"
                  end },
                L.label { x = MW - io_w - 8, y = math.floor((UNIT_H - L.lh(S.label)) / 2), width = io_w,
                  horizontal_alignment = "right", elide = "left", color = kit.ink("hi"), text = function()
                    local x = u()
                    return ("%s  ↓%s ↑%s"):format(size_text(x.size), rate_text(x.read_rate), rate_text(x.write_rate))
                  end },
                L.rule { y = UNIT_H - 1, width = MW, strength = "faint" },
              }
            end,
          },
        })),
      },
    },
    right_column("drive"),
  })

  -- ------------------------------------------------------------ network --
  local net_ref, the_iface = model.net_ref, model.the_iface
  local function net_peak()
    local r = net_ref()
    local i = the_iface()
    return math.max(peak_of(history("rx:" .. r), 1024), peak_of(history("tx:" .. r), 1024),
      i.rx_rate or 0, i.tx_rate or 0) * 1.15
  end
  local TRAFFIC_H = COL_H >= 600 and 70 or 54
  local net_chart_h = COL_H - CH - 18 - 2 * (CH + TRAFFIC_H) - 12
  local function traffic(key)
    return function()
      local out, top = {}, net_peak()
      for _, v in ipairs(history(key .. net_ref())) do out[#out + 1] = v / top end
      return out
    end
  end
  local net_page = page("net", function() return the_iface().wireless and "Wi-Fi" or "Ethernet" end,
    function() return net_ref() end, {
    left_column("net", {
      ring = { caption = "Link throughput",
        value = function() local i = the_iface() return ((i.rx_rate or 0) + (i.tx_rate or 0)) / (2 * net_peak()) end,
        text = function() local i = the_iface() return rate_text((i.rx_rate or 0) + (i.tx_rate or 0)) end,
        label = "Rx + Tx", color = kit.signal("accent") },
      minis = {
        { label = "Receive", value = function() return (the_iface().rx_rate or 0) / net_peak() end,
          text = function() return rate_text(the_iface().rx_rate) end, text_size = 12 },
        { label = "Send", value = function() return (the_iface().tx_rate or 0) / net_peak() end,
          text = function() return rate_text(the_iface().tx_rate) end, text_size = 12 },
      },
      triplet = { title = "Receive " .. minutes("network"), series = function() return history("rx:" .. net_ref()) end,
        top = net_peak, format = rate_text, font_size = 12 },
      status = {
        kind = function() return the_iface().state == "up" and "ok" or "warn" end,
        title = function() return the_iface().state == "up" and "Linked" or "No link" end,
        subtitle = function() return "State " .. tostring(the_iface().state or "--") .. "  ·  " .. net_ref() end,
      },
      channels = {
        { label = "Rx", value = function() return (the_iface().rx_rate or 0) / net_peak() end },
        { label = "Tx", value = function() return (the_iface().tx_rate or 0) / net_peak() end },
      },
    }),
    ui.Item {
      x = MX, y = TOP, width = MW, height = COL_H,
      chart { id = "performance-net-throughput", caption = "Receive / send  ·  " .. minutes("network"),
        scale = rate_text, width = MW - 10, height = net_chart_h, floor = 1024, hatch = true,
        first = function() return history("rx:" .. net_ref()) end,
        second = function() return history("tx:" .. net_ref()) end },
      L.section { y = COL_H - 2 * (CH + TRAFFIC_H) - 12, width = MW, height = CH + TRAFFIC_H, text = "Traffic  ·  send",
        note = function() return rate_text(the_iface().tx_rate) end,
        kit.spectrum { width = MW, height = TRAFFIC_H - 4, gap = 2, color = kit.signal("info"), values = traffic("tx:") },
      },
      L.section { y = COL_H - (CH + TRAFFIC_H), width = MW, height = CH + TRAFFIC_H, text = "Traffic  ·  receive",
        note = function() return rate_text(the_iface().rx_rate) end,
        kit.spectrum { width = MW, height = TRAFFIC_H - 4, gap = 2, values = traffic("rx:") },
      },
    },
    right_column("net"),
  })

  -- ---------------------------------------------------------------- gpu --
  local gpu_ref, the_card, gpu_index = model.gpu_ref, model.the_card, model.gpu_index
  local function asleep() return the_card().suspended == true end
  local gpu_busy_h = math.floor((COL_H - 3 * CH - 32) * .46)
  local gpu_small_h = math.floor((COL_H - 3 * CH - 32 - gpu_busy_h) / 2)
  local DIAL = math.min(180, math.floor(COL_H * .32))
  local gpu_page = page("gpu", function() return "GPU " .. gpu_index() end, function() return the_card().model or "" end, {
    left_column("gpu", {
      ring = { caption = "Engine load", value = function() return asleep() and 0 or (the_card().busy or 0) / 100 end,
        text = function() return asleep() and "Off" or pct(the_card().busy) end, label = "Busy" },
      minis = {
        { label = "VRAM", value = function() local g = the_card() return (g.vram_used or 0) / math.max(1, g.vram_total or 1) end,
          text = function() local g = the_card()
            return g.vram_total and pct(100 * (g.vram_used or 0) / math.max(1, g.vram_total)) or "--" end },
        { label = "Video", value = function() local g = the_card() return math.max(g.encoder or 0, g.decoder or 0) / 100 end,
          text = function() local g = the_card()
            return (g.encoder or g.decoder) and pct(math.max(g.encoder or 0, g.decoder or 0)) or "--" end },
      },
      triplet = { title = "Engine " .. minutes("gpu"), series = function() return history("gpu:" .. gpu_ref()) end,
        top = function() return 100 end, format = pct },
      status = load_status(function()
        if asleep() then return "asleep" end
        local b = the_card().busy or 0
        return b >= 90 and "alert" or b >= 70 and "warn" or "ok"
      end),
      channels = {
        { label = "Busy", value = function() return asleep() and 0 or (the_card().busy or 0) / 100 end },
        { label = "Enc", value = function() return (the_card().encoder or 0) / 100 end },
        { label = "Dec", value = function() return (the_card().decoder or 0) / 100 end },
        { label = "VRAM", value = function() local g = the_card() return (g.vram_used or 0) / math.max(1, g.vram_total or 1) end },
      },
    }),
    ui.Item {
      x = MX, y = TOP, width = MW, height = COL_H,
      visible = function() return not asleep() and not the_card().vram_total end,
      chart { id = "performance-gpu-graph", caption = "Utilization  ·  " .. minutes("gpu"), scale = function() return "100%" end,
        width = MW - 10, height = COL_H - CH - 18, top = 100, hatch = true,
        first = function() return history("gpu:" .. gpu_ref()) end },
    },
    ui.Item {
      x = MX, y = TOP, width = MW, height = COL_H,
      visible = function() return not asleep() and the_card().vram_total ~= nil end,
      chart { id = "performance-gpu-busy", caption = "Utilization  ·  " .. minutes("gpu"), scale = function() return "100%" end,
        width = MW - 10, height = gpu_busy_h, top = 100, hatch = true,
        first = function() return history("gpu:" .. gpu_ref()) end },
      chart { y = CH + gpu_busy_h + 16, id = "performance-gpu-video", caption = "Video encode / decode  ·  " .. minutes("gpu"),
        scale = function() return "100%" end, width = MW - 10, height = gpu_small_h, top = 100,
        first = function() return history("gpuenc:" .. gpu_ref()) end,
        second = function() return history("gpudec:" .. gpu_ref()) end },
      chart { y = 2 * CH + gpu_busy_h + gpu_small_h + 32, id = "performance-gpu-memory",
        caption = "Memory usage  ·  " .. minutes("gpu"),
        scale = function() return size_text(the_card().vram_total) end, width = MW - 10, height = gpu_small_h, top = 100,
        first = function() return history("gpumem:" .. gpu_ref()) end, color = kit.signal("info") },
    },
    L.item {
      x = MX, y = TOP, width = MW, height = COL_H, visible = asleep,
      kit.panel { width = MW, height = COL_H },
      kit.decor("hatch", { x = 1, y = 1, width = MW - 2, height = COL_H - 2, spacing = 14, weight = 1,
        color = kit.stroke("faint") }),
      kit.decor("brackets", { width = MW, height = COL_H, length = 10 }),
      kit.dial { x = math.floor((MW - DIAL) / 2), y = math.floor(COL_H * .16), size = DIAL, value = 0,
        color = kit.signal("info") },
      ui.Column { x = 0, y = math.floor(COL_H * .16) + DIAL + 24, width = MW, gap = 8, align = "center",
        L.heading { id = "performance-gpu-sleep-title", text = "Powered down", level = "section",
          font_size = theme.size.large,
          active = function() return opened() and on("gpu")() and asleep() end },
        L.label { width = MW - 40, horizontal_alignment = "center", font_size = S.body,
          text = "Not read while it sleeps: reading it would wake it." },
        kit.chip { text = L.term("gpu.asleep", "Asleep"), width = 64, color = kit.signal("info") },
      },
    },
    right_column("gpu"),
  })

  -- ---------------------------------------------------------------- fan --
  local fan_ref, the_fan = model.fan_ref, model.the_fan
  local function fan_top()
    local f = the_fan()
    if f.max and f.max > 0 then return f.max end
    return peak_of(history(fan_ref()), 1000) * 1.15
  end
  local fan_page = page("fan", function() return "Fan " .. (fan_ref():gsub("^fan", "")) end,
    function() return the_fan().label or "" end, {
    left_column("fan", {
      ring = { caption = "Rotor speed", value = function() return (the_fan().rpm or 0) / math.max(1, fan_top()) end,
        text = function() return tostring(math.floor(the_fan().rpm or 0)) end, label = "RPM", color = kit.signal("accent") },
      minis = {
        { label = "CPU temp", value = function() return (temps().cpu or 0) / 100 end,
          text = function() local t = temps().cpu return t and ("%d°"):format(math.floor(t + .5)) or "--" end },
        { label = "CPU load", value = function() return (cpu().usage or 0) / 100 end, text = function() return pct(cpu().usage) end },
      },
      triplet = { title = "Speed " .. minutes("fans"), series = function() return history(fan_ref()) end, top = fan_top,
        format = function(v) return ("%d"):format(math.floor(v)) end },
      status = stress(function() return 100 * (the_fan().rpm or 0) / math.max(1, fan_top()) end, 75, 95),
      channels = {
        { label = "RPM", value = function() return (the_fan().rpm or 0) / math.max(1, fan_top()) end },
        { label = "Temp", value = function() return (temps().cpu or 0) / 100 end },
        { label = "Load", value = function() return (cpu().usage or 0) / 100 end },
      },
    }),
    ui.Item {
      x = MX, y = TOP, width = MW, height = COL_H,
      chart { id = "performance-fan-graph", caption = "Speed  ·  " .. minutes("fans"),
        scale = function(top) return ("%d RPM"):format(math.floor(top)) end, width = MW - 10, height = COL_H - CH - 18,
        top = fan_top, hatch = true, first = function() return history(fan_ref()) end },
    },
    right_column("fan"),
  })

  -- ------------------------------------------------------------ the list --
  local row_title, row_sub, row_value = model.row_title, model.row_sub, model.row_value
  --- A row's level, 0..100: its own load, or for a link its traffic on a
  --- log scale up to a gigabit.
  local function row_level(row)
    if row.kind == "cpu" then return cpu().usage or 0 end
    if row.kind == "memory" then return memory().percent or 0 end
    if row.kind == "drive" then return model.drive(row.ref).busy or 0 end
    if row.kind == "gpu" then local g = model.card(row.ref) return g.suspended and 0 or (g.busy or 0) end
    if row.kind == "net" then
      local i = model.iface(row.ref)
      local r = (i.rx_rate or 0) + (i.tx_rate or 0)
      return 100 * math.min(1, math.log(1 + r, 10) / 8.1)
    end
    local f = model.fan(row.ref)
    return 100 * (f.rpm or 0) / math.max(1, (f.max and f.max > 0) and f.max or 8000)
  end
  local ICON = { cpu = "memory", memory = "memory_alt", drive = "hard_drive", gpu = "developer_board",
    fan = "mode_fan" }
  local function icon_of(row)
    if row.kind == "net" then return model.iface(row.ref).wireless and "wifi" or "lan" end
    return ICON[row.kind] or "developer_board"
  end
  local settle = { duration = theme.duration.large, easing = theme.ease.emphasized_decel }
  local RW_ = SIDE_W - 24
  local function device_row(row)
    local W = RW_
    local function picked() return selected:get() == row.key end
    local function level() return opened() and row_level(row) or 0 end
    local color = kit.level(level)
    local TX, VW = 52, 66
    local accent = kit.signal("accent")
    local area = kit.action {
      id = "performance-device-" .. row.key,
      width = W, height = ROW_H, cursor = "pointer",
      on_clicked = function() selected:set(row.key) end,
      -- The picked row: its bar swells out of the left edge and the
      -- theme's corner marks close in on it.
      ui.Rect { height = ROW_H, color = accent,
        width = function() return picked() and 4 or 0 end, behavior = { width = settle } },
      L.item { width = W, height = ROW_H, opacity = function() return picked() and 1 or 0 end,
        scale = function() return picked() and 1 or 1.06 end,
        behavior = { opacity = { duration = theme.duration.normal }, scale = settle },
        kit.decor("brackets", { width = W, height = ROW_H, length = 7, color = kit.stroke("hot") }) },
      -- What it is, as an icon (the picked one lit), and the theme's code.
      kit.icon(function() return icon_of(row) end, 22, function() return picked() and accent() or kit.ink("lo")() end,
        { x = 16, y = 5, fill = picked }),
      L.code("dev" .. row.key, "##", { x = 4, y = 29, width = TX - 8, horizontal_alignment = "center" }),
      kit.text { x = TX, y = 5, width = W - TX - VW - 6, height = L.lh(S.body), elide = "right",
        text = function() return row_title(row) end, font_size = S.body, color = kit.ink("hi") },
      L.label { x = TX, y = 5 + L.lh(S.body), width = W - TX - VW - 6, elide = "right", font_size = S.micro,
        text = function() return row_sub(row) end },
      kit.text { anchors = { right = true, right_margin = 6 }, y = 5, width = VW, height = L.lh(S.body),
        horizontal_alignment = "right", elide = "right", font_size = S.body, color = color,
        text = function() return (row_value(row):gsub(" %(.*%)", "")) end },
      kit.meter { x = W - VW - 6, y = ROW_H - 14, width = VW, height = 5, count = 10, color = color,
        value = function() return level() / 100 end },
      L.rule { x = TX, y = ROW_H - 1, width = W - TX, strength = "faint" },
    }
    -- The picked row on the theme's hover plate, a shade deeper.
    return kit.hover(area, function(hovered)
      return accent():alpha(picked() and .12 or hovered and .05 or 0)
    end, math.floor(ROW_H / 4))
  end

  -- The resource mix: every kind's load on one hexagon.
  local function mix()
    if not opened() then return { 0, 0, 0, 0, 0, 0 } end
    local m = memory()
    local s = m.swap or {}
    local gpu, disk, net = 0, 0, 0
    for _, g in ipairs(model.gpus().cards or {}) do if not g.suspended then gpu = math.max(gpu, g.busy or 0) end end
    for _, d in ipairs(model.drives().drives or {}) do disk = math.max(disk, d.busy or 0) end
    for _, i in ipairs(model.network().interfaces or {}) do
      if not i.virtual then
        net = math.max(net, 100 * math.min(1, math.log(1 + (i.rx_rate or 0) + (i.tx_rate or 0), 10) / 8.1))
      end
    end
    local function f(v) return .06 + .94 * math.max(0, math.min(1, v / 100)) end
    return { f(cpu().usage or 0), f(m.percent or 0), f(100 * (s.used or 0) / math.max(1, s.total or 1)), f(gpu), f(disk), f(net) }
  end
  local lh = L.lh(S.micro)
  local RS = RADAR_H - (L.CAPTION_H + 6) - 2 * (lh + 4) - lh - 8
  local axes = { "CPU", "Mem", "Swap", "GPU", "Disk", "Net" }
  local ry = L.CAPTION_H + 6 + lh + 4
  local radar = { x = 12, y = M.HEIGHT - RADAR_H - 12, width = RW_, height = RADAR_H,
    L.caption { width = RW_, text = "Resource mix", note = function() return pct(cpu().usage) .. " CPU" end },
    kit.radar { x = math.floor((RW_ - RS) / 2), y = ry, size = RS, values = mix },
  }
  for k, name in ipairs(axes) do
    local a = math.rad(360 * (k - 1) / 6)
    local cx = RW_ / 2 + (RS / 2 + 22) * math.sin(a)
    local cy = ry + RS / 2 - (RS / 2 + lh / 2 + 3) * math.cos(a)
    radar[#radar + 1] = L.label { x = cx - 22, y = cy - lh / 2, width = 44, horizontal_alignment = "center", text = name,
      font_size = S.micro, color = kit.ink("hi") }
  end
  radar[#radar + 1] = L.code("mix", "CMS DIAG CONTROL  ·  ##.##", { x = 0, y = RADAR_H - lh, width = RW_ })

  local LIST_Y = TITLE_Y + L.heading_h(S.title) + 8
  local side = L.card {
    id = "performance-devices", key = "perf-devices", header = false,
    width = SIDE_W, height = M.HEIGHT,
    L.heading { id = "performance-devices-title", active = opened, x = 12, y = TITLE_Y, width = RW_ - 130, text = "Devices" },
    L.label { anchors = { right = true, right_margin = 12 }, y = TITLE_Y + math.floor((L.heading_h(S.title) - L.lh(S.label)) / 2),
      width = 120, horizontal_alignment = "right",
      text = function() local n = list.devices:len() return ("%d device%s"):format(n, n == 1 and "" or "s") end },
    L.rule { x = 12, y = LIST_Y - 4, width = RW_ },
    -- Whole rows only: the list is a number of rows tall and scrolls.
    (kit.scroll({
      x = 12, y = LIST_Y, width = RW_, clip = true,
      height = math.floor((M.HEIGHT - LIST_Y - RADAR_H - 28 + 3) / (ROW_H + 3)) * (ROW_H + 3) - 3,
      ui.Repeater { as = "column", gap = 3, width = RW_, model = list.devices, delegate = device_row },
    })),
    ui.Item(radar),
  }

  local main = L.card {
    id = "performance-main", key = "perf-main", header = false,
    width = MAIN_W, height = M.HEIGHT,
    cpu_page, memory_page, drive_page, net_page, gpu_page, fan_page,
  }

  return { page = ui.Row {
    id = "dashboard-performance",
    width = M.WIDTH, height = M.HEIGHT, gap = GAP,
    side, main,
  } }
end

return M
