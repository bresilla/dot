-- Material auth marker presentation, supplied with shared marker state.
local morf = require("morf")
local ui = require("morf.ui")
local theme = require("theme")
local kit = require("kit")
local C = theme.color
local V = {}
function V.build(model)
  local state = model.state
  local W, H, BADGE = 320, 76, 52

  local function step() return state.step end
  local function is(name) return function() return state.step == name end end

  local shake = morf.signal("caelestia.authsteps.shake", 0)
  local seen = 0
  morf.effect("caelestia.authsteps.shake", function()
    local n = state.failures
    if n > seen then
      shake:set(1)
      morf.timer(70, function() shake:set(0) end, false)
    end
    seen = n
  end)

  -- ------------------------------------------------------------- the glyphs --

  local function ink()
    local s = step()
    if s == "failed" then return C.onErrorContainer end
    if s == "ok" then return C.onPrimary end
    return C.onPrimaryContainer
  end

  -- Two eyes, the pupils looking one way and the other.
  local function eye(x)
    return kit.surface {
      x = x, y = 16, width = 14, height = 20, radius = 7,
      color = ink,
      kit.surface {
        x = 3, y = 6, width = 8, height = 8, radius = 4,
        color = function() return C.primaryContainer end,
        loop = function()
          if not model.opened:get() or step() ~= "face" then return nil end
          return { translate_x = { from = -2, to = 2, duration = 1100, alternate = true, easing = "in_out_sine" } }
        end,
      },
    }
  end
  local eyes = ui.Item {
    anchors = { fill = true }, visible = is("face"),
    eye(10), eye(28),
  }

  -- A fingerprint, a ring going out from it.
  local finger = ui.Item {
    anchors = { fill = true }, visible = is("finger"),
    kit.surface {
      anchors = { center_in = true }, width = 40, height = 40, radius = 20,
      color = function() return C.onPrimaryContainer:alpha(0) end,
      border_width = 2, border_color = function() return C.onPrimaryContainer end,
      loop = function()
        if not model.opened:get() or step() ~= "finger" then return nil end
        return {
          scale = { from = 0.7, to = 1.35, duration = 1400, easing = "out_cubic" },
          opacity = { from = 0.9, to = 0, duration = 1400, easing = "out_cubic" },
        }
      end,
    },
    kit.icon("fingerprint", 30, ink, { anchors = { center_in = true }, fill = true }),
  }

  -- A key, and a caret blinking beside it.
  local password = ui.Item {
    anchors = { fill = true }, visible = is("password"),
    kit.icon("key", 24, ink, { x = 9, anchors = { vertical_center = true }, fill = true }),
    kit.surface {
      x = 36, anchors = { vertical_center = true }, width = 3, height = 18, radius = 1,
      color = ink,
      loop = function()
        if not model.opened:get() or step() ~= "password" then return nil end
        return { opacity = { from = 1, to = 0, duration = 520, alternate = true } }
      end,
    },
  }

  local verdict = ui.Item {
    anchors = { fill = true },
    visible = function() return step() == "ok" or step() == "failed" end,
    kit.icon(function() return step() == "ok" and "check" or "close" end, 30, ink,
      { anchors = { center_in = true }, fill = true }),
  }

  local badge = ui.Item {
    width = BADGE, height = BADGE,
    kit.shape {
      anchors = { fill = true },
      shape = function()
        local s = step()
        if s == "face" then return "cookie9" end
        if s == "finger" then return "soft_burst" end
        if s == "password" then return "pill" end
        if s == "failed" then return "sunny" end
        return "circle"
      end,
      color = function()
        local s = step()
        if s == "failed" then return C.errorContainer end
        if s == "ok" then return C.primary end
        return C.primaryContainer
      end,
      loop = function()
        if not model.opened:get() or (step() ~= "face" and step() ~= "finger") then return nil end
        return { rotation = { to = 360, duration = 9000, hold = true } }
      end,
    },
    eyes, finger, password, verdict,
    kit.decor("corners", { length = 6, color = kit.stroke("mark") }) or ui.Item {},
  }

  -- --------------------------------------------------------------- the pill --

  local WORDS = {
    face = "Looking for your face",
    finger = "Touch the fingerprint sensor",
    password = "Type your password",
    ok = "Authorized",
    failed = "Not authorized",
  }

  local content = ui.Item {
    id = "authsteps",
    anchors = { fill = true },
    ui.Row {
      x = 14, anchors = { vertical_center = true }, gap = 14, align = "center",
      translate_x = function() return shake:get() == 1 and 10 or 0 end,
      behavior = { translate_x = ui.spring { stiffness = 900, damping = 9 } },
      badge,
      ui.Column {
        gap = 2,
        kit.heading { id = "authsteps-title", scope = "authsteps", level = "section",
          font_weight = 600, width = W - BADGE - 50, elide = "right",
          text = function()
            local svc = state.service ~= "" and state.service or "Authentication"
            return svc
          end,
        },
        kit.subtitle {
          font_size = theme.size.small, width = W - BADGE - 50, elide = "right",
          color = function() return step() == "failed" and kit.signal("alert")() or kit.ink("lo")() end,
          text = function()
            local s = step()
            if state.failures > 0 and (s == "face" or s == "finger" or s == "password") then
              return "Try again · " .. (WORDS[s] or "")
            end
            return WORDS[s] or ""
          end,
        },
      },
    },
  }

  if theme.motion.auth_result then
    theme.motion.auth_result(content,"authsteps",{active=function() return model.opened:get() end,
      read=function() return state.step,state.failures end})
  end
  return {content=content,width=W,height=H,edge="top"}
end
return V
