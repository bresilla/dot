-- Simple workspace markers matching the right-edge level pills.
-- The active marker slides between slots; a switch reveals the HUD card.
-- Geometry keeps the level pills on the right edge aligned.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local stripes = require("themes.tsugumori.stripes")
local C = theme.color
-- The few drawing helpers the rail uses.
local P = {}
local STRENGTH = { faint = .13, quiet = .24, idle = .4, mark = .72, hot = 1 }
function P.line(strength) local a = STRENGTH[strength] return function() return C.primary:alpha(a) end end
function P.signal() return function() return C.primary end end
function P.ink(kind)
  if kind == "lo" then return function() return C.onSurfaceVariant end end
  return function() return C.primary end
end
function P.label(props)
  local text = props.text
  props.text = function() local t = type(text) == "function" and text() or text return tostring(t or ""):upper() end
  props.font_family = props.font_family or theme.font
  props.color = props.color or P.ink("lo")
  return ui.Text(props)
end
function P.brackets(spec)
  local w, h, l = spec.width, spec.height, spec.length or 8
  local d = ("M0 %g V0 H%g M%g 0 H%g V%g M%g %g V%g H%g M%g %g H0 V%g"):format(
    l, l, w - l, w, l, w, h - l, h, w - l, l, h, h - l)
  return ui.Path { width = w, height = h, view_box = { 0, 0, w, h }, d = d, fill_color = "transparent",
    stroke_color = spec.color, stroke_width = 1, stroke_cap = "square" }
end
function P.hatch(spec)
  return stripes.box { x = spec.x, y = spec.y, width = spec.width, height = spec.height,
    gap = spec.spacing or 6, weight = spec.weight or 1.5, color = spec.color }
end
local V = {}

function V.geometry(model)
  local w, h = model.desk_size()
  local item, gap = 14, 10
  local track = model.count * item + (model.count - 1) * gap
  return { w = w, h = h, item = item, gap = gap, top = math.floor((h - track) / 2),
    pill_x = theme.LEFT / 2 - 3, bud_x = theme.LEFT + 8 }
end

