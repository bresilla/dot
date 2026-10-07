-- GAME-inspired title decode and registration lights. See REFERENCE.md.
-- Titles decode once; their leading light pulses a couple of times while in
-- view and then rests (finite: nothing animates at rest).
local morf = require("morf")
local ui = require("morf.ui")
local symbols = { "!", "<", ">", "-", "_", "/", "[", "]", "{", "}", "=", "+", "*", "^", "?", "#" }
return function(theme, kit, props)
  local C, source = theme.color, props.text
  local active = props.active or function() return true end
  local pace = 0.5
  local tick = 40
  local delay = (props.reveal_delay or 560) * pace
  local lead, stagger = (props.decode_lead or 650) * pace, (props.decode_stagger or 80) * pace
  local size = props.font_size or 14
  local id = assert(props.id, "animated headings need a stable id")
  local function caption()
    local value = source
    if type(value) == "function" then value = value() end
    return tostring(value or ""):upper()
  end
  local height = props.height or math.ceil(size * 1.5)
  local width = props.width or function() return utf8.len(caption()) * size * 0.65 + 18 end
  local function available()
    return math.max(0,(type(width)=="function" and width() or width)-16)
  end
  local alignment=props.horizontal_alignment
  -- A centered/right-aligned label's box can be much wider than its word.
  -- Measure the actual font so the light follows the word, not the box edge.
  local measure
  if alignment=="center" or alignment=="right" then
    measure=kit.text {id=id.."-measure",height=height,opacity=0,
      font_size=size,font_weight=props.font_weight or 500,text=caption}
  end
  local function label(suffix, color)
    return kit.text { id = id .. suffix, x = 16, width = available,
      height = height, font_size = size, font_weight = props.font_weight or 500,
      horizontal_alignment = props.horizontal_alignment, vertical_alignment = props.vertical_alignment or "center",
      elide = props.elide or "right", text = caption(), color = color }
  end
  -- The split-colour ghosts exist from a title's first decode on, not
  -- before: most titles of a shell sit in pages never opened.
  local a, b
  local title = label("-text", props.color or function() return C.primary end)
  -- Uppercase letter ink sits above the line box's midpoint because that
  -- box also reserves space for descenders. Raise the pip optically.
  local pip = ui.Rect { id = id .. "-light", x = function()
      if not measure then return 0 end
      local spare=math.max(0,available()-(measure.layout_width or available()))
      return alignment=="center" and spare/2 or spare
    end,
    anchors={vertical_center=true,vertical_center_offset=-math.max(1,size*.075)},
    width = 5, height = 5, opacity = 0.18, color = props.color or function() return C.primary end }
  -- The blink's next pulse, cancelled with the title: it would reach for a
  -- pip that is gone.
  local light_clock
  local node = ui.Item { id = id, x = props.x, y = props.y, anchors = props.anchors,
    on_destroyed = function() if light_clock then light_clock:cancel() light_clock = nil end end,
    width = width, height = height, visible = props.visible, title, pip }
  local function ghosts()
    if a then return end
    a = label("-ghost-a", function() return C.secondary end)
    b = label("-ghost-b", function() return C.tertiary end)
    a.opacity, b.opacity, a.z, b.z = 0, 0, -1, -1
    ui.reparent(a, node) ui.reparent(b, node)
  end
  if measure then ui.reparent(measure,node) end
  local timer, flash, light
  -- Random pauses are timer-driven; only the short burst needs animation
  -- frames. Every title chooses fresh timing independently on each burst.
  local light_on=false
  local PULSES, pulses = 2, 0
  local pulse
  local function schedule(low, high)
    if light_clock then light_clock:cancel() end
    light_clock = morf.timer(math.random(low, high), pulse, false)
  end
  function pulse()
    light_clock=nil
    if not light_on then return end
    if light then light:stop() end
    morf.animation.stop(pip,"opacity")
    light=morf.animation.play {
      {node=pip,property="opacity",duration=460,keyframes={
        {at=0,value=.18},{at=.15,value=1},{at=.4,value=.18},
        {at=.6,value=.18},{at=.75,value=1},{at=1,value=.18},
      }},
    }
    pulses=pulses+1
    light_clock=nil
    if pulses<PULSES then schedule(7000,11000) end
  end
  local elapsed, duration, letters, final, shown = 0, 0, {}, "", nil
  local function finish()
    timer.running = false
    if flash then flash:finish() flash = nil end
    title.text = final
    shown = final
    if a then a.text, b.text, a.opacity, b.opacity = final, final, 0, 0 end
  end
  local function paint()
    local output, t = {}, elapsed - delay
    for i, char in ipairs(letters) do
      if char:match("%s") or t >= lead + math.min(i - 1, 9) * stagger then
        output[i] = char
      else
        output[i] = symbols[(i * 7 + math.floor(math.max(0, t) / tick) * 11) % #symbols + 1]
      end
    end
    -- Only the title scrambles; the split-colour ghosts carry the final
    -- word (they flash once, offset), so a tick re-shapes one run, and only
    -- when the scramble actually moved.
    local value = table.concat(output)
    if value ~= shown then shown = value title.text = value end
  end
  timer = ui.Timer { id = id .. "-decode", interval = tick, ["repeat"] = true, running = false,
    on_triggered = function()
      elapsed = elapsed + tick
      if elapsed >= duration then finish() else paint() end
    end }
  ui.reparent(timer, node)
  local was, previous = false, nil
  local function in_view()
    local viewports = props.viewports or (props.viewport and {props.viewport}) or {}
    if #viewports == 0 then return true end
    -- Read our geometry before the parent exists; its first layout re-runs
    -- this effect after the enclosing viewport has finished construction.
    local x, y = node.layout_x, node.layout_y
    if not x or not y then return false end
    local right, bottom = x + (node.layout_width or 0), y + (node.layout_height or 0)
    for _, get_view in ipairs(viewports) do
      local view = get_view()
      if not view then return false end
      local vx, vy = view.layout_x, view.layout_y
      if not vx or not vy then return false end
      x, y = math.max(x, vx), math.max(y, vy)
      right = math.min(right, vx + (view.layout_width or 0))
      bottom = math.min(bottom, vy + (view.layout_height or 0))
      if right <= x or bottom <= y then return false end
    end
    return true
  end
  morf.effect(id .. ".appearance."..(props.effect_scope or ""), function()
    local visible = props.visible
    if type(visible) == "function" then visible = visible() end
    local on, value = active() and visible ~= false and in_view(), caption()
    local blink=on and value~=""
    if blink~=light_on then
      light_on=blink
      if blink then
        pulses=0
        schedule(4000,9000)
      else
        if light_clock then light_clock:cancel() light_clock=nil end
        if light then light:stop() light=nil end
        morf.animation.stop(pip,"opacity")
        pip.opacity=.18
      end
    end
    if on == was and value == previous then return end
    was, previous, final = on, value, value
    finish()
    if not on or value == "" then return end
    letters = {}
    for _, code in utf8.codes(value) do letters[#letters + 1] = utf8.char(code) end
    elapsed, duration = 0, delay + lead + math.min(#letters - 1, 9) * stagger
    paint()
    timer.running = true
    ghosts()
    a.text, b.text = value, value
    -- The split-color title flash remains finite.
    local tracks = {}
    for i, ghost in ipairs { a, b } do
      tracks[#tracks + 1] = { node = ghost, property = "translate_x", from = i == 1 and -3 or 3,
        to = 0, delay = delay, duration = 280 * pace, easing = "out_cubic" }
      tracks[#tracks + 1] = { node = ghost, property = "opacity", delay = delay, duration = 280 * pace,
        keyframes = { {at=0,value=0}, {at=0.25,value=0.65}, {at=1,value=0} } }
    end
    flash = morf.animation.play { { parallel = tracks } }
  end, { owner = node })
  return node
end
