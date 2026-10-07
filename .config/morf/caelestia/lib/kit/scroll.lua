-- Scrolled views (the Scroll archetype) around the engine's flickable.
--
--     local node, flick = scroll.make("scroll_view", {
--       id = "page", width = 400, height = 300, clip = true,
--       ui.Column { ... },                        -- the content
--     })
--
-- `node` is the control, the one to place -- it takes no pointer input of
-- its own --; `flick` the `ui.Flickable`
-- inside it, which keeps the spec's `id` and flickable properties
-- (`content_y`, `interactive`, ...). The archetype follows where it has
-- scrolled (`t.position_y`, `t.size_y`, `t.at_end`, ...), answers the
-- arrows, Page keys, Home, End and Space, and snaps (`snap = "items" |
-- "pages"`); the skin draws `scroll_bar_x`/`scroll_bar_y` from that,
-- `edge_fade` and `overscroll`. `scroll_policy_x`/`_y` say when a bar
-- shows. `on_scrolled(x, y)`, `on_reached_start`, `on_reached_end` follow
-- it.
--
-- A snapping view settles once the scrolling pauses: the archetype picks
-- the item or page, and the view glides there. A `pager` scrolls sideways
-- a page at a time (its skin draws the page dots), a `shelf` sideways an
-- item at a time (`item_size`; its skin draws edge fades and arrows), and
-- the wheel turns either sideways. An `infinite_scroll` that reaches its
-- end sets `t.loading` and calls `on_load_more(done)`; `done()` clears it
-- (the skin shows a loading row meanwhile). A skin moves the view with
-- `spec.glide(x, y)`, which eases there.
local ui = require("morf.ui")
local control = require("lib.kit.control")

local M = {}

local CONTROL = { x = true, y = true, z = true, anchors = true, visible = true, opacity = true, layout = true,
  width = true, height = true }
local SETTINGS = { content = true, scroll_policy_x = true, scroll_policy_y = true, snap = true, item_size = true, step = true,
  widget = true, on_scrolled = true, on_reached_start = true, on_reached_end = true, focus_policy = true,
  on_load_more = true, pages = true }

local DEFAULTS = {
  pager = { snap = "pages", scroll_policy_x = "never", scroll_policy_y = "never" },
  shelf = { snap = "items", item_size = 120, scroll_policy_x = "never", scroll_policy_y = "never" },
}
-- Views that scroll sideways: the wheel turns them that way.
local SIDEWAYS = { pager = true, shelf = true }
local GLIDE = { duration = 260, easing = "out_cubic" }

local function get(v) if type(v) == "function" then return v() end return v end

