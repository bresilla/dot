-- Material workspace rail geometry and liquid indicator motion. Down the
-- left edge on a desk; upright (a phone, `model.bottom`) along the bottom
-- one. The motion is written along and across its edge: `along` is y down
-- the left edge or x across the bottom; `across` is how far out of the edge,
-- x from the left or up from the bottom.
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
  local along = model.bottom and w or h
  local track = math.floor(along * 0.5)
  local gap = math.max(3, math.floor(10 * scale + 0.5))
  local item = (track - gap * (model.count - 1)) / model.count
  return {
    w = w, h = h,
    top = (model.bottom and model.start() or 0) + math.floor((along - track) / 2),
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
  local B = model.bottom
  -- A node's place along and across its edge, read and written.
  local function across_of(node) return B and (model.edge() - node.y - node.height) or node.x end
  local function along_of(node) return B and node.x or node.y end
  local function across_len(node) return B and node.height or node.width end
  local function along_len(node) return B and node.width or node.height end
  local function place(node, c, cl, a, al)
    if B then node.x, node.width, node.height, node.y = a, al, cl, model.edge() - c - cl
    else node.x, node.y, node.width, node.height = c, a, cl, al end
  end
  local AX, AL = B and "x" or "y", B and "width" or "height"

  -- The pill lit as the active one: none while the accent is out as the
  -- bud, the new one's once the bud has closed into it.
  lit = morf.signal("caelestia.rail.lit", model.active())
  local pills = {}
  for i = 1, model.count do
    local function id() return base(model.active()) + i - 1 end
    local pill = kit.surface {
      id = "rail-pill-" .. i,
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
    local function at() local g = V.geometry(model) return g.top + (i - 1) * (g.item + g.gap) end
    local function item() return V.geometry(model).item end
    if B then
      pill.x, pill.width, pill.height = at, item, PILL_W
      pill.y = function() return model.edge() - (theme.LEFT + PILL_W) / 2 end
    else
      pill.x, pill.width, pill.y, pill.height = (theme.LEFT - PILL_W) / 2, PILL_W, at, item
    end
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
  local bud = ui.Item { id = "rail-bud", label }
  place(bud, g0.pill_x, PILL_W, g0.top, g0.item)
  -- At rest it is nothing at all: no size, so a panel sliding the rail
  -- out carries nothing that could show. It takes its size only while it
  -- is out (see `pop` and `tuck`).
  local swell = ui.Item { id = "rail-swell" }
  place(swell, tucked_x(g0), 0, g0.top - PAD, 0)
  local shape = ui.SdfShape {
    id = "rail-swell-background",
    shape = "box",
    operation = "smooth_union",
    blend_group = 1000,
    track = swell,
    opacity = 0,
    -- Square where it joins the frame, round on its far side.
    top_left_radius = B and 9999 or 0, bottom_left_radius = 0,
    top_right_radius = 9999, bottom_right_radius = B and 0 or 9999,
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
    local l0, r0 = along_of(swell), along_of(swell) + along_len(swell)
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
      { node = swell, property = AX, duration = duration, keyframes = pos },
      { node = swell, property = AL, duration = duration, keyframes = len },
      { node = bud, property = AX, duration = duration, keyframes = bpos },
      { node = bud, property = AL, duration = duration, keyframes = blen },
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
    local bx0, bw0, r0 = across_of(bud), across_len(bud), across_of(swell) + w
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
    if B then
      -- Up from the bottom edge: a y is the edge less how far out and how big.
      local edge = model.edge()
      local sy, by = {}, {}
      for i, k in ipairs(sx) do sy[i] = { at = k.at, value = edge - k.value - w } end
      for i, k in ipairs(bx) do by[i] = { at = k.at, value = edge - k.value - bw[i].value } end
      return {
        { node = swell, property = "y", duration = duration, keyframes = sy, delay = delay },
        { node = bud, property = "y", duration = duration, keyframes = by, delay = delay },
        { node = bud, property = "height", duration = duration, keyframes = bw, delay = delay },
      }
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
      place(swell, tucked_x(g), swell_w(g), from - PAD, g.item + 2 * PAD)
      place(bud, g.pill_x, PILL_W, from, g.item)
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
      if across_of(swell) < -0.5 then
        stop(across)
        across = morf.animation.play { { parallel = reach(true, 260, theme.ease.spatial) } }
      end
      if math.abs(along_of(swell) - (y - PAD)) > 0.5 then
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
      place(swell,tucked_x(g),0,along_of(swell),0)
      place(bud,g.pill_x,PILL_W,slot_y(g,id,base),g.item)
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
  if not B then
    local leftbar = model.leftbar
    kit.ride("rail", root, leftbar.drawer,
      function() return theme.SIDE_W + theme.STRIP / 2 + theme.LEFT / 2 end)
  end
  return {node=root,shape=shape}
end

return V
