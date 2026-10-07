-- Tsugumori's look for the Form widgets: the error summary a square plate
-- tinted with the alert signal in an alert hairline, a hatched band down its
-- head, captions in caps; each field's message in the alert signal under it;
-- a settings page's status as a readout on the raised ground; and the lit
-- suggested key giving its caption over to the theme's running bars while
-- it sends. Everything moves on the theme's own glide. The layout is
-- lib.kit.form's, shared by every theme; what shows when, the archetype's.
local ui = require("morf.ui")
local look = require("lib.kit.form").look
local stripes = require("themes.tsugumori.stripes")

return function(S, theme, M, hud)
  local C = theme.color
  local function alert() return M.signal("alert")() end
  -- The hatch is drawn once, as tall as a plate can grow, and clipped.
  local BAND, TALL = 8, 320
  local L = look {
    text = M.text, icon = M.icon, loading = M.loading,
    spring = function() return M.spring() end,
    quick = function() return { duration = 140, easing = "out_cubic" } end,
    body = theme.size.small, small = theme.size.small, weight = 600, font = theme.mono,
    radius = 0, caps = true,
    tones = {
      error_ground = function() return alert():alpha(0.1) end,
      error_edge = function() return alert():alpha(0.7) end,
      error_ink = alert,
      ink = function() return C.onSurface end,
      ink_dim = function() return C.onSurfaceVariant end,
      hover = function() return alert():alpha(0.14) end,
      saved = function() return M.signal("ok")() end,
      unsaved = function() return C.primary end,
      status_ground = function() return C.surfaceContainerHigh end,
    },
    decorate = function(plate, height)
      ui.reparent(ui.Item { x = 1, y = 1, width = BAND, clip = true,
        height = function() return math.max(0, height() - 2) end,
        stripes.box { width = BAND, height = TALL, gap = 4, weight = 1.5,
          color = function() return alert():alpha(0.6) end } }, plate)
    end,
  }

  local function message() return L.message end

  --- A form: the alert plate over its fields, a message under each.
  S.Form = { summary = L.summary, message = message }
  S.form = S.Form
  S.login_form = S.Form
  --- A settings page: its status readout where a form's plate would be.
  S.settings_form = { summary = L.status, message = message }
  --- One row: a failed send says so on a line under it.
  S.inline_form = { summary = L.failure, message = message }

  --- The submit button: the lit suggested key, the running bars in its ink
  --- while it sends.
  function S.form_submit(t, spec, node, send)
    return L.submit(S.suggested(t, spec, node, send), t, spec, function() return C.onPrimary end)
  end
end
