-- Material workspace rail geometry and liquid indicator motion.
local morf=require("morf")
local ui=require("morf.ui")
local theme=require("theme")
local kit=require("kit")
local C=theme.color
local V={}
local PILL_W=6
local function slot_y(g,id,base) return g.top+(id-base(id))*(g.item+g.gap) end
function V.geometry(model)
  local w, h = model.desk_size()
  local scale = math.min(w, h) / 2160
  local track = math.floor(h * 0.5)
  local gap = math.max(3, math.floor(10 * scale + 0.5))
  local item = (track - gap * (model.count - 1)) / model.count
  return {
    w = w, h = h,
    top = math.floor((h - track) / 2),
    gap = gap, item = item,
    -- The pill, centred in the left border; the bud, a disc the pill's
    -- height, clear of the border by a gap.
    pill_x = theme.LEFT / 2 - PILL_W / 2,
    bud_x = theme.LEFT + math.max(8, math.floor(14 * scale)),
  }
end


function V.build(model)
  local enabled = model.enabled
  local base=model.base
  local lit

  -- The pill lit as the active one: none while the accent is out as the
  -- bud, the new one's once the bud has closed into it.
  lit = morf.signal("caelestia.rail.lit", model.active())
  local pills = {}
  for i = 1, model.count do
    local function id() return base(model.active()) + i - 1 end
    local pill = kit.surface {
      id = "rail-pill-" .. i,
      x = (theme.LEFT - PILL_W) / 2, width = PILL_W,
      height = function() return V.geometry(model).item end,
      radius = PILL_W / 2,
      color = function()
        if lit:get() == id() then return C.primary end
        return model.occupied(id()) and C.onSurfaceVariant or C.outlineVariant
      end,
      -- No easing: the accent does not fade from pill to pill, it moves
      -- (the bud below), and hands over in a frame where the two are the
      -- same shape.
    }
    -- Only to look at: the pointer near them opens the left panel.
    pill.y = function() local g = V.geometry(model) return g.top + (i - 1) * (g.item + g.gap) end
    pill.opacity = function() return lit:get() == id() and 1 or 0.6 end
    pills[i] = pill
  end

  -- The swell: a box in the frame's own field (`M.shape`, which init.lua
  -- adds to it), joined with the frame's seam as a drawer is -- the frame
  -- bulging out beside a pill, the pill's height and a margin. It carries
  -- the bud: the lit pill, which rides out in it and opens into a disc
  -- with the number. Tucked, the swell is past the screen's edge.
  local g0 = V.geometry(model)
  local PAD = math.max(5, math.floor(g0.item * 0.12))
  local function swell_w(g) return theme.LEFT + (g.bud_x - theme.LEFT) + g.item + PAD end
  local function tucked_x(g) return -(swell_w(g) + theme.SEAM + 2) end

  local number = morf.signal("caelestia.rail.number", "")
  -- The number: its digits morph from one workspace's to the next.
  local label = ui.Item {
    id = "rail-number",
    anchors = { center_in = true },
    width = 3 * math.floor(math.floor(g0.item * 0.32) * 0.62 + 0.5),
    height = math.floor(g0.item * 0.32),
    opacity = 0,
    kit.morph_number {
      id = "rail-digits",
      value = function() return number:get() end,
      size = math.floor(g0.item * 0.32),
      color = function() return C.onPrimary end,
      duration = 300,
    },
  }
  local bud = ui.Item {
    id = "rail-bud",
    x = g0.pill_x, y = g0.top, width = PILL_W, height = g0.item,
    label,
  }
  -- At rest it is nothing at all: no size, so a panel sliding the rail
  -- out carries nothing that could show. It takes its size only while it
  -- is out (see `pop` and `tuck`).
  local swell = ui.Item {
    id = "rail-swell",
    x = tucked_x(g0), y = g0.top - PAD,
    width = 0, height = 0,
  }
  local shape = ui.SdfShape {
    id = "rail-swell-background",
    shape = "box",
    operation = "smooth_union",
    blend_group = 1000,
    track = swell,
    opacity = 0,
    top_left_radius = 0, bottom_left_radius = 0,
    top_right_radius = 9999, bottom_right_radius = 9999,
  }

  local shown = morf.signal("caelestia.rail.shown", false)
  local field = ui.Sdf {
    id = "rail-field",
    anchors = { fill = true },
    fill_color = function() return C.primary end,
    opacity = function() return shown:get() and 1 or 0 end,
    ui.SdfShape { shape = "box", radius = 9999, track = bud },
  }

  -- --------------------------------------------------------- motion --

  local function stop(handle) if handle then handle:stop() end end

  -- The swell's two edges along y travel apart: the one in front sets off
  -- at once and fast, the one behind waits and follows, so it stretches
  -- along the edge towards the new pill and draws itself in there.
  local SLIDE = { reach = 0.6, wait = 0.1, lead = theme.ease.emphasized_decel, trail = theme.ease.standard }
  local function stretch_to(y1, h1, duration)
    local o = SLIDE
    local l0, r0 = swell.y, swell.y + swell.height
    local l1, r1 = y1, y1 + h1
    local forward = (l1 + r1) >= (l0 + r0)
    local function edge(from, to, t, leading)
      local u
      if leading then u = math.min(1, t / o.reach)
      else u = math.max(0, math.min(1, (t - o.wait) / (1 - o.wait))) end
      return from + (to - from) * morf.easing.value(leading and o.lead or o.trail, u)
    end
    local pos, len = {}, {}
    for i = 0, 30 do
      local t = i / 30
      local l = edge(l0, l1, t, not forward)
      local r = edge(r0, r1, t, forward)
      pos[#pos + 1] = { at = t, value = l }
      len[#len + 1] = { at = t, value = math.max(2 * PAD + PILL_W, r - l) }
    end
    local bpos, blen = {}, {}
    for i, k in ipairs(pos) do
      bpos[i] = { at = k.at, value = k.value + PAD }
      blen[i] = { at = k.at, value = len[i].value - 2 * PAD }
    end
    return {
      { node = swell, property = "y", duration = duration, keyframes = pos },
      { node = swell, property = "height", duration = duration, keyframes = len },
      { node = bud, property = "y", duration = duration, keyframes = bpos },
      { node = bud, property = "height", duration = duration, keyframes = blen },
    }
  end

  -- The bud opens out of the pill into the disc (or closes back into
  -- it) on one curve, and the swell's far edge keeps just past the
  -- bud's: out, it rises from inside the frame over the first quarter and
  -- then carries the bud; in, it carries the bud down and sinks away over
  -- the last part, once the bud is a pill again.
  local function smooth(t) t = math.max(0, math.min(1, t)) return t * t * (3 - 2 * t) end
  local function reach(out, duration, easing, delay)
    local g = V.geometry(model)
    local w = swell_w(g)
    local hidden = tucked_x(g) + w -- the swell's far edge, tucked
    local bx0, bw0, r0 = bud.x, bud.width, swell.x + w
    local bx1 = out and g.bud_x or g.pill_x
    local bw1 = out and g.item or PILL_W
    local sx, bx, bw = {}, {}, {}
    local N = 30
    for i = 0, N do
      local t = i / N
      local u = morf.easing.value(easing, out and t or math.min(1, t / 0.75))
      local x = bx0 + (bx1 - bx0) * u
      local width = bw0 + (bw1 - bw0) * u
      local carry = x + width + PAD
      local r
      if out then r = r0 + (carry - r0) * smooth(t / 0.25)
      else r = carry + (hidden - carry) * smooth((t - 0.6) / 0.4) end
      sx[#sx + 1] = { at = t, value = r - w }
      bx[#bx + 1] = { at = t, value = x }
      bw[#bw + 1] = { at = t, value = width }
    end
    return {
      { node = swell, property = "x", duration = duration, keyframes = sx, delay = delay },
      { node = bud, property = "x", duration = duration, keyframes = bx, delay = delay },
      { node = bud, property = "width", duration = duration, keyframes = bw, delay = delay },
    }
  end

  local across, along, words, hide, travel
  local last -- the workspace the bud last showed
  local function whole(id) return ("%d"):format(math.floor(id + 0.5)) end

  -- The number comes up into the bud, or goes down out of it; between
-- workspaces its digits morph (kit.morph_number).
  local function number_in(from_below, delay)
    stop(words)
    local rise = V.geometry(model).item * 0.3
    words = morf.animation.play {
      {
        parallel = {
          { node = label, property = "translate_y", from = from_below and rise or -rise, to = 0,
            duration = 340, easing = theme.ease.spatial, delay = delay },
          { node = label, property = "scale", from = 0.6, to = 1, duration = 340, easing = theme.ease.spatial, delay = delay },
          { node = label, property = "opacity", from = 0, to = 1, duration = 180, delay = delay },
        },
      },
    }
  end
  local function number_out(to_below, done)
    stop(words)
    local rise = V.geometry(model).item * 0.3
    words = morf.animation.play {
      {
        parallel = {
          { node = label, property = "translate_y", to = to_below and rise or -rise, duration = 140, easing = "in_cubic" },
          { node = label, property = "scale", to = 0.6, duration = 140, easing = "in_cubic" },
          { node = label, property = "opacity", to = 0, duration = 120, easing = "in_cubic" },
        },
      },
      on_finished = done,
    }
  end

  local function tuck()
    -- The number sinks; the swell sinks back into the frame, the bud
    -- closing into the pill it sits by, to exactly its shape -- and then
    -- it is that pill's accent, in the same frame.
    number_out(true)
    stop(across)
    local steps = reach(false, 300, theme.ease.emphasized_accel, 60)
    local id = last
    across = morf.animation.play {
      { parallel = steps },
      on_finished = function(reason)
        if reason ~= "completed" then return end
        lit:set(id)
        shown:set(false)
        -- Sunk back: nothing again, until the next switch.
        swell.width, swell.height = 0, 0
        shape.opacity = 0
      end,
    }
  end

  local function pop(id)
    shape.opacity = 1
    local g = V.geometry(model)
    local y = slot_y(g, id, base)
    local down = not last or id > last
    if travel then travel:cancel() travel = nil end
    if not shown:get() then
      -- From the pill it was on (or the new one's, from another group of
      -- ten): the frame swells out beside it and the pill rides out into
      -- the swell, opening into the disc; then the swell flows along the
      -- edge to the new pill.
      local from = (last and base(last) == base(id)) and slot_y(g, last, base) or y
      stop(along)
      swell.x, swell.y = tucked_x(g), from - PAD
      swell.width, swell.height = swell_w(g), g.item + 2 * PAD
      bud.x, bud.y, bud.width, bud.height = g.pill_x, from, PILL_W, g.item
      label.opacity = 0
      -- It comes out with the number of where it was, which morphs into
      -- the one of where it goes as it travels there.
      number:set(whole(last or id))
      shown:set(true)
      lit:set(0)
      stop(across)
      across = morf.animation.play { { parallel = reach(true, 300, theme.ease.spatial) } }
      number_in(down, 90)
      if from ~= y then
        travel = morf.timer(140, function()
          travel = nil
          number:set(whole(id))
          stop(along)
          along = morf.animation.play { { parallel = stretch_to(y - PAD, g.item + 2 * PAD, 320) } }
        end, false)
      else
        number:set(whole(id))
      end
    else
      -- Out already, or on its way back: out again, flowing to the new
      -- pill, the number rolling over.
      if swell.x < -0.5 then
        stop(across)
        across = morf.animation.play { { parallel = reach(true, 260, theme.ease.spatial) } }
      end
      if math.abs(swell.y - (y - PAD)) > 0.5 then
        stop(along)
        along = morf.animation.play { { parallel = stretch_to(y - PAD, g.item + 2 * PAD, 300) } }
      end
      -- The digits morph on to the new number.
      number:set(whole(id))
      if label.opacity < 1 then number_in(down, 0) end
    end
    last = id
    if hide then hide:cancel() end
    hide = morf.timer(model.hold() + (travel and 460 or 0), function()
      hide = nil
      tuck()
    end, false)
  end

  local first = true
  morf.effect("caelestia.rail.follow", function()
    local id = model.active()
    if first then first = false last = id lit:set(id) return end
    if not enabled() then
      stop(across) stop(along) stop(words)
      if hide then hide:cancel() hide=nil end
      if travel then travel:cancel() travel=nil end
      local g=V.geometry(model)
      lit:set(id) last=id shown:set(false)
      shape.opacity,label.opacity=0,0
      swell.width,swell.height,swell.x=0,0,tucked_x(g)
      bud.x,bud.y,bud.width,bud.height=g.pill_x,slot_y(g,id,base),PILL_W,g.item
      return
    end
    if id == last then return end
    pop(id)
  end)

  local root = ui.Item {
    id = "rail", accessible_role = "navigation", accessible_name = "Workspaces",
    anchors = { fill = true },
    visible = enabled,
    ui.Item { anchors = { fill = true }, table.unpack(pills) },
    swell,
    field,
    bud,
  }
  -- The left panel opening carries the rail out with it, to the strip on
  -- its far side: between the panel and the desk.
  local leftbar = model.leftbar
  kit.ride("rail", root, leftbar.drawer,
    function() return theme.SIDE_W + theme.STRIP / 2 + theme.LEFT / 2 end)
  return {node=root,shape=shape}
end

return V
