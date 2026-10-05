local morf=require("morf")
local M={}
M.FIELDS={
  {"description","Task","What needs doing?"},
  {"project","Project","work.website"},
  {"priority","Priority","H, M or L — leave blank for none"},
  {"scheduled","Scheduled · start date & time","tomorrow or 2026-10-01T09:00"},
  {"due","Due · deadline","friday or 2026-10-02T17:00"},
  {"wait","Hide until","tomorrow — leave blank to show now"},
  {"tags","Tags","work, calls"},
  {"recur","Repeat","daily, weekly, monthly — needs a due date"},
  {"until","Stop repeating after","2026-12-31"},
  {"depends","Depends on tasks","Task IDs or UUIDs, separated by commas"},
}
function M.new(ctx)
  local planner=ctx.planner or require("planner")
  local client=planner.client
  local initial={}
  for _,spec in ipairs(M.FIELDS) do initial[spec[1]]="" end
  local model={key="tasks",active=ctx.active,close=ctx.close,FIELDS=M.FIELDS,
    help="Dates accept Taskwarrior expressions or a date and time. Editing a repeating occurrence changes only that occurrence.",
    editing=require("themes.session").keep("caelestia.tasks.editing",false),deleting=require("themes.session").keep("caelestia.tasks.deleting",false),
    query=require("themes.session").keep("caelestia.tasks.query",""),filter=require("themes.session").keep("caelestia.tasks.filter","Open"),
    selected=require("themes.session").keep("caelestia.tasks.selected",""),editor_revision=require("themes.session").keep("caelestia.tasks.editor",0),
    draft=morf.state(require("themes.session").restore("tasks.draft",initial)),rows=morf.list_model({}),error=client.error,busy=client.busy,loaded=client.loaded,
    count=morf.signal("caelestia.tasks.count",0)}
  local original,session=require("themes.session").restore("tasks.original",{}),0
  require("themes.session").register("tasks.original",function() return original end)
  require("themes.session").register("tasks.draft",function()
    local values={}
    for _,field in ipairs(M.FIELDS) do values[field[1]]=model.draft[field[1]] end
    return values
  end)
  local function task(id)
    for _,row in ipairs(client.tasks:get()) do if row.uuid==id then return row end end
  end
  function model.edit(row,day)
    if row then
      row=task(type(row)=="table" and row.uuid or row)
      if not row then client.error:set("This task is no longer available.") return false end
    end
    session=session+1 model.selected:set(row and row.uuid or "") model.deleting:set(false)
    original={}
    for _,spec in ipairs(M.FIELDS) do
      local name=spec[1]
      local value=row and row[name] or ""
      if name=="tags" or name=="depends" then value=type(value)=="table" and table.concat(value,",") or value end
      if name=="due" or name=="scheduled" or name=="wait" or name=="until" then value=planner.dates.date(value) end
      if name=="scheduled" and day then value=day.."T09:00" end
      original[name]=tostring(value or "") model.draft[name]=original[name]
    end
    client.error:set("") model.editing:set(true) model.editor_revision:set(model.editor_revision:get()+1)
    return true
  end
  function model.set_field(name,value)
    if not model.editing:get() then return end
    for _,spec in ipairs(M.FIELDS) do if spec[1]==name then model.draft[name]=value model.deleting:set(false) return end end
  end
  function model.cancel() session=session+1 model.deleting:set(false) model.editing:set(false) end
  local function writable()
    if not model.active() or client.busy:get() then return false end
    local dry=morf.env("CAELESTIA_DRY_RUN")
    if dry and dry~="" and dry~="0" then client.error:set("Task changes are disabled in this preview.") return false end
    return true
  end
  local function saved(serial)
    return function(ok) if ok and serial==session then model.cancel() end end
  end
  function model.save()
    if not model.editing:get() or not writable() then return false end
    local id=model.selected:get()
    if id~="" and not task(id) then client.error:set("This task is no longer available.") return false end
    local fields={description=model.draft.description}
    for _,spec in ipairs(M.FIELDS) do
      local name=spec[1]
      if id=="" or model.draft[name]~=original[name] then fields[name]=model.draft[name] end
    end
    return client.save(id~="" and id or nil,fields,saved(session))
  end
  function model.complete(id)
    if not writable() or not task(id) then return false end
    return client.action(id,"done")
  end
  local running=false
  function model.running()
    if model.active() then
      local id=model.selected:get()
      local row=id~="" and task(id) or nil
      running=row and row.start~=nil or false
    end
    return running
  end
  local function selected_action(action)
    if not model.editing:get() or not writable() then return false end
    local id=model.selected:get()
    if not task(id) then client.error:set("This task is no longer available.") return false end
    return client.action(id,action,saved(session))
  end
  function model.finish() return selected_action("done") end
  function model.start_stop() return selected_action(model.running() and "stop" or "start") end
  function model.delete()
    if model.selected:get()=="" or not model.editing:get() or not model.active() then return false end
    if not model.deleting:get() then model.deleting:set(true) return false end
    return selected_action("delete")
  end
  function model.refresh() if model.active() then return client.refresh() end end
  function model.set_filter(value)
    if value=="Open" or value=="Today" or value=="Active" then model.filter:set(value) end
  end
  morf.effect("caelestia.tasks.rows",function()
    if not model.active() then return end
    morf.minute_clock:get()
    local found,q,f={},model.query:get():lower(),model.filter:get()
    local today=morf.time.format("%Y-%m-%d")
    local tasks=client.tasks:get()
    model.count:set(#tasks)
    for _,row in ipairs(tasks) do
      local haystack=(row.description.." "..(row.project or "").." "..table.concat(row.tags or {}," ")):lower()
      local due,scheduled=planner.dates.day(row.due),planner.dates.day(row.scheduled)
      local matches=f=="Open" or (f=="Active" and row.start~=nil)
        or (f=="Today" and ((due~="" and due<=today) or scheduled==today))
      if matches and (q=="" or haystack:find(q,1,true)) then
        local details={}
        if row.project and row.project~="" then details[#details+1]=row.project end
        if row.priority and row.priority~="" then details[#details+1]="Priority "..row.priority end
        if row.start then details[#details+1]="In progress" end
        if row.wait then details[#details+1]="Waiting" end
        local when=row.scheduled or row.due
        found[#found+1]={uuid=row.uuid,description=row.description,detail=table.concat(details," · "),
          date=when and ((row.scheduled and "Scheduled " or "Due ")..planner.dates.date(when,"%d %b · %H:%M")) or "No date · click to plan",
          overdue=due~="" and due<today}
      end
    end
    model.rows:replace(found,"uuid")
  end)
  return model
end
return M
