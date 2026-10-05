-- Tsugumori's looks for the Drag archetype's widgets: square and
-- technical. Dividers are hairlines with three studs that part; carried
-- rows, tabs and tiles leave a hatched print where they lifted from and
-- take a primary frame with registration brackets; a swiped card draws a
-- threshold rule under itself; a row's actions are square primary and
-- error blocks; pulling turns a diamond reticle that fills as it nears
-- the threshold; the sheet's grip is a stud rail; a drop target's
-- brackets close in over a hatch while it would take what is over it.
-- Nothing squashes or stretches. Behaviour is lib.kit.drag's and the
-- archetype's.
local ui = require("morf.ui")
local stripes = require("themes.tsugumori.stripes")
local stroke = require("themes.tsugumori.strokes")

return function(S, theme, M, hud)
  local C = theme.color
  local quick = { duration = 140, easing = "out_cubic" }
  local snap = { duration = 220, easing = "out_expo" }
  local function W(t) return (t.width and t.width > 0) and t.width or 0 end
  local function H(t) return (t.height and t.height > 0) and t.height or 0 end
  local function clamp01(v) return v < 0 and 0 or (v > 1 and 1 or v) end
  local function num(v, fallback) return type(v) == "number" and v or fallback end

  local function brackets(t, length, visible)
    return hud().corners { length = length or 6, weight = 2, color = function() return C.primary end,
      visible = visible or function() return t.visual_focus end }
  end

  -- A hatched print, `w` x `h`, of a carried thing (shown while it is
  -- lifted, offset behind it: the place it came up from).
  local function print_of(t, spec, w, h)
    w, h = num(spec.width, w), num(spec.height, h)
    return ui.Item { anchors = { fill = true }, opacity = function() return t.active and 1 or 0 end,
      behavior = { opacity = quick },
      stripes.box { x = 5, y = 5, width = w, height = h, gap = 6, weight = 1,
        color = function() return C.primary:alpha(0.45) end } }
  end

  -- A square frame: the container tone, a hairline, primary and bracketed
  -- while it is carried.
  local function frame(t, rest)
    return ui.Item { anchors = { fill = true },
      ui.Rect { anchors = { fill = true },
        color = function()
          local base = rest and rest() or C.surfaceContainer
          if t.active then return C.surfaceContainerHigh end
          return base
        end,
        border_width = 1,
        border_color = function() return (t.active or t.hovered) and C.primary or stroke(C, "idle") end,
        behavior = { color = quick, border_color = quick } },
      ui.Rect { anchors = { fill = true, margins = 1 }, color = function() return C.primary end,
        opacity = function() return t.down and not t.active and 0.14 or (t.hovered and 0.05 or 0) end,
        behavior = { opacity = quick } },
      brackets(t, 6, function() return t.active or t.visual_focus end) }
  end

  -- Three square studs along `across`, parting while hovered or held.
  local function studs(t, across)
    local node = ui.Item { anchors = { fill = true } }
    for i = -1, 1 do
      local function at() return i * ((t.active or t.hovered) and 8 or 5) end
      ui.reparent(ui.Rect { width = 3, height = 3,
        x = function() return W(t) / 2 - 1.5 + (across and 0 or at()) end,
        y = function() return H(t) / 2 - 1.5 + (across and at() or 0) end,
        color = function() return t.active and C.primary or C.outline end,
        behavior = { x = quick, y = quick, color = quick } }, node)
    end
    return node
  end

  -- A divider: a hairline through the studs, primary while it is held.
  local function divider(t, spec, extra)
    local across = (spec.axis or "x") == "x"
    local slots = {
      background = ui.Item { anchors = { fill = true },
        ui.Rect {
          x = function() return across and math.floor(W(t) / 2) or 0 end,
          y = function() return across and 0 or math.floor(H(t) / 2) end,
          width = function() return across and 1 or W(t) end,
          height = function() return across and H(t) or 1 end,
          color = function() return t.active and C.primary or stroke(C, t.hovered and "hover" or "idle") end,
          behavior = { color = quick } },
        brackets(t, 4) },
      handle = ui.Item { anchors = { fill = true },
        ui.Rect { width = across and 7 or 30, height = across and 30 or 7,
          x = function() return (W(t) - (across and 7 or 30)) / 2 end,
          y = function() return (H(t) - (across and 30 or 7)) / 2 end,
          color = function() return C.surface end, border_width = 1,
          border_color = function() return t.active and C.primary or stroke(C, "idle") end },
        studs(t, across) },
    }
    for k, v in pairs(extra or {}) do slots[k] = v end
    return slots
  end

  S.split_pane = function(t, spec) return divider(t, spec) end

  --- A panel's edge: the divider, and while it is dragged a framed
  --- readout of the width beside it.
  S.resizable_panel = function(t, spec)
    return divider(t, spec, {
      ghost = ui.Rect { x = -70, y = function() return H(t) / 2 - 13 end, width = 62, height = 26,
        color = function() return C.surface end, border_width = 1, border_color = function() return C.primary end,
        opacity = function() return t.active and 1 or 0 end, behavior = { opacity = quick },
        M.menu_label { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
          color = function() return C.primary end,
          text = function() return ("W %d"):format(math.floor((t.value or 0) + 0.5)) end } },
    })
  end

  --- A corner grip: a hatched right triangle, primary while held.
  S.resize_grip = function(t)
    return {
      background = ui.Item { anchors = { fill = true }, brackets(t, 4) },
      handle = ui.Path { anchors = { fill = true, margins = 3 }, view_box = { 0, 0, 18, 18 },
        d = "M18 0 V18 H0 Z M18 6 L6 18 M18 12 L12 18", fill_color = "transparent", stroke_width = 1,
        stroke_color = function() return t.active and C.primary or (t.hovered and C.onSurface or C.outline) end },
    }
  end

  --- A row that is carried: a square frame with a stud grip and a caps
  --- label; lifted, its hatched print stays behind it.
  S.reorderable_rows = function(t, spec)
    local grip = ui.Item { x = 12, width = 10, height = 16, anchors = { vertical_center = true } }
    for r = 0, 2 do
      for c = 0, 1 do
        ui.reparent(ui.Rect { x = c * 6, y = r * 6, width = 3, height = 3,
          color = function() return t.active and C.primary or C.outline end }, grip)
      end
    end
    return {
      background = ui.Item { anchors = { fill = true }, print_of(t, spec, 280, 48), frame(t) },
      handle = ui.Item { anchors = { fill = true }, grip,
        ui.Rect { width = 3, anchors = { top = true, bottom = true }, color = function() return C.primary end,
          opacity = function() return t.active and 1 or 0 end, behavior = { opacity = quick } } },
      content = ui.Item { anchors = { fill = true },
        spec.icon and M.icon(spec.icon, 18, function() return t.active and C.primary or C.onSurfaceVariant end,
          { x = 36, anchors = { vertical_center = true } }) or nil,
        M.menu_label { x = spec.icon and 66 or 36, anchors = { vertical_center = true },
          text = tostring(spec.label or ""):upper(),
          color = function() return t.active and C.primary or C.onSurface end } },
    }
  end

  --- A tab that is carried: caps, the current one primary over a full
  --- rule; carried, it takes a frame over its hatched print.
  S.reorderable_tabs = function(t, spec)
    return {
      handle = ui.Item {},
      background = ui.Item { anchors = { fill = true },
        print_of(t, spec, 88, 40),
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end, border_width = 1,
          border_color = function() return C.primary end, opacity = function() return t.active and 1 or 0 end,
          behavior = { opacity = quick } },
        ui.Rect { anchors = { fill = true }, color = function() return C.primary end,
          opacity = function() return t.down and 0.14 or (t.hovered and 0.05 or 0) end, behavior = { opacity = quick } },
        ui.Rect { anchors = { left = true, right = true, bottom = true },
          height = function() return t.highlighted and 2 or 1 end,
          color = function() return t.highlighted and C.primary or stroke(C, "idle") end },
        brackets(t, 5) },
      content = M.menu_label { anchors = { fill = true }, horizontal_alignment = "center", vertical_alignment = "center",
        text = tostring(spec.label or ""):upper(),
        color = function() return (t.highlighted or t.active) and C.primary or C.onSurfaceVariant end },
    }
  end

  --- A tile that is carried: a square frame, its icon over a caps label;
  --- lifted, it leaves a hatched print.
  S.sortable_grid = function(t, spec)
    return {
      handle = ui.Item {},
      background = ui.Item { anchors = { fill = true }, print_of(t, spec, 88, 100), frame(t) },
      content = ui.Item { anchors = { fill = true },
        M.icon(spec.icon or "apps", 28, function() return t.active and C.primary or C.onSurface end,
          { anchors = { horizontal_center = true }, y = function() return H(t) / 2 - 30 end }),
        M.section_label { anchors = { left = true, right = true }, y = function() return H(t) / 2 + 8 end,
          horizontal_alignment = "center", elide = "right", text = tostring(spec.label or ""):upper(),
          color = function() return t.active and C.primary or C.onSurfaceVariant end } },
    }
  end

  --- A card that is swiped: a square frame whose rule along its foot
  --- measures the swipe against its distance, primary once it would go.
  S.swipe_dismiss = function(t, spec)
    local distance = num(spec.swipe_distance, 80)
    local function reach() return clamp01(math.abs(t.delta_x or 0) / distance) end
    return {
      handle = ui.Item {},
      background = frame(t),
      content = ui.Item { anchors = { fill = true },
        ui.Rect { x = 0, width = 3, anchors = { top = true, bottom = true }, color = function() return C.primary end },
        M.menu_label { x = 16, y = function() return H(t) / 2 - 19 end, text = tostring(spec.label or ""):upper(),
          color = function() return C.onSurface end },
        M.section_label { x = 16, y = function() return H(t) / 2 + 3 end, text = spec.detail or "" },
        ui.Rect { anchors = { left = true, bottom = true }, height = 2,
          width = function() return reach() * W(t) end,
          color = function() return reach() >= 1 and C.primary or stroke(C, "hover") end } },
    }
  end

  --- A row whose actions wait under its trailing edge: square blocks in
  --- the primary and the error tones, their caps labels sliding in.
  S.swipe_actions = function(t, spec)
    local reveal = spec.reveal or 128
    local actions = spec.actions or {}
    local function uncovered()
      local base = t.open and reveal or 0
      if not t.active then return base / reveal end
      return clamp01((base - (t.delta_x or 0)) / reveal)
    end
    -- (Past the trailing edge: the left one right to left.)
    local plates = ui.Item { x = function() return t.mirrored and -reveal or W(t) end, width = reveal,
      height = function() return H(t) end }
    local each = reveal / math.max(1, #actions)
    for i, action in ipairs(actions) do
      local function tone()
        if action.tone == "destructive" then return C.error, C.onError end
        return C.primary, C.onPrimary
      end
      ui.reparent(ui.Rect { x = (i - 1) * each, width = each, height = function() return H(t) end,
        color = function() return (tone()) end,
        M.icon(action.icon or "check", 20, function() local _, ink = tone() return ink end,
          { anchors = { horizontal_center = true }, y = function() return H(t) / 2 - 19 end, opacity = uncovered,
            translate_x = function() return (1 - uncovered()) * 12 end }),
        M.section_label { anchors = { left = true, right = true }, y = function() return H(t) / 2 + 4 end,
          horizontal_alignment = "center", text = tostring(action.label or ""):upper(), opacity = uncovered,
          color = function() local _, ink = tone() return ink end } }, plates)
    end
    return {
      handle = ui.Item {},
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end },
        ui.Rect { anchors = { fill = true }, color = function() return C.primary end,
          opacity = function() return t.down and 0.12 or (t.hovered and 0.05 or 0) end, behavior = { opacity = quick } },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return stroke(C, "idle") end },
        brackets(t, 5) },
      content = M.menu_label { x = 16, anchors = { vertical_center = true }, text = tostring(spec.label or ""):upper(),
        color = function() return C.onSurface end },
      drop_indicator = plates,
    }
  end

  --- Pulling to refresh: a diamond reticle that comes down and turns with
  --- the pull, its core filling as it nears the threshold, turning in
  --- steps while the list refreshes.
  S.pull_to_refresh = function(t, spec)
    local REST = spec.pull_distance or 64
    local reticle = ui.Item { width = 28, height = 28, anchors = { center_in = true },
      rotation = function() return 45 + (t.pull or 0) * 180 end,
      loop = function()
        if t.refreshing then return { rotation = { from = 45, to = 405, duration = 1100, easing = "in_out_cubic" } } end
        return nil
      end,
      ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
        border_color = function() return C.primary end },
      ui.Rect { anchors = { center_in = true }, width = 14, height = 14, color = function() return C.primary end,
        scale = function() return t.refreshing and 1 or clamp01(t.pull or 0) end } }
    return {
      background = ui.Item {},
      handle = ui.Item {},
      drop_indicator = ui.Item { width = 44, height = 44, z = 5,
        x = function() return (W(t) - 44) / 2 end,
        y = function() return t.refreshing and (REST - 44) / 2 or math.min(1.4, t.pull or 0) * REST / 2 - 22 end,
        visible = function() return t.refreshing or (t.pull or 0) > 0.02 end,
        behavior = { y = snap },
        ui.Rect { anchors = { fill = true }, color = function() return C.surface end, border_width = 1,
          border_color = function() return stroke(C, "idle") end },
        reticle },
    }
  end

  --- A sheet's grip: a hairline rail with three studs, which part and
  --- turn primary while it is held.
  S.sheet_handle = function(t)
    local rail = ui.Item { anchors = { fill = true } }
    for i = -1, 1 do
      ui.reparent(ui.Rect { y = 11, width = 6, height = 3,
        x = function() return W(t) / 2 - 3 + i * ((t.active or t.hovered) and 14 or 9) end,
        color = function() return t.active and C.primary or C.outline end,
        behavior = { x = quick, color = quick } }, rail)
    end
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return stroke(C, t.active and "focus" or "quiet") end },
        brackets(t, 5) },
      handle = rail,
    }
  end

  --- A window's title strip: a hatched band at its start, a caps title
  --- and a primary rule under it that brightens while the window moves.
  S.window_move = function(t, spec)
    local h = num(spec.height, 34)
    return {
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true, margins = 1 }, color = function() return C.primary end,
          opacity = function() return t.active and 0.1 or (t.hovered and 0.05 or 0) end, behavior = { opacity = quick } },
        ui.Item { x = 1, y = 1, width = 36, height = h - 2, clip = true,
          opacity = function() return (t.active or t.hovered) and 1 or 0.5 end, behavior = { opacity = quick },
          stripes.box { width = 36, height = h - 2, gap = 5, weight = 1, color = function() return C.primary:alpha(0.6) end } },
        ui.Rect { anchors = { left = true, right = true, bottom = true }, height = 1,
          color = function() return t.active and C.primary or C.primary:alpha(0.4) end },
        brackets(t, 5) },
      content = M.menu_label { anchors = { fill = true }, horizontal_alignment = "center",
        vertical_alignment = "center", text = tostring(spec.label or ""):upper(),
        color = function() return t.active and C.primary or C.onSurface end },
      handle = ui.Item {},
    }
  end

  local function chip_face(spec, ink)
    return ui.Row { anchors = { center_in = true }, gap = 8, align = "center",
      spec.icon and M.icon(spec.icon, 16, ink) or nil,
      M.menu_label { text = tostring(spec.label or ""):upper(), color = ink } }
  end

  --- Something to drag out: a square chip frame; carried, a hatched
  --- primary copy with brackets rides the pointer and the chip stays as
  --- an outline.
  S.drag_source = function(t, spec)
    local w, h = num(spec.width, 160), num(spec.height, 44)
    return {
      handle = ui.Item {},
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true },
          color = function() return t.active and "transparent" or C.surfaceContainer end, border_width = 1,
          border_color = function() return (t.hovered or t.active) and C.primary or stroke(C, "idle") end,
          behavior = { border_color = quick } },
        ui.Rect { anchors = { fill = true, margins = 1 }, color = function() return C.primary end,
          opacity = function() return t.down and 0.14 or (t.hovered and 0.05 or 0) end, behavior = { opacity = quick } },
        brackets(t, 5) },
      content = ui.Item { anchors = { fill = true }, opacity = function() return t.active and 0.4 or 1 end,
        chip_face(spec, function() return C.onSurface end) },
      ghost = ui.Item { width = w, height = h, z = 30,
        translate_x = function() return t.delta_x or 0 end, translate_y = function() return t.delta_y or 0 end,
        visible = function() return t.active end,
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainerHigh end, border_width = 1,
          border_color = function() return C.primary end },
        stripes.box { width = w, height = h, gap = 6, weight = 1, color = function() return C.primary:alpha(0.25) end },
        hud().corners { length = 7, weight = 2, color = function() return C.primary end },
        chip_face(spec, function() return C.primary end) },
    }
  end

  --- Where a drag lands: a hairline frame with registration brackets
  --- round an icon and a caps caption; while a drag it would take is over
  --- it the brackets close in, a hatch comes up under them, the frame and
  --- caption turn primary and the icon swells.
  S.drop_zone = function(t, spec)
    local w, h = num(spec.width, 280), num(spec.height, 104)
    return {
      handle = ui.Item {},
      background = ui.Item { anchors = { fill = true },
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end, border_width = 1,
          border_color = function() return t.accepting and C.primary or stroke(C, "idle") end,
          behavior = { border_color = quick } },
        ui.Item { anchors = { fill = true }, clip = true, opacity = function() return t.accepting and 1 or 0 end,
          behavior = { opacity = quick },
          stripes.box { width = w, height = h, gap = 8, weight = 1, color = function() return C.primary:alpha(0.18) end } },
        ui.Item { anchors = { fill = true, margins = 6 },
          scale = function() return t.accepting and 0.95 or 1 end, behavior = { scale = snap },
          hud().corners { length = 12, weight = 2,
            color = function() return t.accepting and C.primary or stroke(C, "corner") end } } },
      content = ui.Item { anchors = { fill = true },
        M.icon(spec.icon or "upload", 28, function() return t.accepting and C.primary or C.onSurfaceVariant end,
          { anchors = { horizontal_center = true }, y = function() return H(t) / 2 - 32 end,
            scale = function() return t.accepting and 1.25 or 1 end, behavior = { scale = snap } }),
        M.menu_label { anchors = { left = true, right = true }, y = function() return H(t) / 2 + 8 end,
          horizontal_alignment = "center", text = tostring(spec.label or "Drop here"):upper(),
          color = function() return t.accepting and C.primary or C.onSurfaceVariant end } },
    }
  end

  -- ------------------------------------------------------ slide to confirm --

  --- Slide to confirm: a square channel in a hairline, its prompt in caps
  --- fading as the knob -- a primary block with a double chevron -- is
  --- slid across; a hatched run follows it in (its clip moves, the stripes
  --- stay put). Let go short, the knob shutters home; all the way, it
  --- shows a tick for a moment.
  function S.slide_to_confirm(t, spec)
    local K = t.knob or 52
    local bw, bh = num(spec.width, 280), num(spec.height, 52)
    local function along() return (t.value or 0) * (t.extent or 0) end
    local function offset() return along() + K - bw end
    local run = ui.Item { anchors = { fill = true }, translate_x = function() return -offset() end,
      behavior = { translate_x = snap },
      stripes.box { width = bw, height = bh, gap = 7, weight = 2, color = function() return C.primary:alpha(.3) end } }
    return {
      background = ui.Item { anchors = { fill = true },
        opacity = function() return t.enabled == false and 0.4 or 1 end,
        ui.Rect { anchors = { fill = true }, color = function() return C.surfaceContainer end },
        ui.Item { anchors = { fill = true }, clip = true,
          ui.Item { anchors = { fill = true }, translate_x = offset, behavior = { translate_x = snap },
            ui.Item { anchors = { fill = true }, clip = true, run } } },
        ui.Rect { anchors = { fill = true }, color = "transparent", border_width = 1,
          border_color = function() return stroke(C, (t.hovered or t.active) and "hover" or "idle") end,
          behavior = { border_color = quick } } },
      content = M.text { anchors = { fill = true, left_margin = K, right_margin = 12 }, horizontal_alignment = "center",
        vertical_alignment = "center", elide = "right",
        text = function()
          return tostring(t.done and (spec.done_label or "Done") or (spec.label or "Slide to confirm")):upper()
        end,
        font_size = theme.typography.menu, font_weight = 500, color = function() return C.onSurfaceVariant end,
        opacity = function() return t.done and 1 or math.max(0, 1 - (t.value or 0) * 1.8) end,
        behavior = { opacity = quick } },
      handle = ui.Item { x = 0, y = 0, width = K, height = bh, translate_x = along, behavior = { translate_x = snap },
        ui.Rect { anchors = { fill = true, margins = 4 }, color = function() return C.primary end,
          ui.Rect { anchors = { fill = true, margins = 3 }, color = "transparent", border_width = 1,
            border_color = function() return C.onPrimary:alpha(.35) end } },
        M.icon(function() return t.done and "check" or "keyboard_double_arrow_right" end, 22,
          function() return C.onPrimary end, { anchors = { center_in = true } }) },
      drop_indicator = brackets(t, 7),
    }
  end
end
