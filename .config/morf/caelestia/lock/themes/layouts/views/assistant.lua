-- The Assistant page, in the page template (themes/layouts/page.lua): the
-- frame draws its title; under it, what the page says while no provider is
-- connected, and where its connection stands.
local P = require("themes.layouts.page")
local M = {}
function M.build(model, w, h)
  local inner = P.inner(w)
  return P.page { id = "assistant-page", width = w, height = h,
    P.empty { id = "assistant-welcome", width = w, icon = "auto_awesome", title = "Room to think.",
      text = "Your assistant has a new home. Connect a provider to start a conversation." },
    P.section { id = "assistant-connection", width = w, title = "Connection",
      P.row { id = "assistant-provider", width = inner, icon = "forum", on = function() return false end,
        title = "Provider", subtitle = model.status },
      P.row { id = "assistant-context", width = inner, icon = "history", on = function() return false end,
        title = "Conversations", subtitle = "Conversations and context will live here." },
    },
  }
end
return M
