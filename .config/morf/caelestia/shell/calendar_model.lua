local morf=require("morf")
local M={}
function M.new(ctx)
  local planner=ctx.planner or require("planner")
  local model={key="calendar",active=ctx.active,days=morf.list_model({}),agenda=morf.list_model({}),
    month=morf.signal("caelestia.calendar.title",""),selected_day=planner.selected_day,error=planner.client.error,
    weekdays={"M","T","W","T","F","S","S"}}
  morf.effect("caelestia.calendar.month",function()
    if not model.active() then return end
    morf.minute_clock:get()
    local today=morf.time.date()
    local first=morf.time.time {year=today.year,month=today.month,day=1,hour=12}
    first=morf.time.add(first,{months=planner.month_offset:get()})
    local date=morf.time.date(first)
    model.month:set(morf.time.format("%B %Y",first))
    local out={}
    for _,week in ipairs(morf.time.month(date.year,date.month,1)) do for _,day in ipairs(week) do
      local key=("%04d-%02d-%02d"):format(day.year,day.month,day.day)
      out[#out+1]={key=key,day=day.day,current=day.current,today=key==morf.time.format("%Y-%m-%d"),count=#planner.agenda(key)}
    end end
    model.days:replace(out,"key")
  end)
  morf.effect("caelestia.calendar.agenda",function()
    if model.active() then model.agenda:replace(planner.agenda(model.selected_day:get()),"uuid") end
  end)
  function model.day_title()
    local t=morf.time.parse(model.selected_day:get())
    return t and morf.time.format("%A, %d %B",t) or model.selected_day:get()
  end
  function model.step(delta) if model.active() then planner.month_offset:set(planner.month_offset:get()+delta) end end
  function model.today()
    if not model.active() then return end
    planner.month_offset:set(0) model.selected_day:set(morf.time.format("%Y-%m-%d"))
  end
  function model.select(day)
    if model.active() and type(day)=="string" and day:match("^%d%d%d%d%-%d%d%-%d%d$") and morf.time.parse(day) then model.selected_day:set(day) end
  end
  function model.plan() if model.active() then ctx.edit(nil,model.selected_day:get()) end end
  function model.edit(id)
    if not model.active() then return false end
    for _,row in ipairs(planner.client.tasks:get()) do if row.uuid==id then ctx.edit(row) return true end end
    return false
  end
  return model
end
return M
