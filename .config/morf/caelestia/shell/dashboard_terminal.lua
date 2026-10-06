-- The dashboard's Terminal tab: shells of the user's own, in tabs. The view
-- owns them (they live while the shell does).
local state = require("dashboard_state")
local view = require("themes").view("dashboard_terminal")
local visual = view.build(state.context(6))
return { WIDTH = view.WIDTH, HEIGHT = view.HEIGHT, page = visual.page }
