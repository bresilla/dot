-- Material 3's look for the Form widgets: the error summary a tonal card in
-- errorContainer at 12 px corners sliding down over the fields once a send
-- was tried, each field's message in the error role with its glyph under
-- it (the supporting line's place), a settings page's status on
-- surfaceContainer, and the filled button giving its label over to M3
-- expressive's loading indicator while it sends. The layout is
-- lib.kit.form's, shared by every theme; what shows when, the archetype's.
local look = require("lib.kit.form").look

return function(S, theme, M)
  local function C() return theme.color end
  local L = look {
    text = M.text, icon = M.icon, loading = M.loading,
    spring = function() return M.spring(460, 30) end,
    quick = function() return { duration = theme.duration.small, easing = theme.ease.standard } end,
    body = theme.size.normal, small = theme.size.small, weight = 500,
    radius = 12,
    tones = {
      error_ground = function() return C().errorContainer end,
      error_ink = function() return C().error end,
      banner_ink = function() return C().onErrorContainer end,
      banner_label = function() return C().onErrorContainer end,
      banner_dim = function() return C().onErrorContainer:alpha(0.78) end,
      ink = function() return C().onSurface end,
      ink_dim = function() return C().onSurfaceVariant end,
      hover = function() return C().onErrorContainer:alpha(0.08) end,
      saved = function() return C().primary end,
      unsaved = function() return C().tertiary end,
      status_ground = function() return C().surfaceContainer end,
    },
  }

  local function message() return L.message end

  --- A form: the summary card over its fields, a message under each.
  S.Form = { summary = L.summary, message = message }
  S.form = S.Form
  S.login_form = S.Form
  --- A settings page: its status where a form's summary would be.
  S.settings_form = { summary = L.status, message = message }
  --- One row: a failed send says so on a line under it.
  S.inline_form = { summary = L.failure, message = message }

  --- The submit button: the filled button, the loading indicator in its
  --- ink while it sends.
  function S.form_submit(t, spec, node, send)
    return L.submit(S.suggested(t, spec, node, send), t, spec, function() return C().onPrimary end)
  end
end