function V.build(model)
  local W, H = 176, 92
  local function geometry() return V.geometry(model) end
  local function center(id)
    local g = geometry()
    return g.top + (id - model.base(id)) * (g.item + g.gap) + g.item / 2
  end
  local shown = morf.signal("tsugumori.rail.shown", false)
  local root = ui.Item { id = "rail", accessible_role = "navigation", accessible_name = "Workspaces",
    anchors = { fill = true }, visible = model.enabled }

  -- Slots.
  for i = 1, model.count do
    local function id() return model.base(model.active()) + i - 1 end
    ui.reparent(ui.Rect { id = "rail-pill-" .. i, x = function() return geometry().pill_x end, width = 6,
      height = function() return geometry().item end,
      y = function() return center(id()) - geometry().item / 2 end,
      color = function() return C.primary end,
      opacity = function() return model.occupied(id()) and .65 or .28 end,
      behavior = { opacity = { duration = 180 } } }, root)
  end

  -- The active marker has the same shape as every workspace slot.
  ui.reparent(ui.Rect { id = "rail-selector", x = function() return geometry().pill_x end, width = 6,
    height = function() return geometry().item end,
    y = function() return center(model.active()) - geometry().item / 2 end,
    color = function() return C.primary end,
    behavior = { y = { duration = 380, easing = "out_cubic" } } }, root)

  -- -------------------------------------------------------------- card --
  local digits = ui.Text { id = "rail-value", x = 12, y = 26, height = 36, font_size = 32,
    font_family = theme.font, font_weight = 300,
    text = function() return ("%02d"):format(model.active()) end, color = function() return C.primary end }
  local meter = ui.Item { id = "rail-meter", x = 12, y = H - 22, width = W - 24, height = 6 }
  local CELL_GAP = 2
  local cell_w = (W - 24 - CELL_GAP * (model.count - 1)) / model.count
  for i = 1, model.count do
    local function id() return model.base(model.active()) + i - 1 end
    ui.reparent(ui.Rect { x = (i - 1) * (cell_w + CELL_GAP), width = cell_w, height = 6,
      color = function()
        if id() == model.active() then return C.primary end
        return model.occupied(id()) and C.primary:alpha(.4) or C.primary:alpha(.08)
      end }, meter)
  end
  local card = ui.Item { id = "rail-swell", x = -W - 12, width = W, height = H, visible = false, opacity = 0,
    y = function() return math.max(12, math.min(geometry().h - H - 12, center(model.active()) - H / 2)) end,
    behavior = { y = { duration = 380, easing = "out_cubic" } },
    stretch = kit.STRETCH,
    ui.Rect { width = W, height = H, color = "transparent", border_width = 1, border_color = P.line("quiet") },
    P.brackets { width = W, height = H, length = 8, color = P.line("hot") },
    -- Header strip: code block, status chip, a stud.
    ui.Rect { x = 8, y = 8, width = 98, height = 11, color = function() return C.primary end },
    kit.heading { id = "rail-title", text = "Workspace", level = "caption", x = 12, y = 6, width = 92,
      font_size = 10, ink = function() return C.surface end,
      active = function() return shown:get() end, reveal_delay = 0, decode_lead = 160, decode_stagger = 20 },
    ui.Rect { x = 112, y = 8, width = 44, height = 11, color = "transparent", border_width = 1,
      border_color = P.signal("accent") },
    P.label { x = 112, y = 6, width = 44, height = 14, font_size = 10, horizontal_alignment = "center",
      color = P.ink("accent"),
      text = function() return model.occupied(model.active()) and "ACTIVE" or "EMPTY" end },
    ui.Rect { x = W - 15, y = 9, width = 7, height = 7, color = P.line("mark") },
    ui.Rect { x = 8, y = 23, width = W - 16, height = 1, color = P.line("quiet") },
    digits,
    P.label { x = 64, y = 32, text = function() return ("/%02d"):format(model.base(model.active()) + model.count - 1) end,
      font_size = 10, color = P.ink("lo") },
    P.label { x = 104, y = 32, width = W - 112, font_size = 10, color = P.ink("accent"), elide = "right",
      text = function()
        local n = 0
        local b = model.base(model.active())
        for i = b, b + model.count - 1 do if model.occupied(i) then n = n + 1 end end
        return ("OCC %02d/%02d"):format(n, model.count)
      end },
    P.hatch { x = 104, y = 52, width = W - 116, height = 8, spacing = 5, weight = 1.5, color = P.line("mark") },
    meter,
  }
  local shape = ui.SdfShape { id = "rail-swell-background", shape = "box", radius = 0,
    operation = "smooth_union", blend = 6, track = card, opacity = 0 }
  ui.reparent(card, root)
  kit.ride("rail", root, model.leftbar.drawer,
    function() return theme.SIDE_W + theme.STRIP / 2 + theme.LEFT / 2 end)

  local motion, hide
  local function cancel()
    if hide then hide:cancel() hide = nil end
    if motion then motion:stop() motion = nil end
  end
  local function close(immediate)
    cancel() shown:set(false)
    if immediate then
      card.visible, card.opacity, shape.opacity = false, 0, 0
      card.x = -W - 12
      return
    end
    motion = morf.animation.play { { parallel = {
      { node = card, property = "x", to = -W - 12, duration = 260, easing = "in_out_quint" },
      { node = card, property = "opacity", to = 0, duration = 180 },
      { node = shape, property = "opacity", to = 0, duration = 180 },
    } }, on_finished = function(reason) if reason == "completed" then card.visible = false end end }
  end
  local function pop()
    cancel() shown:set(true) card.visible = true
    motion = morf.animation.play { { parallel = {
      { node = card, property = "x", to = geometry().bud_x, duration = 340, easing = "out_expo" },
      { node = card, property = "opacity", to = 1, duration = 180 },
      { node = shape, property = "opacity", to = 1, duration = 180 },
      { node = digits, property = "translate_y", from = -8, to = 0, duration = 280, easing = "out_cubic" },
      { node = digits, property = "opacity", from = 0, to = 1, duration = 180 },
    } } }
    hide = morf.timer(model.hold(), function() hide = nil close(false) end, false)
  end

  local last = model.active()
  morf.effect("tsugumori.rail.follow", function()
    local id, on = model.active(), model.enabled()
    local changed = id ~= last
    last = id
    if not on then close(true) elseif changed then pop() end
  end, { owner = root })
  return { node = root, shape = shape }
end
return V
