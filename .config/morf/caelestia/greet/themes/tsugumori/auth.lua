local stroke = require("themes.tsugumori.strokes")
-- Phase field and staged registration adapted from Tsugumori (MIT).
-- See LICENSE-Tsugumori. Receives counts, state and actions, never an authentication secret.
local morf = require("morf")
local ui = require("morf.ui")
local osk = require("lib.util.osk")
local tokens = require("themes.tsugumori.tokens")
return function(ctx, kind, W, H, main, output)
  local C = ctx.C
  local S = math.max(0.65, math.min(1.6, math.min(W / 1280, H / 1080)))
  local function s(n) return math.floor(n * S + 0.5) end
  local function text(value, props)
    props = props or {} props.text = value
    props.font_family = tokens.font
    props.font_size = props.font_size or s(14)
    props.color = props.color or function() return C.onSurface end
    return ui.Text(props)
  end
  local feedback = require("themes.tsugumori.interaction")({color=C})
  local function button(id, caption, width, action)
    local area
    -- A kit Press: the press, Tab and its keys are the archetype's.
    area = require("lib.kit.widgets").area { id = id, width = width, height = s(36), cursor = "pointer",
      on_clicked = function() if not ctx.busy:get() then action() end end,
      ui.Rect { anchors = { fill = true }, border_width = 1,
        border_color = function() return stroke(C,"focus") end,
        color = function() return area and area.hovered and C.primaryContainer or C.surfaceContainer end },
      text(caption, { anchors = { center_in = true }, font_size = s(12) }),
    }
    return feedback(area)
  end
  local function sheet() return ctx.stage:get() == "sheet" and main() end
  local function heading(value, props)
    props.text, props.active = value, sheet
    props.reveal_delay = 650
    return require("themes.tsugumori.heading")({color=C}, {
      text = function(p) return text(p.text, p) end,
    }, props)
  end
  local function person() return kind == "greet" and ctx.person() or ctx.me end
  local PW = math.min(s(560), W - s(40))
  local FOLIO = s(88)
  local INNER = PW - FOLIO - s(40)
  local compact = W < H or W < 1000
  local keyboard = compact or not ctx.keyboard_attached()
  local look = {
    panel = function() return C.surfaceContainer end,
    key = function() return C.surfaceContainerHighest end,
    key_dim = function() return C.surfaceContainerHigh end,
    accent = function() return C.primary end, on_accent = function() return C.onPrimary end,
    text = function() return C.onSurface end, dim = function() return C.onSurfaceVariant end,
    press = function() return C.secondaryContainer end, font = tokens.font, icons = tokens.icon_font, radius = 0,
  }
  local pad = osk.new { prefix = kind .. ".pattern", width = math.min(INNER, s(250)), mode = "pattern",
    active = function() return sheet() and ctx.method:get() == "pattern" and not ctx.busy:get() end,
    look = look, on_pattern = ctx.pattern }
  local kb
  if keyboard then
    kb = osk.new { prefix = kind .. ".osk",
      active = function() return sheet() and ctx.method:get() == "password" and not ctx.busy:get() end,
      action = function(props) return feedback(require("lib.kit.widgets").area(props), props.id) end, width = INNER,
      mode = "full", numbers = true, look = look,
      send = function(event)
        if event.text then ctx.type_text(event.text)
        elseif event.key == "backspace" then ctx.backspace()
        elseif event.key == "enter" then ctx.submit()
        elseif event.key == "escape" then ctx.escape() end
      end }
  end
  local function entry_height() return ctx.method:get() == "pattern" and pad.height() or s(54) end
  local function height()
    return s(kind == "greet" and 536 or 484) + entry_height()
      + (ctx.has_pattern() and s(44) or 0)
      + ((kb and ctx.method:get() == "password") and (kb.height() + s(12)) or 0)
  end
  local field = ui.Rect { id = kind .. "-field", width = INNER, height = s(54), border_width = 1,
    color = function() return C.surfaceContainerHighest end,
    border_color = function() return ctx.bad:get() and C.error or stroke(C,"focus") end,
    text(function() return ctx.typed:get() == 0 and "PASSWORD" or string.rep("|", ctx.typed:get()) end,
      { x = s(12), anchors = { vertical_center = true }, width = INNER - s(75), elide = "right" }),
    (function()
      local node = button(kind .. "-submit", ">", s(42), ctx.submit)
      node.anchors = { right = true, right_margin = s(8), vertical_center = true }
      return node
    end)(),
  }
  local phase = require("themes.tsugumori.phase")
  local access = ui.Item { id = kind .. "-access-progress", opacity = 0 }
  local glyph_count = ui.Item { opacity = 1, width = 0 }
  local glyph_running, glyph_refresh
  morf.effect(kind .. ".glyph-count", function()
    local count = math.min(64, ctx.typed:get())
    if glyph_running then glyph_running:stop() end
    if glyph_refresh then glyph_refresh(700) end
    glyph_running = morf.animation.play { { node = glyph_count, property = "width", to = count,
      duration = math.min(700, 100 * math.sqrt(math.max(1, math.abs(count - glyph_count.width)))), easing = "out_cubic" } }
  end, { owner = glyph_count })
  local rows = { x = FOLIO + s(20), y = s(20), width = INNER, gap = s(12),
    heading(kind == "lock" and "01 / SESSION ACCESS" or "01 / LOGIN TERMINAL", {
      id = kind .. "-access-title", width = INNER, font_size = s(tokens.typography.section), color = function() return C.primary end }),
    ui.Rect { width = INNER, height = 1, color = function() return stroke(C,"quiet") end },
    heading(function() local p = person() return p.label ~= "" and p.label or p.name end,
      { id = kind .. "-name", width = INNER, elide = "right", font_size = s(tokens.typography.hero), height = s(34) }),
  }
  if kind == "greet" then
    rows[#rows + 1] = ui.Row { gap = s(8),
      button("greet-previous-user", "< ACCOUNT", (INNER - s(8)) / 2, function() ctx.step_person(-1) end),
      button("greet-next-user", "ACCOUNT >", (INNER - s(8)) / 2, function() ctx.step_person(1) end),
    }
  end
  local clock = ui.Row { width = INNER, height = s(56), gap = s(16),
    text(function() return ctx.clock:get() end, { font_size = s(36), color = function() return C.primary end }),
    text(function() return ctx.day:get() end, { width = INNER - s(160), font_size = s(11), wrap = true }),
  }
  rows[#rows + 1] = clock
  local glyph
  glyph, glyph_refresh = phase.field(C, function() return access.opacity end,
    { id = kind .. "-compound-glyph", width = s(162), height = s(162), x = (INNER-s(162))/2 },
    function() return glyph_count.width end)
  rows[#rows + 1] = ui.Item { width = INNER, height = s(174), glyph }
  rows[#rows + 1] = ui.Item { width = INNER, height = entry_height,
    ui.Item { width = INNER, height = s(54), visible = function() return ctx.method:get() == "password" end, field },
    ui.Item { width = INNER, height = pad.height, visible = function() return ctx.method:get() == "pattern" end,
      (function() pad.node.anchors = { horizontal_center = true } return pad.node end)() },
  }
  rows[#rows + 1] = text(function() return ctx.message:get() end, {
    id = kind .. "-message", width = INNER, height = s(38), wrap = true, font_size = s(12),
    color = function() return ctx.bad:get() and C.error or C.onSurfaceVariant end,
  })
  local method = button(kind .. "-method", function() return ctx.method:get() == "pattern" and "USE PASSWORD" or "USE PATTERN" end,
    INNER, function() ctx.method:set(ctx.method:get() == "pattern" and "password" or "pattern") ctx.clear() ctx.say("") end)
  method.visible = ctx.has_pattern
  method.height = function() return ctx.has_pattern() and s(36) or 0 end
  rows[#rows + 1] = method
  if kind == "greet" then
    rows[#rows + 1] = button("greet-session", function() local sn = ctx.session() return sn and sn.name or "NO SESSIONS" end,
      INNER, function() ctx.step_session(1) end)
  end
  if kb then
    rows[#rows + 1] = ui.Item { width = INNER,
      height = function() return ctx.method:get() == "password" and kb.height() or 0 end,
      visible = function() return ctx.method:get() == "password" end, kb.node }
  end
  local content = ui.Column(rows)
  local folio = ui.Rect { id = kind .. "-folio", x = 1, y = 1, width = FOLIO,
    height = function() return height()-2 end, color = function() return C.primary end, opacity = 0,
    text("TYPE / 17", { anchors = { horizontal_center = true }, y = s(20), font_size = s(11), color = function() return C.onPrimary end }),
    text("TS", { anchors = { center_in = true }, font_size = s(42), color = function() return C.onPrimary end }),
    text("ACCESS", { anchors = { bottom = true, bottom_margin = s(20), horizontal_center = true }, font_size = s(11), color = function() return C.onPrimary end }),
  }
  local glance = ui.Column { id = kind .. "-glance", x = compact and s(40) or math.floor(W * 0.09),
    y = math.floor(H * 0.32), gap = s(12),
    text(function() return ctx.clock:get() end, { id = kind .. "-clock", font_size = compact and s(76) or s(110), color = function() return C.primary end }),
    text(function() return ctx.day:get() end, { font_size = s(16) }),
    text("────────────────", { color = function() return stroke(C,"quiet") end }),
    text("PRESS ENTER TO CONTINUE", { font_size = s(12), visible = function() return not sheet() and main() end }),
  }
  local frame = ui.Rect { anchors = { fill = true }, border_width = 1,
    color = function() return C.surfaceContainer end, border_color = function() return stroke(C,"focus") end }
  local panel = ui.Item { id = kind .. "-sheet", width = PW, height = height,
    x = math.floor((W - PW) / 2),
    y = function() return math.max(s(20), math.floor((H - height()) / 2)) end,
    visible = false,
    translate_x = function() return ctx.shake:get() == 1 and s(10) or 0 end,
    behavior = { translate_x = { duration = 100, easing = "out_cubic" },
      height = { duration = 240, easing = "in_out_cubic" }, y = { duration = 240, easing = "in_out_cubic" } },
    frame,
    folio,
    content,
  }
  local presentation = ui.Item { id = kind .. "-phase-progress", opacity = 0 }
  local running
  frame.opacity = 0
  content.opacity = 1
  for _, node in ipairs(rows) do node.opacity = 0 end
  local function opacity_step(node, from, target, a, b, duration, inverse)
    local keys = {}
    for i = 0, 60 do
      local value = phase.ramp(from + (target-from)*i/60, a, b)
      keys[#keys+1] = { at = i/60, value = inverse and 1-value or value }
    end
    return { node = node, property = "opacity", duration = duration, keyframes = keys }
  end
  local shown = false
  morf.effect(kind .. ".tsugumori.reveal", function()
    local next_shown = sheet()
    if shown == next_shown then return end
    shown = next_shown
    if running then running:stop() end
    panel.visible = true
    local from, target = access.opacity, shown and 1 or 0
    local duration = math.max(1, (shown and 1450 or 950)*math.abs(target-from))
    local steps = {
      { node = access, property = "opacity", to = target, duration = duration, easing = "linear" },
      opacity_step(frame,from,target,0.10,0.35,duration),
      opacity_step(folio,from,target,0.28,0.67,duration),
      opacity_step(glance,from,target,0,0.28,duration,true),
    }
    for i, node in ipairs(rows) do
      local start = math.min(0.59,0.28+(i-1)*0.055)
      steps[#steps+1] = opacity_step(node,from,target,start,start+0.28,duration)
    end
    running = morf.animation.play {
      { parallel = steps },
      on_finished = function(reason) if reason == "completed" and not sheet() then panel.visible = false end end,
    }
    glyph_refresh(duration)
  end, { owner = panel })
  morf.animation.play { { node = presentation, property = "opacity", to = 1, duration = 1450, easing = "linear" } }
  local artwork, animate_artwork = phase.field(C, function() return presentation.opacity end,
    { id = kind .. "-phase-field", width = W, height = H })
  animate_artwork(1450)
  local root = { id = kind .. "-tsugumori", width = W, height = H, color = function() return C.surface:alpha(1) end,
    presentation, access, glyph_count,
    artwork,
    ui.Rect { x = s(18), y = s(18), width = W - s(36), height = H - s(36), color = "transparent",
      border_width = 1, border_color = function() return stroke(C,"idle") end },
    text(kind == "lock" and "TSUGUMORI / SESSION SECURED" or ((ctx.hostname or "SYSTEM"):upper() .. " / SYSTEM READY"), {
      x = s(38), y = s(34), font_size = s(12), color = function() return C.primary end }),
    glance,
    panel,
    -- The input under it all is the shared flow's (themes.layouts.auth_input).
    require("themes.layouts.auth_input").sheet { id = kind .. "-open", active = main, open = ctx.open_sheet,
      key = ctx.key, swipe = s(60) },
  }
  if kind == "lock" then
    root[#root + 1] = require("themes.tsugumori.lock_desktop")(ctx,W,H,main,output,s)
  end
  if kind == "greet" then
    root[#root + 1] = ui.Row { anchors = { right = true, right_margin = s(38), bottom = true, bottom_margin = s(34) }, gap = s(8),
      button("greet-suspend", "SUSPEND", s(90), function() ctx.power("Suspend", "suspend") end),
      button("greet-reboot", "RESTART", s(90), function() ctx.power("Reboot", "reboot") end),
      button("greet-poweroff", "POWER OFF", s(90), function() ctx.power("PowerOff", "power off") end),
    }
  end
  return ui.Rect(root)
end
