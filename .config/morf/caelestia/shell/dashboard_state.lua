-- What the dashboard's tabs share: which tab is chosen, whether the drawer
-- is open, and the pointer areas on the panel (the panel counts as hovered
-- while any of them is; see NEEDS.md, "hover that contains its children").
-- Each tab's page is its own module, built as it loads, so each gets its
-- own instruction budget.

local morf = require("morf")
local ui = require("morf.ui")
local sysinfo = require("lib.services.sysinfo")
local session = require("themes.session")
sysinfo.restore_history(session.restore("graphs"))
session.register("graphs",sysinfo.snapshot_history)

-- Keep one graph's worth of recent activity even before its tab is opened.
-- sysinfo's fixed-size rings overwrite the oldest sample; nothing is written
-- to disk. Only graph sources stay awake, not process scans or other services.
-- The pages still stop reading these sources while hidden, so collecting
-- history does not keep their UI bindings updating.
for _, name in ipairs { "cpu", "memory", "drives", "network", "gpu", "fans", "battery" } do
  sysinfo.sources[name]:pin(true)
end

local M = {}

M.tab = require("themes.session").keep("caelestia.dashboard.tab", 1)
M.displayed = require("themes.session").keep("caelestia.dashboard.displayed", 1)
M.opened = morf.signal("caelestia.dashboard.shown", false)

-- Inspect collection without reading a source (which would wake an idle
-- sampler and hide a background-sampling failure).
function M.history_status()
  local status = { opened = M.opened:get(), limit = sysinfo.history_size, sources = {} }
  for _, name in ipairs { "cpu", "memory", "drives", "network", "gpu", "fans", "battery" } do
    local source = sysinfo.sources[name]
    status.sources[name] = { samples = source.samples, running = source:running(),
      updated = source.updated, error = source.error }
  end
  return status
end

M.areas = {}

--- A MouseArea the panel counts as its own for hover.
function M.area(props)
  local a = props.cursor == "pointer" and require("kit").action(props) or ui.MouseArea(props)
  M.areas[#M.areas + 1] = a
  return a
end

--- What page `i` is given: whether it is on screen (the drawer open and its
--- tab chosen -- the pages read their services only then; graph history
--- continues collecting above), whether its tab
--- is chosen, and `area`.
function M.context(i)
  return {
    opened = function() return M.opened:get() and M.displayed:get() == i end,
    current = function() return M.displayed:get() == i end,
    area = M.area,
  }
end

return M
