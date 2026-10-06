-- The Drop page (a placeholder for https://github.com/termworks/drop), in
-- the page template (themes/layouts/page.lua): the frame draws its title.
local P = require("themes.layouts.page")
local M = {}
function M.build(model, w, h)
  return P.page { id = "drop-page", width = w, height = h,
    P.empty { id = "drop-placeholder", width = w, icon = "forum", title = "Messaging & file sharing",
      text = model.status },
  }
end
return M
