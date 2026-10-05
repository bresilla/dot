-- Shared weather readings and formatting. Views own geometry and animation.
local morf = require("morf")
local services = require("services")
local M = {}
function M.place_name(place)
  place = tostring(place or "")
  return place:match("^([^,]+)") or place
end
function M.clock(time)
  if not time then return "--" end
  return (morf.time.format("%I:%M %p", time):gsub("^0", ""))
end
function M.new(ctx)
  local model = { active=ctx.opened, clock=M.clock, symbol=services.weather_symbol }
  local last = { available=false }
  function model.now()
    if model.active() then last=services.weather() or {available=false} end
    return last
  end
  function model.place()
    local w=model.now()
    return w.available and M.place_name(w.place) or "Weather"
  end
  function model.date()
    morf.minute_clock:get()
    return morf.time.format("%A, %B %-d")
  end
  function model.temperature(value,bare)
    if value==nil then return "--" end
    local w=model.now()
    return ("%d%s"):format(math.floor(value+.5),bare and "°" or (w.units and w.units.temperature) or "°")
  end
  function model.day(index) return (model.now().daily or {})[index] end
  function model.today() return model.day(1) or {} end
  function model.day_name(index)
    if index==1 then return "Today" end
    local d=model.day(index)
    return d and d.time and morf.time.format("%a",d.time) or "--"
  end
  function model.day_date(index)
    local d=model.day(index)
    return d and d.time and morf.time.format("%b %-d",d.time) or ""
  end
  function model.humidity()
    local value=model.now().humidity
    return value and ("%d%%"):format(math.floor(value+.5)) or "--"
  end
  function model.wind()
    local w=model.now()
    return w.wind_speed and ("%.1f %s"):format(w.wind_speed,(w.units and w.units.wind) or "km/h") or "--"
  end
  function model.count() return math.min(7,#(model.now().daily or {})) end
  function model.forecast_title()
    local count=model.count()
    return count>0 and (count.."-day forecast") or "Forecast"
  end
  function model.range(index)
    local minimum,maximum
    for i=1,model.count() do
      local d=model.day(i)
      if d.low and d.high then
        minimum=math.min(minimum or d.low,d.low)
        maximum=math.max(maximum or d.high,d.high)
      end
    end
    local d=model.day(index)
    if not minimum or not d or not d.low or not d.high then return 0,0 end
    local span=math.max(1,maximum-minimum)
    return (d.low-minimum)/span,math.max(0,d.high-d.low)/span
  end
  return model
end
return M
