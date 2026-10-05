local model=require("tasks_model").new {
  active=require("presentation").active("leftbar.tasks"),
  close=function() require("leftbar").drawer.set(false) end,
}
local M={edit=model.edit}
function M.build(w,h) return require("themes").view("tasks_page").build(model,w,h) end
return M
