-- Small form controls shared by the Tasks and Calendar pages.
local ui = require("morf.ui")
local kit = require("kit")
local rows = require("themes.layouts.rows")
local theme = require("theme")
local C = theme.color
local M = {}

function M.label(text, props)
  props = props or {}
  props.text = text
  props.font_size = props.font_size or theme.size.small
  props.color = props.color or function() return C.onSurfaceVariant end
  return kit.section_label(props)
end
function M.subtitle(text, props)
  props = props or {}
  props.text = text
  props.font_size = props.font_size or theme.size.small
  props.color = props.color or function() return C.onSurfaceVariant end
  return kit.subtitle(props)
end
function M.button(id, text, icon, width, action, selected)
  return kit.pill {
    id = id, label = text, icon = icon, width = width, height = 36,
    on_clicked = action,
    color = function() return selected and selected() and C.primary or C.surfaceContainerHighest end,
    ink = function() return selected and selected() and C.onPrimary or C.onSurface end,
  }
end
function M.field(id, label, placeholder, width, changed, accepted, escaped)
  local input_node, input = kit.text_field("entry", {
    id = id, x = 12, width = width - 24, height = 40,
    font_family = theme.font, font_size = theme.size.normal,
    color = function() return C.onSurface end,
    placeholder_color = function() return C.onSurfaceVariant end,
    caret_color = function() return C.primary end,
    selection_color = function() return C.primary:alpha(0.3) end,
    placeholder = placeholder, on_text_changed = changed, on_accepted = accepted,
    on_escape = escaped,
  })
  local node = ui.Column { width = width, gap = 5,
    M.label(label),
    rows.well { width = width, height = 40, input_node },
  }
  return node, input
end
function M.message(text, width, height)
  return kit.subtitle { text = text, width = width, height = height or 46, wrap = true,
    font_size = theme.size.small, color = function() return C.onSurfaceVariant end }
end
return M
