-- Audio-route snapshots, independent of volume and default-device selection.
local morf=require("morf")
local M={}
local function lower(value) return type(value)=="string" and value:lower() or "" end
local function kind(value)
  value=lower(value)
  if value:find("earbud",1,true) or value:find("earphone",1,true) or value:find("in-ear",1,true)
    or value:find("airpods",1,true) or value:find("buds",1,true) then return "earbuds" end
  if value:find("headphone",1,true) or value:find("headset",1,true) then return "headphones" end
end
function M.devices(rows)
  local found={}
  for _,sink in ipairs(rows or {}) do
    local props=sink.properties or {}
    local label=props["device.alias"] or props["device.description"] or sink.description or sink.name or "Headphones"
    local hints=table.concat({label,props["device.form_factor"] or "",props["device.icon_name"] or sink.icon_name or ""}," ")
    local category=kind(hints)
    local address=props["api.bluez5.address"] or (sink.name or ""):match("bluez_output%.([%x_]+)")
    local identity=address and ("bluetooth:"..address:gsub("_",":"):lower())
      or props["device.name"] or sink.name or tostring(sink.id or sink.index)
    local ports=sink.ports or {}
    local has_route=false
    for _,port in pairs(ports) do
      local port_kind=kind((port.type or "").." "..(port.name or "").." "..(port.description or ""))
      if port_kind then
        has_route=true
        local availability=lower(port.availability)
        local plugged=availability=="available" or availability=="yes"
          or ((availability=="availability unknown" or availability=="unknown" or availability=="")
            and sink.active_port==port.name)
        if plugged then
          local id=address and identity or identity..":"..(port.name or "headphones")
          local chosen=category=="earbuds" and "earbuds" or port_kind
          if props["device.form_factor"]=="internal" then label=port.description or "Headphones" end
          found[id]={id=id,name=label,kind=chosen}
        end
      end
    end
    if category and not has_route then found[identity]={id=identity,name=label,kind=category} end
  end
  return found
end
function M.new(connected)
  local known, expiry, initialized={}, {},false
  local tracker={}
  function tracker.update(rows)
    local current=M.devices(rows)
    local additions={}
    for id,device in pairs(current) do
      if expiry[id] then expiry[id]:cancel() expiry[id]=nil end
      if initialized and not known[id] then additions[#additions+1]=device end
      known[id]=device
    end
    -- A Bluetooth profile handoff briefly removes/recreates its sink. Keep
    -- identity for a short grace period; never grow a permanent device history.
    for id in pairs(known) do
      if not current[id] and not expiry[id] then
        expiry[id]=morf.timer(1000,function() known[id]=nil expiry[id]=nil end,false)
      end
    end
    initialized=true
    table.sort(additions,function(a,b) return a.id<b.id end)
    for _,device in ipairs(additions) do connected(device) end
  end
  function tracker.stop()
    for _,timer in pairs(expiry) do timer:cancel() end
    known,expiry,initialized={}, {},false
  end
  return tracker
end
return M
