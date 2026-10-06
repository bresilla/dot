-- The controller supplies shared Lule state; themes own all composition.
-- One model; the page is built where it is shown (the quick settings'
-- Lule page), at that page's width, and scrolls when taller.
local ui = require("morf.ui")
local kit = require("kit")
local view = require("themes").view("lule_page")
local model = require("lule_model").new()
-- Its own size where it has the room: the dashboard-wide layout.
local M = { model = model, active = model.active, WIDTH = view.WIDTH, HEIGHT = view.HEIGHT }

--- The page at `w` x `h` (h a number or a function): the cards and their
--- controls, scrolled in that room.
function M.build(w, h)
  local visual = view.build(model, w)
  local height = type(h) == "function" and h or function() return h end
  return (kit.scroll({ id = "lule-scroll", width = w, height = height, clip = true,
    ui.Item { width = w, height = visual.height, visual.page } }))
end
return M
