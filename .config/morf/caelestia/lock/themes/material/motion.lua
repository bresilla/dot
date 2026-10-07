-- Material drawer choreography, separate from drawer state and placement.
local morf = require("morf")
return function(theme)
  local M = {}
  function M.drawer(ctx)
    local panel, spec, d = ctx.panel, ctx.spec, ctx.drawer
    local axis, floating, tucked = ctx.axis, ctx.floating, ctx.tucked
  local running
  -- A floating panel (edge "center") joins no edge: it grows in evenly
  -- about its centre as it and its background fade in, and shrinks a
  -- touch as they fade out.
  local function pop(opening)
    local hidden = not panel.visible
    if running then running:stop() end
    if opening then panel.visible = true end
    running = morf.animation.play {
      {
        parallel = {
          { node = panel, property = "scale", from = opening and hidden and 0.92 or nil, to = opening and 1 or 0.96,
            duration = opening and 420 or 160, easing = opening and theme.ease.spatial or theme.ease.emphasized_accel },
          { node = panel, property = "opacity", from = opening and hidden and 0 or nil, to = opening and 1 or 0,
            duration = opening and 180 or 140 },
          { node = d.shape, property = "opacity", from = opening and hidden and 0 or nil, to = opening and 1 or 0,
            duration = opening and 180 or 140 },
        },
      },
      on_finished = function(reason)
        if reason == "completed" and not d.open:get() then panel.visible = false end
      end,
    }
  end
  local function move(opening)
    if floating then return pop(opening) end
    local hidden = not panel.visible
    if running then running:stop() end
    if opening then panel.visible = true end
    local slide = {
      node = panel, property = axis, to = opening and 0 or tucked(),
      duration = opening and theme.duration.drawer_open or theme.duration.drawer_close,
      easing = opening and theme.ease.spatial or theme.ease.emphasized_accel,
    }
    -- The reference's contents fade in over the first hundred-odd
    -- milliseconds of the slide, and its background with them: the
    -- background is a layer of the frame's field, whose own opacity fades
    -- it -- fillet and all -- and leaves the frame as it is. Closing only
    -- slides.
    if opening and hidden then
      spec.content.opacity = 0
      d.shape.opacity = 0
    end
    local fade = { duration = opening and 150 or 1, easing = theme.ease.standard_decel }
    running = morf.animation.play {
      {
        parallel = {
          slide,
          { node = spec.content, property = "opacity", to = 1,
            duration = fade.duration, easing = fade.easing },
          { node = d.shape, property = "opacity", to = 1,
            duration = fade.duration, easing = fade.easing },
        },
      },
      on_finished = function(reason)
        if reason == "completed" and not d.open:get() then panel.visible = false end
      end,
    }
  end

    return move, function() if running then running:stop() running=nil end end
  end
function M.entries(entries, coming, opts)
    if require("themes.session").restoring then
      for _, entry in ipairs(entries) do
        entry.node.opacity = coming and 1 or 0
        entry.node.scale, entry.node.translate_x, entry.node.translate_y = 1, 0, 0
        if entry.shape then entry.shape.opacity = coming and 1 or 0 end
      end
      return {}, 0
    end
  opts = opts or {}
  local handles = {}
  for k, entry in ipairs(entries) do
    local n = entry.node
    local fresh = not (n.opacity > 0 and n.opacity < 1)
    local steps
    if coming then
      local delay = (opts.delay or 40) + (k - 1) * (opts.stagger or 26)
      steps = {
        { node = n, property = "scale", from = fresh and (opts.from or 0.92) or nil, to = 1, duration = 420, easing = theme.ease.spatial, delay = delay },
        { node = n, property = "opacity", from = fresh and 0 or nil, to = 1, duration = 220, delay = delay },
      }
    else
      steps = {
        { node = n, property = "scale", to = 0.96, duration = 160, easing = theme.ease.emphasized_accel, delay = (k - 1) * (opts.leave_stagger or 0) },
        { node = n, property = "opacity", to = 0, duration = 120, delay = (k - 1) * (opts.leave_stagger or 0) },
      }
    end
    if entry.shape then
      steps[#steps + 1] = { node = entry.shape, property = "opacity", from = coming and fresh and 0 or nil,
        to = coming and 1 or 0, duration = coming and 220 or 120,
        delay = coming and ((opts.delay or 40) + (k - 1) * (opts.stagger or 26)) or 0 }
    end
    handles[#handles + 1] = morf.animation.play { { parallel = steps } }
  end
  return handles, coming and (420 + #entries * (opts.stagger or 26)) or 200
end

  return M
end
