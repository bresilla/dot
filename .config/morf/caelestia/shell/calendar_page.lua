local M={}
function M.build(w,h)
  local model=require("calendar_model").new {
    active=require("presentation").active("leftbar.calendar"),
    edit=function(task,day)
      require("leftbar").panel.select("tasks") require("tasks_page").edit(task,day)
    end,
  }
  return require("themes").view("calendar_page").build(model,w,h)
end
return M