function M.make(widget, spec)
  local given = spec or {}
  spec = {}
  for k, v in pairs(DEFAULTS[widget] or {}) do spec[k] = v end
  for k, v in pairs(given) do spec[k] = v end
  local flick_props, control_props = { anchors = { fill = true } }, {}
  for k, v in pairs(spec) do
    if type(k) == "number" then flick_props[k] = v
    elseif CONTROL[k] then control_props[k] = v
    elseif not SETTINGS[k] then flick_props[k] = v end
  end
  local flick = ui.Flickable(flick_props)
  local settings = { widget = widget, id = spec.id and (spec.id .. "-scroll") or nil, flick = flick }
  for k, v in pairs(spec) do if SETTINGS[k] and type(k) == "string" then settings[k] = v end end
  -- (The glue's to call, not a handler for the node.)
  settings.on_load_more = nil
  -- Keys jump; a settle, a page dot or an arrow glides.
  -- (An eased offset does not wake the geometry's binding as it moves: it
  -- is told where the glide goes as it sets out, and where it is after.)
  local gliding, glide_x, glide_y
  local refresh = function() end
  local function glide(x, y)
    if gliding then gliding:stop() gliding = nil end
    x, y = x or flick.content_x or 0, y or flick.content_y or 0
    local steps = {}
    if math.abs(x - (flick.content_x or 0)) > 0.5 then
      steps[#steps + 1] = { node = flick, property = "content_x", to = x, duration = GLIDE.duration, easing = GLIDE.easing }
    end
    if math.abs(y - (flick.content_y or 0)) > 0.5 then
      steps[#steps + 1] = { node = flick, property = "content_y", to = y, duration = GLIDE.duration, easing = GLIDE.easing }
    end
    if #steps == 0 then return end
    glide_x, glide_y = x, y
    gliding = morf.animation.play { { parallel = steps }, on_finished = function() gliding = nil refresh() end }
    refresh()
  end
  local settling = false
  settings.glide = glide
  settings.on_scroll_to = function(x, y)
    if settling then glide(x, y) else
      if gliding then gliding:stop() gliding = nil end
      flick.content_x, flick.content_y = x, y
      refresh()
    end
  end
  -- Not a target for the pointer: presses go to what is in it, or under
  -- it, and the flickable scrolls itself. Keys reach it once it has focus
  -- by a policy that says so; its scroll bar, a Range, is reached by Tab.
  control_props.focus_policy = spec.focus_policy or "none"
  control_props.accepted_buttons = {}
  -- An infinite scroll asks for more as it reaches its end, once at a time.
  local t
  if widget == "infinite_scroll" then
    local given = spec.on_reached_end
    settings.on_reached_end = function(...)
      if given then given(...) end
      if t and not t.loading and spec.on_load_more then
        t.loading = true
        spec.on_load_more(function() if t then t.loading = false end end)
      end
    end
  end
  -- A sideways view turns the wheel sideways: a notch is an item (or a page).
  if SIDEWAYS[widget] then
    control_props.on_wheel = function(_, _, px, py, sx, sy)
      local steps = (sy ~= nil and sy ~= 0) and sy or (sx or 0)
      if steps == 0 then return end
      local unit = (widget == "shelf" and (get(spec.item_size) or 120)) or (flick.layout_width or 0)
      local room = math.max(0, (t and t.content_width or 0) - (flick.layout_width or 0))
      local base = gliding and glide_x or flick.content_x or 0
      local to = math.max(0, math.min(room, (math.floor(base / unit + 0.5) + (steps > 0 and 1 or -1)) * unit))
      glide(to, nil)
    end
  end
  local root, ctl
  root, t, ctl = control.make("Scroll", widget, settings, { children = { flick }, props = control_props,
    state = { loading = false } })
  -- A Flickable receives wheel input but is not itself a pointer target.
  -- Empty space between its controls must still start a touch inside its
  -- subtree, otherwise the panel behind it receives the drag instead.
  -- Keep this below the content so buttons, fields and sliders retain
  -- their own input. Cover the content as well as the viewport so it
  -- remains hittable after scrolling; exclude it from measured content.
  ui.reparent(ui.MouseArea {
    id = spec.id and (spec.id .. "-touch-background"), z = -1,
    width = function() return math.max(t.content_width or 0, flick.layout_width or 0) end,
    height = function() return math.max(t.content_height or 0, flick.layout_height or 0) end,
  }, flick)
  -- Snapping: once the scrolling pauses, the archetype settles it.
  local pause
  local function settle_soon()
    local snap = get(spec.snap)
    if snap == nil or snap == "none" or gliding then return end
    if pause then pause:cancel() end
    pause = morf.timer(140, function()
      pause = nil
      if gliding then return end
      settling = true
      pcall(ctl.send, "settle")
      settling = false
    end, false)
  end
  -- Where the flickable is, for the archetype (and the skin through it).
  -- The content's size is its children's, as laid out.
  -- (Or what `spec.content` names, or `set_content` hands it later: content
  -- reparented into the flickable after it was made.)
  local content = {}
  for _, child in ipairs(spec) do content[#content + 1] = child end
  if spec.content then content = { spec.content } end
  local generation = morf.signal("kit.scroll.content." .. tostring(flick), 0)
  morf.effect("kit.scroll.geometry." .. ctl.id, function()
    generation:get()
    local w, h = 0, 0
    for _, child in ipairs(content) do
      w = math.max(w, (child.layout_width or 0) + (tonumber(child.x) or 0))
      h = math.max(h, (child.layout_height or 0) + (tonumber(child.y) or 0))
    end
    local cx, cy = flick.content_x or 0, flick.content_y or 0
    if gliding then cx, cy = glide_x, glide_y end
    ctl.send("geometry", cx, cy, w, h,
      root.layout_width or 0, root.layout_height or 0)
    settle_soon()
  end, { owner = root })
  refresh = function() generation:set(generation:get() + 1) end
  ctl.set_content = function(node)
    content = { node }
    generation:set(generation:get() + 1)
  end
  return root, flick, t, ctl
end

return M
