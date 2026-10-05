-- A wide workspace ready for an assistant connection.
local ui = require("morf.ui")
local kit = require("kit")
local theme = require("theme")
local C = theme.color
local M = {}
function M.build(model, w, h)
  local wide = w >= 680
  local x = wide and 232 or 16
  return kit.card { id = "assistant-page", width = w, height = h,
    kit.card { x = 16, y = 16, width = 200, height = function() return h() - 32 end, visible = wide,
      color = function() return C.surfaceContainerHigh end,
      kit.icon("forum", 28, function() return C.primary end, { x = 20, y = 22 }),
      kit.heading { id = "assistant-title", active = model.active, width = 164, x = 20, y = 66, text = model.title, font_size = 22, font_weight = 700 },
      kit.subtitle { x = 20, y = 106, width = 160, height = 80, wrap = true,
        text = "Conversations and context will live here.", color = function() return C.onSurfaceVariant end },
      kit.section_label { x = 20, y = function() return h() - 84 end, text = model.status, font_size = theme.size.small,
        color = function() return C.outline end },
    },
    ui.Item { x = x, y = 16, width = w - x - 16, height = function() return h() - 32 end,
      ui.Column { anchors = { center_in = true }, gap = 14, align = "center",
        kit.shape { shape = "cookie9", width = 86, height = 86, color = function() return C.primaryContainer end,
          kit.icon("auto_awesome", 38, function() return C.onPrimaryContainer end, { anchors = { center_in = true } }) },
        kit.heading { id = "assistant-welcome-title", active = model.active, text = "Room to think.", font_size = 32, font_weight = 700 },
        kit.subtitle { width = w - x - 48, height = 72, wrap = true, horizontal_alignment = "center",
          text = "Your assistant has a new home. Connect a provider to start a conversation.",
          color = function() return C.onSurfaceVariant end },
      },
    },
  }
end
return M
