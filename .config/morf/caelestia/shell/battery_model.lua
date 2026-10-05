-- Battery readings and bounded source history, independent of presentation.
local sysinfo=require("lib.services.sysinfo")
local M={}
function M.duration(seconds)
  if not seconds or seconds<=0 then return "--" end
  local h,m=seconds//3600,(seconds%3600)//60
  return h>0 and ("%dh %02dm"):format(h,m) or ("%dm"):format(m)
end
function M.number(value,format) return value and format:format(value) or "--" end
function M.new(ctx)
  local model={active=ctx.opened,samples=sysinfo.history_size,
    interval=sysinfo.sources.battery.interval,number=M.number,duration=M.duration}
  model.minutes=("%d min"):format(math.floor(model.samples*model.interval/60000+.5))
  local last={batteries={}}
  local series={}
  function model.state()
    if model.active() then
      local ok,value=pcall(sysinfo.battery)
      last=ok and type(value)=="table" and value or {batteries={}}
    end
    return last
  end
  function model.battery() return (model.state().batteries or {})[1] or {} end
  function model.charging() return model.battery().status=="Charging" end
  function model.present() return model.battery().name~=nil end
  function model.series(field)
    if model.active() then
      local key="bat:"..(model.battery().name or "BAT0")..":"..field
      local ok,value=pcall(sysinfo.history,key)
      series[field]=ok and type(value)=="table" and value or {}
    end
    return series[field] or {}
  end
  function model.remaining()
    local state=model.state()
    return M.duration(model.charging() and state.time_to_full or state.time_left)
  end
  function model.limit()
    local b=model.battery()
    if not b.charge_limit then return "--" end
    return b.charge_start and ("%d–%d %%"):format(b.charge_start,b.charge_limit) or ("%d %%"):format(b.charge_limit)
  end
  function model.voltage_bottom()
    local design=model.battery().voltage_design or 0
    local low=design>0 and design*.92 or 0
    for _,v in ipairs(model.series("voltage")) do if v>0 and v<low then low=v*.98 end end
    return low
  end
  function model.voltage_top()
    local peak=(model.battery().voltage_design or 0)*1.05
    for _,v in ipairs(model.series("voltage")) do peak=math.max(peak,v*1.02) end
    return math.max(1,peak)
  end
  return model
end
return M
